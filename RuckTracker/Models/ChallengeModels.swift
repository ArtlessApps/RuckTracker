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
