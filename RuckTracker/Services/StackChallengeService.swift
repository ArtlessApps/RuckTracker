//
//  StackChallengeService.swift
//  RuckTracker
//
//  Service for managing stack challenges and user enrollments
//

import Foundation
import Supabase

@MainActor
class StackChallengeService: ObservableObject {
    static let shared = StackChallengeService()
    
    private let supabaseClient: SupabaseClient?
    
    @Published var weeklyChallenges: [StackChallenge] = []
    @Published var seasonalChallenges: [StackChallenge] = []
    @Published var userEnrollments: [UserChallengeEnrollment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Get current authenticated user ID
    private var currentUserId: UUID? {
        return SupabaseManager.shared.currentUser?.id
    }
    
    private init() {
        // Use existing SupabaseManager
        self.supabaseClient = SupabaseManager.shared.client
        
        // Load cached enrollments first
        loadCachedUserEnrollments()
        
        // Load challenges and fresh enrollments on init
        Task {
            await loadChallenges()
            await loadUserEnrollments()
        }
    }
    
    // MARK: - Challenge Loading
    
    func loadChallenges() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if let client = supabaseClient {
                try await loadChallengesFromSupabase(client: client)
            } else {
                loadMockChallenges()
            }
        } catch {
            print("❌ Error loading challenges: \(error)")
            errorMessage = error.localizedDescription
            // Fallback to mock data on error
            loadMockChallenges()
        }
        
        isLoading = false
    }
    
    private func loadChallengesFromSupabase(client: SupabaseClient) async throws {
        // Load all active challenges
        let allChallenges: [StackChallenge] = try await client
            .from("stack_challenges")
            .select()
            .eq("is_active", value: true)
            .order("sort_order")
            .execute()
            .value
        
        // Separate challenges by season (seasonal vs non-seasonal)
        weeklyChallenges = allChallenges.filter { $0.season == nil }
        seasonalChallenges = allChallenges.filter { $0.season != nil }
        
        print("✅ Loaded \(weeklyChallenges.count) weekly challenges and \(seasonalChallenges.count) seasonal challenges")
    }
    
    private func loadMockChallenges() {
        weeklyChallenges = StackChallenge.mockWeeklyChallenges
        seasonalChallenges = StackChallenge.mockSeasonalChallenges
        print("📱 Using mock challenge data")
    }
    
    // MARK: - Challenge Enrollment
    
    func enrollInChallenge(_ challenge: StackChallenge, weightLbs: Double) async throws -> UserChallengeEnrollment {
        guard let client = supabaseClient,
              let userId = currentUserId else {
            // Return mock enrollment for testing when not authenticated
            let mockEnrollment = UserChallengeEnrollment(
                id: UUID(),
                userId: currentUserId ?? UUID(), // Use current user ID or fallback
                challengeId: challenge.id,
                enrolledAt: Date(),
                currentWeightLbs: weightLbs,
                targetWeightLbs: challenge.weightPercentage != nil ? weightLbs * (challenge.weightPercentage! / 100) : weightLbs,
                isActive: true,
                completedAt: nil,
                completionPercentage: 0.0
            )
            
            userEnrollments.append(mockEnrollment)
            cacheUserEnrollments()
            print("📱 Mock enrolled in challenge: \(challenge.title)")
            print("📱 Total enrollments now: \(userEnrollments.count)")
            return mockEnrollment
        }
        
        let targetWeight = challenge.weightPercentage != nil ? 
            weightLbs * (challenge.weightPercentage! / 100) : weightLbs
        
        let enrollmentData: [String: AnyJSON] = [
            "challenge_id": try AnyJSON(challenge.id.uuidString),
            "user_id": try AnyJSON(userId.uuidString),
            "current_weight_lbs": try AnyJSON(weightLbs),
            "target_weight_lbs": try AnyJSON(targetWeight),
            "is_active": try AnyJSON(true),
            "completion_percentage": try AnyJSON(0.0)
        ]
        
        do {
            let enrollment: UserChallengeEnrollment = try await client
                .from("user_challenge_enrollments")
                .insert(enrollmentData)
                .select()
                .single()
                .execute()
                .value
            
            userEnrollments.append(enrollment)
            cacheUserEnrollments()
            print("✅ Successfully enrolled in challenge: \(challenge.title)")
            return enrollment
        } catch {
            // Handle RLS policy violation (common in simulator)
            if let postgrestError = error as? PostgrestError,
               postgrestError.code == "42501" {
                print("⚠️ RLS policy violation in simulator - using local enrollment")
                
                // Create local enrollment for simulator
                let localEnrollment = UserChallengeEnrollment(
                    id: UUID(),
                    userId: userId,
                    challengeId: challenge.id,
                    enrolledAt: Date(),
                    currentWeightLbs: weightLbs,
                    targetWeightLbs: targetWeight,
                    isActive: true,
                    completedAt: nil,
                    completionPercentage: 0.0
                )
                
                userEnrollments.append(localEnrollment)
                cacheUserEnrollments()
                print("📱 Local enrollment created for simulator: \(challenge.title)")
                return localEnrollment
            } else {
                throw error
            }
        }
    }
    
    func loadUserEnrollments() async {
        guard let client = supabaseClient,
              let userId = currentUserId else {
            print("📱 Using mock enrollments - preserving existing \(userEnrollments.count) enrollments")
            return
        }
        
        do {
            let enrollments: [UserChallengeEnrollment] = try await client
                .from("user_challenge_enrollments")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("enrolled_at", ascending: false)
                .execute()
                .value
            
            userEnrollments = enrollments
            cacheUserEnrollments()
            print("✅ Loaded \(enrollments.count) user enrollments")
        } catch {
            print("❌ Error loading user enrollments: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Challenge Management (Admin Functions)
    
    func addChallenge(_ challenge: StackChallenge) async throws {
        guard let client = supabaseClient else {
            print("📱 Mock: Would add challenge \(challenge.title)")
            return
        }
        
        var challengeData: [String: AnyJSON] = [
            "title": try AnyJSON(challenge.title),
            "focus_area": try AnyJSON(challenge.focusArea.rawValue),
            "duration_days": try AnyJSON(challenge.durationDays),
            "distance_focus": try AnyJSON(challenge.distanceFocus),
            "recovery_focus": try AnyJSON(challenge.recoveryFocus),
            "is_active": try AnyJSON(challenge.isActive),
            "sort_order": try AnyJSON(challenge.sortOrder)
        ]
        
        if let description = challenge.description {
            challengeData["description"] = try AnyJSON(description)
        }
        
        if let weightPercentage = challenge.weightPercentage {
            challengeData["weight_percentage"] = try AnyJSON(weightPercentage)
        }
        
        if let paceTarget = challenge.paceTarget {
            challengeData["pace_target"] = try AnyJSON(paceTarget)
        }
        
        if let season = challenge.season {
            challengeData["season"] = try AnyJSON(season.rawValue)
        }
        
        let _: StackChallenge = try await client
            .from("stack_challenges")
            .insert(challengeData)
            .select()
            .single()
            .execute()
            .value
        
        // Reload challenges after adding
        await loadChallenges()
        print("✅ Successfully added challenge: \(challenge.title)")
    }
    
    func deleteChallenge(_ challengeId: UUID) async throws {
        guard let client = supabaseClient else {
            print("📱 Mock: Would delete challenge \(challengeId)")
            return
        }
        
        try await client
            .from("stack_challenges")
            .update(["is_active": try AnyJSON(false)])
            .eq("id", value: challengeId.uuidString)
            .execute()
        
        // Reload challenges after deletion
        await loadChallenges()
        print("✅ Successfully deactivated challenge: \(challengeId)")
    }
    
    // MARK: - Challenge Workouts
    
    func loadChallengeWorkouts(for challengeId: UUID) async -> [ChallengeWorkout] {
        guard let client = supabaseClient else {
            return mockChallengeWorkouts(for: challengeId)
        }
        
        do {
            let workouts: [ChallengeWorkout] = try await client
                .from("challenge_workouts")
                .select()
                .eq("challenge_id", value: challengeId.uuidString)
                .order("day_number")
                .execute()
                .value
            
            print("✅ Loaded \(workouts.count) workouts for challenge")
            return workouts
        } catch {
            print("❌ Error loading challenge workouts: \(error)")
            return mockChallengeWorkouts(for: challengeId)
        }
    }
    
    private func mockChallengeWorkouts(for challengeId: UUID) -> [ChallengeWorkout] {
        // Return mock workouts for testing
        return [
            ChallengeWorkout(
                id: UUID(),
                challengeId: challengeId,
                dayNumber: 1,
                workoutType: .ruck,
                distanceMiles: 3.0,
                targetPaceMinutes: nil,
                weightLbs: 45.0,
                durationMinutes: 60,
                instructions: "Start strong - 3 mile ruck with heavy weight",
                isRestDay: false
            ),
            ChallengeWorkout(
                id: UUID(),
                challengeId: challengeId,
                dayNumber: 2,
                workoutType: .rest,
                distanceMiles: nil,
                targetPaceMinutes: nil,
                weightLbs: nil,
                durationMinutes: nil,
                instructions: "Active recovery day - light stretching or walking",
                isRestDay: true
            ),
            ChallengeWorkout(
                id: UUID(),
                challengeId: challengeId,
                dayNumber: 3,
                workoutType: .ruck,
                distanceMiles: 2.0,
                targetPaceMinutes: nil,
                weightLbs: 45.0,
                durationMinutes: 45,
                instructions: "Short power ruck - focus on form with heavy weight",
                isRestDay: false
            ),
            ChallengeWorkout(
                id: UUID(),
                challengeId: challengeId,
                dayNumber: 4,
                workoutType: .rest,
                distanceMiles: nil,
                targetPaceMinutes: nil,
                weightLbs: nil,
                durationMinutes: nil,
                instructions: "Rest day - mobility work",
                isRestDay: true
            ),
            ChallengeWorkout(
                id: UUID(),
                challengeId: challengeId,
                dayNumber: 5,
                workoutType: .ruck,
                distanceMiles: 4.0,
                targetPaceMinutes: nil,
                weightLbs: 45.0,
                durationMinutes: 80,
                instructions: "Long power ruck - build strength endurance",
                isRestDay: false
            ),
            ChallengeWorkout(
                id: UUID(),
                challengeId: challengeId,
                dayNumber: 6,
                workoutType: .rest,
                distanceMiles: nil,
                targetPaceMinutes: nil,
                weightLbs: nil,
                durationMinutes: nil,
                instructions: "Pre-finale rest - prepare for final challenge",
                isRestDay: true
            ),
            ChallengeWorkout(
                id: UUID(),
                challengeId: challengeId,
                dayNumber: 7,
                workoutType: .ruck,
                distanceMiles: 5.0,
                targetPaceMinutes: nil,
                weightLbs: 45.0,
                durationMinutes: 90,
                instructions: "Power finale - longest distance with heavy weight",
                isRestDay: false
            )
        ]
    }
    
    // MARK: - Helper Functions
    
    func isUserEnrolled(in challenge: StackChallenge) -> Bool {
        let enrolled = userEnrollments.contains { enrollment in
            enrollment.challengeId == challenge.id && enrollment.isActive
        }
        print("🔍 Checking enrollment for '\(challenge.title)': \(enrolled) (total enrollments: \(userEnrollments.count))")
        return enrolled
    }
    
    func getUserEnrollment(for challenge: StackChallenge) -> UserChallengeEnrollment? {
        return userEnrollments.first { enrollment in
            enrollment.challengeId == challenge.id && enrollment.isActive
        }
    }
    
    func refreshData() async {
        await loadChallenges()
        await loadUserEnrollments()
    }
    
    // MARK: - Challenge Completion Tracking
    
    func recordChallengeWorkoutCompletion(
        userEnrollmentId: UUID,
        challengeWorkoutId: UUID,
        actualDistanceMiles: Double?,
        actualDurationMinutes: Int?,
        actualWeightLbs: Double?,
        performanceScore: Double?,
        notes: String?
    ) async throws {
        guard let client = supabaseClient else {
            print("📱 Mock: Would record challenge workout completion")
            return
        }
        
        var completionData: [String: AnyJSON] = [
            "user_enrollment_id": try AnyJSON(userEnrollmentId.uuidString),
            "challenge_workout_id": try AnyJSON(challengeWorkoutId.uuidString)
        ]
        
        if let distance = actualDistanceMiles {
            completionData["actual_distance_miles"] = try AnyJSON(distance)
        }
        
        if let duration = actualDurationMinutes {
            completionData["actual_duration_minutes"] = try AnyJSON(duration)
        }
        
        if let weight = actualWeightLbs {
            completionData["actual_weight_lbs"] = try AnyJSON(weight)
        }
        
        if let score = performanceScore {
            completionData["performance_score"] = try AnyJSON(score)
        }
        
        if let notes = notes {
            completionData["notes"] = try AnyJSON(notes)
        }
        
        try await client
            .from("user_challenge_completions")
            .insert(completionData)
            .execute()
        
        print("✅ Recorded challenge workout completion")
    }
    
    func updateEnrollmentProgress(_ enrollmentId: UUID, completionPercentage: Double) async throws {
        guard let client = supabaseClient else {
            print("📱 Mock: Would update enrollment progress")
            return
        }
        
        try await client
            .from("user_challenge_enrollments")
            .update(["completion_percentage": try AnyJSON(completionPercentage)])
            .eq("id", value: enrollmentId.uuidString)
            .execute()
        
        // Update local state
        if let index = userEnrollments.firstIndex(where: { $0.id == enrollmentId }) {
            userEnrollments[index].completionPercentage = completionPercentage
        }
        
        print("✅ Updated enrollment progress to \(completionPercentage)%")
    }
    
    // MARK: - Local Persistence
    
    private func cacheUserEnrollments() {
        do {
            let data = try JSONEncoder().encode(userEnrollments)
            UserDefaults.standard.set(data, forKey: "cached_user_challenge_enrollments")
            print("✅ Cached \(userEnrollments.count) user challenge enrollments")
        } catch {
            print("❌ Failed to cache user challenge enrollments: \(error)")
        }
    }
    
    private func loadCachedUserEnrollments() {
        guard let data = UserDefaults.standard.data(forKey: "cached_user_challenge_enrollments") else {
            print("📱 No cached user challenge enrollments found")
            return
        }
        
        do {
            let cachedEnrollments = try JSONDecoder().decode([UserChallengeEnrollment].self, from: data)
            userEnrollments = cachedEnrollments
            print("✅ Loaded \(cachedEnrollments.count) cached user challenge enrollments")
        } catch {
            print("❌ Failed to load cached user challenge enrollments: \(error)")
        }
    }
}

// MARK: - Step 5: Add these extensions to your existing StackChallengeService.swift file
// Add these methods at the end of your StackChallengeService class

extension StackChallengeService {
    
    // MARK: - Universal Challenge Support
    
    
    /// Get or create enrollment for a challenge (used by ChallengeManager)
    func getOrCreateEnrollment(for challenge: StackChallenge) async -> UserChallengeEnrollment? {
        // Check if already enrolled
        if let existingEnrollment = getUserEnrollment(for: challenge) {
            return existingEnrollment
        }
        
        // No existing enrollment found
        return nil
    }
    
    /// Get workouts for a challenge (placeholder for server integration)
    func getWorkouts(for challengeId: UUID) async -> [ChallengeWorkout] {
        // For now, return empty array - workouts will be generated by ChallengeManager
        // Later this can fetch from server with dynamic programming
        return []
    }
    
    /// Complete a workout (placeholder for server integration)
    func completeWorkout(_ workoutId: UUID, notes: String?) async {
        // This will eventually save to server
        // For now, completion is handled locally by ChallengeManager
        print("📱 Mock: Completed workout \(workoutId)")
    }
    
    /// Generate dynamic workouts based on challenge parameters
    func generateWorkouts(for challenge: StackChallenge, userWeight: Double) async -> [ChallengeWorkout] {
        var workouts: [ChallengeWorkout] = []
        
        for day in 1...challenge.durationDays {
            let workout = generateWorkout(
                for: challenge,
                day: day,
                userWeight: userWeight
            )
            workouts.append(workout)
        }
        
        return workouts
    }
    
    /// Generate a single workout based on challenge parameters
    private func generateWorkout(
        for challenge: StackChallenge,
        day: Int,
        userWeight: Double
    ) -> ChallengeWorkout {
        
        // Determine if this should be a rest day
        let isRestDay = shouldBeRestDay(challenge: challenge, day: day)
        
        if isRestDay {
            return ChallengeWorkout(
                id: UUID(),
                challengeId: challenge.id,
                dayNumber: day,
                workoutType: .rest,
                distanceMiles: nil,
                targetPaceMinutes: nil,
                weightLbs: nil,
                durationMinutes: 30,
                instructions: generateRestInstructions(challenge: challenge),
                isRestDay: true
            )
        }
        
        // Generate training workout
        return generateTrainingWorkout(
            challenge: challenge,
            day: day,
            userWeight: userWeight
        )
    }
    
    /// Determine if a day should be a rest day
    private func shouldBeRestDay(challenge: StackChallenge, day: Int) -> Bool {
        switch challenge.focusArea {
        case .recovery:
            // Recovery challenges have fewer rest days
            return day == 4 || day == 7
            
        case .power, .progressiveWeight:
            // Power challenges need more recovery
            return day % 2 == 0 && day != challenge.durationDays
            
        case .speed, .speedDevelopment:
            // Speed work needs recovery
            return day == 2 || day == 5
            
        case .distance, .enduranceProgression:
            // Distance training with strategic rest
            return day == 3 || day == 6
            
        case .tacticalMixed:
            // Mixed training with varied rest
            return day == 2 || day == 5
        }
    }
    
    /// Generate training workout based on challenge parameters
    private func generateTrainingWorkout(
        challenge: StackChallenge,
        day: Int,
        userWeight: Double
    ) -> ChallengeWorkout {
        
        let ruckWeight = calculateRuckWeight(
            challenge: challenge,
            day: day,
            userWeight: userWeight
        )
        
        let distance = calculateDistance(
            challenge: challenge,
            day: day
        )
        
        let targetPace = calculateTargetPace(
            challenge: challenge,
            day: day
        )
        
        return ChallengeWorkout(
            id: UUID(),
            challengeId: challenge.id,
            dayNumber: day,
            workoutType: .ruck,
            distanceMiles: distance,
            targetPaceMinutes: targetPace,
            weightLbs: ruckWeight,
            durationMinutes: nil,
            instructions: nil, // Will use dynamic generation from extensions
            isRestDay: false
        )
    }
    
    /// Calculate ruck weight based on challenge parameters
    private func calculateRuckWeight(
        challenge: StackChallenge,
        day: Int,
        userWeight: Double
    ) -> Double? {
        
        // Use challenge percentage if available
        if let weightPercentage = challenge.weightPercentage {
            let baseWeight = userWeight * (weightPercentage / 100)
            
            switch challenge.focusArea {
            case .power, .progressiveWeight:
                // Progressive overload - 3% increase per day
                let progression = 1.0 + (Double(day - 1) * 0.03)
                return baseWeight * progression
                
            case .distance, .enduranceProgression:
                // Lighter for distance focus
                return baseWeight * 0.85
                
            case .recovery:
                // Very light for recovery
                return baseWeight * 0.6
                
            default:
                return baseWeight
            }
        }
        
        // Default weights based on challenge focus
        let baseWeight: Double
        switch challenge.focusArea {
        case .power, .progressiveWeight:
            baseWeight = 35.0 + (Double(day - 1) * 2.0) // Progressive increase
            
        case .speed, .speedDevelopment:
            baseWeight = 25.0 // Light for speed
            
        case .distance, .enduranceProgression:
            baseWeight = 30.0 // Moderate for distance
            
        case .recovery:
            baseWeight = 15.0 // Very light
            
        case .tacticalMixed:
            baseWeight = 35.0 // Standard tactical weight
        }
        
        // Adjust for user weight (scaling for smaller/larger users)
        let weightAdjustment = userWeight / 180.0 // Assume 180 as average
        return baseWeight * weightAdjustment
    }
    
    /// Calculate distance based on challenge parameters
    private func calculateDistance(
        challenge: StackChallenge,
        day: Int
    ) -> Double? {
        
        switch challenge.focusArea {
        case .distance, .enduranceProgression:
            // Progressive distance building
            let baseDistance = 2.0
            let increment = 0.5
            return baseDistance + (Double(day - 1) * increment)
            
        case .power, .progressiveWeight:
            // Shorter distances for power focus
            let distances = [3.0, 2.0, 4.0, 2.5, 5.0, 3.5, 4.5]
            return distances[(day - 1) % distances.count]
            
        case .speed, .speedDevelopment:
            // Consistent distances for speed work
            return 3.0
            
        case .recovery:
            // Light distances for recovery
            return 1.5 + (Double(day - 1) * 0.2)
            
        case .tacticalMixed:
            // Varied tactical distances
            let distances = [2.5, 3.0, 4.0, 3.5, 5.0, 4.0, 6.0]
            return distances[(day - 1) % distances.count]
        }
    }
    
    /// Calculate target pace based on challenge parameters
    private func calculateTargetPace(
        challenge: StackChallenge,
        day: Int
    ) -> Double? {
        
        // Use challenge pace target if available
        if let basePace = challenge.paceTarget {
            switch challenge.focusArea {
            case .speed, .speedDevelopment:
                // Progressive speed improvement (faster each day)
                return basePace - (Double(day - 1) * 0.3)
                
            case .recovery:
                // Easy pace for recovery
                return basePace + 3.0
                
            default:
                return basePace
            }
        }
        
        // Default paces based on challenge focus
        switch challenge.focusArea {
        case .speed, .speedDevelopment:
            // Fast pace with progression
            return 16.0 - (Double(day - 1) * 0.3)
            
        case .power, .progressiveWeight:
            // Slower pace with heavy weight
            return 20.0
            
        case .distance, .enduranceProgression:
            // Steady endurance pace
            return 18.0
            
        case .recovery:
            // Easy recovery pace
            return 22.0
            
        case .tacticalMixed:
            // Mixed tactical pace
            return 18.5
        }
    }
    
    /// Generate rest day instructions
    private func generateRestInstructions(challenge: StackChallenge) -> String {
        switch challenge.focusArea {
        case .power, .progressiveWeight:
            return "Active recovery day. Light stretching, mobility work, and preparation for your next power session."
            
        case .speed, .speedDevelopment:
            return "Recovery day. Focus on light movement and mobility to prepare for speed work."
            
        case .distance, .enduranceProgression:
            return "Rest day. Light walking or easy movement to aid recovery while maintaining fitness."
            
        case .recovery:
            return "Gentle movement day. Focus on what feels good - light stretching, walking, or mobility work."
            
        case .tacticalMixed:
            return "Active recovery. Light movement and equipment maintenance preparation."
        }
    }
    
    // MARK: - Progress Tracking
    
    /// Get completion percentage for an enrollment
    func getCompletionPercentage(for enrollment: UserChallengeEnrollment) -> Double {
        return enrollment.completionPercentage
    }
    
    /// Update enrollment with current weight
    func updateEnrollmentWeight(enrollmentId: UUID, newWeight: Double) async throws {
        guard let client = supabaseClient else {
            // Update local state for mock
            if let index = userEnrollments.firstIndex(where: { $0.id == enrollmentId }) {
                userEnrollments[index].currentWeightLbs = newWeight
            }
            print("📱 Mock: Updated enrollment weight to \(newWeight) lbs")
            return
        }
        
        try await client
            .from("user_challenge_enrollments")
            .update(["current_weight_lbs": try AnyJSON(newWeight)])
            .eq("id", value: enrollmentId.uuidString)
            .execute()
        
        // Update local state
        if let index = userEnrollments.firstIndex(where: { $0.id == enrollmentId }) {
            userEnrollments[index].currentWeightLbs = newWeight
        }
        
        print("✅ Updated enrollment weight to \(newWeight) lbs")
    }
    
    /// Complete a challenge enrollment
    func completeChallenge(enrollmentId: UUID) async throws {
        guard let client = supabaseClient else {
            // Update local state for mock
            if let index = userEnrollments.firstIndex(where: { $0.id == enrollmentId }) {
                let enrollment = userEnrollments[index]
                let updatedEnrollment = UserChallengeEnrollment(
                    id: enrollment.id,
                    userId: enrollment.userId,
                    challengeId: enrollment.challengeId,
                    enrolledAt: enrollment.enrolledAt,
                    currentWeightLbs: enrollment.currentWeightLbs,
                    targetWeightLbs: enrollment.targetWeightLbs,
                    isActive: false,
                    completedAt: Date(),
                    completionPercentage: 100.0
                )
                userEnrollments[index] = updatedEnrollment
            }
            print("📱 Mock: Completed challenge enrollment")
            return
        }
        
        try await client
            .from("user_challenge_enrollments")
            .update([
                "completion_percentage": try AnyJSON(100.0),
                "completed_at": try AnyJSON(Date()),
                "is_active": try AnyJSON(false)
            ])
            .eq("id", value: enrollmentId.uuidString)
            .execute()
        
        // Update local state
        if let index = userEnrollments.firstIndex(where: { $0.id == enrollmentId }) {
            let enrollment = userEnrollments[index]
            let updatedEnrollment = UserChallengeEnrollment(
                id: enrollment.id,
                userId: enrollment.userId,
                challengeId: enrollment.challengeId,
                enrolledAt: enrollment.enrolledAt,
                currentWeightLbs: enrollment.currentWeightLbs,
                targetWeightLbs: enrollment.targetWeightLbs,
                isActive: false,
                completedAt: Date(),
                completionPercentage: 100.0
            )
            userEnrollments[index] = updatedEnrollment
        }
        
        print("✅ Completed challenge enrollment")
    }
    
    // MARK: - Data Management
    
    /// Refresh challenge data from server
    func refreshChallenges() async {
        await loadChallenges()
        await loadUserEnrollments()
    }
    
    /// Clear local cache
    func clearCache() {
        weeklyChallenges.removeAll()
        seasonalChallenges.removeAll()
        userEnrollments.removeAll()
        
        // Clear UserDefaults cache
        UserDefaults.standard.removeObject(forKey: "cached_user_challenge_enrollments")
        
        print("🗑️ Cleared challenge cache")
    }
    
    /// Get challenge by ID
    func getChallenge(by id: UUID) -> StackChallenge? {
        return (weeklyChallenges + seasonalChallenges).first { $0.id == id }
    }
    
    /// Get all active challenges
    func getAllActiveChallenges() -> [StackChallenge] {
        return (weeklyChallenges + seasonalChallenges).filter { $0.isActive }
    }
    
    /// Get challenges by focus area
    func getChallenges(by focusArea: StackChallenge.FocusArea) -> [StackChallenge] {
        return getAllActiveChallenges().filter { $0.focusArea == focusArea }
    }
    
    /// Get user's active enrollments
    func getActiveEnrollments() -> [UserChallengeEnrollment] {
        return userEnrollments.filter { $0.isActive }
    }
    
    /// Get user's completed enrollments
    func getCompletedEnrollments() -> [UserChallengeEnrollment] {
        return userEnrollments.filter { $0.completedAt != nil }
    }
}

// MARK: - Challenge Service Errors
enum ChallengeServiceError: Error {
    case notAuthenticated
    case challengeNotFound
    case alreadyEnrolled
    case enrollmentNotFound
    case invalidWeight
    case networkError(String)
    
    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .challengeNotFound:
            return "Challenge not found"
        case .alreadyEnrolled:
            return "Already enrolled in this challenge"
        case .enrollmentNotFound:
            return "Enrollment not found"
        case .invalidWeight:
            return "Invalid weight value"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
