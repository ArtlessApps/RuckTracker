// Models/Program.swift
import Foundation

struct Program: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let difficulty: Difficulty
    let category: Category
    let durationWeeks: Int
    let isFeatured: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum Difficulty: String, Codable, CaseIterable, Comparable {
        case beginner, intermediate, advanced, elite
        
        static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
            let order: [Difficulty] = [.beginner, .intermediate, .advanced, .elite]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    enum Category: String, Codable, CaseIterable {
        case military, adventure, fitness, historical
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, difficulty, category
        case durationWeeks = "duration_weeks"
        case isFeatured = "is_featured"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ProgramWeek: Codable, Identifiable {
    let id: UUID
    let programId: UUID
    let weekNumber: Int
    let baseWeightLbs: Double?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case programId = "program_id"
        case weekNumber = "week_number"
        case baseWeightLbs = "base_weight_lbs"
        case description
    }
}

struct ProgramWorkout: Codable, Identifiable {
    let id: UUID
    let weekId: UUID
    let dayNumber: Int
    let workoutType: WorkoutType
    let distanceMiles: Double?
    let targetPaceMinutes: Double?
    let instructions: String?
    
    enum WorkoutType: String, Codable {
        case ruck, rest, crossTraining = "cross_training"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case weekId = "week_id"
        case dayNumber = "day_number"
        case workoutType = "workout_type"
        case distanceMiles = "distance_miles"
        case targetPaceMinutes = "target_pace_minutes"
        case instructions
    }
}


// MARK: - Extended Program Workout with UI State
struct ProgramWorkoutWithState: Identifiable {
    let workout: ProgramWorkout
    let weekNumber: Int
    let isCompleted: Bool
    let isLocked: Bool
    let completionDate: Date?
    
    var id: UUID { workout.id }
    
    var displayTitle: String {
        switch workout.workoutType {
        case .ruck:
            if let distance = workout.distanceMiles {
                return "\(Int(distance)) Mile Ruck"
            }
            return "Ruck Workout"
        case .rest:
            return "Rest Day"
        case .crossTraining:
            return "Cross Training"
        }
    }
    
    var displaySubtitle: String {
        if workout.workoutType == .rest {
            return "Recovery day"
        }
        
        var parts: [String] = []
        if let distance = workout.distanceMiles {
            parts.append("\(String(format: "%.1f", distance)) mi")
        }
        if let pace = workout.targetPaceMinutes {
            parts.append("\(Int(pace)) min/mi pace")
        }
        
        return parts.isEmpty ? "Workout \(workout.dayNumber)" : parts.joined(separator: " • ")
    }
}

struct WeightProgression: Codable, Identifiable {
    let id: UUID
    let userProgramId: UUID
    let weekNumber: Int
    let weightLbs: Double
    let wasAutoAdjusted: Bool
    let reason: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userProgramId = "user_program_id"
        case weekNumber = "week_number"
        case weightLbs = "weight_lbs"
        case wasAutoAdjusted = "was_auto_adjusted"
        case reason
        case createdAt = "created_at"
    }
}

// MARK: - Mock Data Extensions
extension Program {
    /// Programs are now loaded from Programs.json
    /// This property exists only for backward compatibility during migration
    static var mockPrograms: [Program] {
        // Return empty array - all programs should come from Programs.json
        print("⚠️ WARNING: mockPrograms called - Programs.json should be used instead")
        return []
    }
}

// MARK: - Supporting Data Structures for Universal Program Manager

struct HeartRateData: Codable {
    let averageHeartRate: Double
    let maxHeartRate: Double
    let timeInZones: [HeartRateZone: TimeInterval]
}

struct PaceData: Codable {
    let averageMinutesPerMile: Double
    let fastestMile: Double
    let slowestMile: Double
    let paceVariability: Double
}

enum HeartRateZone: String, Codable, CaseIterable {
    case recovery = "Recovery"
    case aerobic = "Aerobic"
    case threshold = "Threshold"
    case anaerobic = "Anaerobic"
    case neuromuscular = "Neuromuscular"
}
