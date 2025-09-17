// Services/ProgramService.swift
import Supabase
import Foundation
import Combine

class ProgramService: ObservableObject {
    private let supabase = SupabaseManager.shared.client
    
    @Published var programs: [Program] = []
    @Published var userPrograms: [UserProgram] = []
    @Published var isLoading = false
    
    // Add these for real-time subscriptions
    private var subscriptions: Set<AnyCancellable> = []
    private var realtimeChannel: RealtimeChannel?
    
    init() {
        // Start real-time subscriptions when service is created
        setupRealtimeSubscriptions()
    }
    
    deinit {
        // Clean up subscriptions
        realtimeChannel?.unsubscribe()
    }
    
    // MARK: - Program Discovery
    
    func fetchPrograms() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let response: [Program] = try await supabase
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
        let response: [Program] = try await supabase
            .from("programs")
            .select()
            .eq("is_featured", value: true)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Program Enrollment
    
    func enrollInProgram(_ program: Program, startingWeight: Double) async throws {
        guard let userId = SupabaseManager.shared.currentUser?.id else {
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
        
        try await supabase
            .from("user_programs")
            .insert(userProgram)
            .execute()
        
        // Fetch updated user programs
        try await fetchUserPrograms()
    }
    
    func fetchUserPrograms() async throws {
        guard let userId = SupabaseManager.shared.currentUser?.id else { return }
        
        let response: [UserProgram] = try await supabase
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
        let response: [ProgramWeek] = try await supabase
            .from("program_weeks")
            .select()
            .eq("program_id", value: programId.uuidString)
            .order("week_number", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    func fetchWorkoutsForWeek(_ weekId: UUID) async throws -> [ProgramWorkout] {
        let response: [ProgramWorkout] = try await supabase
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
        guard let userId = SupabaseManager.shared.currentUser?.id else { return }
        
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
        
        try await supabase
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
        let progression = WeightProgression(
            id: UUID(),
            userProgramId: userProgramId,
            weekNumber: weekNumber,
            weightLbs: newWeight,
            wasAutoAdjusted: wasAutoAdjusted,
            reason: reason,
            createdAt: Date()
        )
        
        try await supabase
            .from("weight_progressions")
            .insert(progression)
            .execute()
    }
    
    // MARK: - Real-time Setup
    
    private func setupRealtimeSubscriptions() {
        subscribeToPrograms()
        
        // Subscribe to user programs when authenticated
        SupabaseManager.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.subscribeToUserPrograms()
                } else {
                    self?.unsubscribeFromUserPrograms()
                }
            }
            .store(in: &subscriptions)
    }
    
    private func subscribeToPrograms() {
        // Listen for changes to the programs table
        realtimeChannel = supabase.realtime.channel("programs-channel")
        
        realtimeChannel?
            .on("postgres_changes", filter: .init(
                event: "*", 
                schema: "public", 
                table: "programs"
            )) { [weak self] payload in
                print("Program updated: \(payload)")
                Task {
                    try await self?.fetchPrograms()
                }
            }
        
        realtimeChannel?.subscribe { [weak self] status, error in
            if let error = error {
                print("Real-time subscription error: \(error)")
            } else {
                print("Real-time subscription status: \(status)")
            }
        }
    }
    
    private func subscribeToUserPrograms() {
        guard let userId = SupabaseManager.shared.currentUser?.id else { return }
        
        // Create a separate channel for user-specific data
        let userChannel = supabase.realtime.channel("user-programs-\(userId)")
        
        userChannel
            .on("postgres_changes", filter: .init(
                event: "*",
                schema: "public",
                table: "user_programs",
                filter: "user_id=eq.\(userId)"
            )) { [weak self] payload in
                print("User program updated: \(payload)")
                Task {
                    try await self?.fetchUserPrograms()
                }
            }
        
        userChannel.subscribe()
    }
    
    private func unsubscribeFromUserPrograms() {
        // Clean up user-specific subscriptions when logged out
        // Supabase automatically handles this, but you can add cleanup here
    }
}

enum ProgramError: Error {
    case notAuthenticated
    case programNotFound
    case alreadyEnrolled
}
