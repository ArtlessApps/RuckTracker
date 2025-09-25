//
//  LeaderboardIntegration.swift
//  RuckTracker
//
//  Helper functions to integrate leaderboard updates with workout completion
//

import Foundation

extension WorkoutDataManager {
    
    // MARK: - Leaderboard Integration
    
    /// Updates leaderboard data when a new workout is completed
    func updateLeaderboardsAfterWorkout(_ workout: WorkoutEntity) async {
        await updateWeeklyDistanceLeaderboard()
        await updateConsistencyLeaderboard()
    }
    
    /// Calculate and update user's weekly distance total
    private func updateWeeklyDistanceLeaderboard() async {
        let calendar = Calendar.current
        let now = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return }
        
        // Calculate this week's totals
        let weeklyWorkouts = workouts.filter { workout in
            guard let workoutDate = workout.date else { return false }
            return weekInterval.contains(workoutDate)
        }
        
        let totalDistance = weeklyWorkouts.reduce(0) { $0 + $1.distance }
        let workoutCount = weeklyWorkouts.count
        
        // Update leaderboard
        do {
            try await LeaderboardService.shared.updateUserWeeklyDistance(
                distance: totalDistance,
                workoutCount: workoutCount
            )
            print("✅ Updated weekly distance leaderboard: \(totalDistance) miles, \(workoutCount) workouts")
        } catch {
            print("❌ Failed to update weekly distance leaderboard: \(error)")
        }
    }
    
    /// Calculate and update user's consistency streak
    private func updateConsistencyLeaderboard() async {
        let calendar = Calendar.current
        let streaks = calculateConsistencyStreaks()
        
        let currentStreak = streaks.currentStreak
        let bestStreak = streaks.bestStreak
        let lastWorkoutDate = workouts.last?.date
        
        // Update leaderboard
        do {
            try await LeaderboardService.shared.updateUserConsistencyStreak(
                currentStreak: currentStreak,
                bestStreak: bestStreak,
                lastWorkoutDate: lastWorkoutDate
            )
            print("✅ Updated consistency leaderboard: current=\(currentStreak), best=\(bestStreak)")
        } catch {
            print("❌ Failed to update consistency leaderboard: \(error)")
        }
    }
    
    /// Calculate user's consistency streaks
    private func calculateConsistencyStreaks() -> (currentStreak: Int, bestStreak: Int) {
        let calendar = Calendar.current
        let now = Date()
        
        // Group workouts by week
        let workoutsByWeek = Dictionary(grouping: workouts) { workout in
            guard let date = workout.date else { return Date.distantPast }
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? Date.distantPast
        }
        
        // Get sorted weeks with workouts
        let weeksWithWorkouts = workoutsByWeek.keys
            .filter { $0 != Date.distantPast }
            .sorted()
        
        guard !weeksWithWorkouts.isEmpty else {
            return (currentStreak: 0, bestStreak: 0)
        }
        
        // Calculate current streak (from most recent week backwards)
        var currentStreak = 0
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        // Check if current week has workouts
        if weeksWithWorkouts.contains(currentWeekStart) {
            currentStreak = 1
            
            // Count backwards from current week
            var checkWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)
            while let week = checkWeek, weeksWithWorkouts.contains(week) {
                currentStreak += 1
                checkWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: week)
            }
        } else {
            // Check if last week has workouts (grace period)
            if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart),
               weeksWithWorkouts.contains(lastWeek) {
                currentStreak = 1
                
                // Count backwards from last week
                var checkWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: lastWeek)
                while let week = checkWeek, weeksWithWorkouts.contains(week) {
                    currentStreak += 1
                    checkWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: week)
                }
            }
        }
        
        // Calculate best streak (longest consecutive weeks)
        var bestStreak = 0
        var tempStreak = 0
        
        for (index, week) in weeksWithWorkouts.enumerated() {
            if index == 0 {
                tempStreak = 1
            } else {
                let previousWeek = weeksWithWorkouts[index - 1]
                let expectedPreviousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: week) ?? Date.distantPast
                
                if calendar.isDate(previousWeek, inSameDayAs: expectedPreviousWeek) {
                    tempStreak += 1
                } else {
                    bestStreak = max(bestStreak, tempStreak)
                    tempStreak = 1
                }
            }
        }
        bestStreak = max(bestStreak, tempStreak)
        
        return (currentStreak: currentStreak, bestStreak: max(bestStreak, currentStreak))
    }
}

// MARK: - Workout Manager Integration

extension WorkoutManager {
    
    /// Call this after successfully saving a workout
    func updateLeaderboardsAfterSave() {
        Task { @MainActor in
            // Get the most recent workout and update leaderboards
            let workouts = WorkoutDataManager.shared.workouts
            if let lastWorkout = workouts.last {
                await WorkoutDataManager.shared.updateLeaderboardsAfterWorkout(lastWorkout)
            }
        }
    }
}

// MARK: - Usage Instructions

/*
Integration Instructions:

1. Add the leaderboard card to PhoneMainView.swift:
   - Add `@State private var showingLeaderboards = false` to the state variables
   - Add `leaderboardsCard` to the main content VStack
   - Add the leaderboards sheet modifier

2. Update PremiumManager.swift:
   - Add `.leaderboards` case to PremiumFeature enum
   - Add feature name and description

3. Update SupabaseConfig.swift:
   - Add the three leaderboard table names to Tables struct

4. In WorkoutManager.swift, add this to your workout saving logic:
   ```swift
   // After successfully saving workout
   updateLeaderboardsAfterSave()
   ```

5. Create the database tables using the SQL schema provided

6. The leaderboard will automatically:
   - Update weekly distance totals when workouts are completed
   - Calculate and maintain consistency streaks
   - Show premium gate for free users
   - Provide leaderboard settings for privacy control

The UI matches the existing card style with:
- Same rounded rectangle background
- Premium badge for free users
- Chevron right indicator
- Consistent typography and spacing
*/
