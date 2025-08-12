import XCTest
@testable import rallie

class OpenAIServiceTests: XCTestCase {
    
    var openAIService: OpenAIService!
    
    override func setUp() {
        super.setUp()
        openAIService = OpenAIService.shared
    }
    
    override func tearDown() {
        // Clear any saved API key after tests
        openAIService.deleteAPIKey()
        super.tearDown()
    }
    
    func testAPIKeySaveAndRetrieve() {
        // Test saving and retrieving API key
        let testKey = "test-api-key-12345"
        
        // Save the key
        openAIService.saveAPIKey(testKey)
        
        // Retrieve the key
        let retrievedKey = openAIService.getAPIKey()
        
        // Verify the key matches
        XCTAssertEqual(testKey, retrievedKey)
    }
    
    func testAPIKeyDeletion() {
        // Test deleting API key
        let testKey = "test-api-key-delete"
        
        // Save the key
        openAIService.saveAPIKey(testKey)
        
        // Delete the key
        openAIService.deleteAPIKey()
        
        // Verify the key is nil
        let retrievedKey = openAIService.getAPIKey()
        XCTAssertNil(retrievedKey)
    }
    
    func testPromptConstruction() {
        // Test prompt construction with player profile
        let profile = PlayerProfile(
            name: "John Doe",
            skillLevel: "Intermediate",
            playStyle: "Aggressive Baseliner",
            focusAreas: ["Forehand", "Serve"],
            preferredDrills: ["Cross-court rallies", "Serve practice"]
        )
        
        let duration = 30
        
        let prompt = openAIService.constructPrompt(profile: profile, duration: duration)
        
        // Verify prompt contains key information
        XCTAssertTrue(prompt.contains("John Doe"))
        XCTAssertTrue(prompt.contains("Intermediate"))
        XCTAssertTrue(prompt.contains("Aggressive Baseliner"))
        XCTAssertTrue(prompt.contains("Forehand"))
        XCTAssertTrue(prompt.contains("Serve"))
        XCTAssertTrue(prompt.contains("30 minutes"))
        XCTAssertTrue(prompt.contains("JSON"))
    }
    
    func testJSONExtraction() {
        // Test JSON extraction from AI response
        let jsonString = """
        {
            "title": "Test Plan",
            "description": "A test training plan",
            "totalDuration": 30,
            "segments": [
                {
                    "name": "Forehand Practice",
                    "duration": 10,
                    "focus": "Work on consistent follow-through",
                    "machineSettings": {
                        "speed": 40,
                        "spin": 20,
                        "spinType": "topspin",
                        "position": {
                            "x": 50,
                            "y": 60
                        },
                        "quantity": 15
                    }
                }
            ]
        }
        """
        
        let aiResponse = "Here's a training plan for you:\n\n```json\n\(jsonString)\n```\n\nLet me know if you'd like any changes!"
        
        do {
            let extractedJSON = try openAIService.extractJSONFromResponse(aiResponse)
            XCTAssertEqual(extractedJSON, jsonString)
        } catch {
            XCTFail("Failed to extract JSON: \(error)")
        }
    }
    
    func testJSONExtractionFailure() {
        // Test JSON extraction failure
        let aiResponse = "I'm sorry, I couldn't create a plan for you right now."
        
        XCTAssertThrowsError(try openAIService.extractJSONFromResponse(aiResponse)) { error in
            XCTAssertEqual(error as? OpenAIService.OpenAIError, OpenAIService.OpenAIError.jsonExtractionFailed)
        }
    }
    
    func testParseTrainingPlan() {
        // Test parsing training plan from JSON
        let jsonString = """
        {
            "title": "Test Plan",
            "description": "A test training plan",
            "totalDuration": 30,
            "segments": [
                {
                    "name": "Forehand Practice",
                    "duration": 10,
                    "focus": "Work on consistent follow-through",
                    "machineSettings": {
                        "speed": 40,
                        "spin": 20,
                        "spinType": "topspin",
                        "position": {
                            "x": 50,
                            "y": 60
                        },
                        "quantity": 15
                    }
                }
            ]
        }
        """
        
        do {
            let plan = try openAIService.parseTrainingPlan(from: jsonString)
            
            // Verify plan properties
            XCTAssertEqual(plan.title, "Test Plan")
            XCTAssertEqual(plan.description, "A test training plan")
            XCTAssertEqual(plan.totalDuration, 30)
            XCTAssertEqual(plan.segments.count, 1)
            
            // Verify segment properties
            let segment = plan.segments[0]
            XCTAssertEqual(segment.name, "Forehand Practice")
            XCTAssertEqual(segment.duration, 10)
            XCTAssertEqual(segment.focus, "Work on consistent follow-through")
            
            // Verify machine settings
            XCTAssertEqual(segment.machineSettings.speed, 40)
            XCTAssertEqual(segment.machineSettings.spin, 20)
            XCTAssertEqual(segment.machineSettings.spinType, .topspin)
            XCTAssertEqual(segment.machineSettings.quantity, 15)
            
            // Verify position
            XCTAssertEqual(segment.machineSettings.position.x, 50)
            XCTAssertEqual(segment.machineSettings.position.y, 60)
            
        } catch {
            XCTFail("Failed to parse training plan: \(error)")
        }
    }
    
    func testParseTrainingPlanInvalidJSON() {
        // Test parsing invalid JSON
        let invalidJSON = "{ this is not valid JSON }"
        
        XCTAssertThrowsError(try openAIService.parseTrainingPlan(from: invalidJSON)) { error in
            XCTAssertEqual(error as? OpenAIService.OpenAIError, OpenAIService.OpenAIError.invalidJSON)
        }
    }
    
    // Note: We can't easily test the actual API call without mocking the network layer,
    // which would require additional setup. In a real project, we would use a mocking
    // framework or dependency injection to test the API call functionality.
}
