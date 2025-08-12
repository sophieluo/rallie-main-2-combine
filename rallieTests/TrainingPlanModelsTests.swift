import XCTest
@testable import rallie

class TrainingPlanModelsTests: XCTestCase {
    
    // MARK: - Test Data
    
    func testTrainingPlanCodable() {
        // Create a sample training plan
        let position = Position(x: 50, y: 60)
        let machineSettings = MachineSettings(speed: 40, spin: 20, spinType: .topspin, position: position, quantity: 15)
        let segment = TrainingSegment(
            name: "Forehand Practice",
            duration: 5,
            focus: "Work on consistent follow-through",
            machineSettings: machineSettings
        )
        
        let originalPlan = TrainingPlan(
            id: UUID().uuidString,
            title: "Test Training Plan",
            description: "A plan for testing",
            totalDuration: 15,
            createdAt: Date(),
            segments: [segment]
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(originalPlan)
            
            // Decode back from JSON
            let decoder = JSONDecoder()
            let decodedPlan = try decoder.decode(TrainingPlan.self, from: data)
            
            // Verify properties match
            XCTAssertEqual(originalPlan.id, decodedPlan.id)
            XCTAssertEqual(originalPlan.title, decodedPlan.title)
            XCTAssertEqual(originalPlan.description, decodedPlan.description)
            XCTAssertEqual(originalPlan.totalDuration, decodedPlan.totalDuration)
            XCTAssertEqual(originalPlan.segments.count, decodedPlan.segments.count)
            
            // Verify segment properties
            let originalSegment = originalPlan.segments[0]
            let decodedSegment = decodedPlan.segments[0]
            XCTAssertEqual(originalSegment.name, decodedSegment.name)
            XCTAssertEqual(originalSegment.duration, decodedSegment.duration)
            XCTAssertEqual(originalSegment.focus, decodedSegment.focus)
            
            // Verify machine settings
            XCTAssertEqual(originalSegment.machineSettings.speed, decodedSegment.machineSettings.speed)
            XCTAssertEqual(originalSegment.machineSettings.spin, decodedSegment.machineSettings.spin)
            XCTAssertEqual(originalSegment.machineSettings.spinType, decodedSegment.machineSettings.spinType)
            XCTAssertEqual(originalSegment.machineSettings.quantity, decodedSegment.machineSettings.quantity)
            
            // Verify position
            XCTAssertEqual(originalSegment.machineSettings.position.x, decodedSegment.machineSettings.position.x)
            XCTAssertEqual(originalSegment.machineSettings.position.y, decodedSegment.machineSettings.position.y)
            
        } catch {
            XCTFail("Failed to encode/decode TrainingPlan: \(error)")
        }
    }
    
    func testPlayerProfileCodable() {
        // Create a sample player profile
        let originalProfile = PlayerProfile(
            name: "John Doe",
            skillLevel: "Intermediate",
            playStyle: "Aggressive Baseliner",
            focusAreas: ["Forehand", "Serve"],
            preferredDrills: ["Cross-court rallies", "Serve practice"]
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(originalProfile)
            
            // Decode back from JSON
            let decoder = JSONDecoder()
            let decodedProfile = try decoder.decode(PlayerProfile.self, from: data)
            
            // Verify properties match
            XCTAssertEqual(originalProfile.name, decodedProfile.name)
            XCTAssertEqual(originalProfile.skillLevel, decodedProfile.skillLevel)
            XCTAssertEqual(originalProfile.playStyle, decodedProfile.playStyle)
            XCTAssertEqual(originalProfile.focusAreas, decodedProfile.focusAreas)
            XCTAssertEqual(originalProfile.preferredDrills, decodedProfile.preferredDrills)
            
        } catch {
            XCTFail("Failed to encode/decode PlayerProfile: \(error)")
        }
    }
    
    func testTrainingSessionCodable() {
        // Create a sample training session
        let planId = UUID().uuidString
        let startTime = Date()
        let originalSession = TrainingSession(
            id: UUID().uuidString,
            planId: planId,
            startTime: startTime,
            endTime: nil,
            status: .inProgress,
            currentSegmentIndex: 2
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(originalSession)
            
            // Decode back from JSON
            let decoder = JSONDecoder()
            let decodedSession = try decoder.decode(TrainingSession.self, from: data)
            
            // Verify properties match
            XCTAssertEqual(originalSession.id, decodedSession.id)
            XCTAssertEqual(originalSession.planId, decodedSession.planId)
            XCTAssertEqual(originalSession.status, decodedSession.status)
            XCTAssertEqual(originalSession.currentSegmentIndex, decodedSession.currentSegmentIndex)
            
            // Dates should be approximately equal (within a small tolerance due to precision loss in encoding)
            let tolerance = 0.001 // 1 millisecond tolerance
            XCTAssertEqual(originalSession.startTime.timeIntervalSince1970, 
                          decodedSession.startTime.timeIntervalSince1970, 
                          accuracy: tolerance)
            
        } catch {
            XCTFail("Failed to encode/decode TrainingSession: \(error)")
        }
    }
    
    func testSpinTypeDescription() {
        // Test spin type descriptions
        XCTAssertEqual(SpinType.flat.description, "Flat")
        XCTAssertEqual(SpinType.topspin.description, "Topspin")
        XCTAssertEqual(SpinType.backspin.description, "Backspin")
        XCTAssertEqual(SpinType.extremeTopspin.description, "Extreme Topspin")
        XCTAssertEqual(SpinType.extremeBackspin.description, "Extreme Backspin")
    }
}
