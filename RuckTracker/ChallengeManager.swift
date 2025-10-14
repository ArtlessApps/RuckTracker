//
//  ChallengeManager.swift
//  RuckTracker
//
//  Universal challenge state management for any challenge type
//

import Foundation
import SwiftUI

@MainActor
class ChallengeManager: ObservableObject {
    @Published var completedWorkouts: Set<UUID> = []
    @Published var currentWorkout: ChallengeWorkout?
    @Published var workouts: [ChallengeWorkout] = []
    @Published var enrollment: UserChallengeEnrollment?
    @Published var isLoading = false
    
    let challengeService = LocalChallengeService.shared
    private var challenge: Challenge?
    
    // MARK: - Initialization
    
    func loadChallenge(_ challenge: Challenge) async {
        self.challenge = challenge
        isLoading = true
        
        // Load enrollment data
        enrollment = await getEnrollment(for: challenge)
        
        // Load or generate workouts
        workouts = await getWorkouts(for: challenge)
        
        // Load completion state
        await loadCompletionState()
        
        // Set current workout
        updateCurrentWorkout()
        
        isLoading = false
    }
    
    // MARK: - Enrollment Management
    
    private func getEnrollment(for challenge: Challenge) async -> UserChallengeEnrollment? {
        // Check if user is already enrolled
        if challengeService.isEnrolledIn(challengeId: challenge.id) {
            // Create enrollment from existing data
            let userChallenge = challengeService.userChallenges.first { $0.challengeId == challenge.id }
            if let userChallenge = userChallenge {
                return UserChallengeEnrollment(
                    id: userChallenge.id,
                    challengeId: challenge.id,
                    enrolledAt: userChallenge.startDate,
                    startingWeight: userChallenge.currentWeightLbs,
                    completionPercentage: userChallenge.completionPercentage,
                    currentDay: userChallenge.currentDay,
                    isActive: userChallenge.isActive,
                    completedAt: userChallenge.completedAt
                )
            }
        }
        
        return nil
    }
    
    func enrollInChallenge(weightLbs: Double) async throws {
        print("🔧 ChallengeManager.enrollInChallenge called with weight: \(weightLbs)")
        print("🔧 Current challenge is: \(String(describing: self.challenge?.title))")
        
        guard let challenge = self.challenge else { 
            print("❌ No challenge loaded in ChallengeManager - enrollment failed")
            return 
        }
        
        print("🔧 Proceeding with enrollment for challenge: \(challenge.title)")
        challengeService.enrollInChallenge(challenge, startingWeight: weightLbs)
        
        // Create enrollment object
        let newEnrollment = UserChallengeEnrollment(
            challengeId: challenge.id,
            startingWeight: weightLbs
        )
        enrollment = newEnrollment
        
        // Generate personalized workouts based on user weight
        workouts = await generatePersonalizedWorkouts(for: challenge, userWeight: weightLbs)
        
        // Reset completion state for new enrollment
        completedWorkouts.removeAll()
        updateCurrentWorkout()
    }
    
    // MARK: - Workout Management
    
    private func getWorkouts(for challenge: Challenge) async -> [ChallengeWorkout] {
        // Load workouts from the challenge service
        return challengeService.getChallengeWorkouts(forChallengeId: challenge.id)
    }
    
    private func generatePersonalizedWorkouts(for challenge: Challenge, userWeight: Double) async -> [ChallengeWorkout] {
        // Load workouts from the challenge service
        let workouts = challengeService.getChallengeWorkouts(forChallengeId: challenge.id)
        
        // Adjust weights based on user's actual weight if needed
        return workouts.map { workout in
            var adjustedWorkout = workout
            
            if let baseWeight = workout.weightLbs, !workout.isRestDay {
                // Adjust weight based on user's actual weight vs base weight (180 lbs)
                let weightRatio = userWeight / 180.0
                adjustedWorkout = ChallengeWorkout(
                    id: workout.id,
                    challengeId: workout.challengeId,
                    dayNumber: workout.dayNumber,
                    workoutType: workout.workoutType,
                    distanceMiles: workout.distanceMiles,
                    targetPaceMinutes: workout.targetPaceMinutes,
                    weightLbs: baseWeight * weightRatio,
                    durationMinutes: workout.durationMinutes,
                    instructions: workout.instructions,
                    isRestDay: workout.isRestDay,
                    createdAt: workout.createdAt,
                    updatedAt: workout.updatedAt
                )
            }
            
            return adjustedWorkout
        }
    }
    
    // MARK: - Completion Tracking
    
    func isWorkoutCompleted(_ workoutId: UUID) -> Bool {
        return completedWorkouts.contains(workoutId)
    }
    
    func canCompleteWorkout(_ workout: ChallengeWorkout) -> Bool {
        guard enrollment != nil else { return false }
        
        // Can only complete current day or past days
        let currentDay = getCurrentDay()
        return workout.dayNumber <= currentDay
    }
    
    func isWorkoutLocked(_ workout: ChallengeWorkout) -> Bool {
        guard enrollment != nil else { return true }
        
        // Workout is locked if any previous workout is not completed
        let previousWorkouts = workouts.filter { $0.dayNumber < workout.dayNumber }
        for prevWorkout in previousWorkouts {
            if !completedWorkouts.contains(prevWorkout.id) {
                return true
            }
        }
        
        return false
    }
    
    func completeWorkout(_ workout: ChallengeWorkout) async {
        // Mark as completed locally
        completedWorkouts.insert(workout.id)
        
        // Save completion to service
        await saveWorkoutCompletion(workout)
        
        // Update current workout to next uncompleted
        updateCurrentWorkout()
        
        // Update enrollment progress
        await updateEnrollmentProgress()
    }
    
    private func saveWorkoutCompletion(_ workout: ChallengeWorkout) async {
        // Save to UserDefaults for persistence
        let completedArray = Array(completedWorkouts).map { $0.uuidString }
        UserDefaults.standard.set(completedArray, forKey: "completed_workouts_\(workout.challengeId)")
        
        // TODO: Also save to server via challengeService when available
        print("✅ Saved completion for workout \(workout.dayNumber)")
    }
    
    private func loadCompletionState() async {
        guard let challenge = challenge else { return }
        
        // Load from UserDefaults
        let completedArray = UserDefaults.standard.stringArray(forKey: "completed_workouts_\(challenge.id)") ?? []
        completedWorkouts = Set(completedArray.compactMap { UUID(uuidString: $0) })
        
        print("📱 Loaded \(completedWorkouts.count) completed workouts for challenge")
    }
    
    private func updateEnrollmentProgress() async {
        guard let enrollment = enrollment else { return }
        
        let completionPercentage = Double(completedWorkouts.count) / Double(workouts.count) * 100.0
        
        // Update local enrollment
        self.enrollment?.completionPercentage = completionPercentage
        
        // Update local storage
        // TODO: Update server when available
        print("✅ Updated enrollment progress to \(completionPercentage)%")
    }
    
    // MARK: - Current Day Logic
    
    private func getCurrentDay() -> Int {
        guard let enrollment = enrollment else { return 1 }
        
        let calendar = Calendar.current
        let daysSinceEnrollment = calendar.dateComponents([.day], from: enrollment.enrolledAt, to: Date()).day ?? 0
        
        // Return current day (1-based), capped at challenge duration
        return min(daysSinceEnrollment + 1, challenge?.durationDays ?? 7)
    }
    
    private func updateCurrentWorkout() {
        // Find the first uncompleted workout
        currentWorkout = workouts.first { workout in
            !completedWorkouts.contains(workout.id) && canCompleteWorkout(workout)
        }
    }
    
    // MARK: - Progress Helpers
    
    var progressPercentage: Double {
        guard !workouts.isEmpty else { return 0.0 }
        return Double(completedWorkouts.count) / Double(workouts.count)
    }
    
    var completedWorkoutCount: Int {
        return completedWorkouts.count
    }
    
    var totalWorkoutCount: Int {
        return workouts.count
    }
    
    var isFullyCompleted: Bool {
        return completedWorkouts.count == workouts.count && !workouts.isEmpty
    }
    
    // MARK: - Cleanup
    
    func reset() {
        completedWorkouts.removeAll()
        currentWorkout = nil
        workouts.removeAll()
        enrollment = nil
        challenge = nil
    }
}
