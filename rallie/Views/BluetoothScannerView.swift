import SwiftUI
import CoreBluetooth

struct BluetoothScannerView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var isScanning = false
    @Environment(\.presentationMode) var presentationMode
    @State private var showCommandView = false
    
    // Manual command input states
    @State private var byteInputs: [String] = Array(repeating: "00", count: 9)
    @State private var calculatedCRC: String = "00"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showManualCommandSection = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Connection status
                HStack {
                    Image(systemName: bluetoothManager.isConnected ? "bluetooth.connected" : "bluetooth")
                        .foregroundColor(bluetoothManager.isConnected ? .blue : .gray)
                    Text(bluetoothManager.connectionStatus)
                        .font(.headline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Device list
                List {
                    ForEach(bluetoothManager.discoveredPeripherals, id: \.identifier) { peripheral in
                        Button(action: {
                            bluetoothManager.connectToPeripheral(peripheral)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(peripheral.name ?? "Unknown Device")
                                        .font(.headline)
                                    Text(peripheral.identifier.uuidString)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Show signal strength indicator
                                if let rssi = bluetoothManager.rssiValues[peripheral.identifier] {
                                    signalStrengthView(for: rssi)
                                }
                                
                                // Show connected indicator if this is the connected device
                                if bluetoothManager.targetPeripheral?.identifier == peripheral.identifier {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    
                    // Manual Command Section Toggle
                    if bluetoothManager.isConnected {
                        Section(header: Text("Manual Commands")) {
                            Button(action: {
                                withAnimation {
                                    showManualCommandSection.toggle()
                                }
                            }) {
                                HStack {
                                    Text(showManualCommandSection ? "Hide Manual Command Input" : "Show Manual Command Input")
                                    Spacer()
                                    Image(systemName: showManualCommandSection ? "chevron.up" : "chevron.down")
                                }
                            }
                            
                            if showManualCommandSection {
                                manualCommandSection
                            }
                        }
                    }
                }
                
                // Scan button
                Button(action: {
                    if isScanning {
                        bluetoothManager.stopScanning()
                        isScanning = false
                    } else {
                        bluetoothManager.startScanning()
                        isScanning = true
                    }
                }) {
                    Text(isScanning ? "Stop Scanning" : "Start Scanning")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isScanning ? Color.red : Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Bluetooth Devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Start scanning when view appears
                bluetoothManager.startScanning()
                isScanning = true
            }
            .onDisappear {
                // Stop scanning when view disappears
                bluetoothManager.stopScanning()
                isScanning = false
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Bluetooth Command"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // Manual Command Input Section
    var manualCommandSection: some View {
        VStack(spacing: 15) {
            Text("Enter 9 bytes (hex):")
                .font(.subheadline)
            
            // Row 1
            HStack(spacing: 10) {
                ForEach(0..<3) { index in
                    TextField("", text: $byteInputs[index])
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                        .multilineTextAlignment(.center)
                        .onChange(of: byteInputs[index]) { newValue in
                            formatHexInput(index: index, newValue: newValue)
                        }
                }
            }
            
            // Row 2
            HStack(spacing: 10) {
                ForEach(3..<6) { index in
                    TextField("", text: $byteInputs[index])
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                        .multilineTextAlignment(.center)
                        .onChange(of: byteInputs[index]) { newValue in
                            formatHexInput(index: index, newValue: newValue)
                        }
                }
            }
            
            // Row 3
            HStack(spacing: 10) {
                ForEach(6..<9) { index in
                    TextField("", text: $byteInputs[index])
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                        .multilineTextAlignment(.center)
                        .onChange(of: byteInputs[index]) { newValue in
                            formatHexInput(index: index, newValue: newValue)
                        }
                }
            }
            
            // CRC byte (calculated automatically)
            HStack {
                Text("CRC:")
                    .font(.headline)
                Text(calculatedCRC)
                    .font(.headline)
                    .padding(8)
                    .frame(width: 60)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            // Send button
            Button(action: {
                sendCommand()
            }) {
                Text("Send Command")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // Format and validate hex input
    private func formatHexInput(index: Int, newValue: String) {
        let filtered = newValue.filter { "0123456789ABCDEFabcdef".contains($0) }
        let truncated = String(filtered.prefix(2))
        
        if truncated != newValue {
            byteInputs[index] = truncated.uppercased()
        } else {
            byteInputs[index] = newValue.uppercased()
        }
        
        calculateCRC()
    }
    
    // Calculate CRC (simple XOR of all bytes)
    private func calculateCRC() {
        var crc: UInt8 = 0
        
        for byteString in byteInputs {
            if let byte = UInt8(byteString, radix: 16) {
                crc ^= byte // XOR operation
            }
        }
        
        calculatedCRC = String(format: "%02X", crc)
    }
    
    // Send the command with CRC
    private func sendCommand() {
        guard bluetoothManager.isConnected else {
            alertMessage = "Not connected to a Bluetooth device"
            showAlert = true
            return
        }
        
        for (index, byteString) in byteInputs.enumerated() {
            if byteString.count != 2 || UInt8(byteString, radix: 16) == nil {
                alertMessage = "Invalid hex value at byte \(index + 1)"
                showAlert = true
                return
            }
        }
        
        var commandString = ""
        for byteString in byteInputs {
            commandString += byteString
        }
        commandString += calculatedCRC
        
        bluetoothManager.sendRawByteCommand(commandString)
        alertMessage = "Command sent: \(commandString)"
        showAlert = true
        print("📤 Manual command sent: \(commandString)")
    }
    
    // Helper function to display signal strength
    private func signalStrengthView(for rssi: NSNumber) -> some View {
        let signalStrength = rssi.intValue
        
        let bars: Int
        if signalStrength >= -60 {
            bars = 3 // Strong
        } else if signalStrength >= -80 {
            bars = 2 // Medium
        } else {
            bars = 1 // Weak
        }
        
        return HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Rectangle()
                    .fill(index < bars ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(6 + (index * 3)))
            }
        }
    }
}

// Preview
struct BluetoothScannerView_Previews: PreviewProvider {
    static var previews: some View {
        BluetoothScannerView(bluetoothManager: BluetoothManager.shared)
    }
}
