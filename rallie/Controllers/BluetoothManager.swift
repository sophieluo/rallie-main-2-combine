import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Singleton instance for shared access
    static let shared = BluetoothManager()
    
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var responseCharacteristic: CBCharacteristic?

    private var serviceUUID: CBUUID?
    private var commandCharacteristicUUID: CBUUID?
    private var responseCharacteristicUUID: CBUUID?
    
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

        // Optional setup: Only initialize if UUID strings are valid
        if let serviceUUIDString = Bundle.main.object(forInfoDictionaryKey: "BLE_SERVICE_UUID") as? String,
           let commandCharUUIDString = Bundle.main.object(forInfoDictionaryKey: "BLE_COMMAND_CHARACTERISTIC_UUID") as? String,
           let responseCharUUIDString = Bundle.main.object(forInfoDictionaryKey: "BLE_RESPONSE_CHARACTERISTIC_UUID") as? String,
           let validServiceUUID = UUID(uuidString: serviceUUIDString),
           let validCommandCharUUID = UUID(uuidString: commandCharUUIDString),
           let validResponseCharUUID = UUID(uuidString: responseCharUUIDString) {
            
            self.serviceUUID = CBUUID(nsuuid: validServiceUUID)
            self.commandCharacteristicUUID = CBUUID(nsuuid: validCommandCharUUID)
            self.responseCharacteristicUUID = CBUUID(nsuuid: validResponseCharUUID)

            centralManager = CBCentralManager(delegate: self, queue: nil)
            print("🔵 BluetoothManager initialized with UUIDs")
        } else {
            print("⚠️ BluetoothManager not initialized — UUIDs missing or invalid")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard let serviceUUID = serviceUUID else { return }

        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
            print("🔍 Scanning for peripherals...")
        } else {
            print("⚠️ Bluetooth not available: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("🔵 Discovered peripheral: \(peripheral.name ?? "Unknown")")
        targetPeripheral = peripheral
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
        peripheral.delegate = self
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to peripheral")
        isConnected = true
        guard let serviceUUID = serviceUUID else { return }
        peripheral.discoverServices([serviceUUID])
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
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("🔍 Discovered service: \(service.uuid)")
            // Discover both command and response characteristics
            let characteristicUUIDs = [commandCharacteristicUUID, responseCharacteristicUUID].compactMap { $0 }
            peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for char in characteristics {
            if char.uuid == commandCharacteristicUUID {
                self.commandCharacteristic = char
                print("✅ Found command characteristic")
            } else if char.uuid == responseCharacteristicUUID {
                self.responseCharacteristic = char
                // Enable notifications for responses
                peripheral.setNotifyValue(true, for: char)
                print("✅ Found response characteristic and enabled notifications")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, data.count == 5 else {
            print("⚠️ Received invalid response data")
            return
        }
        
        // Verify response header
        guard data[0] == 0x5A && data[1] == 0xA5 && data[2] == 0x82 else {
            print("⚠️ Invalid response header")
            return
        }
        
        // Extract response status
        if let status = ResponseStatus(rawValue: data[3]) {
            lastResponseStatus = status
            print("📥 Received response: \(statusDescription(for: status))")
        } else {
            print("⚠️ Unknown response status: \(data[3])")
        }
    }
    
    private func statusDescription(for status: ResponseStatus) -> String {
        switch status {
        case .rejected: return "Rejected"
        case .accepted: return "Accepted"
        case .completed: return "Completed"
        }
    }

    // Send command using the new 10-byte protocol
    func sendCommand(_ commandBytes: [UInt8]) {
        guard let peripheral = targetPeripheral,
              let characteristic = commandCharacteristic else {
            print("⚠️ Cannot send command – not connected")
            return
        }
        
        // Ensure command is exactly 10 bytes
        guard commandBytes.count == 10 else {
            print("⚠️ Invalid command length: \(commandBytes.count) bytes (expected 10)")
            return
        }
        
        let data = Data(commandBytes)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        
        // Print command details for debugging
        print("📤 Sent command: \(commandBytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
        print("   Upper Wheel: \(commandBytes[3])%, Lower Wheel: \(commandBytes[4])%, Pitch: \(commandBytes[5])°, Yaw: \(commandBytes[6])°, Feed: \(commandBytes[7])%, Control: \(commandBytes[8])")
    }
    
    // Convenience method to stop the ball machine
    func stopMachine() {
        // Create a stop command (control bit = 0)
        var stopCommand: [UInt8] = [0x5A, 0xA5, 0x83, 0, 0, 0, 0, 0, 0, 0]
        
        // Calculate CRC
        var crc: UInt8 = 0
        for i in 0..<(stopCommand.count - 1) {
            crc ^= stopCommand[i]
        }
        stopCommand[stopCommand.count - 1] = crc
        
        sendCommand(stopCommand)
    }
}
