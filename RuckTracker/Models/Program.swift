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

struct UserProgram: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let programId: UUID
    let enrolledAt: Date
    let startingWeightLbs: Double
    var currentWeightLbs: Double
    let targetWeightLbs: Double
    var isActive: Bool
    let completedAt: Date?
    var completionPercentage: Double
    var currentWeek: Int
    var nextWorkoutDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case programId = "program_id"
        case enrolledAt = "enrolled_at"
        case startingWeightLbs = "starting_weight_lbs"
        case currentWeightLbs = "current_weight_lbs"
        case targetWeightLbs = "target_weight_lbs"
        case isActive = "is_active"
        case completedAt = "completed_at"
        case completionPercentage = "completion_percentage"
        case currentWeek = "current_week"
        case nextWorkoutDate = "next_workout_date"
    }
}

struct ProgramProgress: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let programId: UUID
    let workoutDate: Date
    let weekNumber: Int
    let workoutNumber: Int
    let weightLbs: Double
    let distanceMiles: Double
    let durationMinutes: Int
    let completed: Bool
    let notes: String?
    let heartRateData: HeartRateData?
    let paceData: PaceData?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case programId = "program_id"
        case workoutDate = "workout_date"
        case weekNumber = "week_number"
        case workoutNumber = "workout_number"
        case weightLbs = "weight_lbs"
        case distanceMiles = "distance_miles"
        case durationMinutes = "duration_minutes"
        case completed
        case notes
        case heartRateData = "heart_rate_data"
        case paceData = "pace_data"
    }
}

struct WorkoutCompletion: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let userProgramId: UUID
    let programWorkoutId: UUID
    let completedAt: Date
    let actualDistanceMiles: Double
    let actualWeightLbs: Double
    let actualDurationMinutes: Int
    let performanceScore: Double
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userProgramId = "user_program_id"
        case programWorkoutId = "program_workout_id"
        case completedAt = "completed_at"
        case actualDistanceMiles = "actual_distance_miles"
        case actualWeightLbs = "actual_weight_lbs"
        case actualDurationMinutes = "actual_duration_minutes"
        case performanceScore = "performance_score"
        case notes
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
    /// Deprecated: Programs now loaded from Programs.json
    @available(*, deprecated, message: "Use LocalProgramService instead")
    static var mockPrograms: [Program] {
        // Keep for backwards compatibility
        return [
        Program(
            id: UUID(),
            title: "Military Foundation",
            description: "8-week foundational program designed for those new to rucking",
            difficulty: .beginner,
            category: .military,
            durationWeeks: 8,
            isFeatured: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Program(
            id: UUID(),
            title: "Ranger Challenge",
            description: "Advanced 12-week program for experienced ruckers",
            difficulty: .advanced,
            category: .military,
            durationWeeks: 12,
            isFeatured: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Program(
            id: UUID(),
            title: "Selection Prep",
            description: "Elite 16-week program for special operations preparation",
            difficulty: .elite,
            category: .military,
            durationWeeks: 16,
            isFeatured: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Program(
            id: UUID(),
            title: "Adventure Ruck",
            description: "10-week program focused on outdoor adventure preparation",
            difficulty: .intermediate,
            category: .adventure,
            durationWeeks: 10,
            isFeatured: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Program(
            id: UUID(),
            title: "Fitness Foundation",
            description: "6-week program for general fitness improvement",
            difficulty: .beginner,
            category: .fitness,
            durationWeeks: 6,
            isFeatured: false,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Program(
            id: UUID(),
            title: "Historical March",
            description: "14-week program based on historical military marches",
            difficulty: .advanced,
            category: .historical,
            durationWeeks: 14,
            isFeatured: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        ]
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
