import Foundation
import SwiftUI

// MARK: - Leaderboard Entry Models

struct WeeklyDistanceEntry: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let weekStartDate: Date
    let weekEndDate: Date
    let totalDistance: Double
    let totalWorkouts: Int
    let ranking: Int?
    let createdAt: Date
    let updatedAt: Date
    
    // Display properties
    var displayName: String = "Anonymous"
    var isCurrentUser: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case weekStartDate = "week_start_date"
        case weekEndDate = "week_end_date"
        case totalDistance = "total_distance"
        case totalWorkouts = "total_workouts"
        case ranking
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ConsistencyStreakEntry: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let currentStreak: Int
    let bestStreak: Int
    let lastWorkoutDate: Date?
    let streakStartDate: Date?
    let ranking: Int?
    let createdAt: Date
    let updatedAt: Date
    
    // Display properties
    var displayName: String = "Anonymous"
    var isCurrentUser: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case currentStreak = "current_streak"
        case bestStreak = "best_streak"
        case lastWorkoutDate = "last_workout_date"
        case streakStartDate = "streak_start_date"
        case ranking
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserLeaderboardSettings: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    var displayName: String?
    var showInWeeklyDistance: Bool
    var showInConsistency: Bool
    var privacyLevel: PrivacyLevel
    let createdAt: Date
    let updatedAt: Date
    
    enum PrivacyLevel: String, Codable, CaseIterable {
        case `public` = "public"
        case friends = "friends"
        case `private` = "private"
        
        var displayName: String {
            switch self {
            case .public: return "Public"
            case .friends: return "Friends Only"
            case .private: return "Private"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case displayName = "display_name"
        case showInWeeklyDistance = "show_in_weekly_distance"
        case showInConsistency = "show_in_consistency"
        case privacyLevel = "privacy_level"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Leaderboard Types

enum LeaderboardType: String, CaseIterable {
    case weeklyDistance = "weekly_distance"
    case consistency = "consistency"
    
    var title: String {
        switch self {
        case .weeklyDistance: return "Weekly Distance"
        case .consistency: return "Consistency Streak"
        }
    }
    
    var subtitle: String {
        switch self {
        case .weeklyDistance: return "This week's total distance leaders"
        case .consistency: return "Consecutive weeks with workouts"
        }
    }
    
    var iconName: String {
        switch self {
        case .weeklyDistance: return "figure.run"
        case .consistency: return "calendar.badge.checkmark"
        }
    }
    
    var color: Color {
        switch self {
        case .weeklyDistance: return .green
        case .consistency: return .orange
        }
    }
}
