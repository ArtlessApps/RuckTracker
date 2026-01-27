// Models/ChallengeModels.swift
import Foundation

// MARK: - Additional Models for Local Storage

struct UserChallenge: Identifiable, Codable {
    let id: UUID
    let userId: UUID  // Keep for compatibility, but unused locally
    let challengeId: UUID
    let startDate: Date
    let targetWeight: Double?
    var isActive: Bool
    var completedAt: Date?
    
    // Additional properties for challenge tracking
    var currentDay: Int
    var completionPercentage: Double
    var currentWeightLbs: Double
    
    init(id: UUID = UUID(), userId: UUID = UUID(), challengeId: UUID, startDate: Date = Date(), targetWeight: Double? = nil, isActive: Bool = true, completedAt: Date? = nil, currentDay: Int = 1, completionPercentage: Double = 0.0, currentWeightLbs: Double = 0.0) {
        self.id = id
        self.userId = userId
        self.challengeId = challengeId
        self.startDate = startDate
        self.targetWeight = targetWeight
        self.isActive = isActive
        self.completedAt = completedAt
        self.currentDay = currentDay
        self.completionPercentage = completionPercentage
        self.currentWeightLbs = currentWeightLbs
    }
}

struct ChallengeCompletion: Identifiable, Codable {
    let id: UUID
    let userId: UUID  // Keep for compatibility
    let userChallengeId: UUID
    let challengeDay: Int
    let completedAt: Date
    let actualDistanceMiles: Double?
    let actualWeightLbs: Double?
    let actualDurationMinutes: Int?
    let performanceScore: Double?
    let notes: String?
}

struct ChallengeProgress {
    let completed: Int
    let total: Int
    let completionPercentage: Double
    let currentDay: Int
    let nextWorkoutDay: Int?
}

// MARK: - Challenge Workout Models

struct ChallengeWorkout: Identifiable, Codable {
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
    let createdAt: Date
    let updatedAt: Date
    
    enum WorkoutType: String, Codable, CaseIterable {
        case ruck, rest, run, strength, cardio
        
        var displayName: String {
            switch self {
            case .ruck: return "Ruck"
            case .rest: return "Rest"
            case .run: return "Run"
            case .strength: return "Strength"
            case .cardio: return "Cardio"
            }
        }
        
        var iconName: String {
            switch self {
            case .ruck: return "backpack.fill"
            case .rest: return "bed.double.fill"
            case .run: return "figure.run"
            case .strength: return "dumbbell.fill"
            case .cardio: return "heart.fill"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, dayNumber = "day_number"
        case challengeId = "challenge_id"
        case workoutType = "workout_type"
        case distanceMiles = "distance_miles"
        case targetPaceMinutes = "target_pace_minutes"
        case weightLbs = "weight_lbs"
        case durationMinutes = "duration_minutes"
        case instructions
        case isRestDay = "is_rest_day"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - ChallengeWorkout Extensions

extension ChallengeWorkout {
    func getWorkoutTitle(for challenge: Challenge) -> String {
        if isRestDay {
            return "Rest Day"
        }
        
        // Keep titles simple - detailed stats are shown separately
        return workoutType.displayName
    }
    
    var displaySubtitle: String {
        if isRestDay {
            return "Recovery day"
        }
        
        var parts: [String] = []
        if let distance = distanceMiles {
            parts.append("\(String(format: "%.1f", distance)) mi")
        }
        if let weight = weightLbs {
            parts.append("\(Int(weight)) lbs")
        }
        if let pace = targetPaceMinutes {
            parts.append("\(Int(pace)) min/mi")
        }
        if let duration = durationMinutes {
            parts.append("\(duration) min")
        }
        
        return parts.isEmpty ? "Workout" : parts.joined(separator: " • ")
    }
    
    func getInstructions(for challenge: Challenge) -> String {
        // Return custom instructions if available
        if let instructions = instructions, !instructions.isEmpty {
            return instructions
        }
        
        // Generate default instructions based on workout type
        switch workoutType {
        case .ruck:
            var instruction = "Complete a rucking workout"
            if let distance = distanceMiles {
                instruction += " covering \(String(format: "%.1f", distance)) miles"
            }
            if let weight = weightLbs {
                instruction += " with \(String(format: "%.0f", weight)) lbs"
            }
            if let pace = targetPaceMinutes {
                instruction += " at \(String(format: "%.1f", pace)) min/mile pace"
            }
            return instruction + "."
            
        case .run:
            var instruction = "Complete a running workout"
            if let distance = distanceMiles {
                instruction += " covering \(String(format: "%.1f", distance)) miles"
            }
            if let pace = targetPaceMinutes {
                instruction += " at \(String(format: "%.1f", pace)) min/mile pace"
            }
            return instruction + "."
            
        case .strength:
            var instruction = "Complete a strength training workout"
            if let duration = durationMinutes {
                instruction += " for \(duration) minutes"
            }
            return instruction + "."
            
        case .cardio:
            var instruction = "Complete a cardio workout"
            if let duration = durationMinutes {
                instruction += " for \(duration) minutes"
            }
            return instruction + "."
            
        case .rest:
            return "Take a rest day to allow your body to recover and prepare for the next workout."
        }
    }
}

struct ChallengeWorkoutCompletion: Identifiable, Codable {
    let id: UUID
    let userId: UUID  // Keep for compatibility
    let userChallengeId: UUID
    let challengeWorkoutId: UUID
    let completedAt: Date
    let actualDistanceMiles: Double?
    let actualWeightLbs: Double?
    let actualDurationMinutes: Int?
    let performanceScore: Double?
    let notes: String?
}

// MARK: - User Challenge Enrollment Model

struct UserChallengeEnrollment: Identifiable, Codable {
    let id: UUID
    let challengeId: UUID
    let enrolledAt: Date
    var completionPercentage: Double
    var currentDay: Int
    var isActive: Bool
    var completedAt: Date?
    
    init(id: UUID = UUID(), challengeId: UUID, enrolledAt: Date = Date(), completionPercentage: Double = 0.0, currentDay: Int = 1, isActive: Bool = true, completedAt: Date? = nil) {
        self.id = id
        self.challengeId = challengeId
        self.enrolledAt = enrolledAt
        self.completionPercentage = completionPercentage
        self.currentDay = currentDay
        self.isActive = isActive
        self.completedAt = completedAt
    }
}
