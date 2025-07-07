import Foundation
import Combine
import CoreGraphics

enum ControlMode {
    case manual    // User selects target points by tapping
    case interactive  // Real-time player position tracking
}

enum SpinType {
    case flat
    case topSpin
    case backSpin
    case sideSpin
    
    var description: String {
        switch self {
        case .flat:
            return "Flat"
        case .topSpin:
            return "Top Spin"
        case .backSpin:
            return "Back Spin"
        case .sideSpin:
            return "Side Spin"
        }
    }
}

class LogicManager: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private let bluetoothManager: BluetoothManager
    
    @Published var controlMode: ControlMode = .manual
    
    // Ball parameters that can be configured by the user
    @Published var ballSpeed: Int = 50 // Default 50mph (range: 20-80mph)
    @Published var spinType: SpinType = .flat // Default flat spin
    @Published var ballActive: Bool = false // Whether the ball machine is active
    
    // Store recent player positions with timestamps
    private var timedPositionBuffer: [(point: CGPoint, timestamp: Date)] = []
    
    // Ensure we send a command only every `commandInterval` seconds
    private var lastCommandSent: Date = .distantPast
    private var commandInterval: TimeInterval = 3.0
    
    init(playerPositionPublisher: Published<CGPoint?>.Publisher, bluetoothManager: BluetoothManager) {
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
        
        // Adjust command interval based on mode
        commandInterval = (controlMode == .interactive) ? 2.0 : 3.0
    }
    
    private func attemptToSendSmoothedCommand() {
        let now = Date()
        
        // Respect interval between commands
        guard now.timeIntervalSince(lastCommandSent) >= commandInterval else { return }
        
        // Keep only data from the last 3 seconds
        timedPositionBuffer = timedPositionBuffer.filter { now.timeIntervalSince($0.timestamp) <= 3.0 }
        
        // For interactive mode, we use a shorter window to be more responsive
        let timeWindow: TimeInterval = (controlMode == .interactive) ? 0.7 : 1.0
        
        // Extract only positions from the recent window for averaging
        let recent = timedPositionBuffer
            .filter { now.timeIntervalSince($0.timestamp) <= timeWindow }
            .map { $0.point }
        
        guard !recent.isEmpty else {
            print("⚠️ No recent positions in last \(timeWindow)s to average")
            return
        }
        
        // Compute average position to represent player's current location
        let avgX = recent.map { $0.x }.reduce(0, +) / CGFloat(recent.count)
        let avgY = recent.map { $0.y }.reduce(0, +) / CGFloat(recent.count)
        let avgPoint = CGPoint(x: avgX, y: avgY)
        
        // Get zone ID for logging purposes
        let zoneID = CommandLookup.zoneID(for: avgPoint)
        
        // Get command with current ball speed and spin settings
        let commandBytes = CommandLookup.command(for: avgPoint, speed: ballSpeed, spin: spinType, startBall: ballActive)
        
        if let zoneID = zoneID {
            print("📍 \(controlMode == .interactive ? "Interactive" : "Manual") mode: Averaged player position: \(avgPoint), mapped to zone \(zoneID)")
            print("🏓 Using ball speed: \(ballSpeed)mph, spin: \(spinType.description)")
        } else {
            print("❓ \(controlMode == .interactive ? "Interactive" : "Manual") mode: Averaged point \(avgPoint) is outside zone grid — using fallback")
        }
        
        // Send the command via Bluetooth
        bluetoothManager.sendCommand(commandBytes)
        
        // Update last sent timestamp
        lastCommandSent = now
    }
}
