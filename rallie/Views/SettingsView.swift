import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var logicManager: LogicManager = .shared
    @ObservedObject var cameraController: CameraController = .shared
    @ObservedObject var bluetoothManager: BluetoothManager = .shared
    @State private var showCamera = false
    
    // Ball speed settings
    private let speedOptions = [20, 30, 40, 50, 60, 70, 80]
    
    // Spin type settings
    private let spinOptions: [SpinType] = [.flat, .topspin, .extremeTopspin]
    private let spinLabels = ["Flat", "Topspin", "Extreme Topspin"]
    
    // Launch interval settings
    @State private var launchInterval: Double = 3.0
    
    // Debug settings
    @State private var showDebugSection = false
    
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
                Section(header: Text("Bluetooth Debug")) {
                    Toggle("Show Debug Controls", isOn: $showDebugSection)
                    
                    if showDebugSection {
                        VStack(alignment: .leading, spacing: 10) {
                            // Connection status with color indicator
                            HStack {
                                Text("Connection Status:")
                                Spacer()
                                Text(bluetoothManager.isConnected ? "Connected" : "Disconnected")
                                    .foregroundColor(bluetoothManager.isConnected ? .green : .red)
                                    .fontWeight(.bold)
                            }
                            
                            // Basic debug buttons
                            Button("Print Connection Status") {
                                bluetoothManager.printConnectionStatus()
                            }
                            .foregroundColor(.blue)
                            
                            Button("Send Test Command (Center Court)") {
                                bluetoothManager.sendTestCommand()
                            }
                            .foregroundColor(.green)
                            
                            // Troubleshooting tip
                            Text("Tip: Check ESP32 is named 'Rallie_ESP32'")
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
            .navigationTitle("Ball Machine Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Label("Back", systemImage: "chevron.backward")
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                if #available(iOS 16.0, *) {
                    CameraView(cameraController: cameraController)
                } else {
                    // Fallback for earlier iOS versions
                    Text("Camera tracking requires iOS 16 or later")
                        .padding()
                }
            }
            .onAppear {
                // Initialize the slider with the current value from LogicManager
                launchInterval = logicManager.launchInterval
            }
        }
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
