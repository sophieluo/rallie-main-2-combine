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
    
    @Published var controlMode: ControlMode = .manual
    
    // Ball parameters that can be configured by the user
    @Published var ballSpeed: Int = 50 // Default 50mph (range: 20-80mph)
    @Published var spinType: SpinType = .flat // Default flat spin
    @Published var ballActive: Bool = false // Whether the ball machine is active
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
                
                // In interactive mode, we process positions as they come in
                if self.controlMode == .interactive && self.ballActive {
                    self.attemptToSendSmoothedCommand()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Manually send a command for a specific target point (used in manual mode)
    func sendCommandForTargetPoint(_ point: CGPoint) {
        guard controlMode == .manual else { return }
        
        // Update last command zone for display
        lastCommandZone = CommandLookup.zoneID(for: point)
        
        let commandBytes = CommandLookup.command(for: point, speed: ballSpeed, spin: spinType, startBall: ballActive)
        bluetoothManager.sendCommand(commandBytes)
        print("📤 Manual mode: Sent command for point \(point)")
        
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
            // Stop the machine
            bluetoothManager.stopMachine()
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
        guard now.timeIntervalSince(lastCommandSent) >= launchInterval else { return }
        
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
        
        // Compute average position to represent player's current location
        let avgX = recent.map { $0.x }.reduce(0, +) / CGFloat(recent.count)
        let avgY = recent.map { $0.y }.reduce(0, +) / CGFloat(recent.count)
        let avgPoint = CGPoint(x: avgX, y: avgY)
        
        // Get zone ID for logging purposes
        let zoneID = CommandLookup.zoneID(for: avgPoint)
        
        // Update last command zone for display
        lastCommandZone = zoneID
        
        // Get command with current ball speed and spin settings
        let commandBytes = CommandLookup.command(for: avgPoint, speed: ballSpeed, spin: spinType, startBall: ballActive)
        
        if let zoneID = zoneID {
            print("📍 \(controlMode == .interactive ? "Interactive" : "Manual") mode: Averaged player position: \(avgPoint), mapped to zone \(zoneID)")
            print("🏓 Using ball speed: \(ballSpeed)mph, spin: \(spinType.description), interval: \(String(format: "%.1f", launchInterval))s")
        } else {
            print("❓ \(controlMode == .interactive ? "Interactive" : "Manual") mode: Averaged point \(avgPoint) is outside zone grid — using fallback")
        }
        
        // Send the command via Bluetooth
        bluetoothManager.sendCommand(commandBytes)
        
        // Update last sent timestamp
        lastCommandSent = now
    }
}
