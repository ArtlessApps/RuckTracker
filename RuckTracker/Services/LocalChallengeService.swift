import Foundation
import Combine

@MainActor
class LocalChallengeService: ObservableObject {
    static let shared = LocalChallengeService()
    
    // Published state
    @Published var challenges: [Challenge] = []
    @Published var userChallenges: [UserChallenge] = []
    @Published var enrolledChallenge: Challenge?
    @Published var challengeProgress: ChallengeProgress?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storage = LocalChallengeStorage.shared
    private var localChallenges: [LocalChallenge] = []
    
    private init() {
        loadChallenges()
        loadUserChallenges()
        loadEnrollmentStatus()
    }
    
    // MARK: - Challenge Loading
    
    func loadChallenges() {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load from bundled JSON with custom decoder
            let result: Result<[LocalChallenge], Error> = Bundle.main.decodeWithCustomDecoder("Challenges.json")
            
            switch result {
            case .success(let loadedChallenges):
                localChallenges = loadedChallenges
                challenges = loadedChallenges.map { $0.toChallenge() }
                print("✅ Loaded \(challenges.count) challenges from bundle")
                
            case .failure(let error):
                errorMessage = "Failed to load challenges: \(error.localizedDescription)"
                print("❌ Error loading challenges: \(error)")
                print("❌ CRITICAL: Challenges.json must be added to the bundle")
                // No fallback - challenges should come from JSON only
                challenges = []
            }
        }
        
        isLoading = false
    }
    
    func loadUserChallenges() {
        userChallenges = storage.getAllUserChallenges()
        print("✅ Loaded \(userChallenges.count) user challenges")
    }
    
    func loadEnrollmentStatus() {
        guard let challengeId = storage.getEnrolledChallengeId() else {
            enrolledChallenge = nil
            challengeProgress = nil
            return
        }
        
        // Find the enrolled challenge
        enrolledChallenge = challenges.first { $0.id == challengeId }
        
        // Calculate progress
        if enrolledChallenge != nil {
            challengeProgress = storage.getChallengeProgress(challengeId: challengeId)
        }
        
        print("✅ Loaded enrollment status: \(enrolledChallenge?.title ?? "None")")
    }
    
    // MARK: - Challenge Enrollment
    
    func enrollInChallenge(_ challenge: Challenge, startingWeight: Double) {
        storage.enrollInChallenge(challenge.id, startingWeight: startingWeight)
        enrolledChallenge = challenge
        challengeProgress = storage.getChallengeProgress(challengeId: challenge.id)
        
        // Trigger UI update
        objectWillChange.send()
        
        print("✅ Enrolled in challenge: \(challenge.title)")
    }
    
    func unenrollFromChallenge() {
        storage.unenrollFromChallenge()
        enrolledChallenge = nil
        challengeProgress = nil
        
        print("✅ Unenrolled from current challenge")
    }
    
    // MARK: - Challenge Completion
    
    func completeChallengeDay(
        challengeId: UUID,
        day: Int,
        distanceMiles: Double,
        weightLbs: Double,
        durationMinutes: Int,
        notes: String? = nil
    ) {
        // Workout is already saved to CoreData by WorkoutManager
        // Just need to link it to the challenge
        
        guard let enrolledChallengeId = storage.getEnrolledChallengeId() else {
            print("❌ No enrolled challenge found")
            return
        }
        
        // Update the most recent workout with challenge metadata
        if let recentWorkout = WorkoutDataManager.shared.workouts.first {
            recentWorkout.challengeId = enrolledChallengeId.uuidString
            recentWorkout.challengeDay = Int16(day)
            WorkoutDataManager.shared.saveContext()
        }
        
        // Recalculate progress
        challengeProgress = storage.getChallengeProgress(challengeId: enrolledChallengeId)
        
        // Trigger UI update
        objectWillChange.send()
        
        print("✅ Completed challenge day \(day)")
    }
    
    // MARK: - Helper Methods
    
    func isEnrolledIn(challengeId: UUID) -> Bool {
        return storage.getEnrolledChallengeId() == challengeId
    }
    
    func getEnrolledChallengeId() -> UUID? {
        return storage.getEnrolledChallengeId()
    }
    
    // MARK: - Testing
    
    func testChallengeIntegration(challengeId: UUID) {
        print("\n🧪 Testing Challenge Integration for Challenge: \(challengeId)")
        
        guard let challenge = challenges.first(where: { $0.id == challengeId }) else {
            print("❌ Challenge not found")
            return
        }
        
        print("📚 Challenge: \(challenge.title)")
        print("📅 Duration: \(challenge.durationDays) days")
        print("🎯 Focus: \(challenge.focusArea.displayName)")
        
        if let weightPercentage = challenge.weightPercentage {
            print("⚖️ Weight: \(weightPercentage)% of body weight")
        }
        
        if let paceTarget = challenge.paceTarget {
            print("🏃 Pace Target: \(paceTarget) min/mile")
        }
        
        print("✅ Integration test complete\n")
    }
}
