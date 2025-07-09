import Foundation
import Combine
import CoreGraphics

enum ControlMode {
    case manual    // User selects target points by tapping
    case interactive  // Real-time player position tracking
}

class LogicManager: ObservableObject {
    // Singleton instance for shared access
    private static var _shared: LogicManager?
    
    static var shared: LogicManager {
        if _shared == nil {
            _shared = LogicManager(
                playerPositionPublisher: CameraController.shared.$projectedPlayerPosition.eraseToAnyPublisher(),
                bluetoothManager: BluetoothManager.shared
            )
        }
        return _shared!
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let bluetoothManager: BluetoothManager
    
    @Published var controlMode: ControlMode = .interactive
    
    // Ball parameters that can be configured by the user
    @Published var ballSpeed: Int = 50 // Default 50mph (range: 20-80mph)
    @Published var spinType: SpinType = .flat // Default flat spin
    @Published var ballActive: Bool = true // Whether the ball machine is active
    @Published var launchInterval: TimeInterval = 3.0 // Default 3s (range: 2-9s)
    
    // Track the last command zone for display
    @Published var lastCommandZone: Int? = nil
    
    // Constants for launch interval
    static let minLaunchInterval: TimeInterval = 2.0
    static let maxLaunchInterval: TimeInterval = 9.0
    
    // Store recent player positions with timestamps
    private var timedPositionBuffer: [(point: CGPoint, timestamp: Date)] = []
    
    // Ensure we send a command only every `launchInterval` seconds
    private var lastCommandSent: Date = .distantPast
    
    // Time window for position averaging (shorter for more responsive tracking)
    private var positionAveragingWindow: TimeInterval {
        // Use a smaller window for shorter intervals to be more responsive
        // and a larger window for longer intervals for more stability
        return min(launchInterval * 0.3, 1.0)
    }
    
    init(playerPositionPublisher: AnyPublisher<CGPoint?, Never>, bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        
        // Subscribe to player position updates from CameraController
        playerPositionPublisher
            .compactMap { $0 } // Ignore nil values
            .sink { [weak self] position in
                guard let self = self else { return }
                
                // Store the new position with timestamp
                self.timedPositionBuffer.append((point: position, timestamp: Date()))
                
                // Debug logging to check conditions
                print("🔍 Position received: \(position), controlMode: \(self.controlMode), ballActive: \(self.ballActive)")
                
                // In interactive mode, we process positions as they come in
                if self.controlMode == .interactive && self.ballActive {
                    print("✅ Conditions met for sending command: interactive mode and ball active")
                    self.attemptToSendSmoothedCommand()
                } else {
                    if self.controlMode != .interactive {
                        print("❌ Not sending command: controlMode is not interactive")
                    }
                    if !self.ballActive {
                        print("❌ Not sending command: ball machine is not active")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Manually send a command for a specific target point (used in manual mode)
    func sendCommandForTargetPoint(_ point: CGPoint) {
        // Update last command zone for display
        lastCommandZone = CommandLookup.zoneID(for: point)
        
        // Convert court coordinates to integers for ESP32
        // Scale to 0-1000 range for better precision
        let x = Int(min(max(point.x, 0), CourtLayout.courtWidth) * (1000.0 / CourtLayout.courtWidth))
        let y = Int(min(max(point.y, 0), CourtLayout.courtLength) * (1000.0 / CourtLayout.courtLength))
        
        // Convert spin type to integer value
        let spinValue: Int
        switch spinType {
        case .flat:
            spinValue = 0
        case .topspin:
            spinValue = 1
        case .extremeTopspin:
            spinValue = 2
        }
        
        // Send position command directly to ESP32
        bluetoothManager.sendPositionCommand(x: Double(x), y: Double(y), speed: Double(ballSpeed), spin: Double(spinValue))
        print("📤 \(controlMode == .interactive ? "Interactive" : "Manual") mode: Sent command for point \(point)")
        
        // Update last sent timestamp
        lastCommandSent = Date()
    }
    
    /// Set ball speed (20-80mph in 10mph increments)
    func setBallSpeed(_ speed: Int) {
        let clampedSpeed = min(max(speed, CommandLookup.minSpeed), CommandLookup.maxSpeed)
        // Round to nearest 10mph
        ballSpeed = (clampedSpeed / CommandLookup.speedInterval) * CommandLookup.speedInterval
        print("🏓 Ball speed set to \(ballSpeed)mph")
    }
    
    /// Set spin type
    func setSpinType(_ spin: SpinType) {
        spinType = spin
        print("🔄 Spin type set to \(spin.description)")
    }
    
    /// Set launch interval (2-9 seconds)
    func setLaunchInterval(_ interval: TimeInterval) {
        let clampedInterval = min(max(interval, LogicManager.minLaunchInterval), LogicManager.maxLaunchInterval)
        launchInterval = clampedInterval
        print("⏱️ Launch interval set to \(String(format: "%.1f", launchInterval))s")
    }
    
    /// Toggle ball machine active state
    func toggleBallMachine() {
        ballActive = !ballActive
        
        if !ballActive {
            // Stop the machine by sending a stop command
            bluetoothManager.sendPositionCommand(x: 0, y: 0, speed: 0, spin: 0)
            print("⏹️ Ball machine stopped")
        } else {
            print("▶️ Ball machine activated")
            // Send initial command based on current mode
            if controlMode == .interactive {
                attemptToSendSmoothedCommand()
            }
        }
    }
    
    /// Toggle between manual and interactive modes
    func toggleControlMode() {
        controlMode = (controlMode == .manual) ? .interactive : .manual
        print("🔄 Switched to \(controlMode == .manual ? "manual" : "interactive") mode")
        
        // Clear position buffer when switching modes
        timedPositionBuffer.removeAll()
    }
    
    private func attemptToSendSmoothedCommand() {
        let now = Date()
        
        // Respect interval between commands
        guard now.timeIntervalSince(lastCommandSent) >= launchInterval else {
            print("⏱️ Command skipped: Interval not reached (last: \(String(format: "%.1f", now.timeIntervalSince(lastCommandSent)))s / required: \(String(format: "%.1f", launchInterval))s)")
            return
        }
        
        // Keep only data from the last 3 seconds
        timedPositionBuffer = timedPositionBuffer.filter { now.timeIntervalSince($0.timestamp) <= 3.0 }
        
        // Extract only positions from the recent window for averaging
        let recent = timedPositionBuffer
            .filter { now.timeIntervalSince($0.timestamp) <= positionAveragingWindow }
            .map { $0.point }
        
        guard !recent.isEmpty else {
            print("⚠️ No recent positions in last \(String(format: "%.1f", positionAveragingWindow))s to average")
            return
        }
        
        print("🎯 Found \(recent.count) positions in averaging window of \(String(format: "%.1f", positionAveragingWindow))s")
        
        // Compute average position to represent player's current location
        let avgX = recent.map { $0.x }.reduce(0, +) / CGFloat(recent.count)
        let avgY = recent.map { $0.y }.reduce(0, +) / CGFloat(recent.count)
        let avgPoint = CGPoint(x: avgX, y: avgY)
        
        // Get zone ID for logging purposes
        let zoneID = CommandLookup.zoneID(for: avgPoint)
        
        // Update last command zone for display
        lastCommandZone = zoneID
        
        // Convert court coordinates to integers for ESP32
        // Scale to 0-1000 range for better precision
        let x = Int(avgPoint.x * (1000.0 / CourtLayout.courtWidth))
        let y = Int(avgPoint.y * (1000.0 / CourtLayout.courtLength))
        
        // Convert spin type to integer value
        let spinValue: Int
        switch spinType {
        case .flat:
            spinValue = 0
        case .topspin:
            spinValue = 1
        case .extremeTopspin:
            spinValue = 2
        }
        
        if let zoneID = zoneID {
            print("📍 \(controlMode == .interactive ? "Interactive" : "Manual") mode: Averaged player position: \(avgPoint), mapped to zone \(zoneID)")
        } else {
            print("❓ \(controlMode == .interactive ? "Interactive" : "Manual") mode: Averaged point \(avgPoint) is outside zone grid — using actual position anyway")
        }
        
        print("🏓 Using ball speed: \(ballSpeed)mph, spin: \(spinType.description), interval: \(String(format: "%.1f", launchInterval))s")
        
        // Always send position command with the player's actual position, regardless of zone
        print("🚀 ATTEMPTING TO SEND COMMAND: x=\(x), y=\(y), speed=\(ballSpeed), spin=\(spinValue)")
        bluetoothManager.sendPositionCommand(x: Double(x), y: Double(y), speed: Double(ballSpeed), spin: Double(spinValue))
        print("✅ Command sent to BluetoothManager")
        
        // Update last sent timestamp
        lastCommandSent = now
    }
}
