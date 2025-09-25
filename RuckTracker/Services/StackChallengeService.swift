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
    private let supabaseClient: SupabaseClient?
    
    @Published var weeklyChallenges: [StackChallenge] = []
    @Published var seasonalChallenges: [StackChallenge] = []
    @Published var userEnrollments: [UserChallengeEnrollment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Current user ID for testing - replace with proper auth
    private var mockCurrentUserId: UUID? = UUID()
    
    init() {
        // Use existing SupabaseManager
        self.supabaseClient = SupabaseManager.shared.client
        
        // Load challenges on init
        Task {
            await loadChallenges()
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
        // Load weekly challenges
        let weeklyResponse: [StackChallenge] = try await client
            .from("stack_challenges")
            .select()
            .eq("challenge_type", value: "weekly")
            .eq("is_active", value: true)
            .order("sort_order")
            .execute()
            .value
        
        // Load seasonal challenges
        let seasonalResponse: [StackChallenge] = try await client
            .from("stack_challenges")
            .select()
            .eq("challenge_type", value: "seasonal")
            .eq("is_active", value: true)
            .order("sort_order")
            .execute()
            .value
        
        weeklyChallenges = weeklyResponse
        seasonalChallenges = seasonalResponse
        
        print("✅ Loaded \(weeklyResponse.count) weekly challenges and \(seasonalResponse.count) seasonal challenges")
    }
    
    private func loadMockChallenges() {
        weeklyChallenges = StackChallenge.mockWeeklyChallenges
        seasonalChallenges = StackChallenge.mockSeasonalChallenges
        print("📱 Using mock challenge data")
    }
    
    // MARK: - Challenge Enrollment
    
    func enrollInChallenge(_ challenge: StackChallenge, weightLbs: Double) async throws -> UserChallengeEnrollment {
        guard let client = supabaseClient,
              let userId = mockCurrentUserId else {
            // Return mock enrollment for testing
            let mockEnrollment = UserChallengeEnrollment(
                id: UUID(),
                userId: mockCurrentUserId ?? UUID(), // Mock user ID
                challengeId: challenge.id,
                enrolledAt: Date(),
                currentWeightLbs: weightLbs,
                targetWeightLbs: challenge.weightPercentage != nil ? weightLbs * (challenge.weightPercentage! / 100) : weightLbs,
                isActive: true,
                completedAt: nil,
                completionPercentage: 0.0
            )
            
            userEnrollments.append(mockEnrollment)
            print("📱 Mock enrolled in challenge: \(challenge.title)")
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
        
        let enrollment: UserChallengeEnrollment = try await client
            .from("user_challenge_enrollments")
            .insert(enrollmentData)
            .select()
            .single()
            .execute()
            .value
        
        userEnrollments.append(enrollment)
        print("✅ Successfully enrolled in challenge: \(challenge.title)")
        return enrollment
    }
    
    func loadUserEnrollments() async {
        guard let client = supabaseClient,
              let userId = mockCurrentUserId else {
            print("📱 Using mock enrollments")
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
            "challenge_type": try AnyJSON(challenge.challengeType.rawValue),
            "focus_area": try AnyJSON(challenge.focusArea.rawValue),
            "duration_days": try AnyJSON(challenge.durationDays),
            "distance_focus": try AnyJSON(challenge.distanceFocus),
            "recovery_focus": try AnyJSON(challenge.recoveryFocus),
            "is_seasonal": try AnyJSON(challenge.isSeasonal),
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
        return userEnrollments.contains { enrollment in
            enrollment.challengeId == challenge.id && enrollment.isActive
        }
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
