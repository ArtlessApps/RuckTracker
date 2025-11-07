// Utilities/ChallengeProgressCalculator.swift
import Foundation

/// Shared utility for calculating challenge progress across different views
struct ChallengeProgressCalculator {
    
    /// Calculate the progress percentage for a challenge
    /// - Parameter challenge: The challenge to calculate progress for
    /// - Returns: A value between 0 and 1 representing completion percentage
    static func calculateProgress(for challenge: Challenge) -> Double {
        let totalDays = challenge.durationDays
        guard totalDays > 0 else { return 0 }
        
        // Get completed workouts from CoreData
        // IMPORTANT: Filter by challenge.id (the Challenge's ID), not userChallenge.id
        let completedWorkouts = WorkoutDataManager.shared.workouts.filter {
            $0.challengeId == challenge.id.uuidString
        }.count
        
        return Double(completedWorkouts) / Double(totalDays)
    }
    
    /// Get the count of completed workouts for a challenge
    /// - Parameter challenge: The challenge to check
    /// - Returns: Number of completed workouts
    static func getCompletedCount(for challenge: Challenge) -> Int {
        return WorkoutDataManager.shared.workouts.filter {
            $0.challengeId == challenge.id.uuidString
        }.count
    }
}

