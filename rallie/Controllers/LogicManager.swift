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
        return min(launchInterval * 0.8, 2.0)
    }
    
    init(playerPositionPublisher: AnyPublisher<CGPoint?, Never>, bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        
        // Subscribe to player position updates
        playerPositionPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] position in
                guard let self = self, let position = position else { return }
                
                // Only process positions in interactive mode
                if self.controlMode == .interactive {
                    self.processNewPlayerPosition(position)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Process a new player position update
    private func processNewPlayerPosition(_ position: CGPoint) {
        let now = Date()
        
        // Add to position buffer
        timedPositionBuffer.append((point: position, timestamp: now))
        
        // Remove positions older than the averaging window
        timedPositionBuffer = timedPositionBuffer.filter {
            now.timeIntervalSince($0.timestamp) <= positionAveragingWindow
        }
        
        // Try to send a command based on the smoothed position
        attemptToSendSmoothedCommand()
    }
    
    /// Set ball speed (20-80mph in 10mph increments)
    func setBallSpeed(_ speed: Int) {
        let clampedSpeed = min(max(speed, CommandLookup.minSpeed), CommandLookup.maxSpeed)
        // Round to nearest 10mph
        ballSpeed = (clampedSpeed / CommandLookup.speedInterval) * CommandLookup.speedInterval
    }
    
    /// Set spin type
    func setSpinType(_ type: SpinType) {
        spinType = type
    }
    
    /// Set launch interval (2-9 seconds)
    func setLaunchInterval(_ interval: TimeInterval) {
        launchInterval = min(max(interval, LogicManager.minLaunchInterval), LogicManager.maxLaunchInterval)
    }
    
    /// Send a command to the ball machine for a specific target point
    func sendCommandForTargetPoint(_ point: CGPoint) {
        // Update last command zone for display
        lastCommandZone = CommandLookup.zoneID(for: point)
        
        // Convert court coordinates to integers for ESP32
        let x = Int(point.x * (1000.0 / CourtLayout.courtWidth))
        let y = Int(point.y * (1000.0 / CourtLayout.courtLength))
        
        // Convert spin type to integer value
        let spinValue: Int
        switch spinType {
        case .flat:
            spinValue = 0
        case .topspin:
            spinValue = 1
        case .extremeTopspin:
            spinValue = 2
        case .backspin:
            spinValue = -1
        case .extremeBackspin:
            spinValue = -2
        }
        
        // Send command to the ball machine
        bluetoothManager.sendPositionCommand(
            x: Double(x),
            y: Double(y),
            speed: Double(ballSpeed),
            spin: Double(spinValue)
        )
        
        // Update last command time
        lastCommandSent = Date()
    }
    
    /// Switch between manual and interactive control modes
    func toggleControlMode() {
        controlMode = controlMode == .manual ? .interactive : .manual
        
        // Clear position buffer when switching modes
        timedPositionBuffer.removeAll()
    }
    
    /// Private method to attempt sending a command based on smoothed player position
    private func attemptToSendSmoothedCommand() {
        let now = Date()
        
        // Respect interval between commands
        guard now.timeIntervalSince(lastCommandSent) >= launchInterval else {
            return
        }
        
        // Need at least a few positions for smoothing
        guard timedPositionBuffer.count >= 3 else {
            return
        }
        
        // Calculate weighted average position (more recent positions have higher weight)
        var totalWeight: Double = 0
        var weightedSumX: Double = 0
        var weightedSumY: Double = 0
        
        for (i, positionData) in timedPositionBuffer.enumerated() {
            // Linear weight: newer positions have higher weight
            let weight = Double(i + 1)
            totalWeight += weight
            
            weightedSumX += weight * Double(positionData.point.x)
            weightedSumY += weight * Double(positionData.point.y)
        }
        
        let avgX = weightedSumX / totalWeight
        let avgY = weightedSumY / totalWeight
        let avgPoint = CGPoint(x: avgX, y: avgY)
        
        // Get zone ID for the averaged position
        let zoneID = CommandLookup.zoneID(for: avgPoint)
        
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
        case .backspin:
            spinValue = -1
        case .extremeBackspin:
            spinValue = -2
        }
        
        if let zoneID = zoneID {
            // Update last command zone for display
            lastCommandZone = zoneID
            
            // Send command to the ball machine
            bluetoothManager.sendPositionCommand(
                x: Double(x),
                y: Double(y),
                speed: Double(ballSpeed),
                spin: Double(spinValue)
            )
            
            // Update last command time
            lastCommandSent = Date()
        }
    }
}
