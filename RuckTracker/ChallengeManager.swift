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
    
    private let challengeService = StackChallengeService()
    private var challenge: StackChallenge?
    
    // MARK: - Initialization
    
    func loadChallenge(_ challenge: StackChallenge) async {
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
    
    private func getEnrollment(for challenge: StackChallenge) async -> UserChallengeEnrollment? {
        // Check if user is already enrolled
        if let existingEnrollment = challengeService.getUserEnrollment(for: challenge) {
            return existingEnrollment
        }
        
        return nil
    }
    
    func enrollInChallenge(weightLbs: Double) async throws {
        guard let challenge = challenge else { return }
        
        let newEnrollment = try await challengeService.enrollInChallenge(challenge, weightLbs: weightLbs)
        enrollment = newEnrollment
        
        // Generate personalized workouts based on user weight
        workouts = await generatePersonalizedWorkouts(for: challenge, userWeight: weightLbs)
        
        // Reset completion state for new enrollment
        completedWorkouts.removeAll()
        updateCurrentWorkout()
    }
    
    // MARK: - Workout Management
    
    private func getWorkouts(for challenge: StackChallenge) async -> [ChallengeWorkout] {
        // For now, use mock generation - can be replaced with server data later
        return ChallengeWorkout.generateMockWorkouts(for: challenge)
    }
    
    private func generatePersonalizedWorkouts(for challenge: StackChallenge, userWeight: Double) async -> [ChallengeWorkout] {
        // This would eventually call the server for dynamic generation
        // For now, use the mock generation with user weight consideration
        let mockWorkouts = ChallengeWorkout.generateMockWorkouts(for: challenge)
        
        // Adjust weights based on user's actual weight
        return mockWorkouts.map { workout in
            var adjustedWorkout = workout
            
            if let baseWeight = workout.weightLbs, !workout.isRestDay {
                // Adjust weight based on user's actual weight vs mock weight (180 lbs)
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
                    isRestDay: workout.isRestDay
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
        
        // TODO: Update server when available
        do {
            try await challengeService.updateEnrollmentProgress(enrollment.id, completionPercentage: completionPercentage)
        } catch {
            print("❌ Failed to update enrollment progress: \(error)")
        }
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
