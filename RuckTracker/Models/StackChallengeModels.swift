//
//  StackChallengeModels.swift
//  RuckTracker
//
//  Challenge models for structured fitness challenges
//

import Foundation

// MARK: - Stack Challenge Model
struct StackChallenge: Codable, Identifiable {
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
        case weekly, seasonal
        
        var displayName: String {
            switch self {
            case .weekly: return "Weekly"
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

// MARK: - User Challenge Enrollment
struct UserChallengeEnrollment: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let challengeId: UUID
    let enrolledAt: Date
    var currentWeightLbs: Double
    let targetWeightLbs: Double?
    var isActive: Bool
    let completedAt: Date?
    var completionPercentage: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case challengeId = "challenge_id"
        case enrolledAt = "enrolled_at"
        case currentWeightLbs = "current_weight_lbs"
        case targetWeightLbs = "target_weight_lbs"
        case isActive = "is_active"
        case completedAt = "completed_at"
        case completionPercentage = "completion_percentage"
    }
}

// MARK: - Challenge Workout
struct ChallengeWorkout: Codable, Identifiable {
    let id: UUID
    let challengeId: UUID
    let dayNumber: Int
    let workoutType: WorkoutType
    let distanceMiles: Double?
    let targetPaceMinutes: Double?
    let weightLbs: Double?
    let durationMinutes: Int?
    let instructions: String?
    let isRestDay: Bool
    
    enum WorkoutType: String, Codable {
        case ruck, rest, crossTraining = "cross_training"
        
        var displayName: String {
            switch self {
            case .ruck: return "Ruck"
            case .rest: return "Rest"
            case .crossTraining: return "Cross Training"
            }
        }
        
        var iconName: String {
            switch self {
            case .ruck: return "figure.walk"
            case .rest: return "bed.double.fill"
            case .crossTraining: return "dumbbell.fill"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case challengeId = "challenge_id"
        case dayNumber = "day_number"
        case workoutType = "workout_type"
        case distanceMiles = "distance_miles"
        case targetPaceMinutes = "target_pace_minutes"
        case weightLbs = "weight_lbs"
        case durationMinutes = "duration_minutes"
        case instructions
        case isRestDay = "is_rest_day"
    }
}

// MARK: - User Challenge Completion
struct UserChallengeCompletion: Codable, Identifiable {
    let id: UUID
    let userEnrollmentId: UUID
    let challengeWorkoutId: UUID
    let completedAt: Date
    let actualDistanceMiles: Double?
    let actualDurationMinutes: Int?
    let actualWeightLbs: Double?
    let performanceScore: Double?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userEnrollmentId = "user_enrollment_id"
        case challengeWorkoutId = "challenge_workout_id"
        case completedAt = "completed_at"
        case actualDistanceMiles = "actual_distance_miles"
        case actualDurationMinutes = "actual_duration_minutes"
        case actualWeightLbs = "actual_weight_lbs"
        case performanceScore = "performance_score"
        case notes
    }
}

// MARK: - Mock Data for Testing
extension StackChallenge {
    static let mockWeeklyChallenges: [StackChallenge] = [
        StackChallenge(
            id: UUID(),
            title: "Power Week",
            description: "Heavy weight focus challenge - Build strength with increased load carrying",
            challengeType: .weekly,
            focusArea: .power,
            durationDays: 7,
            weightPercentage: 27.5,
            paceTarget: nil,
            distanceFocus: false,
            recoveryFocus: false,
            isSeasonal: false,
            season: nil,
            isActive: true,
            sortOrder: 1,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Speed Week",
            description: "Pace improvement focus challenge - Push your limits with faster paces",
            challengeType: .weekly,
            focusArea: .speed,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: 18.0,
            distanceFocus: false,
            recoveryFocus: false,
            isSeasonal: false,
            season: nil,
            isActive: true,
            sortOrder: 2,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Distance Week",
            description: "Endurance building focus challenge - Go the extra mile",
            challengeType: .weekly,
            focusArea: .distance,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: nil,
            distanceFocus: true,
            recoveryFocus: false,
            isSeasonal: false,
            season: nil,
            isActive: true,
            sortOrder: 3,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Active Recovery",
            description: "Light recovery focus challenge - Maintain movement while recovering",
            challengeType: .weekly,
            focusArea: .recovery,
            durationDays: 7,
            weightPercentage: 15.0,
            paceTarget: 22.0,
            distanceFocus: false,
            recoveryFocus: true,
            isSeasonal: false,
            season: nil,
            isActive: true,
            sortOrder: 4,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
    
    static let mockSeasonalChallenges: [StackChallenge] = [
        StackChallenge(
            id: UUID(),
            title: "Load Carrier",
            description: "Progressive weight mastery challenge - Master heavy carries through systematic progression",
            challengeType: .seasonal,
            focusArea: .progressiveWeight,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: nil,
            distanceFocus: false,
            recoveryFocus: false,
            isSeasonal: true,
            season: .fall,
            isActive: true,
            sortOrder: 5,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Pace Pusher",
            description: "Speed development challenge - Systematic pace improvements over time",
            challengeType: .seasonal,
            focusArea: .speedDevelopment,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: nil,
            distanceFocus: false,
            recoveryFocus: false,
            isSeasonal: true,
            season: .winter,
            isActive: true,
            sortOrder: 6,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Distance Master",
            description: "Endurance progression challenge - Build your distance capabilities",
            challengeType: .seasonal,
            focusArea: .enduranceProgression,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: nil,
            distanceFocus: true,
            recoveryFocus: false,
            isSeasonal: true,
            season: .spring,
            isActive: true,
            sortOrder: 7,
            createdAt: Date(),
            updatedAt: Date()
        ),
        StackChallenge(
            id: UUID(),
            title: "Tactical Ready",
            description: "Mixed operational skills challenge - Real-world application focus",
            challengeType: .seasonal,
            focusArea: .tacticalMixed,
            durationDays: 7,
            weightPercentage: nil,
            paceTarget: nil,
            distanceFocus: false,
            recoveryFocus: false,
            isSeasonal: true,
            season: .summer,
            isActive: true,
            sortOrder: 8,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}
