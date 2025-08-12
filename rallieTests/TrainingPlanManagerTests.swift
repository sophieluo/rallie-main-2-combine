import XCTest
@testable import rallie

class TrainingPlanManagerTests: XCTestCase {
    
    var planManager: TrainingPlanManager!
    var testBluetoothManager: TestBluetoothManager!
    
    // Sample training plan for testing
    var testPlan: TrainingPlan!
    
    override func setUp() {
        super.setUp()
        
        // Create a test Bluetooth manager
        testBluetoothManager = TestBluetoothManager()
        
        // Create a test plan manager with the test Bluetooth manager
        planManager = TrainingPlanManager(bluetoothManager: testBluetoothManager)
        
        // Create a sample training plan for testing
        let position = Position(x: 50, y: 60)
        let machineSettings = MachineSettings(speed: 40, spin: 20, spinType: .topspin, position: position, quantity: 15)
        let segment1 = TrainingSegment(
            name: "Forehand Practice",
            duration: 5,
            focus: "Work on consistent follow-through",
            machineSettings: machineSettings
        )
        
        let position2 = Position(x: 30, y: 70)
        let machineSettings2 = MachineSettings(speed: 50, spin: 30, spinType: .backspin, position: position2, quantity: 20)
        let segment2 = TrainingSegment(
            name: "Backhand Practice",
            duration: 5,
            focus: "Focus on backhand technique",
            machineSettings: machineSettings2
        )
        
        testPlan = TrainingPlan(
            id: "test-plan-id",
            title: "Test Training Plan",
            description: "A plan for testing",
            totalDuration: 10,
            createdAt: Date(),
            segments: [segment1, segment2]
        )
        
        // Clear any existing plans
        UserDefaults.standard.removeObject(forKey: TrainingPlanManager.plansUserDefaultsKey)
    }
    
    override func tearDown() {
        // Clean up
        planManager = nil
        testBluetoothManager = nil
        testPlan = nil
        super.tearDown()
    }
    
    func testSaveAndRetrievePlan() {
        // Save the plan
        planManager.savePlan(testPlan)
        
        // Retrieve all plans
        let plans = planManager.getAllPlans()
        
        // Verify the plan was saved
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].id, testPlan.id)
        XCTAssertEqual(plans[0].title, testPlan.title)
        XCTAssertEqual(plans[0].segments.count, testPlan.segments.count)
    }
    
    func testDeletePlan() {
        // Save the plan
        planManager.savePlan(testPlan)
        
        // Verify the plan was saved
        XCTAssertEqual(planManager.getAllPlans().count, 1)
        
        // Delete the plan
        planManager.deletePlan(withId: testPlan.id)
        
        // Verify the plan was deleted
        XCTAssertEqual(planManager.getAllPlans().count, 0)
    }
    
    func testStartSession() {
        // Save the plan
        planManager.savePlan(testPlan)
        
        // Start a session
        let session = planManager.startSession(forPlanId: testPlan.id)
        
        // Verify the session was created
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.planId, testPlan.id)
        XCTAssertEqual(session?.status, .inProgress)
        XCTAssertEqual(session?.currentSegmentIndex, 0)
        
        // Verify the current session was set
        XCTAssertNotNil(planManager.currentSession)
        
        // Verify the first segment's machine settings were sent to the Bluetooth manager
        XCTAssertEqual(testBluetoothManager.lastSpeed, testPlan.segments[0].machineSettings.speed)
        XCTAssertEqual(testBluetoothManager.lastSpin, testPlan.segments[0].machineSettings.spin)
        XCTAssertEqual(testBluetoothManager.lastX, testPlan.segments[0].machineSettings.position.x)
        XCTAssertEqual(testBluetoothManager.lastY, testPlan.segments[0].machineSettings.position.y)
    }
    
    func testPauseAndResumeSession() {
        // Save the test plan and start a session
        planManager.savePlan(testPlan)
        _ = planManager.startSession(forPlanId: testPlan.id)
        
        // Pause the session
        planManager.pauseSession()
        
        // Verify the session is paused
        XCTAssertEqual(planManager.currentSession?.status, .paused)
        
        // Resume the session
        planManager.resumeSession()
        
        // Verify the session is resumed
        XCTAssertEqual(planManager.currentSession?.status, .inProgress)
    }
    
    func testStopSession() {
        // Save the test plan and start a session
        planManager.savePlan(testPlan)
        _ = planManager.startSession(forPlanId: testPlan.id)
        
        // Stop the session
        planManager.stopSession()
        
        // Verify the session is stopped
        XCTAssertNil(planManager.currentSession)
    }
    
    func testNextSegment() {
        // Save the test plan and start a session
        planManager.savePlan(testPlan)
        _ = planManager.startSession(forPlanId: testPlan.id)
        
        // Move to the next segment
        planManager.nextSegment()
        
        // Verify we're on the second segment
        XCTAssertEqual(planManager.currentSegmentIndex, 1)
        
        // Verify the second segment's machine settings were sent to the Bluetooth manager
        XCTAssertEqual(testBluetoothManager.lastSpeed, testPlan.segments[1].machineSettings.speed)
        XCTAssertEqual(testBluetoothManager.lastSpin, testPlan.segments[1].machineSettings.spin)
        XCTAssertEqual(testBluetoothManager.lastX, testPlan.segments[1].machineSettings.position.x)
        XCTAssertEqual(testBluetoothManager.lastY, testPlan.segments[1].machineSettings.position.y)
    }
    
    func testPreviousSegment() {
        // Save the test plan and start a session
        planManager.savePlan(testPlan)
        _ = planManager.startSession(forPlanId: testPlan.id)
        
        // Move to the next segment
        planManager.nextSegment()
        
        // Verify we're on the second segment
        XCTAssertEqual(planManager.currentSegmentIndex, 1)
        
        // Move back to the previous segment
        planManager.previousSegment()
        
        // Verify we're back on the first segment
        XCTAssertEqual(planManager.currentSegmentIndex, 0)
        
        // Verify the first segment's machine settings were sent to the Bluetooth manager
        XCTAssertEqual(testBluetoothManager.lastSpeed, testPlan.segments[0].machineSettings.speed)
        XCTAssertEqual(testBluetoothManager.lastSpin, testPlan.segments[0].machineSettings.spin)
        XCTAssertEqual(testBluetoothManager.lastX, testPlan.segments[0].machineSettings.position.x)
        XCTAssertEqual(testBluetoothManager.lastY, testPlan.segments[0].machineSettings.position.y)
    }
}

// Test Bluetooth Manager for testing - subclass of the real BluetoothManager
class TestBluetoothManager: BluetoothManager {
    var lastX: Double = 0
    var lastY: Double = 0
    var lastSpeed: Double = 0
    var lastSpin: Double = 0
    
    // Override the sendPositionCommand to track the values without actually sending commands
    override func sendPositionCommand(x: Double, y: Double, speed: Double, spin: Double, completion: ((Bool) -> Void)? = nil) {
        lastX = x
        lastY = y
        lastSpeed = speed
        lastSpin = spin
        
        // Simulate successful command sending
        completion?(true)
    }
}
