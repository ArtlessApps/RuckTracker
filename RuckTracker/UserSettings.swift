import SwiftUI

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    // MARK: - Coach Settings
    // The "Why" - This drives the entire recommendation engine
    @Published var ruckingGoal: RuckingGoal = .longevity
    
    // The "How" - Customize the intensity
    @Published var experienceLevel: ExperienceLevel = .beginner
    
    // The "When" - Dynamic scheduling
    @Published var preferredTrainingDays: [Int] = [2, 4, 7] // Mon, Wed, Sat default
    
    // The Result - The active plan ID
    @Published var activeProgramID: String?
}

// MARK: - Enums (The Psychology)

enum RuckingGoal: String, CaseIterable, Codable {
    case longevity = "Longevity & Health" // Peter Attia Crowd
    case weightLoss = "Burn Calories"     // Weight Loss Crowd
    case hiking = "Hiking & Hunting"      // The Outdoorsman
    case goruckBasic = "GORUCK Basic"     // First Event
    case goruckTough = "GORUCK Tough"     // Serious Event
    case military = "Military Selection"  // Professional
    
    var icon: String {
        switch self {
        case .longevity: return "heart.text.square.fill"
        case .weightLoss: return "flame.fill"
        case .hiking: return "mountain.2.fill"
        case .goruckBasic: return "figure.walk"
        case .goruckTough: return "trophy.fill"
        case .military: return "star.fill"
        }
    }
}

enum ExperienceLevel: String, CaseIterable, Codable {
    case beginner = "New to Rucking"
    case intermediate = "Hiker / Runner"
    case advanced = "Ruck Pro"
}
