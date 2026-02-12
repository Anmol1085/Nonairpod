import Foundation
import CoreBluetooth
import OSLog

class BatteryMonitor: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - Published Properties
    @Published var leftBattery: Int?
    @Published var rightBattery: Int?
    @Published var caseBattery: Int?
    @Published var lastUpdated: Date?
    @Published var isConnected: Bool = false
    @Published var isLeftRightSwapped: Bool = false
    
    // Charging Status
    @Published var isLeftCharging: Bool = false
    @Published var isRightCharging: Bool = false
    @Published var isCaseCharging: Bool = false
    
    private var targetPeripheral: CBPeripheral?
    private var centralManager: CBCentralManager?
    // Broaden search to "Enco" to catch variations like "OPPO Enco" or "Enco Air3"
    private let targetDeviceName = "Enco"
    private var serviceDiscoveryPending = true 
    
    // Using standard Battery Service UUID
    private let batteryServiceUUID = CBUUID(string: "180F")
    private let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")
    
    // UserDefaults Keys
    private let kLeftBattery = "OppoEnco_LeftBattery"
    private let kRightBattery = "OppoEnco_RightBattery"
    private let kCaseBattery = "OppoEnco_CaseBattery"
    private let kLastUpdated = "OppoEnco_LastUpdated"
    private let kIsSwapped = "OppoEnco_IsLeftRightSwapped"
    
    private let logger = Logger(subsystem: "com.anmol.OppoEncoMonitor", category: "BatteryMonitor")
    
    override init() {
        super.init()
        loadCachedData()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Caching Logic
    
    private func loadCachedData() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: kLeftBattery) != nil {
            leftBattery = defaults.integer(forKey: kLeftBattery)
        }
        if defaults.object(forKey: kRightBattery) != nil {
            rightBattery = defaults.integer(forKey: kRightBattery)
        }
        if defaults.object(forKey: kCaseBattery) != nil {
            caseBattery = defaults.integer(forKey: kCaseBattery)
        }
        if defaults.object(forKey: kIsSwapped) != nil {
            isLeftRightSwapped = defaults.bool(forKey: kIsSwapped)
        }
        lastUpdated = defaults.object(forKey: kLastUpdated) as? Date
    }
    
    func toggleSwap() {
        isLeftRightSwapped.toggle()
        UserDefaults.standard.set(isLeftRightSwapped, forKey: kIsSwapped)
        // Force update UI by swapping current values immediately for visual feedback
        let temp = leftBattery
        leftBattery = rightBattery
        rightBattery = temp
        
        // Also swap charging status
        let tempCharge = isLeftCharging
        isLeftCharging = isRightCharging
        isRightCharging = tempCharge
    }
    
    private func saveBatteryData(left: Int?, right: Int?, caseVal: Int?) {
        let defaults = UserDefaults.standard
        let now = Date()
        
        if let left = left {
            if left > 0 { // Only save non-zero values
                leftBattery = left
                defaults.set(left, forKey: kLeftBattery)
            }
        }
        if let right = right {
            if right > 0 {
                rightBattery = right
                defaults.set(right, forKey: kRightBattery)
            }
        }
        if let caseVal = caseVal {
            if caseVal > 0 {
                caseBattery = caseVal
                defaults.set(caseVal, forKey: kCaseBattery)
            }
        }
        
        lastUpdated = now
        defaults.set(now, forKey: kLastUpdated)
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScan()
        } else {
            logger.error("Bluetooth is not available.")
            isConnected = false
        }
    }
    
    func startScan() {
        guard centralManager?.state == .poweredOn else { return }
        
        // 1. Scan for advertising devices
        centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        logger.info("Started scanning...")
        
        // 2. Retrieve already connected devices (e.g. Single Earbud mode)
        // Check for devices offering Battery Service (180F) or standard audio services
        // Note: 180F is the most reliable one to check for power
        // 2. Retrieve already connected devices (e.g. Single Earbud mode)
        // Check for devices offering Battery Service (180F) or standard audio services
        // Note: 180F is the most reliable one to check for power
        guard let connected = centralManager?.retrieveConnectedPeripherals(withServices: [batteryServiceUUID]) else { return }
        
        for p in connected {
            if let name = p.name, name.localizedCaseInsensitiveContains(targetDeviceName) {
                self.targetPeripheral = p
                self.targetPeripheral?.delegate = self
                centralManager?.connect(p, options: nil)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name, name.localizedCaseInsensitiveContains(targetDeviceName) else { 
            return 
        }
        
        // Notify UI that we saw the device
        DispatchQueue.main.async {
            self.lastUpdated = Date()
        }

        self.targetPeripheral = peripheral
        self.targetPeripheral?.delegate = self
        
        // Parse Manufacturer Data if present
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            parseManufacturerData(manufacturerData)
        }
        
        // Prevent Connection Spam: Only connect if completely disconnected and not already trying
        if peripheral.state == .disconnected {
             // Rate limit connection attempts?
             centralManager?.connect(peripheral, options: nil)
        } else if peripheral.state == .connected {
             // If already connected, ensure we discover services once, not every packet
             if serviceDiscoveryPending { 
                 peripheral.discoverServices(nil)
                 serviceDiscoveryPending = false
             }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        serviceDiscoveryPending = false
        peripheral.discoverServices(nil) // Discover ALL services
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect: \(String(describing: error))")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        serviceDiscoveryPending = true // Reset so we discover again next time
        startScan()
    }
    
    // MARK: - Parsing
    
    private func parseManufacturerData(_ data: Data) {
        // DISABLE Manufacturer Data parsing.
        // It is unreliable and overwrites the correct data from the 0xAA response packet.
        // The user reported "4%" values, which likely come from misinterpreting this data.
        
        /*
        guard data.count > 10 else { return }
        
        // ... (Old logic commented out) ...
        
        let candidateLeft = Int(data[3])
        let candidateRight = Int(data[5])
        
        var left: Int? = nil
        var right: Int? = nil
        var caseBat: Int? = nil
        
        if (0...100).contains(candidateLeft) { left = candidateLeft }
        if (0...100).contains(candidateRight) { right = candidateRight }
        
        if data.count > 15 {
             let candidateCase = Int(data[15])
             if (0...100).contains(candidateCase) { caseBat = candidateCase }
        }
        
        DispatchQueue.main.async {
            self.saveBatteryData(left: left, right: right, caseVal: caseBat)
        }
        */
    }

    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
             logger.error("Error discovering services: \(error)")
             return
        }
        guard let services = peripheral.services else { return }
        
        for service in services {
            // Target specific Oppo proprietary services + Battery Service
            let uuid = service.uuid.uuidString
            if uuid.contains("790") || uuid.contains("79C") || uuid.contains("79A") || uuid == "180F" {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            let props = characteristic.properties
            
            // 1. Read if possible
            if props.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            
            // 2. Subscribe (Notify/Indicate)
            if props.contains(.notify) || props.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            // 3. POKE: If writable, send magic bytes to force update
            // Identifying 79A/79C write characteristics
            if props.contains(.write) || props.contains(.writeWithoutResponse) {
                if characteristic.uuid.uuidString.contains("79A") || characteristic.uuid.uuidString.contains("79C") {
                    
                    // Try a few common "Get Status" bytes
                    let commands: [UInt8] = [0x00, 0x01, 0xAA, 0x55]
                    for cmd in commands {
                        let data = Data([cmd])
                        let type: CBCharacteristicWriteType = props.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
                        peripheral.writeValue(data, for: characteristic, type: type)
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        
        // Check for "0xAA" response packet (Oppo Status)
        // Format: AA [Len] [..7 bytes..] [01] [Count] [ID1] [Val1] [ID2] [Val2] ...
        if data.first == 0xAA && data.count > 12 {
            parseOppoStatusPacket(data)
            return
        }
        
        // Log only if needed (commented out to reduce spam)
        // if data.count > 0 { logToFile("RX [\(characteristic.uuid.uuidString)]: Hex=\(hex)") }
        
        // Standard Battery Service check
        if (characteristic.uuid == batteryServiceUUID || characteristic.uuid.uuidString.contains("2A19")) {
             let val = Int(data[0])
             if val > 0 {
                 DispatchQueue.main.async {
                     // Standard service is often wrong/stub (0%), but if valid, use it for Case or General
                     // But we prefer Oppo proprietary data
                 }
             }
        }
    }


    // MARK: - Parsing
    
    enum DeviceTarget {
        case left, right, caseUnit, unknown
    }
    
    private func targetFor(id: Int) -> DeviceTarget {
        if isLeftRightSwapped {
            switch id {
            case 1: return .right
            case 2: return .left
            case 3: return .caseUnit
            default: return .unknown
            }
        } else {
            switch id {
            case 1: return .left
            case 2: return .right
            case 3: return .caseUnit
            default: return .unknown
            }
        }
    }

    private func parseOppoStatusPacket(_ data: Data) {
        let count = Int(data[10])
        let type = data[9]
        var offset = 11

        // Type 0x01 = Battery Levels
        if type == 0x01 {
            var newLeft: Int?
            var newRight: Int?
            var newCase: Int?
            
            for _ in 0..<count {
                guard offset + 1 < data.count else { break }
                let id = Int(data[offset])
                let val = Int(data[offset + 1])
                // Clamp value to 100% to handle status codes like 228 (0xE4)
                let clampedVal = val > 100 ? 100 : val
                
                switch targetFor(id: id) {
                case .left: newLeft = clampedVal
                case .right: newRight = clampedVal
                case .caseUnit: newCase = clampedVal
                case .unknown: break
                }
                
                offset += 2
            }
            
            DispatchQueue.main.async {
                self.saveBatteryData(left: newLeft, right: newRight, caseVal: newCase)
            }
        }
        // Type 0x02 = Charging Status
        else if type == 0x02 {
            var leftCharge: Bool?
            var rightCharge: Bool?
            var caseCharge: Bool?
            
            for _ in 0..<count {
                guard offset + 1 < data.count else { break }
                let id = Int(data[offset])
                let val = Int(data[offset + 1])
                // Assumption: non-zero = Charging (e.g. 1, 3, 4)
                let isCharging = (val > 0)
                
                switch targetFor(id: id) {
                case .left: leftCharge = isCharging
                case .right: rightCharge = isCharging
                case .caseUnit: caseCharge = isCharging
                case .unknown: break
                }
                
                offset += 2
            }
            
            DispatchQueue.main.async {
                if let l = leftCharge { self.isLeftCharging = l }
                if let r = rightCharge { self.isRightCharging = r }
                if let c = caseCharge { self.isCaseCharging = c }
            }
        }
    }
}
