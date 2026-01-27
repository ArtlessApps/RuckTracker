import Foundation
import CoreData

class LocalChallengeStorage {
    static let shared = LocalChallengeStorage()
    
    private let defaults = UserDefaults.standard
    private let enrollmentKey = "enrolled_challenge_id"
    private let enrollmentDateKey = "challenge_enrollment_date"
    
    private init() {}
    
    // MARK: - Challenge Enrollment
    
    func enrollInChallenge(_ challengeId: UUID) {
        defaults.set(challengeId.uuidString, forKey: enrollmentKey)
        defaults.set(Date(), forKey: enrollmentDateKey)
        print("✅ Enrolled in challenge: \(challengeId)")
    }
    
    func getEnrolledChallengeId() -> UUID? {
        guard let idString = defaults.string(forKey: enrollmentKey),
              let uuid = UUID(uuidString: idString) else {
            return nil
        }
        return uuid
    }
    
    func getEnrollmentDate() -> Date? {
        return defaults.object(forKey: enrollmentDateKey) as? Date
    }
    
    func unenrollFromChallenge() {
        // Get the enrolled challenge ID before clearing
        if let challengeId = getEnrolledChallengeId() {
            // Delete all associated workouts
            WorkoutDataManager.shared.deleteWorkoutsForChallenge(challengeId)
            
            // Clear completion tracking
            UserDefaults.standard.removeObject(forKey: "completed_workouts_\(challengeId)")
        }
        
        // Clear enrollment data
        defaults.removeObject(forKey: enrollmentKey)
        defaults.removeObject(forKey: enrollmentDateKey)
        
        print("✅ Unenrolled from challenge and deleted all associated workouts")
    }
    
    func getAllUserChallenges() -> [UserChallenge] {
        // For now, return a single user challenge if enrolled
        guard let challengeId = getEnrolledChallengeId() else {
            return []
        }
        
        let userChallenge = UserChallenge(
            challengeId: challengeId,
            isActive: true
        )
        
        return [userChallenge]
    }
    
    // MARK: - Challenge Progress
    
    func getChallengeProgress(challengeId: UUID) -> ChallengeProgress {
        let completions = getCompletedChallengeDays(challengeId: challengeId)
        let totalDays = getTotalChallengeDays(challengeId: challengeId)
        
        let completionPercentage = totalDays > 0 
            ? Double(completions.count) / Double(totalDays) * 100.0
            : 0.0
        
        let currentDay = completions.count + 1
        let nextWorkoutDay = completions.count + 1
        
        return ChallengeProgress(
            completed: completions.count,
            total: totalDays,
            completionPercentage: completionPercentage,
            currentDay: currentDay,
            nextWorkoutDay: nextWorkoutDay <= totalDays ? nextWorkoutDay : nil
        )
    }
    
    // MARK: - Challenge Workout Completions
    
    func getCompletedChallengeDays(challengeId: UUID) -> [WorkoutEntity] {
        return WorkoutDataManager.shared.workouts.filter { workout in
            workout.challengeId == challengeId.uuidString
        }
    }
    
    func getTotalChallengeDays(challengeId: UUID) -> Int {
        // Get total days from the challenge workout loader
        let workouts = LocalChallengeWorkoutLoader.shared.getWorkouts(forChallengeId: challengeId)
        return workouts.count
    }
}
