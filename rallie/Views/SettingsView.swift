import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var logicManager: LogicManager = .shared
    @ObservedObject var cameraController: CameraController = .shared
    @ObservedObject var bluetoothManager: BluetoothManager = .shared
    @State private var showCamera = false
    @State private var showBluetoothScanner = false
    
    // Ball speed settings
    private let speedOptions = [20, 30, 40, 50, 60, 70, 80]
    
    // Spin type settings
    private let spinOptions: [SpinType] = [.flat, .topspin, .extremeTopspin]
    private let spinLabels = ["Flat", "Topspin", "Extreme Topspin"]
    
    // Launch interval settings
    @State private var launchInterval: Double = 3.0
    
    // Debug settings
    @State private var showDebugSection = false
    
    // Manual command input states
    @State private var byteInputs: [String] = Array(repeating: "00", count: 9)
    @State private var calculatedCRC: String = "00"
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Initialize with current values from LogicManager
    init() {
        // Initialize state variables with current values from LogicManager
        _launchInterval = State(initialValue: logicManager.launchInterval)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ball Speed")) {
                    Picker("Speed (mph)", selection: $logicManager.ballSpeed) {
                        ForEach(speedOptions, id: \.self) { speed in
                            Text("\(speed) mph").tag(speed)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Spin Type")) {
                    Picker("Spin", selection: $logicManager.spinType) {
                        ForEach(0..<spinOptions.count, id: \.self) { index in
                            Text(spinLabels[index]).tag(spinOptions[index])
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Launch Interval")) {
                    VStack {
                        Slider(value: $launchInterval, in: 2...9, step: 0.5)
                            .onChange(of: launchInterval) { newValue in
                                logicManager.setLaunchInterval(newValue)
                            }
                        
                        HStack {
                            Text("2s")
                            Spacer()
                            Text("\(String(format: "%.1f", launchInterval))s")
                                .font(.headline)
                            Spacer()
                            Text("9s")
                        }
                    }
                }
                
                // Simple Bluetooth Debug Section
                Section(header: Text("Bluetooth Connection")) {
                    Toggle("Show Debug Controls", isOn: $showDebugSection)
                    
                    // Bluetooth Scanner Button
                    Button(action: {
                        showBluetoothScanner = true
                    }) {
                        HStack {
                            Image(systemName: "bluetooth.circle")
                            Text("Scan for Bluetooth Devices")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .foregroundColor(.blue)
                    
                    // Connection status with color indicator
                    HStack {
                        Text("Connection Status:")
                        Spacer()
                        Text(bluetoothManager.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(bluetoothManager.isConnected ? .green : .red)
                            .fontWeight(.bold)
                    }
                    
                    if showDebugSection {
                        VStack(alignment: .leading, spacing: 10) {
                            // Basic debug buttons
                            Button("Print Connection Status") {
                                bluetoothManager.printConnectionStatus()
                            }
                            .foregroundColor(.blue)
                            
                            Button("Send Predefined Test Command (Center Court)") {
                                bluetoothManager.sendATCommand("DATA=0.5,0.5,40,0")
                            }
                            .foregroundColor(.green)
                            
                            // Manual command input section - directly shown without toggle
                            Text("Manual Command Input")
                                .font(.headline)
                                .padding(.top, 10)
                            
                            manualCommandSection
                            
                            // Updated troubleshooting tip
                            Text("Tip: Look for a device named 'ai-thinker' in the scanner")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 5)
                    }
                }
                
                Section {
                    Button(action: {
                        // Apply settings and show camera
                        showCamera = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Start Camera")
                                .bold()
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showBluetoothScanner) {
                BluetoothScannerView(bluetoothManager: bluetoothManager)
            }
            .fullScreenCover(isPresented: $showCamera) {
                if #available(iOS 16.0, *) {
                    CameraView(cameraController: cameraController)
                } else {
                    // Fallback for earlier iOS versions
                    Text("Camera tracking requires iOS 16 or later")
                        .padding( )
                }
            }
            .onAppear {
                // Initialize the slider with the current value from LogicManager
                launchInterval = logicManager.launchInterval
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
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Bluetooth Command"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
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
    
    // Calculate CRC (Modbus CRC-16 algorithm)
    private func calculateCRC() {
        var crc: UInt16 = 0xFFFF
        
        for byteString in byteInputs {
            if let byte = UInt8(byteString, radix: 16) {
                crc = crc ^ UInt16(byte)
                for _ in 1...8 {
                    if crc & 0x0001 != 0 {
                        crc = (crc >> 1) ^ 0xA001
                    } else {
                        crc = crc >> 1
                    }
                }
            }
        }
        
        calculatedCRC = String(format: "%02X", crc & 0xFF)
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
}

#if DEBUG
// Preview provider for SwiftUI canvas
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
