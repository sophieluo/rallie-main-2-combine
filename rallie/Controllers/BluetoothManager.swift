import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BluetoothManager()
    
    private var centralManager: CBCentralManager!
    @Published var targetPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    // Published properties for UI updates
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var connectionStatus = "Disconnected"
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var rssiValues: [UUID: NSNumber] = [:]
    
    // Specific UUIDs from the screenshot
    private let customServiceUUID = CBUUID(string: "5833FF01-9B8B-5191-6142-22A4536EF123")
    private let writeCharacteristicUUID = CBUUID(string: "5833FF02-9B8B-5191-6142-22A4536EF123")
    private let notifyCharacteristicUUID = CBUUID(string: "5833FF03-9B8B-5191-6142-22A4536EF123")
    
    // Alternative service with write & notify characteristics
    private let alternativeServiceUUID = CBUUID(string: "55535343-FE7D-4AE5-8FA9-9FAFD205E455")
    private let alternativeWriteCharacteristicUUID = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
    private let alternativeNotifyCharacteristicUUID = CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616")
    
    // Target device name - set to "ai-thinker" based on the screenshot
    private let targetDeviceName = "ai-thinker"
    
    // ACK handling properties
    private var waitingForAck = false
    private var commandCompletionHandler: ((Bool) -> Void)? = nil
    private var commandTimeoutTimer: Timer? = nil
    private let commandTimeout: TimeInterval = 2.0 // 2 seconds timeout for ACK

    override init() {
        super.init()
        
        print("🔵 BluetoothManager initialized")
        
        // Initialize the central manager with self as delegate
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("🔍 Bluetooth is powered on")
            connectionStatus = "Ready to scan"
        case .poweredOff:
            connectionStatus = "Bluetooth is powered off"
            print("⚠️ Bluetooth is powered off")
        case .unsupported:
            connectionStatus = "Bluetooth is not supported"
            print("⚠️ Bluetooth is not supported")
        case .unauthorized:
            connectionStatus = "Bluetooth is not authorized"
            print("⚠️ Bluetooth is not authorized")
        case .resetting:
            connectionStatus = "Bluetooth is resetting"
            print("⚠️ Bluetooth is resetting")
        case .unknown:
            connectionStatus = "Bluetooth state is unknown"
            print("⚠️ Bluetooth state is unknown")
        @unknown default:
            connectionStatus = "Unknown Bluetooth state"
            print("⚠️ Unknown Bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Store the RSSI value
        rssiValues[peripheral.identifier] = RSSI
        
        // Add to discovered peripherals list if not already there
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            
            // Sort peripherals by signal strength (strongest first)
            discoveredPeripherals.sort { (p1, p2) -> Bool in
                let rssi1 = rssiValues[p1.identifier]?.intValue ?? -100
                let rssi2 = rssiValues[p2.identifier]?.intValue ?? -100
                return rssi1 > rssi2
            }
        }
        
        // Log discovery
        let name = peripheral.name ?? "Unknown"
        print("🔵 Discovered peripheral: \(name) with identifier: \(peripheral.identifier)")
        print("   Advertisement data: \(advertisementData)")
        print("   RSSI: \(RSSI) dBm")
        
        // Auto-connect if it matches our target device name
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
           (localName.lowercased().contains(targetDeviceName) || name.lowercased().contains(targetDeviceName)) {
            print("🔵 Found target device: \(name)")
            connectToPeripheral(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to peripheral: \(peripheral.name ?? "Unknown")")
        connectionStatus = "Connected to \(peripheral.name ?? "Unknown")"
        isConnected = true
        isConnecting = false
        
        // Discover all services
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        connectionStatus = "Failed to connect"
        isConnected = false
        isConnecting = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("❌ Disconnected: \(error?.localizedDescription ?? "No error")")
        connectionStatus = "Disconnected"
        isConnected = false
        isConnecting = false
        
        // Clear the command characteristic
        commandCharacteristic = nil
        notifyCharacteristic = nil
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("❌ Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            print("❌ No services found")
            return
        }
        
        print("🔍 Discovered \(services.count) services")
        
        for service in services {
            print("🔍 Service: \(service.uuid)")
            
            // Check if this is one of our target services
            if service.uuid == customServiceUUID || service.uuid == alternativeServiceUUID {
                print("✅ Found target service: \(service.uuid)")
            }
            
            // Discover characteristics for each service
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("❌ Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("❌ No characteristics found for service \(service.uuid)")
            return
        }
        
        print("🔍 Service \(service.uuid) has \(characteristics.count) characteristics")
        
        for characteristic in characteristics {
            print("🔍 Characteristic: \(characteristic.uuid), Properties: \(characteristic.properties)")
            
            // Check for our specific write characteristic
            if characteristic.uuid == writeCharacteristicUUID || characteristic.uuid == alternativeWriteCharacteristicUUID {
                print("✅ Found write characteristic: \(characteristic.uuid)")
                commandCharacteristic = characteristic
            }
            
            // Check for our specific notify characteristic
            if characteristic.uuid == notifyCharacteristicUUID || characteristic.uuid == alternativeNotifyCharacteristicUUID {
                print("✅ Found notify characteristic: \(characteristic.uuid)")
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            // Subscribe to notifications if the characteristic supports it
            if (characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate)) &&
               notifyCharacteristic == nil {
                print("🔔 Subscribing to notifications for: \(characteristic.uuid)")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        if commandCharacteristic != nil {
            print("✅ Ready to send commands")
        } else {
            print("⚠️ No suitable write characteristic found")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("❌ Error receiving data: \(error!.localizedDescription)")
            if waitingForAck {
                handleAckTimeout()
            }
            return
        }
        
        guard let data = characteristic.value else {
            print("❌ No data received")
            return
        }
        
        // Print raw data for all responses
        print("📥 Raw data received: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Handle MCU responses according to protocol v0.3
        if data.count == 5 && data[0] == 0x5A && data[1] == 0xA5 && data[2] == 0x82 {
            let responseCode = data[3]
            let receivedCRC = data[4]
            
            print("📥 ACK Response: [Header: 0x5A 0xA5, Source: 0x82, Code: \(String(format: "0x%02X", responseCode)), CRC: \(String(format: "0x%02X", receivedCRC))]")
            
            // Calculate CRC16 using the Modbus algorithm
            var crc: UInt16 = 0xFFFF
            for i in 0..<4 { // Calculate CRC for bytes 0-3
                crc ^= UInt16(data[i])
                for _ in 0..<8 {
                    let carryFlag = crc & 0x0001
                    crc >>= 1
                    if carryFlag == 1 {
                        crc ^= 0xA001
                    }
                }
            }
            // Use the low byte of the CRC-16 result
            let calculatedCRC = UInt8(crc & 0xFF)
            
            let isValid = calculatedCRC == receivedCRC
            let isSuccess = isValid && (responseCode == 1 || responseCode == 2)
            
            if isValid {
                switch responseCode {
                case 0:
                    print("⚠️ Command rejected by device")
                case 1:
                    print("✅ Command accepted and started execution")
                case 2:
                    print("✅ Command execution completed")
                default:
                    print("📥 Unknown response code: \(responseCode)")
                }
            } else {
                print("❌ CRC error in device response: expected \(String(format: "0x%02X", calculatedCRC)), got \(String(format: "0x%02X", receivedCRC))")
            }
            
            // If we were waiting for an ACK, handle it
            if waitingForAck {
                handleAckReceived(success: isSuccess)
            }
        } else if let response = String(data: data, encoding: .utf8) {
            print("📥 Received text: \(response)")
        } else {
            print("📥 Received binary data: \(data.count) bytes")
        }
    }
    
    // Handle ACK received
    private func handleAckReceived(success: Bool) {
        // Cancel timeout timer
        commandTimeoutTimer?.invalidate()
        commandTimeoutTimer = nil
        
        // Reset waiting state
        waitingForAck = false
        
        // Call completion handler if one exists
        if let completion = commandCompletionHandler {
            commandCompletionHandler = nil
            completion(success)
        }
    }
    
    // Handle ACK timeout
    private func handleAckTimeout() {
        print("⚠️ Command ACK timeout - no response received")
        
        // Reset waiting state
        waitingForAck = false
        commandTimeoutTimer = nil
        
        // Call completion handler with failure
        if let completion = commandCompletionHandler {
            commandCompletionHandler = nil
            completion(false)
        }
    }
    
    // Send a binary command directly
    func sendBinaryCommand(_ data: Data, completion: ((Bool) -> Void)? = nil) {
        guard let peripheral = targetPeripheral,
              let characteristic = commandCharacteristic else {
            print("⚠️ Cannot send binary command – not connected")
            print("⚠️ DEBUG: Connection details - peripheral: \(targetPeripheral?.name ?? "nil"), characteristic: \(commandCharacteristic?.uuid.uuidString ?? "nil")")
            completion?(false)
            return
        }
        
        // If we're already waiting for an ACK, don't send another command
        if waitingForAck {
            print("⚠️ Cannot send command - still waiting for previous ACK")
            completion?(false)
            return
        }
        
        // Print the command being sent
        print("📤 Sending command: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // If command follows the 10-byte protocol, print a detailed breakdown
        if data.count == 10 && data[0] == 0x5A && data[1] == 0xA5 && data[2] == 0x83 {
            print("📤 Command details: [Header: 0x5A 0xA5, Source: 0x83, " +
                  "UpperWheel: \(data[3])%, LowerWheel: \(data[4])%, " +
                  "Pitch: \(data[5])°, Yaw: \(data[6])°, " +
                  "Feed: \(data[7])%, Control: \(data[8] == 1 ? "Start" : "Stop"), " +
                  "CRC: \(String(format: "0x%02X", data[9]))]")
        }
        
        print("📤 DEBUG: About to write value to characteristic \(characteristic.uuid.uuidString)")
        
        // Set up ACK waiting if completion handler is provided
        if completion != nil {
            waitingForAck = true
            commandCompletionHandler = completion
            
            // Set up timeout timer
            commandTimeoutTimer = Timer.scheduledTimer(withTimeInterval: commandTimeout, repeats: false) { [weak self] _ in
                self?.handleAckTimeout()
            }
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("📤 DEBUG: Write request sent to peripheral")
    }
    
    // Send position command for player tracking
    func sendPositionCommand(x: Double, y: Double, speed: Double, spin: Double, completion: ((Bool) -> Void)? = nil) {
        if !isConnected || commandCharacteristic == nil {
            print("❌ ERROR: Cannot send position command - peripheral not connected")
            printConnectionStatus()
            completion?(false)
            return
        }
        
        print("📤 sendPositionCommand called with x=\(x), y=\(y), speed=\(speed), spin=\(spin)")
        print("📤 DEBUG: Connection state - isConnected: \(isConnected), commandCharacteristic: \(commandCharacteristic != nil ? "available" : "nil")")
        
        // Convert coordinates (0-1000) to normalized coordinates (0.0-1.0)
        let normalizedX = min(1.0, max(0.0, x / 1000.0))
        let normalizedY = min(1.0, max(0.0, y / 1000.0))
        
        print("📤 DEBUG: Normalized coordinates - x: \(normalizedX), y: \(normalizedY)")
        
        // Map normalized coordinates to angles (0-90)
        // For yaw: 0 = leftmost, 90 = rightmost
        // normalizedX: 0.0 (left) -> 1.0 (right) maps to yaw: 0 -> 90
        let yawAngle = UInt8(min(90, max(0, Int(normalizedX * 90))))
        
        // For pitch: 0 = lowest, 90 = highest
        // normalizedY: 0.0 (net) -> 1.0 (baseline) maps to pitch: 0 -> 90
        // Note: We don't invert Y anymore since we want 0 = lowest (net) and 90 = highest (baseline)
        let pitchAngle = UInt8(min(90, max(0, Int(normalizedY * 90))))
        
        print("📤 DEBUG: Calculated angles - yaw: \(yawAngle)° (0=left, 90=right), pitch: \(pitchAngle)° (0=low/net, 90=high/baseline)")
        
        // Convert speed to wheel speeds (0-100)
        // Linear scaling: ballSpeed = 0 → wheelSpeed = 0%, ballSpeed = 80 → wheelSpeed = 100%
        let wheelSpeed = UInt8(min(100, max(0, Int((speed / 80.0) * 100.0))))
        
        // Convert spin (-1.0 to 1.0) to differential wheel speeds
        // Positive spin (topspin) = upper wheel faster
        // Negative spin (backspin) = lower wheel faster
        var upperWheelSpeed = wheelSpeed
        var lowerWheelSpeed = wheelSpeed
        
        if spin > 0 {
            // Topspin - upper wheel faster
            upperWheelSpeed = UInt8(min(100, Double(wheelSpeed) * (1 + spin * 0.5)))
            lowerWheelSpeed = UInt8(max(0, Double(wheelSpeed) * (1 - spin * 0.3)))
        } else if spin < 0 {
            // Backspin - lower wheel faster
            upperWheelSpeed = UInt8(max(0, Double(wheelSpeed) * (1 + spin * 0.3)))
            lowerWheelSpeed = UInt8(min(100, Double(wheelSpeed) * (1 - spin * 0.5)))
        }
        
        // Create the 10-byte command according to the protocol
        var command: [UInt8] = [
            0x5A,                // Byte 0: Header 1 (fixed 5A)
            0xA5,                // Byte 1: Header 2 (fixed A5)
            0x83,                // Byte 2: Data source (fixed 83)
            upperWheelSpeed,     // Byte 3: Upper wheel speed (0-100)
            lowerWheelSpeed,     // Byte 4: Lower wheel speed (0-100)
            pitchAngle,          // Byte 5: Pitch angle (0-90)
            yawAngle,            // Byte 6: Yaw angle (0-90)
            50,                  // Byte 7: Ball feed speed (50% default)
            1,                   // Byte 8: Control bit (1 = start shooting)
            0                    // Byte 9: CRC16 (calculated below)
        ]
        
        // Calculate CRC16 using the Modbus algorithm
        var crc: UInt16 = 0xFFFF
        for i in 0..<(command.count - 1) {
            crc ^= UInt16(command[i])
            for _ in 0..<8 {
                let carryFlag = crc & 0x0001
                crc >>= 1
                if carryFlag == 1 {
                    crc ^= 0xA001
                }
            }
        }
        // Use the low byte of the CRC-16 result
        command[9] = UInt8(crc & 0xFF)
        
        // Send the binary command
        let data = Data(command)
        print("📤 DEBUG: About to call sendBinaryCommand with data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        sendBinaryCommand(data, completion: completion)
        
        // Log the command details
        print("📤 Sent binary command: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
        print("   Upper Wheel: \(upperWheelSpeed)%, Lower Wheel: \(lowerWheelSpeed)%")
        print("   Pitch: \(pitchAngle)°, Yaw: \(yawAngle)°, Feed: 50%, Control: 1")
    }
    
    // Send a raw byte command with hex string input
    func sendRawByteCommand(_ hexString: String, completion: ((Bool) -> Void)? = nil) {
        // Convert hex string to data
        let hexString = hexString.replacingOccurrences(of: " ", with: "")
        var data = Data()
        
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) ?? hexString.endIndex
            let byteString = String(hexString[index..<nextIndex])
            
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            } else {
                print("⚠️ Invalid hex character in command: \(byteString)")
                completion?(false)
                return
            }
            
            if nextIndex == hexString.endIndex {
                break
            }
            
            index = nextIndex
        }
        
        // Ensure we have a valid command
        if data.count == 0 {
            print("⚠️ Empty command")
            completion?(false)
            return
        }
        
        // Send the binary command
        sendBinaryCommand(data, completion: completion)
    }
    
    // Start scanning for devices
    func startScanning() {
        if centralManager.state == .poweredOn {
            connectionStatus = "Scanning..."
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            print("🔍 Started scanning")
        } else {
            print("⚠️ Bluetooth not ready")
        }
    }
    
    // Stop scanning
    func stopScanning() {
        centralManager.stopScan()
        connectionStatus = isConnected ? "Connected" : "Scan stopped"
        print("🛑 Stopped scanning")
    }
    
    // Connect to a specific peripheral
    func connectToPeripheral(_ peripheral: CBPeripheral) {
        targetPeripheral = peripheral
        peripheral.delegate = self
        isConnecting = true
        centralManager.connect(peripheral, options: nil)
        connectionStatus = "Connecting to \(peripheral.name ?? "Unknown")..."
        print("🔌 Connecting to \(peripheral.name ?? "Unknown")")
    }
    
    // Disconnect from current peripheral
    func disconnect() {
        if let peripheral = targetPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    // Print connection status for debugging
    func printConnectionStatus() {
        print("📱 Bluetooth Connection Status:")
        print("   Connected: \(isConnected)")
        print("   Connecting: \(isConnecting)")
        print("   Status: \(connectionStatus)")
        print("   Target Peripheral: \(targetPeripheral?.name ?? "None")")
        print("   Command Characteristic: \(commandCharacteristic != nil ? "Available" : "Not available")")
        print("   Notify Characteristic: \(notifyCharacteristic != nil ? "Available" : "Not available")")
    }
    
    // Legacy method for compatibility
    func sendCommand(_ command: String) {
        sendATCommand(command)
    }
    
    // Legacy method for compatibility with AT commands
    func sendATCommand(_ command: String) {
        print("⚠️ AT commands are deprecated. Using binary protocol instead.")
        
        // Extract parameters from AT command if possible
        if command.hasPrefix("AT+SHOOT=") || command.hasPrefix("AT+DATA=") {
            let paramsString = command.components(separatedBy: "=").last ?? ""
            let params = paramsString.components(separatedBy: ",")
            
            if params.count >= 3 {
                // Try to extract x, y, speed from the AT command
                if let x = Double(params[0]),
                   let y = Double(params[1]),
                   let speed = Double(params[2]) {
                    
                    // Default spin to 0 if not provided
                    let spin = params.count > 3 ? (Double(params[3]) ?? 0) : 0
                    
                    // Convert to binary protocol
                    print("AT command received: \(command)")
                    return
                }
            }
        }
        
        print("AT command received: \(command)")
    }
    
    // Send a test command to the center of the court
    func sendTestCommand() {
        print("Test command received")
    }
}
