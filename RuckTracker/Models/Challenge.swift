// Models/Challenge.swift
import Foundation

struct Challenge: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let challengeType: ChallengeType
    let focusArea: FocusArea
    let durationDays: Int
    let weightPercentage: Double?
    let paceTarget: Double?
    let distanceFocus: Bool
    let recoveryFocus: Bool
    let isSeasonal: Bool
    let season: Season?
    let isActive: Bool
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum ChallengeType: String, Codable, CaseIterable {
        case weekly, monthly, seasonal
        
        var displayName: String {
            switch self {
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .seasonal: return "Seasonal"
            }
        }
    }
    
    enum FocusArea: String, Codable, CaseIterable {
        case power, speed, distance, recovery
        case progressiveWeight = "progressive_weight"
        case speedDevelopment = "speed_development"
        case enduranceProgression = "endurance_progression"
        case tacticalMixed = "tactical_mixed"
        
        var displayName: String {
            switch self {
            case .power: return "Power"
            case .speed: return "Speed"
            case .distance: return "Distance"
            case .recovery: return "Recovery"
            case .progressiveWeight: return "Progressive Weight"
            case .speedDevelopment: return "Speed Development"
            case .enduranceProgression: return "Endurance Progression"
            case .tacticalMixed: return "Tactical Mixed"
            }
        }
        
        var iconName: String {
            switch self {
            case .power, .progressiveWeight: return "scalemass.fill"
            case .speed, .speedDevelopment: return "speedometer"
            case .distance, .enduranceProgression: return "location.fill"
            case .recovery: return "heart.fill"
            case .tacticalMixed: return "shield.fill"
            }
        }
        
        var color: String {
            switch self {
            case .power, .progressiveWeight: return "red"
            case .speed, .speedDevelopment: return "blue"
            case .distance, .enduranceProgression: return "green"
            case .recovery: return "orange"
            case .tacticalMixed: return "purple"
            }
        }
    }
    
    enum Season: String, Codable, CaseIterable {
        case spring, summer, fall, winter
        
        var displayName: String {
            self.rawValue.capitalized
        }
        
        var iconName: String {
            switch self {
            case .spring: return "leaf.fill"
            case .summer: return "sun.max.fill"
            case .fall: return "maple.leaf.fill"
            case .winter: return "snowflake"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description
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
}

// MARK: - Mock Data Extensions
extension Challenge {
    /// Challenges are now loaded from Challenges.json
    /// This property exists only for backward compatibility during migration
    static var mockChallenges: [Challenge] {
        // Return empty array - all challenges should come from Challenges.json
        print("⚠️ WARNING: mockChallenges called - Challenges.json should be used instead")
        return []
    }
}
