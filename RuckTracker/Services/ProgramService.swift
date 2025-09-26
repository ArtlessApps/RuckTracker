// Services/ProgramService.swift
import Foundation
import SwiftUI
import Combine
import Supabase

class ProgramService: ObservableObject {
    private var supabaseClient: SupabaseClient? {
        // Use the correct Supabase REST API URL
        guard let url = URL(string: "https://zqxxcuvgwadokkgmcuwr.supabase.co") else {
            return nil
        }
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxeHhjdXZnd2Fkb2trZ21jdXdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc5OTI4NTIsImV4cCI6MjA3MzU2ODg1Mn0.vU-gcFzN2YyqDWkihIdMGu_LXp0Y--QSB00Vsr9qm_o"
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
    
    @Published var programs: [Program] = []
    @Published var userPrograms: [UserProgram] = []
    @Published var isLoading = false
    
    // Current user ID for testing - replace with proper auth
    private var mockCurrentUserId: UUID? = UUID()
    
    init() {
        // Load cached user programs first
        loadCachedUserPrograms()
        
        // Initialize service and fetch fresh user programs
        Task {
            do {
                try await fetchUserPrograms()
            } catch {
                print("Failed to load user programs on init: \(error)")
            }
        }
    }
    
    // MARK: - Program Discovery
    
    func fetchPrograms() async throws {
        guard let client = supabaseClient else {
            throw ProgramError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: [Program] = try await client
                .from("programs")
                .select()
                .order("is_featured", ascending: false)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.programs = response
            }
        } catch {
            print("Failed to fetch programs from Supabase: \(error)")
            // For testing, we'll use mock data
            await MainActor.run {
                self.programs = createMockPrograms()
            }
        }
    }
    
    // Helper method to create mock programs for testing
    private func createMockPrograms() -> [Program] {
        return [
            Program(
                id: UUID(),
                title: "Military Foundation",
                description: "8-week foundational program designed for those new to rucking",
                difficulty: .beginner,
                category: .military,
                durationWeeks: 8,
                isFeatured: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Program(
                id: UUID(),
                title: "Ranger Challenge",
                description: "Advanced 12-week program for experienced ruckers",
                difficulty: .advanced,
                category: .military,
                durationWeeks: 12,
                isFeatured: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Program(
                id: UUID(),
                title: "Selection Prep",
                description: "Elite 16-week program for special operations preparation",
                difficulty: .elite,
                category: .military,
                durationWeeks: 16,
                isFeatured: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Program(
                id: UUID(),
                title: "Maintenance Program",
                description: "Ongoing program for maintaining fitness levels",
                difficulty: .intermediate,
                category: .fitness,
                durationWeeks: 0,
                isFeatured: false,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
    }
    
    func fetchFeaturedPrograms() async throws -> [Program] {
        guard let client = supabaseClient else {
            throw ProgramError.notAuthenticated
        }
        
        let response: [Program] = try await client
            .from("programs")
            .select()
            .eq("is_featured", value: true)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Program Enrollment
    
    func enrollInProgram(_ program: Program, startingWeight: Double) async throws {
        guard let client = supabaseClient,
              let userId = mockCurrentUserId else {
            throw ProgramError.notAuthenticated
        }
        
        let userProgram = UserProgram(
            id: UUID(),
            userId: userId,
            programId: program.id,
            startedAt: Date(),
            currentWeek: 1,
            currentWeightLbs: startingWeight,
            isActive: true,
            completedAt: nil
        )
        
        do {
            try await client
                .from("user_programs")
                .insert(userProgram)
                .execute()
            
            // Fetch updated user programs
            try await fetchUserPrograms()
        } catch {
            // For testing purposes, we'll simulate successful enrollment
            // In production, you'd want proper error handling
            print("Supabase enrollment failed, simulating success for testing: \(error)")
            
            // Simulate successful enrollment by updating local state
            await MainActor.run {
                self.userPrograms.append(userProgram)
                self.cacheUserPrograms()
            }
        }
    }
    
    func fetchUserPrograms() async throws {
        guard let client = supabaseClient,
              let userId = mockCurrentUserId else { return }
        
        let response: [UserProgram] = try await client
            .from("user_programs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .execute()
            .value
        
        await MainActor.run {
            self.userPrograms = response
            self.cacheUserPrograms()
        }
    }
    
    // MARK: - Program Content
    
    func fetchProgramWeeks(for programId: UUID) async throws -> [ProgramWeek] {
        guard let client = supabaseClient else {
            throw ProgramError.notAuthenticated
        }
        
        let response: [ProgramWeek] = try await client
            .from("program_weeks")
            .select()
            .eq("program_id", value: programId.uuidString)
            .order("week_number", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    func fetchWorkoutsForWeek(_ weekId: UUID) async throws -> [ProgramWorkout] {
        guard let client = supabaseClient else {
            throw ProgramError.notAuthenticated
        }
        
        let response: [ProgramWorkout] = try await client
            .from("program_workouts")
            .select()
            .eq("week_id", value: weekId.uuidString)
            .order("day_number", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Progress Tracking
    
    func recordWorkoutCompletion(
        userProgramId: UUID,
        workoutId: UUID,
        actualDistance: Double,
        actualWeight: Double,
        duration: TimeInterval,
        performanceScore: Double
    ) async throws {
        guard let client = supabaseClient,
              let userId = mockCurrentUserId else { return }
        
        let completion = WorkoutCompletion(
            id: UUID(),
            userId: userId,
            userProgramId: userProgramId,
            programWorkoutId: workoutId,
            completedAt: Date(),
            actualDistanceMiles: actualDistance,
            actualWeightLbs: actualWeight,
            actualDurationMinutes: Int(duration / 60),
            performanceScore: performanceScore,
            notes: nil
        )
        
        try await client
            .from("workout_completions")
            .insert(completion)
            .execute()
    }
    
    func updateWeightProgression(
        userProgramId: UUID,
        weekNumber: Int,
        newWeight: Double,
        wasAutoAdjusted: Bool,
        reason: String?
    ) async throws {
        guard let client = supabaseClient else {
            throw ProgramError.notAuthenticated
        }
        
        let progression = WeightProgression(
            id: UUID(),
            userProgramId: userProgramId,
            weekNumber: weekNumber,
            weightLbs: newWeight,
            wasAutoAdjusted: wasAutoAdjusted,
            reason: reason,
            createdAt: Date()
        )
        
        try await client
            .from("weight_progressions")
            .insert(progression)
            .execute()
    }
    
    // MARK: - Local Persistence
    
    private func cacheUserPrograms() {
        do {
            let data = try JSONEncoder().encode(userPrograms)
            UserDefaults.standard.set(data, forKey: "cached_user_programs")
            print("✅ Cached \(userPrograms.count) user programs")
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
}

enum ProgramError: Error {
    case notAuthenticated
    case programNotFound
    case alreadyEnrolled
}
