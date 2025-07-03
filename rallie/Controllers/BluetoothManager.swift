import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?

    private var serviceUUID: CBUUID?
    private var characteristicUUID: CBUUID?

    override init() {
        super.init()

        // Optional setup: Only initialize if UUID strings are valid
        if let serviceUUIDString = Bundle.main.object(forInfoDictionaryKey: "BLE_SERVICE_UUID") as? String,
           let characteristicUUIDString = Bundle.main.object(forInfoDictionaryKey: "BLE_CHARACTERISTIC_UUID") as? String,
           let validServiceUUID = UUID(uuidString: serviceUUIDString),
           let validCharUUID = UUID(uuidString: characteristicUUIDString) {
            
            self.serviceUUID = CBUUID(nsuuid: validServiceUUID)
            self.characteristicUUID = CBUUID(nsuuid: validCharUUID)

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
        guard let serviceUUID = serviceUUID else { return }
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services, let characteristicUUID = characteristicUUID else { return }
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.uuid == characteristicUUID {
                self.commandCharacteristic = char
                print("✅ Ready to send commands")
            }
        }
    }

    func sendCommand(_ command: String) {
        guard let peripheral = targetPeripheral,
              let characteristic = commandCharacteristic,
              let data = command.data(using: .utf8) else {
            print("⚠️ Cannot send command – not connected or invalid data")
            return
        }

        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("📤 Sent command: \(command)")
    }
}

