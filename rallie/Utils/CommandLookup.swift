import Foundation
import CoreGraphics

/// Ball spin types
enum SpinType: Int, Codable, CaseIterable {
    case flat = 0
    case topspin = 1
    case extremeTopspin = 2
    case backspin = 3
    case extremeBackspin = 4
    
    var description: String {
        switch self {
        case .flat: return "Flat"
        case .topspin: return "Topspin"
        case .extremeTopspin: return "Extreme Topspin"
        case .backspin: return "Backspin"
        case .extremeBackspin: return "Extreme Backspin"
        }
    }
    
    // For JSON encoding/decoding with string values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            // Decode from integer
            guard let type = SpinType(rawValue: intValue) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid spin type value")
            }
            self = type
        } else {
            // Decode from string
            let stringValue = try container.decode(String.self)
            switch stringValue.lowercased() {
            case "flat": self = .flat
            case "topspin": self = .topspin
            case "extreme_topspin": self = .extremeTopspin
            case "backspin": self = .backspin
            case "extreme_backspin": self = .extremeBackspin
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid spin type string")
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

struct CommandLookup {
    // Fallback command if no zone match is found (as byte array)
    static let fallbackCommand: [UInt8] = createCommand(upperWheel: 50, lowerWheel: 50, pitch: 50, yaw: 50, feedSpeed: 50, startBall: true)
    
    // Speed range: 20-80mph with 10mph intervals (7 different speeds)
    static let minSpeed = 20
    static let maxSpeed = 80
    static let speedInterval = 10
    static let speedLevels = 7  // (20, 30, 40, 50, 60, 70, 80)
    
    // Total combinations: 16 zones × 7 speeds × 5 spins = 560 different trajectories
    
    // 3D lookup table: [zoneID][spinType][speedLevel] -> command bytes
    // This structure represents:
    // - 16 different zones (target locations)
    // - 5 different spin types (flat, topspin, extreme topspin, backspin, extreme backspin)
    // - 7 different speed levels (20, 30, 40, 50, 60, 70, 80 mph)
    private static let commandTable: [[[CommandParameters]]] = {
        // Initialize the 3D array with proper dimensions
        var table = Array(repeating: Array(repeating: Array(repeating: CommandParameters(), count: speedLevels), count: SpinType.allCases.count), count: 16)
        
        // Fill the table with commands for each combination
        // In a real implementation, these would be calibrated values from testing
        for zoneID in 0..<16 {
            for spinType in SpinType.allCases {
                for speedLevel in 0..<speedLevels {
                    // For demonstration purposes, we'll generate parameters systematically
                    // In production, these would be pre-calibrated values
                    
                    // Calculate speed percentage (20-80mph) -> (30-100%)
                    let speedMph = minSpeed + (speedLevel * speedInterval)
                    let speedPercentage = min(100, 30 + Int((Float(speedMph) / Float(maxSpeed)) * 70))
                    
                    // Upper wheel speed varies by zone column (0-3)
                    let upperWheelSpeed = 50 + ((zoneID % 4) * 10)
                    
                    // Lower wheel speed varies by zone row (0-3)
                    let lowerWheelSpeed = 50 + ((zoneID / 4) * 10)
                    
                    // Pitch angle varies by speed
                    let pitchAngle = 30 + (speedLevel * 5)
                    
                    // Yaw angle varies by spin type
                    let yawAngle = 45 + (spinType.rawValue * 15)
                    
                    // Ball feed speed is constant for now
                    let feedSpeed = 50
                    
                    // Create command parameters
                    var params = CommandParameters()
                    params.upperWheelSpeed = UInt8(upperWheelSpeed)
                    params.lowerWheelSpeed = UInt8(lowerWheelSpeed)
                    params.pitchAngle = UInt8(pitchAngle)
                    params.yawAngle = UInt8(yawAngle)
                    params.feedSpeed = UInt8(feedSpeed)
                    
                    table[zoneID][spinType.rawValue][speedLevel] = params
                }
            }
        }
        return table
    }()
    
    // Command parameters structure matching the Bluetooth protocol
    struct CommandParameters {
        var upperWheelSpeed: UInt8 = 50  // 0-100%
        var lowerWheelSpeed: UInt8 = 50  // 0-100%
        var pitchAngle: UInt8 = 45       // 0-90 degrees
        var yawAngle: UInt8 = 45         // 0-90 degrees
        var feedSpeed: UInt8 = 50        // 0-100%
        
        // Convert to command bytes array according to protocol
        func toCommandBytes(startBall: Bool = true) -> [UInt8] {
            // Protocol: [0x5A, 0xA5, 0x83, upperWheel, lowerWheel, pitch, yaw, feedSpeed, controlBit, crc]
            var bytes: [UInt8] = [
                0x5A,               // Byte 0: Header 1 (fixed 5A)
                0xA5,               // Byte 1: Header 2 (fixed A5)
                0x83,               // Byte 2: Data source (fixed 83)
                upperWheelSpeed,    // Byte 3: Upper wheel speed (0-100%)
                lowerWheelSpeed,    // Byte 4: Lower wheel speed (0-100%)
                pitchAngle,         // Byte 5: Pitch angle (0-90)
                yawAngle,           // Byte 6: Yaw angle (0-90)
                feedSpeed,          // Byte 7: Feed speed (0-100%)
                startBall ? 1 : 0,  // Byte 8: Control bit: 0=stop, 1=start
                0                   // Byte 9: CRC (calculated below)
            ]
            
            // Calculate CRC16 using the Modbus algorithm
            var crc: UInt16 = 0xFFFF
            for i in 0..<(bytes.count - 1) {
                crc ^= UInt16(bytes[i])
                for _ in 0..<8 {
                    let carryFlag = crc & 0x0001
                    crc >>= 1
                    if carryFlag == 1 {
                        crc ^= 0xA001
                    }
                }
            }
            // Use the low byte of the CRC-16 result
            bytes[bytes.count - 1] = UInt8(crc & 0xFF)
            
            return bytes
        }
    }
    
    // Generate a command based on zone, speed, and spin by looking it up in the table
    static func command(for position: CGPoint, speed: Int = 50, spin: SpinType = .flat, startBall: Bool = true) -> [UInt8] {
        guard let zoneID = zoneID(for: position) else {
            return fallbackCommand
        }
        
        // Validate speed is within range and normalize to speed level (0-6)
        let clampedSpeed = min(max(speed, minSpeed), maxSpeed)
        let speedLevel = (clampedSpeed - minSpeed) / speedInterval
        
        // Look up the command parameters in our 3D table
        let params = commandTable[zoneID][spin.rawValue][speedLevel]
        
        // Convert to command bytes
        let commandBytes = params.toCommandBytes(startBall: startBall)
        
        print("📊 Looked up command for zone \(zoneID), speed \(clampedSpeed)mph, spin \(spin.description)")
        return commandBytes
    }
    
    /// Compute zone ID based on player position in meters.
    /// Court size: 8.23m (width) x 5.49m (length)
    /// Custom zone layout with 16 zones of different sizes
    public static func zoneID(for point: CGPoint) -> Int? {
        let courtWidth: CGFloat = 8.23
        let courtHeight: CGFloat = 5.49
        
        // Check if point is within court boundaries
        guard (0..<courtWidth).contains(point.x), (0..<courtHeight).contains(point.y) else {
            print("❌ Point \(point) is out of bounds")
            return nil
        }
        
        // Define custom zone boundaries based on the image
        // These are normalized coordinates (0.0-1.0) that will be multiplied by court dimensions
        
        // Define horizontal dividers (x-coordinates as percentage of court width)
        let xDividers: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        // Define vertical dividers (y-coordinates as percentage of court height)
        // The zones appear to have different heights in the image
        let yDividers: [CGFloat] = [0.0, 0.2, 0.4, 0.7, 1.0]
        
        // Convert normalized coordinates to actual court coordinates
        let xBoundaries = xDividers.map { $0 * courtWidth }
        let yBoundaries = yDividers.map { $0 * courtHeight }
        
        // Find which zone the point falls into
        var col = -1
        var row = -1
        
        // Find column (x position)
        for i in 0..<(xBoundaries.count - 1) {
            if point.x >= xBoundaries[i] && point.x < xBoundaries[i + 1] {
                col = i
                break
            }
        }
        
        // Find row (y position)
        for i in 0..<(yBoundaries.count - 1) {
            if point.y >= yBoundaries[i] && point.y < yBoundaries[i + 1] {
                row = i
                break
            }
        }
        
        // Ensure we found a valid zone
        guard col >= 0 && row >= 0 else {
            print("❓ Could not determine zone for point \(point)")
            return nil
        }
        
        // Calculate zone ID (4 columns × 4 rows = 16 zones)
        let zoneID = row * 4 + col
        print("📍 Point \(point) mapped to custom zone \(zoneID) (col: \(col), row: \(row))")
        return zoneID
    }
    
    static func createCommand(upperWheel: Int, lowerWheel: Int, pitch: Int, yaw: Int, feedSpeed: Int, startBall: Bool) -> [UInt8] {
        // Protocol: [0x5A, 0xA5, 0x83, upperWheel, lowerWheel, pitch, yaw, feedSpeed, controlBit, crc]
        var bytes: [UInt8] = [
            0x5A,               // Byte 0: Header 1 (fixed 5A)
            0xA5,               // Byte 1: Header 2 (fixed A5)
            0x83,               // Byte 2: Data source (fixed 83)
            UInt8(upperWheel),  // Byte 3: Upper wheel speed (0-100%)
            UInt8(lowerWheel),  // Byte 4: Lower wheel speed (0-100%)
            UInt8(pitch),       // Byte 5: Pitch angle (0-90)
            UInt8(yaw),         // Byte 6: Yaw angle (0-90)
            UInt8(feedSpeed),   // Byte 7: Feed speed (0-100%)
            startBall ? 1 : 0,  // Byte 8: Control bit: 0=stop, 1=start
            0                   // Byte 9: CRC (calculated below)
        ]
        
        // Calculate CRC16 using the Modbus algorithm
        var crc: UInt16 = 0xFFFF
        for i in 0..<(bytes.count - 1) {
            crc ^= UInt16(bytes[i])
            for _ in 0..<8 {
                let carryFlag = crc & 0x0001
                crc >>= 1
                if carryFlag == 1 {
                    crc ^= 0xA001
                }
            }
        }
        // Use the low byte of the CRC-16 result
        bytes[bytes.count - 1] = UInt8(crc & 0xFF)
        
        return bytes
    }
}
