import Foundation
import Combine

/// Manager for handling training plans
class TrainingPlanManager: ObservableObject {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = TrainingPlanManager()
    
    /// Published properties for UI updates
    @Published var savedPlans: [TrainingPlan] = []
    @Published var currentSession: TrainingSession?
    @Published var currentSegmentIndex: Int = 0
    @Published var isExecutingPlan: Bool = false
    @Published var sessionTimer: Timer?
    @Published var segmentTimeRemaining: Int = 0
    
    /// References to other managers
    private let bluetoothManager = BluetoothManager.shared
    
    /// Storage keys
    private let plansStorageKey = "com.mavio.saved_training_plans"
    private let sessionsStorageKey = "com.mavio.training_sessions"
    
    /// Timer for segment execution
    private var segmentTimer: Timer?
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        loadSavedPlans()
        
        // Subscribe to Bluetooth connection status
        bluetoothManager.$isConnected
            .sink { [weak self] isConnected in
                if !isConnected {
                    self?.pauseCurrentSession()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Plan Management
    
    /// Save a new training plan
    /// - Parameter plan: The plan to save
    func savePlan(_ plan: TrainingPlan) {
        // Add the plan to the saved plans
        savedPlans.append(plan)
        
        // Save to persistent storage
        savePlansToStorage()
    }
    
    /// Delete a training plan
    /// - Parameter planId: The ID of the plan to delete
    func deletePlan(withId planId: String) {
        savedPlans.removeAll { $0.id == planId }
        savePlansToStorage()
    }
    
    /// Get a training plan by ID
    /// - Parameter planId: The ID of the plan to retrieve
    /// - Returns: The training plan if found, nil otherwise
    func getPlan(withId planId: String) -> TrainingPlan? {
        return savedPlans.first { $0.id == planId }
    }
    
    /// Save plans to persistent storage
    private func savePlansToStorage() {
        do {
            let data = try JSONEncoder().encode(savedPlans)
            UserDefaults.standard.set(data, forKey: plansStorageKey)
        } catch {
            print("❌ Error saving plans: \(error.localizedDescription)")
        }
    }
    
    /// Load saved plans from persistent storage
    private func loadSavedPlans() {
        guard let data = UserDefaults.standard.data(forKey: plansStorageKey) else {
            return
        }
        
        do {
            savedPlans = try JSONDecoder().decode([TrainingPlan].self, from: data)
        } catch {
            print("❌ Error loading plans: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Session Management
    
    /// Start a training session for a plan
    /// - Parameter planId: The ID of the plan to start
    /// - Returns: Whether the session was successfully started
    func startSession(forPlanId planId: String) -> Bool {
        guard let plan = getPlan(withId: planId) else {
            print("❌ Cannot start session: Plan not found")
            return false
        }
        
        guard bluetoothManager.isConnected else {
            print("❌ Cannot start session: Bluetooth not connected")
            return false
        }
        
        // Create a new session
        let session = TrainingSession(
            planId: planId,
            startTime: Date(),
            endTime: nil,
            status: .inProgress,
            currentSegmentIndex: 0
        )
        
        currentSession = session
        currentSegmentIndex = 0
        isExecutingPlan = true
        
        // Start executing the first segment
        executeCurrentSegment()
        
        return true
    }
    
    /// Pause the current session
    func pauseCurrentSession() {
        guard var session = currentSession, session.status == .inProgress else {
            return
        }
        
        // Update session status
        session.status = .paused
        currentSession = session
        isExecutingPlan = false
        
        // Stop the segment timer
        segmentTimer?.invalidate()
        segmentTimer = nil
        
        // Stop the ball machine
        bluetoothManager.sendPositionCommand(x: 0, y: 0, speed: 0, spin: 0)
    }
    
    /// Resume the current session
    func resumeCurrentSession() {
        guard var session = currentSession, session.status == .paused else {
            return
        }
        
        // Update session status
        session.status = .inProgress
        currentSession = session
        isExecutingPlan = true
        
        // Resume executing the current segment
        executeCurrentSegment()
    }
    
    /// Stop the current session
    func stopCurrentSession() {
        guard var session = currentSession else {
            return
        }
        
        // Update session status
        session.status = .completed
        session.endTime = Date()
        currentSession = session
        isExecutingPlan = false
        
        // Stop the segment timer
        segmentTimer?.invalidate()
        segmentTimer = nil
        
        // Stop the ball machine
        bluetoothManager.sendPositionCommand(x: 0, y: 0, speed: 0, spin: 0)
        
        // Save the session
        saveSession(session)
    }
    
    /// Move to the next segment in the current session
    func nextSegment() {
        guard var session = currentSession,
              let plan = getPlan(withId: session.planId),
              currentSegmentIndex < plan.segments.count - 1 else {
            // If this is the last segment, complete the session
            stopCurrentSession()
            return
        }
        
        // Stop the current segment timer
        segmentTimer?.invalidate()
        segmentTimer = nil
        
        // Update the current segment index
        currentSegmentIndex += 1
        session.currentSegmentIndex = currentSegmentIndex
        currentSession = session
        
        // Execute the new segment
        executeCurrentSegment()
    }
    
    /// Move to the previous segment in the current session
    func previousSegment() {
        guard var session = currentSession, currentSegmentIndex > 0 else {
            return
        }
        
        // Stop the current segment timer
        segmentTimer?.invalidate()
        segmentTimer = nil
        
        // Update the current segment index
        currentSegmentIndex -= 1
        session.currentSegmentIndex = currentSegmentIndex
        currentSession = session
        
        // Execute the new segment
        executeCurrentSegment()
    }
    
    /// Execute the current segment of the training plan
    private func executeCurrentSegment() {
        guard let session = currentSession,
              let plan = getPlan(withId: session.planId),
              currentSegmentIndex < plan.segments.count else {
            return
        }
        
        let segment = plan.segments[currentSegmentIndex]
        
        // Set the segment time remaining
        segmentTimeRemaining = segment.duration * 60 // Convert minutes to seconds
        
        // Configure the ball machine with the segment settings
        configureBallMachine(with: segment.machineSettings)
        
        // Start a timer to track the segment duration
        segmentTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.segmentTimeRemaining > 0 {
                self.segmentTimeRemaining -= 1
            } else {
                // Move to the next segment when time is up
                self.nextSegment()
            }
        }
    }
    
    /// Configure the ball machine with the specified settings
    /// - Parameter settings: The machine settings to apply
    private func configureBallMachine(with settings: MachineSettings) {
        // Send the position command to the ball machine
        bluetoothManager.sendPositionCommand(
            x: settings.position.x,
            y: settings.position.y,
            speed: Double(settings.speed),
            spin: Double(settings.spin)
        )
    }
    
    /// Save a completed session
    /// - Parameter session: The session to save
    private func saveSession(_ session: TrainingSession) {
        var savedSessions = loadSavedSessions()
        savedSessions.append(session)
        
        do {
            let data = try JSONEncoder().encode(savedSessions)
            UserDefaults.standard.set(data, forKey: sessionsStorageKey)
        } catch {
            print("❌ Error saving session: \(error.localizedDescription)")
        }
    }
    
    /// Load saved sessions from persistent storage
    /// - Returns: Array of saved sessions
    private func loadSavedSessions() -> [TrainingSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsStorageKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([TrainingSession].self, from: data)
        } catch {
            print("❌ Error loading sessions: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get all saved sessions
    /// - Returns: Array of saved sessions
    func getAllSessions() -> [TrainingSession] {
        return loadSavedSessions()
    }
    
    /// Get sessions for a specific plan
    /// - Parameter planId: The ID of the plan
    /// - Returns: Array of sessions for the plan
    func getSessions(forPlanId planId: String) -> [TrainingSession] {
        return loadSavedSessions().filter { $0.planId == planId }
    }
}
