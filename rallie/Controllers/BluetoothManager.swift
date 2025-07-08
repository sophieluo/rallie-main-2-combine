import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Singleton instance for shared access
    static let shared = BluetoothManager()
    
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var responseCharacteristic: CBCharacteristic?

    // Hardcoded UUIDs to match ESP32
    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789abc")
    private let characteristicUUID = CBUUID(string: "abcd1234-1234-1234-1234-abcdef123456")
    
    // Response status codes from MCU
    enum ResponseStatus: UInt8 {
        case rejected = 0
        case accepted = 1
        case completed = 2
    }
    
    // Published properties for UI updates
    @Published var isConnected = false
    @Published var lastResponseStatus: ResponseStatus?

    override init() {
        super.init()
        
        print("🔵 BluetoothManager initialized with hardcoded UUIDs:")
        print("   Service UUID: \(serviceUUID.uuidString)")
        print("   Characteristic UUID: \(characteristicUUID.uuidString)")
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🔵 Bluetooth state updated: \(central.state.rawValue)")

        if central.state == .poweredOn {
            print("🔍 Starting scan for peripherals...")
            // Scan for all peripherals first to debug
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("⚠️ Bluetooth not available: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("🔵 Discovered peripheral: \(peripheral.name ?? "Unknown") with identifier: \(peripheral.identifier)")
        print("   Advertisement data: \(advertisementData)")
        print("   RSSI: \(RSSI) dBm")
        
        // Connect to any peripheral named "Rallie_ESP32"
        if peripheral.name == "Rallie_ESP32" {
            print("✅ Found target peripheral: \(peripheral.name ?? "Unknown")")
            targetPeripheral = peripheral
            centralManager.stopScan()
            print("🔍 Stopping scan and connecting...")
            centralManager.connect(peripheral, options: nil)
            peripheral.delegate = self
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to peripheral: \(peripheral.name ?? "Unknown")")
        isConnected = true
        
        // Discover all services first to debug
        print("🔍 Discovering all services...")
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("❌ Disconnected from peripheral")
        isConnected = false
        // Attempt to reconnect
        if let peripheral = targetPeripheral {
            centralManager.connect(peripheral, options: nil)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("⚠️ Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { 
            print("⚠️ No services found")
            return 
        }
        
        print("🔍 Discovered \(services.count) services:")
        for service in services {
            print("   Service: \(service.uuid.uuidString)")
            
            // Discover all characteristics for debugging
            print("🔍 Discovering characteristics for service: \(service.uuid.uuidString)...")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("⚠️ Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { 
            print("⚠️ No characteristics found for service: \(service.uuid.uuidString)")
            return 
        }
        
        print("🔍 Discovered \(characteristics.count) characteristics for service \(service.uuid.uuidString):")
        for char in characteristics {
            print("   Characteristic: \(char.uuid.uuidString), Properties: \(char.properties.rawValue)")
            
            // Match our target characteristic
            if char.uuid.uuidString.lowercased() == characteristicUUID.uuidString.lowercased() {
                self.commandCharacteristic = char
                self.responseCharacteristic = char
                print("✅ Found target characteristic: \(char.uuid.uuidString)")
                
                // Enable notifications if the characteristic supports it
                if char.properties.contains(.notify) {
                    print("🔔 Enabling notifications for characteristic")
                    peripheral.setNotifyValue(true, for: char)
                }
                
                // After finding the characteristic, notify that we're ready to send commands
                print("✅ Bluetooth setup complete, ready to send commands")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else {
            print("⚠️ Received empty response data")
            return
        }
        
        // Log the raw response data for debugging
        print("📥 Received response data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // For ESP32 implementation, we don't expect specific response formats yet
        // Just mark the command as completed
        lastResponseStatus = .completed
    }
    
    // Send command to ESP32 without completion handler (for compatibility with LogicManager)
    func sendCommand(_ commandBytes: [UInt8]) {
        guard let peripheral = targetPeripheral,
              let characteristic = commandCharacteristic else {
            print("⚠️ Cannot send command – not connected")
            return
        }
        
        let data = Data(commandBytes)
        print("📤 Sending command bytes: \(commandBytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    // Send command to ESP32
    func sendCommand(_ commandBytes: [UInt8], completion: @escaping () -> Void) {
        guard let peripheral = targetPeripheral,
              let characteristic = commandCharacteristic else {
            print("⚠️ Cannot send command – not connected")
            return
        }
        
        let data = Data(commandBytes)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        
        // Print command details for debugging
        print("📤 Sent command: \(commandBytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        completion()
    }
    
    // Send position command to ESP32
    func sendPositionCommand(x: Int, y: Int, speed: Int, spin: Int) {
        print("📤 sendPositionCommand called with x=\(x), y=\(y), speed=\(speed), spin=\(spin)")
        
        guard let peripheral = targetPeripheral else {
            print("❌ ERROR: Cannot send position command - peripheral not connected")
            return
        }
        
        guard let characteristic = commandCharacteristic else {
            print("❌ ERROR: Cannot send position command - characteristic not found")
            return
        }
        
        // Format: [x_pos (2 bytes), y_pos (2 bytes), speed (1 byte), spin (1 byte)]
        let xHigh = UInt8((x >> 8) & 0xFF)
        let xLow = UInt8(x & 0xFF)
        let yHigh = UInt8((y >> 8) & 0xFF)
        let yLow = UInt8(y & 0xFF)
        
        let command: [UInt8] = [xHigh, xLow, yHigh, yLow, UInt8(speed), UInt8(spin)]
        let data = Data(command)
        
        print("📤 Sending command to ESP32: x=\(x), y=\(y), speed=\(speed), spin=\(spin)")
        print("📤 Raw bytes: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
        print("📤 Connection status: peripheral=\(peripheral.name ?? "Unknown"), state=\(peripheral.state.rawValue)")
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("📤 writeValue called successfully")
    }
    
    // Test function to send a simple command and verify Bluetooth is working
    func sendTestCommand() {
        print("🧪 Sending test command to ESP32...")
        
        // Print current connection status
        printConnectionStatus()
        
        // Send a simple command to the center of the court
        sendPositionCommand(x: 500, y: 500, speed: 40, spin: 0)
    }
    
    // Add a debug function to print current connection status
    func printConnectionStatus() {
        print("🔍 --- BLUETOOTH CONNECTION STATUS ---")
        print("   Connected: \(isConnected)")
        print("   Target peripheral: \(targetPeripheral?.name ?? "None")")
        print("   Command characteristic: \(commandCharacteristic != nil ? "Found" : "Not found")")
        print("🔍 ---------------------------------")
    }
}
