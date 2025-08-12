import Foundation
import Security
import Combine

/// Service for communicating with OpenAI API to generate training plans
class OpenAIService: ObservableObject {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = OpenAIService()
    
    /// Published properties for UI updates
    @Published var isLoading: Bool = false
    @Published var hasApiKey: Bool = false
    
    /// API key storage key
    private let apiKeyKey = "com.mavio.openai.apikey"
    
    /// API base URL
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    /// Default model to use
    private let defaultModel = "gpt-4"
    
    // MARK: - Initialization
    
    private init() {
        // Check if API key exists on initialization
        hasApiKey = getAPIKey() != nil
    }
    
    // MARK: - API Key Management
    
    /// Save the OpenAI API key securely in the keychain
    /// - Parameter apiKey: The API key to save
    /// - Returns: Whether the save was successful
    func saveAPIKey(_ apiKey: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyKey,
            kSecValueData as String: apiKey.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Delete any existing key before saving
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve the OpenAI API key from the keychain
    /// - Returns: The API key if available, nil otherwise
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data, let apiKey = String(data: data, encoding: .utf8) {
            return apiKey
        }
        
        return nil
    }
    
    /// Check if an API key is stored
    /// - Returns: Whether an API key is available
    func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
    
    // MARK: - API Communication
    
    /// Generate a training plan using the OpenAI API
    /// - Parameters:
    ///   - playerProfile: The player profile to personalize the plan
    ///   - duration: The desired duration of the plan in minutes
    ///   - completion: Completion handler with the result
    func generateTrainingPlan(playerProfile: PlayerProfile, duration: Int, completion: @escaping (Result<TrainingPlan, Error>) -> Void) {
        guard let apiKey = getAPIKey() else {
            completion(.failure(OpenAIError.missingAPIKey))
            return
        }
        
        // Construct the prompt based on player profile
        let prompt = constructPrompt(playerProfile: playerProfile, duration: duration)
        
        // Create the request body
        let requestBody: [String: Any] = [
            "model": defaultModel,
            "messages": [
                ["role": "system", "content": "You are an expert tennis coach specializing in creating personalized training plans."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        ]
        
        // Create the request
        guard let url = URL(string: baseURL) else {
            completion(.failure(OpenAIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Make the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(OpenAIError.noData))
                return
            }
            
            do {
                // Parse the OpenAI response
                let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                
                guard let content = apiResponse.choices.first?.message.content else {
                    completion(.failure(OpenAIError.noContent))
                    return
                }
                
                // Extract the JSON from the response
                guard let jsonData = self.extractJSON(from: content).data(using: .utf8) else {
                    completion(.failure(OpenAIError.invalidJSON))
                    return
                }
                
                // Parse the training plan
                let trainingPlan = try JSONDecoder().decode(TrainingPlan.self, from: jsonData)
                completion(.success(trainingPlan))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Construct the prompt for the OpenAI API
    /// - Parameters:
    ///   - playerProfile: The player profile to personalize the plan
    ///   - duration: The desired duration of the plan in minutes
    /// - Returns: The constructed prompt
    private func constructPrompt(playerProfile: PlayerProfile, duration: Int) -> String {
        return """
        I'm a \(playerProfile.skillLevel) tennis player.
        I have a tennis ball machine that can do 20-80 mph ball serves with various spin options.
        Could you create a \(duration) minute training plan using my ball machine?
        
        Please include:
        - Specific drills with time allocations
        - Ball machine settings (speed, spin, and position) for each drill
        - Number of balls per drill
        
        My play style is \(playerProfile.playStyle) and I want to focus on: \(playerProfile.focusAreas.joined(separator: ", ")).
        
        Format the response as a JSON object with this structure:
        {
            "title": "Training Plan Title",
            "description": "Brief description of the plan",
            "totalDuration": \(duration),
            "segments": [
                {
                    "id": "unique-id-1",
                    "title": "Drill Name",
                    "description": "Detailed description of the drill",
                    "duration": 10,
                    "ballCount": 30,
                    "machineSettings": {
                        "speed": 40,
                        "spin": "topspin",
                        "position": "center"
                    }
                }
            ]
        }
        
        For the spin type, use one of: "flat", "topspin", "extremeTopspin", "backspin", "extremeBackspin".
        For position, use descriptive terms like "center", "leftCorner", "rightCorner", etc.
        """
    }
    
    /// Extract JSON from a text response
    /// - Parameter text: The text to extract JSON from
    /// - Returns: The extracted JSON string
    private func extractJSON(from text: String) -> String {
        // Find the first { and the last }
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}") else {
            return "{}"
        }
        
        return String(text[startIndex...endIndex])
    }
    
    // MARK: - Chat Functionality
    
    func getChatResponse(messages: [ChatMessage], completion: @escaping (Result<String, OpenAIError>) -> Void) {
        guard let apiKey = getAPIKey() else {
            completion(.failure(.missingAPIKey))
            return
        }
        
        // Convert ChatMessage array to OpenAI format
        let openAIMessages = messages.map { message in
            [
                "role": message.isFromUser ? "user" : "assistant",
                "content": message.content
            ]
        }
        
        // Add system message for context
        let systemMessage: [String: String] = [
            "role": "system",
            "content": "You are an AI tennis coach helping the user improve their tennis skills. Provide helpful, concise advice about tennis techniques, training methods, and strategies. Be encouraging and positive."
        ]
        
        let allMessages = [systemMessage] + openAIMessages
        
        // Create request body
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": allMessages,
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        // Create request
        sendRequest(apiKey: apiKey, requestBody: requestBody) { result in
            switch result {
            case .success(let data):
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        completion(.success(content))
                    } else {
                        completion(.failure(.invalidJSON))
                    }
                } catch {
                    completion(.failure(.invalidJSON))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Training Plan Generation
    
    func generateTrainingPlan(for playerProfile: PlayerProfile, completion: @escaping (Result<TrainingPlan, OpenAIError>) -> Void) {
        guard let apiKey = getAPIKey() else {
            completion(.failure(.missingAPIKey))
            return
        }
        
        // Create the prompt for generating a training plan
        let prompt = createTrainingPlanPrompt(for: playerProfile)
        
        // Create request body
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": "You are an AI tennis coach that creates structured training plans. Always respond with valid JSON that matches the TrainingPlan model structure."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.7
        ]
        
        // Send request
        sendRequest(apiKey: apiKey, requestBody: requestBody) { result in
            switch result {
            case .success(let data):
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        
                        // Extract JSON from the response
                        if let jsonString = self.extractJSONString(from: content),
                           let jsonData = jsonString.data(using: .utf8) {
                            
                            // Parse the JSON into a TrainingPlan
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .iso8601
                            
                            do {
                                let trainingPlan = try decoder.decode(TrainingPlan.self, from: jsonData)
                                completion(.success(trainingPlan))
                            } catch {
                                print("Error decoding TrainingPlan: \(error)")
                                completion(.failure(.invalidJSON))
                            }
                        } else {
                            completion(.failure(.invalidJSON))
                        }
                    } else {
                        completion(.failure(.invalidJSON))
                    }
                } catch {
                    completion(.failure(.invalidJSON))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func sendRequest(apiKey: String, requestBody: [String: Any], completion: @escaping (Result<Data, OpenAIError>) -> Void) {
        guard let url = URL(string: baseURL) else {
            completion(.failure(.invalidResponse))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(.invalidJSON))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            // Check for API errors
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                completion(.failure(.apiError(message)))
                return
            }
            
            completion(.success(data))
        }
        
        task.resume()
    }
    
    private func createTrainingPlanPrompt(for playerProfile: PlayerProfile) -> String {
        return """
        Create a tennis training plan for a player with the following profile:
        
        Name: \(playerProfile.name)
        Skill Level: \(playerProfile.skillLevel)
        Play Style: \(playerProfile.playStyle)
        Focus Areas: \(playerProfile.focusAreas.joined(separator: ", "))
        Session Duration: \(playerProfile.sessionDuration) minutes
        
        The training plan should include multiple segments, each with specific machine settings for a tennis ball machine.
        
        Please format your response as a JSON object that matches this structure:
        
        {
            "id": "unique-id-string",
            "title": "Title of the training plan",
            "description": "Brief description of the plan",
            "totalDuration": \(playerProfile.sessionDuration),
            "segments": [
                {
                    "id": "segment-id-1",
                    "title": "Segment Title",
                    "description": "Detailed description of what to do",
                    "duration": 10,
                    "ballCount": 30,
                    "machineSettings": {
                        "speed": 40,
                        "spin": "topspin",
                        "position": "center"
                    }
                }
            ]
        }
        
        For the spin type, use one of: "flat", "topspin", "extremeTopspin", "backspin", "extremeBackspin".
        For position, use descriptive terms like "center", "leftCorner", "rightCorner", etc.
        """
    }
    
    private func extractJSONString(from text: String) -> String? {
        // Look for text between curly braces
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            let jsonSubstring = text[startIndex...endIndex]
            return String(jsonSubstring)
        }
        return nil
    }
}

// MARK: - Supporting Types

/// OpenAI API response structure
struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}

/// OpenAI API errors
enum OpenAIError: Error {
    case missingAPIKey
    case invalidURL
    case noData
    case noContent
    case networkError(Error)
    case invalidResponse
    case invalidJSON
    case apiError(String)
}
