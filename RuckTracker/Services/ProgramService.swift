// Services/ProgramService.swift
import Foundation
import SwiftUI
import Combine
import Supabase

class ProgramService: ObservableObject {
    private var supabaseClient: SupabaseClient? {
        // Simple direct access for now - replace with your actual config
        guard let url = URL(string: "postgresql://postgres:[YOUR-PASSWORD]@db.zqxxcuvgwadokkgmcuwr.supabase.co:5432/postgres") else {
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
        // Initialize service
    }
    
    // MARK: - Program Discovery
    
    func fetchPrograms() async throws {
        guard let client = supabaseClient else {
            throw ProgramError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
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
        
        try await client
            .from("user_programs")
            .insert(userProgram)
            .execute()
        
        // Fetch updated user programs
        try await fetchUserPrograms()
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
}

enum ProgramError: Error {
    case notAuthenticated
    case programNotFound
    case alreadyEnrolled
}
