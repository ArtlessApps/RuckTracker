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
    private let workoutLoader = LocalChallengeWorkoutLoader.shared
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
    
    func enrollInChallenge(_ challenge: Challenge) {
        storage.enrollInChallenge(challenge.id)
        enrolledChallenge = challenge
        challengeProgress = storage.getChallengeProgress(challengeId: challenge.id)
        
        // Reload user challenges to include the new enrollment
        loadUserChallenges()
        
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
    
    // MARK: - Challenge Workouts
    
    func getChallengeWorkouts(forChallengeId challengeId: UUID) -> [ChallengeWorkout] {
        return workoutLoader.getWorkouts(forChallengeId: challengeId)
    }
    
    func getChallengeWorkout(forChallengeId challengeId: UUID, dayNumber: Int) -> ChallengeWorkout? {
        return workoutLoader.getWorkouts(forChallengeId: challengeId).first { $0.dayNumber == dayNumber }
    }
    
    func getActiveChallengeWorkouts(forChallengeId challengeId: UUID) -> [ChallengeWorkout] {
        return workoutLoader.getWorkouts(forChallengeId: challengeId).filter { !$0.isRestDay }
    }
    
    func getRestDays(forChallengeId challengeId: UUID) -> [ChallengeWorkout] {
        return workoutLoader.getWorkouts(forChallengeId: challengeId).filter { $0.isRestDay }
    }
    
    func getCurrentChallengeWorkout() -> ChallengeWorkout? {
        guard let enrolledChallengeId = getEnrolledChallengeId() else { return nil }
        guard let progress = challengeProgress else { return nil }
        
        return getChallengeWorkout(forChallengeId: enrolledChallengeId, dayNumber: progress.currentDay)
    }
    
    func getNextChallengeWorkout() -> ChallengeWorkout? {
        guard let enrolledChallengeId = getEnrolledChallengeId() else { return nil }
        guard let progress = challengeProgress else { return nil }
        
        let nextDay = progress.nextWorkoutDay ?? (progress.currentDay + 1)
        return getChallengeWorkout(forChallengeId: enrolledChallengeId, dayNumber: nextDay)
    }
    
    // MARK: - Challenge Workout Loading
    
    func loadChallengeWorkouts(challengeId: UUID) -> [ChallengeWorkout] {
        let workouts = workoutLoader.getWorkouts(forChallengeId: challengeId)
        print("✅ Loaded \(workouts.count) workouts for challenge: \(challengeId)")
        return workouts
    }
    
    func loadChallengeWorkouts(challengeId: UUID) async -> [ChallengeWorkout] {
        let workouts = workoutLoader.getWorkouts(forChallengeId: challengeId)
        print("✅ Loaded \(workouts.count) workouts for challenge: \(challengeId)")
        return workouts
    }
    
    // MARK: - Challenge Workout Completion
    
    func completeWorkout(
        challengeId: UUID,
        workoutDay: Int,
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
            recentWorkout.challengeDay = Int16(workoutDay)
            WorkoutDataManager.shared.saveContext()
        }
        
        // Recalculate progress
        challengeProgress = storage.getChallengeProgress(challengeId: enrolledChallengeId)
        
        // Trigger UI update
        objectWillChange.send()
        
        print("✅ Completed workout day \(workoutDay) for challenge")
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
        
        // Test challenge workouts
        let workouts = getChallengeWorkouts(forChallengeId: challengeId)
        print("🏋️ Challenge Workouts: \(workouts.count)")
        
        let activeWorkouts = getActiveChallengeWorkouts(forChallengeId: challengeId)
        print("💪 Active Workouts: \(activeWorkouts.count)")
        
        let restDays = getRestDays(forChallengeId: challengeId)
        print("😴 Rest Days: \(restDays.count)")
        
        print("✅ Integration test complete\n")
    }
    
    // MARK: - Challenge Workout Testing
    
    func testChallengeWorkoutLoading() {
        print("\n🧪 Testing Challenge Workout Loading")
        
        // Test loading challenge workouts
        let challengeId = UUID(uuidString: "f1c56e9d-7c3a-4325-adb1-739e5f48b7bb")!
        let workouts = getChallengeWorkouts(forChallengeId: challengeId)
        
        print("📊 Total Workouts: \(workouts.count)")
        
        for workout in workouts {
            print("🏋️ Day \(workout.dayNumber): \(workout.workoutType.displayName)")
            if let distance = workout.distanceMiles {
                print("   📏 Distance: \(distance) miles")
            }
            if let weight = workout.weightLbs {
                print("   ⚖️ Weight: \(weight) lbs")
            }
            if let duration = workout.durationMinutes {
                print("   ⏱️ Duration: \(duration) minutes")
            }
            if let instructions = workout.instructions {
                print("   📝 Instructions: \(instructions)")
            }
            print("   😴 Rest Day: \(workout.isRestDay)")
            print("")
        }
        
        let activeWorkouts = getActiveChallengeWorkouts(forChallengeId: challengeId)
        let restDays = getRestDays(forChallengeId: challengeId)
        
        print("💪 Active Workouts: \(activeWorkouts.count)")
        print("😴 Rest Days: \(restDays.count)")
        
        // Test specific day lookup
        if let day1Workout = getChallengeWorkout(forChallengeId: challengeId, dayNumber: 1) {
            print("✅ Day 1 workout found: \(day1Workout.workoutType.displayName)")
        } else {
            print("❌ Day 1 workout not found")
        }
        
        print("✅ Challenge workout loading test complete\n")
    }
}
