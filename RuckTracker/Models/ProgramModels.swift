// Models/ProgramModels.swift
import Foundation

// MARK: - Additional Models for Local Storage

struct UserProgram: Identifiable, Codable {
    let id: UUID
    let userId: UUID  // Keep for compatibility, but unused locally
    let programId: UUID
    let startDate: Date
    let targetWeight: Double
    var isActive: Bool
    var completedAt: Date?
    
    // Additional properties for program tracking
    var currentWeek: Int
    var completionPercentage: Double
    var currentWeightLbs: Double
    
    init(id: UUID = UUID(), userId: UUID = UUID(), programId: UUID, startDate: Date = Date(), targetWeight: Double, isActive: Bool = true, completedAt: Date? = nil, currentWeek: Int = 1, completionPercentage: Double = 0.0, currentWeightLbs: Double = 0.0) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.startDate = startDate
        self.targetWeight = targetWeight
        self.isActive = isActive
        self.completedAt = completedAt
        self.currentWeek = currentWeek
        self.completionPercentage = completionPercentage
        self.currentWeightLbs = currentWeightLbs
    }
}

struct WorkoutCompletion: Identifiable, Codable {
    let id: UUID
    let userId: UUID  // Keep for compatibility
    let userProgramId: UUID
    let programWorkoutId: UUID
    let completedAt: Date
    let actualDistanceMiles: Double?
    let actualWeightLbs: Double?
    let actualDurationMinutes: Int?
    let performanceScore: Double?
    let notes: String?
}

struct ProgramProgress {
    let completed: Int
    let total: Int
    let completionPercentage: Double
    let currentWeek: Int
    let nextWorkoutDay: Int?
}
