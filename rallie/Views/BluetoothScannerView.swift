import SwiftUI
import CoreBluetooth

struct BluetoothScannerView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var isScanning = false
    @Environment(\.presentationMode) var presentationMode
    
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
                        .disabled(bluetoothManager.isConnecting && bluetoothManager.targetPeripheral?.identifier != peripheral.identifier)
                    }
                }
                
                // Control buttons
                HStack {
                    Button(action: {
                        if isScanning {
                            bluetoothManager.stopScanning()
                            isScanning = false
                        } else {
                            bluetoothManager.startScanning()
                            isScanning = true
                        }
                    }) {
                        HStack {
                            Image(systemName: isScanning ? "stop.circle" : "arrow.clockwise.circle")
                            Text(isScanning ? "Stop Scanning" : "Scan")
                        }
                        .frame(minWidth: 120)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    if bluetoothManager.isConnected {
                        Button(action: {
                            bluetoothManager.disconnect()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Disconnect")
                            }
                            .frame(minWidth: 120)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
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
                bluetoothManager.startScanning()
                isScanning = true
            }
            .onDisappear {
                bluetoothManager.stopScanning()
                isScanning = false
            }
        }
    }
    
    // Helper function to display signal strength
    private func signalStrengthView(for rssi: NSNumber) -> some View {
        let signalStrength = rssi.intValue
        let bars: Int
        
        if signalStrength >= -50 {
            bars = 4
        } else if signalStrength >= -65 {
            bars = 3
        } else if signalStrength >= -80 {
            bars = 2
        } else {
            bars = 1
        }
        
        return HStack(spacing: 2) {
            ForEach(0..<4) { index in
                Rectangle()
                    .fill(index < bars ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 3, height: 8 + CGFloat(index) * 4)
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
