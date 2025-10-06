//
//  ProgramService.swift
//  RuckTracker
//
//  Centralized shared service for all program-related functionality
//  Mirrors the successful StackChallengeService architecture
//

import Foundation
import Supabase
import Combine

@MainActor
class ProgramService: ObservableObject {
    static let shared = ProgramService()
    
    private let supabaseClient: SupabaseClient?
    
    // MARK: - Published State
    @Published var programs: [Program] = []
    @Published var userPrograms: [UserProgram] = []
    @Published var featuredPrograms: [Program] = []
    @Published var userProgress: [ProgramProgress] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Get current authenticated user ID
    private var currentUserId: UUID? {
        return SupabaseManager.shared.currentUser?.id
    }
    
    private init() {
        // Use existing SupabaseManager (following StackChallengeService pattern)
        self.supabaseClient = SupabaseManager.shared.client
        
        // Load cached data first for immediate UI response
        loadCachedUserPrograms()
        loadCachedProgress()
        
        // Load fresh data from server
        Task {
            await loadPrograms()
            await loadUserPrograms()
            await loadUserProgress()
        }
    }
    
    // MARK: - Program Discovery
    
    func loadPrograms() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if let client = supabaseClient {
                try await loadProgramsFromSupabase(client: client)
            } else {
                loadMockPrograms()
            }
        } catch {
            print("❌ Error loading programs: \(error)")
            errorMessage = error.localizedDescription
            // Fallback to mock data on error
            loadMockPrograms()
        }
        
        isLoading = false
    }
    
    private func loadProgramsFromSupabase(client: SupabaseClient) async throws {
        // Load all programs
        let allProgramsResponse: [Program] = try await client
            .from("programs")
            .select()
            .eq("is_active", value: true)
            .order("sort_order")
            .execute()
            .value
        
        // Load featured programs
        let featuredResponse: [Program] = try await client
            .from("programs")
            .select()
            .eq("is_featured", value: true)
            .eq("is_active", value: true)
            .order("sort_order")
            .execute()
            .value
        
        programs = allProgramsResponse
        featuredPrograms = featuredResponse
        
        print("✅ Loaded \(allProgramsResponse.count) programs and \(featuredResponse.count) featured programs")
    }
    
    private func loadMockPrograms() {
        programs = Program.mockPrograms
        featuredPrograms = programs.filter { $0.isFeatured }
        print("📱 Using mock program data")
    }
    
    // MARK: - Program Enrollment
    
    func enrollInProgram(_ program: Program, startingWeight: Double, startDate: Date = Date()) async throws -> UserProgram {
        print("🔍 Attempting to enroll in program: \(program.title) (ID: \(program.id))")
        
        // Check if we're using mock data (no Supabase client or no user)
        guard let client = supabaseClient,
              let userId = currentUserId else {
            // Return mock enrollment for testing or when using mock programs
            let mockEnrollment = UserProgram(
                id: UUID(),
                userId: currentUserId ?? UUID(),
                programId: program.id,
                enrolledAt: startDate,
                startingWeightLbs: startingWeight,
                currentWeightLbs: startingWeight,
                targetWeightLbs: startingWeight + (program.difficulty.weightIncrement * Double(program.durationWeeks)),
                isActive: true,
                completedAt: nil,
                completionPercentage: 0.0,
                currentWeek: 1,
                nextWorkoutDate: Calendar.current.date(byAdding: .day, value: 1, to: startDate)
            )
            
            userPrograms.append(mockEnrollment)
            await cacheUserPrograms()
            print("📱 Mock: Enrolled in program \(program.title)")
            return mockEnrollment
        }
        
        // First, verify the program exists in the database
        do {
            let programExists: [Program] = try await client
                .from("programs")
                .select()
                .eq("id", value: program.id.uuidString)
                .execute()
                .value
            
            if programExists.isEmpty {
                print("⚠️ Program \(program.title) not found in database, using mock enrollment")
                // Program doesn't exist in database, use mock enrollment
                let mockEnrollment = UserProgram(
                    id: UUID(),
                    userId: userId,
                    programId: program.id,
                    enrolledAt: startDate,
                    startingWeightLbs: startingWeight,
                    currentWeightLbs: startingWeight,
                    targetWeightLbs: startingWeight + (program.difficulty.weightIncrement * Double(program.durationWeeks)),
                    isActive: true,
                    completedAt: nil,
                    completionPercentage: 0.0,
                    currentWeek: 1,
                    nextWorkoutDate: Calendar.current.date(byAdding: .day, value: 1, to: startDate)
                )
                
                userPrograms.append(mockEnrollment)
                await cacheUserPrograms()
                print("📱 Mock: Enrolled in program \(program.title)")
                return mockEnrollment
            }
        } catch {
            print("⚠️ Error checking program existence: \(error), using mock enrollment")
            // If we can't check, use mock enrollment to be safe
            let mockEnrollment = UserProgram(
                id: UUID(),
                userId: userId,
                programId: program.id,
                enrolledAt: startDate,
                startingWeightLbs: startingWeight,
                currentWeightLbs: startingWeight,
                targetWeightLbs: startingWeight + (program.difficulty.weightIncrement * Double(program.durationWeeks)),
                isActive: true,
                completedAt: nil,
                completionPercentage: 0.0,
                currentWeek: 1,
                nextWorkoutDate: Calendar.current.date(byAdding: .day, value: 1, to: startDate)
            )
            
            userPrograms.append(mockEnrollment)
            await cacheUserPrograms()
            print("📱 Mock: Enrolled in program \(program.title)")
            return mockEnrollment
        }
        
        // Check if already enrolled
        if getUserProgram(for: program) != nil {
            throw ProgramServiceError.alreadyEnrolled
        }
        
        let newUserProgram = [
            "user_id": try AnyJSON(userId.uuidString),
            "program_id": try AnyJSON(program.id.uuidString),
            "enrolled_at": try AnyJSON(startDate),
            "starting_weight_lbs": try AnyJSON(startingWeight),
            "current_weight_lbs": try AnyJSON(startingWeight),
            "target_weight_lbs": try AnyJSON(startingWeight + (program.difficulty.weightIncrement * Double(program.durationWeeks))),
            "is_active": try AnyJSON(true),
            "completion_percentage": try AnyJSON(0.0),
            "current_week": try AnyJSON(1)
        ]
        
        do {
            let response: [UserProgram] = try await client
                .from("user_programs")
                .insert(newUserProgram)
                .select()
                .execute()
                .value
            
            guard let enrollment = response.first else {
                throw ProgramServiceError.enrollmentFailed
            }
            
            userPrograms.append(enrollment)
            await cacheUserPrograms()
            print("✅ Enrolled in program: \(program.title)")
            
            return enrollment
        } catch {
            // Handle foreign key constraint violation (program doesn't exist in database)
            if let postgrestError = error as? PostgrestError,
               postgrestError.code == "23503" {
                print("⚠️ Foreign key constraint violation - program not found in database, using mock enrollment")
                
                // Create mock enrollment when program doesn't exist in database
                let mockEnrollment = UserProgram(
                    id: UUID(),
                    userId: userId,
                    programId: program.id,
                    enrolledAt: startDate,
                    startingWeightLbs: startingWeight,
                    currentWeightLbs: startingWeight,
                    targetWeightLbs: startingWeight + (program.difficulty.weightIncrement * Double(program.durationWeeks)),
                    isActive: true,
                    completedAt: nil,
                    completionPercentage: 0.0,
                    currentWeek: 1,
                    nextWorkoutDate: Calendar.current.date(byAdding: .day, value: 1, to: startDate)
                )
                
                userPrograms.append(mockEnrollment)
                await cacheUserPrograms()
                print("📱 Mock: Enrolled in program \(program.title)")
                return mockEnrollment
            } else {
                throw error
            }
        }
    }
    
    // MARK: - User Program Management
    
    func loadUserPrograms() async {
        guard let client = supabaseClient,
              let userId = currentUserId else {
            print("📱 Using cached user programs (no client/user)")
            return
        }
        
        do {
            let response: [UserProgram] = try await client
                .from("user_programs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("enrolled_at", ascending: false)
                .execute()
                .value
            
            userPrograms = response
            await cacheUserPrograms()
            print("✅ Loaded \(response.count) user programs")
        } catch {
            print("❌ Error loading user programs: \(error)")
        }
    }
    
    func getUserProgram(for program: Program) -> UserProgram? {
        return userPrograms.first { $0.programId == program.id && $0.isActive }
    }
    
    func getActivePrograms() -> [UserProgram] {
        return userPrograms.filter { $0.isActive }
    }
    
    func getCompletedPrograms() -> [UserProgram] {
        return userPrograms.filter { $0.completedAt != nil }
    }
    
    // MARK: - Progress Tracking
    
    func loadUserProgress() async {
        guard let client = supabaseClient,
              let userId = currentUserId else {
            print("📱 Using cached progress data (no client/user)")
            return
        }
        
        do {
            let response: [ProgramProgress] = try await client
                .from("program_progress")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("workout_date", ascending: false)
                .execute()
                .value
            
            userProgress = response
            await cacheProgress()
            print("✅ Loaded \(response.count) progress entries")
        } catch {
            print("❌ Error loading user progress: \(error)")
        }
    }
    
    func recordProgress(_ progress: ProgramProgress) async throws {
        guard let client = supabaseClient else {
            // Add to local cache for mock
            userProgress.append(progress)
            await cacheProgress()
            print("📱 Mock: Recorded progress")
            return
        }
        
        let progressData = [
            "user_id": try AnyJSON(progress.userId.uuidString),
            "program_id": try AnyJSON(progress.programId.uuidString),
            "workout_date": try AnyJSON(progress.workoutDate),
            "week_number": try AnyJSON(progress.weekNumber),
            "workout_number": try AnyJSON(progress.workoutNumber),
            "weight_lbs": try AnyJSON(progress.weightLbs),
            "distance_miles": try AnyJSON(progress.distanceMiles),
            "duration_minutes": try AnyJSON(progress.durationMinutes),
            "completed": try AnyJSON(progress.completed),
            "notes": try AnyJSON(progress.notes)
        ]
        
        try await client
            .from("program_progress")
            .insert(progressData)
            .execute()
        
        userProgress.append(progress)
        await cacheProgress()
        print("✅ Recorded progress for program")
    }
    
    // MARK: - Workout Loading & Completion
    
    func loadProgramWorkouts(programId: UUID) async throws -> [ProgramWorkout] {
        guard let client = supabaseClient else {
            print("📱 Using mock workouts (no client)")
            return generateMockWorkouts(programId: programId)
        }
        
        do {
            // First get all weeks for this program
            let weeks: [ProgramWeek] = try await client
                .from("program_weeks")
                .select()
                .eq("program_id", value: programId.uuidString)
                .order("week_number", ascending: true)
                .execute()
                .value
            
            if weeks.isEmpty {
                print("📱 No weeks found, using mock workouts")
                return generateMockWorkouts(programId: programId)
            }
            
            // Then get all workouts for these weeks
            let weekIds = weeks.map { $0.id.uuidString }
            let workouts: [ProgramWorkout] = try await client
                .from("program_workouts")
                .select()
                .in("week_id", values: weekIds)
                .order("day_number", ascending: true)
                .execute()
                .value
            
            if workouts.isEmpty {
                print("📱 No workouts found, using mock workouts")
                return generateMockWorkouts(programId: programId)
            }
            
            print("✅ Loaded \(workouts.count) workouts for program")
            return workouts
        } catch {
            print("❌ Error loading workouts: \(error), using mock")
            return generateMockWorkouts(programId: programId)
        }
    }
    
    func loadWorkoutCompletions(userProgramId: UUID) async throws -> [WorkoutCompletion] {
        guard let client = supabaseClient else {
            print("📱 No completions (no client)")
            return []
        }
        
        do {
            let completions: [WorkoutCompletion] = try await client
                .from("workout_completions")
                .select()
                .eq("user_program_id", value: userProgramId.uuidString)
                .order("completed_at", ascending: true)
                .execute()
                .value
            
            print("✅ Loaded \(completions.count) workout completions")
            return completions
        } catch {
            print("❌ Error loading completions: \(error)")
            return []
        }
    }
    
    func completeWorkout(
        userProgramId: UUID,
        programWorkoutId: UUID,
        distanceMiles: Double,
        weightLbs: Double,
        durationMinutes: Int,
        notes: String? = nil
    ) async throws {
        guard let client = supabaseClient,
              let userId = currentUserId else {
            print("📱 Mock: Completed workout")
            return
        }
        
        let performanceScore = calculatePerformanceScore(
            distance: distanceMiles,
            duration: durationMinutes,
            weight: weightLbs
        )
        
        let completionData = [
            "user_id": try AnyJSON(userId.uuidString),
            "user_program_id": try AnyJSON(userProgramId.uuidString),
            "program_workout_id": try AnyJSON(programWorkoutId.uuidString),
            "completed_at": try AnyJSON(Date()),
            "actual_distance_miles": try AnyJSON(distanceMiles),
            "actual_weight_lbs": try AnyJSON(weightLbs),
            "actual_duration_minutes": try AnyJSON(durationMinutes),
            "performance_score": try AnyJSON(performanceScore),
            "notes": try AnyJSON(notes ?? "")
        ]
        
        try await client
            .from("workout_completions")
            .insert(completionData)
            .execute()
        
        print("✅ Completed workout and saved to database")
    }
    
    private func calculatePerformanceScore(distance: Double, duration: Int, weight: Double) -> Double {
        // Simple performance score calculation
        // Higher score = better performance (faster pace with more weight)
        let pacePerMile = Double(duration) / distance
        let baseScore = 100.0 / pacePerMile
        let weightBonus = weight / 10.0
        return baseScore + weightBonus
    }
    
    private func generateMockWorkouts(programId: UUID) -> [ProgramWorkout] {
        // Generate realistic mock workouts for an 8-week program
        let weekId = UUID() // Mock week ID
        return [
            // Week 1
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 1, workoutType: .ruck, distanceMiles: 2.0, targetPaceMinutes: 15.0, instructions: "Easy pace, focus on form"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 2, workoutType: .rest, distanceMiles: nil, targetPaceMinutes: nil, instructions: "Recovery day"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 3, workoutType: .ruck, distanceMiles: 3.0, targetPaceMinutes: 15.0, instructions: "Steady pace"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 4, workoutType: .crossTraining, distanceMiles: nil, targetPaceMinutes: nil, instructions: "30 minutes of cardio"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 5, workoutType: .ruck, distanceMiles: 4.0, targetPaceMinutes: 16.0, instructions: "Long ruck, comfortable pace"),
            
            // Week 2
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 6, workoutType: .rest, distanceMiles: nil, targetPaceMinutes: nil, instructions: "Recovery day"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 7, workoutType: .ruck, distanceMiles: 3.0, targetPaceMinutes: 14.5, instructions: "Pick up the pace"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 8, workoutType: .crossTraining, distanceMiles: nil, targetPaceMinutes: nil, instructions: "Strength training"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 9, workoutType: .ruck, distanceMiles: 5.0, targetPaceMinutes: 15.0, instructions: "Building endurance"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 10, workoutType: .rest, distanceMiles: nil, targetPaceMinutes: nil, instructions: "Recovery day"),
            
            // Week 3
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 11, workoutType: .ruck, distanceMiles: 4.0, targetPaceMinutes: 14.0, instructions: "Faster pace workout"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 12, workoutType: .rest, distanceMiles: nil, targetPaceMinutes: nil, instructions: "Recovery day"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 13, workoutType: .ruck, distanceMiles: 6.0, targetPaceMinutes: 15.5, instructions: "Long endurance ruck"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 14, workoutType: .crossTraining, distanceMiles: nil, targetPaceMinutes: nil, instructions: "Active recovery"),
            ProgramWorkout(id: UUID(), weekId: weekId, dayNumber: 15, workoutType: .ruck, distanceMiles: 3.0, targetPaceMinutes: 13.5, instructions: "Speed work"),
        ]
    }
    
    // MARK: - Program Completion
    
    func completeProgram(_ userProgramId: UUID) async throws {
        guard let client = supabaseClient else {
            // Update local state for mock
            if let index = userPrograms.firstIndex(where: { $0.id == userProgramId }) {
                let program = userPrograms[index]
                let updatedProgram = UserProgram(
                    id: program.id,
                    userId: program.userId,
                    programId: program.programId,
                    enrolledAt: program.enrolledAt,
                    startingWeightLbs: program.startingWeightLbs,
                    currentWeightLbs: program.currentWeightLbs,
                    targetWeightLbs: program.targetWeightLbs,
                    isActive: false,
                    completedAt: Date(),
                    completionPercentage: 100.0,
                    currentWeek: program.currentWeek,
                    nextWorkoutDate: program.nextWorkoutDate
                )
                userPrograms[index] = updatedProgram
            }
            print("📱 Mock: Completed program")
            return
        }
        
        try await client
            .from("user_programs")
            .update([
                "completion_percentage": try AnyJSON(100.0),
                "completed_at": try AnyJSON(Date()),
                "is_active": try AnyJSON(false)
            ])
            .eq("id", value: userProgramId.uuidString)
            .execute()
        
        // Update local state
        if let index = userPrograms.firstIndex(where: { $0.id == userProgramId }) {
            let program = userPrograms[index]
            let updatedProgram = UserProgram(
                id: program.id,
                userId: program.userId,
                programId: program.programId,
                enrolledAt: program.enrolledAt,
                startingWeightLbs: program.startingWeightLbs,
                currentWeightLbs: program.currentWeightLbs,
                targetWeightLbs: program.targetWeightLbs,
                isActive: false,
                completedAt: Date(),
                completionPercentage: 100.0,
                currentWeek: program.currentWeek,
                nextWorkoutDate: program.nextWorkoutDate
            )
            userPrograms[index] = updatedProgram
        }
        
        print("✅ Completed program")
    }
    
    // MARK: - Data Management & Caching
    
    /// Refresh all program data from server
    func refreshPrograms() async {
        await loadPrograms()
        await loadUserPrograms()
        await loadUserProgress()
    }
    
    /// Clear local cache
    func clearCache() {
        programs.removeAll()
        userPrograms.removeAll()
        featuredPrograms.removeAll()
        userProgress.removeAll()
        
        // Clear UserDefaults cache
        UserDefaults.standard.removeObject(forKey: "cached_user_programs")
        UserDefaults.standard.removeObject(forKey: "cached_user_progress")
        
        print("🗑️ Cleared program cache")
    }
    
    /// Get program by ID
    func getProgram(by id: UUID) -> Program? {
        return programs.first { $0.id == id }
    }
    
    /// Get programs by category
    func getPrograms(by category: Program.Category) -> [Program] {
        return programs.filter { $0.category == category }
    }
    
    /// Get programs by difficulty
    func getPrograms(by difficulty: Program.Difficulty) -> [Program] {
        return programs.filter { $0.difficulty == difficulty }
    }
    
    // MARK: - Private Caching Methods
    
    private func cacheUserPrograms() async {
        do {
            let data = try JSONEncoder().encode(userPrograms)
            UserDefaults.standard.set(data, forKey: "cached_user_programs")
            print("💾 Cached \(userPrograms.count) user programs")
        } catch {
            print("❌ Failed to cache user programs: \(error)")
        }
    }
    
    private func loadCachedUserPrograms() {
        guard let data = UserDefaults.standard.data(forKey: "cached_user_programs") else {
            print("📱 No cached user programs found")
            return
        }
        
        do {
            let cachedPrograms = try JSONDecoder().decode([UserProgram].self, from: data)
            userPrograms = cachedPrograms
            print("✅ Loaded \(cachedPrograms.count) cached user programs")
        } catch {
            print("❌ Failed to load cached user programs: \(error)")
        }
    }
    
    private func cacheProgress() async {
        do {
            let data = try JSONEncoder().encode(userProgress)
            UserDefaults.standard.set(data, forKey: "cached_user_progress")
            print("💾 Cached \(userProgress.count) progress entries")
        } catch {
            print("❌ Failed to cache progress: \(error)")
        }
    }
    
    private func loadCachedProgress() {
        guard let data = UserDefaults.standard.data(forKey: "cached_user_progress") else {
            print("📱 No cached progress found")
            return
        }
        
        do {
            let cachedProgress = try JSONDecoder().decode([ProgramProgress].self, from: data)
            userProgress = cachedProgress
            print("✅ Loaded \(cachedProgress.count) cached progress entries")
        } catch {
            print("❌ Failed to load cached progress: \(error)")
        }
    }
}

// MARK: - Service Errors
enum ProgramServiceError: Error {
    case notAuthenticated
    case programNotFound
    case alreadyEnrolled
    case enrollmentNotFound
    case enrollmentFailed
    case invalidWeight
    case networkError(String)
    
    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .programNotFound:
            return "Program not found"
        case .alreadyEnrolled:
            return "Already enrolled in this program"
        case .enrollmentNotFound:
            return "Enrollment not found"
        case .enrollmentFailed:
            return "Failed to enroll in program"
        case .invalidWeight:
            return "Invalid weight value"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Extensions for Program Difficulty Weight Increment
extension Program.Difficulty {
    var weightIncrement: Double {
        switch self {
        case .beginner:
            return 2.5  // 2.5 lbs per week
        case .intermediate:
            return 3.0  // 3.0 lbs per week
        case .advanced:
            return 3.5  // 3.5 lbs per week
        case .elite:
            return 4.0  // 4.0 lbs per week
        }
    }
}
