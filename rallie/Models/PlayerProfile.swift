import Foundation

struct PlayerProfile: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var skillLevel: String
    var playStyle: String
    var focusAreas: [String]
    var sessionDuration: Int
    
    init(name: String, skillLevel: String, playStyle: String, focusAreas: [String], sessionDuration: Int) {
        self.name = name
        self.skillLevel = skillLevel
        self.playStyle = playStyle
        self.focusAreas = focusAreas
        self.sessionDuration = sessionDuration
    }
}
