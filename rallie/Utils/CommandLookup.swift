import Foundation
import CoreGraphics

struct CommandLookup {
    // Fallback 18-digit command if no zone match is found
    static let fallbackCommand = "12000120000030003000"

    // Predefined commands for 4x4 grid zones (zoneID -> 18-digit command)
    private static let hardcodedCommands: [Int: String] = [
        0: "11000110000030003000",  1: "12000110000030003000",
        2: "12000120000030003000",  3: "13000120000030003000",
        4: "11000110000130003000",  5: "12000110000130003000",
        6: "12000120000130003000",  7: "13000120000130003000",
        8: "11000110000230003000",  9: "12000110000230003000",
        10: "12000120000230003000", 11: "13000120000230003000",
        12: "11000110000330003000", 13: "12000110000330003000",
        14: "12000120000330003000", 15: "13000120000330003000"
    ]

    /// Given a position (in meters), return the matching command.
    /// If position is outside court area, return fallback.
    static func command(for position: CGPoint) -> String {
        guard let zoneID = zoneID(for: position) else {
            return fallbackCommand
        }
        return hardcodedCommands[zoneID] ?? fallbackCommand
    }

    /// Compute zone ID based on player position in meters.
    /// Court size: 8.23m (width) x 5.49m (length)
    /// Zones: 4 columns x 4 rows = 16 zones
    public static func zoneID(for point: CGPoint) -> Int? {
        let courtWidth: CGFloat = 8.23
        let courtHeight: CGFloat = 5.49
        let cols = 4
        let rows = 4
        let zoneWidth = courtWidth / CGFloat(cols)
        let zoneHeight = courtHeight / CGFloat(rows)

        // Determine which column and row the point falls into
        let col = Int(point.x / zoneWidth)
        let row = Int(point.y / zoneHeight)

        // Check bounds (ensure point is on court)
        guard (0..<cols).contains(col), (0..<rows).contains(row) else {
            print("❌ Point \(point) is out of bounds")
            return nil
        }

        let zoneID = row * cols + col
        print("📍 Point \(point) mapped to zone \(zoneID) (col: \(col), row: \(row))")
        return zoneID
    }
}

