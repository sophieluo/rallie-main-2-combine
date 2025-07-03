import Foundation
import Combine
import CoreGraphics

class LogicManager: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private let bluetoothManager: BluetoothManager

    // Store recent player positions with timestamps
    private var timedPositionBuffer: [(point: CGPoint, timestamp: Date)] = []

    // Ensure we send a command only every `commandInterval` seconds
    private var lastCommandSent: Date = .distantPast
    private let commandInterval: TimeInterval = 3.0

    init(playerPositionPublisher: Published<CGPoint?>.Publisher, bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager

        // Subscribe to player position updates from CameraController
        playerPositionPublisher
            .compactMap { $0 } // Ignore nil values
            .sink { [weak self] position in
                // Store the new position with timestamp
                self?.timedPositionBuffer.append((point: position, timestamp: Date()))
                // Attempt to calculate and send a smoothed command
                self?.attemptToSendSmoothedCommand()
            }
            .store(in: &cancellables)
    }

    private func attemptToSendSmoothedCommand() {
        let now = Date()

        // Respect 3-second interval between commands
        guard now.timeIntervalSince(lastCommandSent) >= commandInterval else { return }

        // Keep only data from the last 3 seconds
        timedPositionBuffer = timedPositionBuffer.filter { now.timeIntervalSince($0.timestamp) <= 3.0 }

        // Extract only positions from the last 1 second for averaging
        let recent = timedPositionBuffer
            .filter { now.timeIntervalSince($0.timestamp) <= 1.0 }
            .map { $0.point }

        guard !recent.isEmpty else {
            print("⚠️ No recent positions in last 1s to average")
            return
        }

        // Compute average position to represent player's current location
        let avgX = recent.map { $0.x }.reduce(0, +) / CGFloat(recent.count)
        let avgY = recent.map { $0.y }.reduce(0, +) / CGFloat(recent.count)
        let avgPoint = CGPoint(x: avgX, y: avgY)

        // Convert the position to a zone ID (0-15) and fetch the mapped command
        let zoneID = CommandLookup.zoneID(for: avgPoint)
        let command = CommandLookup.command(for: avgPoint)

        if let zoneID = zoneID {
            print("📍 Averaged player position: \(avgPoint), mapped to zone \(zoneID)")
        } else {
            print("❓ Averaged point \(avgPoint) is outside zone grid — using fallback")
        }

        // Send the command via Bluetooth
        bluetoothManager.sendCommand(command)
        print("📤 Sent command: \(command)")

        // Update last sent timestamp
        lastCommandSent = now
    }
}

