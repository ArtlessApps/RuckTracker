import Foundation

// MARK: - Local Challenge Models (for JSON decoding)

struct LocalChallenge: Codable, Identifiable {
    let idx: Int
    let id: UUID
    let title: String
    let description: String
    let challengeType: String
    let focusArea: String
    let durationDays: Int
    let weightPercentage: Double?
    let paceTarget: Double?
    let distanceFocus: Bool
    let recoveryFocus: Bool
    let isSeasonal: Bool
    let season: String?
    let isActive: Bool
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case idx, id, title, description
        case challengeType = "challenge_type"
        case focusArea = "focus_area"
        case durationDays = "duration_days"
        case weightPercentage = "weight_percentage"
        case paceTarget = "pace_target"
        case distanceFocus = "distance_focus"
        case recoveryFocus = "recovery_focus"
        case isSeasonal = "is_seasonal"
        case season
        case isActive = "is_active"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Custom initializer to handle string-to-double conversion
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        idx = try container.decode(Int.self, forKey: .idx)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        challengeType = try container.decode(String.self, forKey: .challengeType)
        focusArea = try container.decode(String.self, forKey: .focusArea)
        durationDays = try container.decode(Int.self, forKey: .durationDays)
        distanceFocus = try container.decode(Bool.self, forKey: .distanceFocus)
        recoveryFocus = try container.decode(Bool.self, forKey: .recoveryFocus)
        isSeasonal = try container.decode(Bool.self, forKey: .isSeasonal)
        season = try container.decodeIfPresent(String.self, forKey: .season)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        
        // Handle weight_percentage as string that needs to be converted to Double
        if let weightString = try container.decodeIfPresent(String.self, forKey: .weightPercentage) {
            weightPercentage = Double(weightString)
        } else {
            weightPercentage = nil
        }
        
        // Handle pace_target as string that needs to be converted to Double
        if let paceString = try container.decodeIfPresent(String.self, forKey: .paceTarget) {
            paceTarget = Double(paceString)
        } else {
            paceTarget = nil
        }
    }
    
    // Convert to existing Challenge model
    func toChallenge() -> Challenge {
        // Parse the date strings to Date objects
        let dateFormatter = ISO8601DateFormatter()
        let createdDate = dateFormatter.date(from: createdAt) ?? Date()
        let updatedDate = dateFormatter.date(from: updatedAt) ?? Date()
        
        return Challenge(
            id: id,
            title: title,
            description: description,
            challengeType: Challenge.ChallengeType(rawValue: challengeType) ?? .weekly,
            focusArea: Challenge.FocusArea(rawValue: focusArea) ?? .power,
            durationDays: durationDays,
            weightPercentage: weightPercentage,
            paceTarget: paceTarget,
            distanceFocus: distanceFocus,
            recoveryFocus: recoveryFocus,
            isSeasonal: isSeasonal,
            season: season != nil ? Challenge.Season(rawValue: season!) : nil,
            isActive: isActive,
            sortOrder: sortOrder,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}
