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
    
    enum Difficulty: String, Codable, CaseIterable {
        case beginner, intermediate, advanced, elite
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
    let startedAt: Date
    var currentWeek: Int
    var currentWeightLbs: Double
    var isActive: Bool
    let completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case programId = "program_id"
        case startedAt = "started_at"
        case currentWeek = "current_week"
        case currentWeightLbs = "current_weight_lbs"
        case isActive = "is_active"
        case completedAt = "completed_at"
    }
}
