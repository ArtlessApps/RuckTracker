import Foundation
import Combine
import SwiftUI

@MainActor
class LocalProgramService: ObservableObject {
    static let shared = LocalProgramService()
    
    // Published state
    @Published var programs: [Program] = []
    @Published var userPrograms: [UserProgram] = []
    @Published var enrolledProgram: Program?
    @Published var programProgress: ProgramProgress?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let catalog: ProgramCatalogService
    private let enrollment: ProgramEnrollmentService
    private let personalized: PersonalizedPlanService
    
    private init() {
        self.catalog = ProgramCatalogService()
        self.enrollment = ProgramEnrollmentService()
        self.personalized = PersonalizedPlanService()

        loadPrograms()
        loadUserPrograms()
        ensurePersistedPersonalizedProgramsInCatalog()
        loadEnrollmentStatus()
    }
    
    // MARK: - Program Loading
    
    func loadPrograms() {
        isLoading = true
        errorMessage = nil

        switch catalog.loadCatalog() {
        case .success(let loadedPrograms):
            programs = loadedPrograms
            print("✅ Loaded \(programs.count) programs")
        case .failure(let error):
            errorMessage = "Failed to load programs: \(error.localizedDescription)"
            programs = []
        }

        // Ensure any persisted generated plans (e.g. MARCH) remain visible after reload.
        ensurePersistedPersonalizedProgramsInCatalog()
        isLoading = false
    }

    /// Inject or replace the personalized MARCH program in memory.
    func upsertMarchProgram(_ generated: MarchPlanGenerator.GeneratedPlan) {
        // Persist the generated weeks for rehydration.
        personalized.persistMarchPlan(generated)

        // Upsert into the catalog (in-memory).
        catalog.upsertProgram(generated.program)
        programs.removeAll { $0.id == generated.program.id }
        programs.append(generated.program.toProgram())

        // Enrollment is an enrollment concern (also anchors schedule).
        enrollment.enroll(programId: generated.program.id)

        // Refresh state derived from enrollment.
        enrolledProgram = generated.program.toProgram()
        programProgress = enrollment.programProgress(programId: generated.program.id)
        userPrograms = enrollment.userPrograms()

        NotificationCenter.default.post(name: .programEnrollmentCompleted, object: enrolledProgram)
        objectWillChange.send()
        print("✅ Upserted + enrolled in MARCH personalized plan with \(generated.weeks.count) weeks")
    }
    
    func loadUserPrograms() {
        userPrograms = enrollment.userPrograms()
        print("✅ Loaded \(userPrograms.count) user programs")
    }
    
    func loadEnrollmentStatus() {
        guard let programId = enrollment.enrolledProgramId() else {
            enrolledProgram = nil
            programProgress = nil
            return
        }
        
        // Find the enrolled program
        enrolledProgram = programs.first { $0.id == programId }
        
        // Calculate progress
        if enrolledProgram != nil {
            programProgress = enrollment.programProgress(programId: programId)
        }
        
        print("✅ Loaded enrollment status: \(enrolledProgram?.title ?? "None")")
    }
    
    // MARK: - Program Enrollment
    
    func enrollInProgram(_ program: Program) {
        enrollment.enroll(programId: program.id)
        enrolledProgram = program
        programProgress = enrollment.programProgress(programId: program.id)
        
        // Update user programs to reflect enrollment
        loadUserPrograms()
        
        // Send notification for enrollment change
        NotificationCenter.default.post(name: .programEnrollmentCompleted, object: program)
        
        // Trigger UI update
        objectWillChange.send()
        
        print("✅ Enrolled in program: \(program.title)")
    }
    
    func unenrollFromProgram() {
        enrollment.unenroll()
        enrolledProgram = nil
        programProgress = nil
        
        // Update user programs to reflect unenrollment
        loadUserPrograms()
        
        // Send notification for enrollment change
        NotificationCenter.default.post(name: .programEnrollmentCompleted, object: nil)
        
        // Trigger UI update
        objectWillChange.send()
        
        print("✅ Unenrolled from current program")
    }
    
    // MARK: - Workout Loading
    
    func loadProgramWorkouts(programId: UUID) -> [ProgramWorkout] {
        let workouts = catalog.loadProgramWorkouts(programId: programId)
        print("✅ Loaded \(workouts.count) workouts for programId: \(programId)")
        return workouts
    }
    
    func loadProgramWorkouts(programId: UUID) async -> [ProgramWorkout] {
        // Currently synchronous; keep async overload for call sites.
        return catalog.loadProgramWorkouts(programId: programId)
    }
    
    func loadWorkoutCompletions(userProgramId: UUID) -> [WorkoutCompletion] {
        let completions = enrollment.workoutCompletions(programId: userProgramId)
        print("✅ Loaded \(completions.count) workout completions")
        return completions
    }
    
    // MARK: - Workout Completion
    
    /// Refresh program progress after a workout is completed
    /// Note: The workout is already saved to CoreData by WorkoutManager with program metadata
    func refreshProgramProgress() {
        print("\n🟠 ===== REFRESHING PROGRAM PROGRESS =====")
        let enrolledProgramId = enrollment.enrolledProgramId()
            ?? (UserSettings.shared.activeProgramID.flatMap { UUID(uuidString: $0) })
        
        guard let enrolledProgramId else {
        print("🟠 ❌ No enrolled program found (enrollment service or activeProgramID)")
            print("🟠 ===== REFRESH ABORTED =====\n")
            return
        }
        
        print("🟠 Enrolled Program ID: \(enrolledProgramId.uuidString)")
        print("🟠 About to call enrollment.programProgress()...")
        
        // Recalculate progress based on workouts in CoreData
        programProgress = enrollment.programProgress(programId: enrolledProgramId)
        
        print("🟠 New progress: \(programProgress?.completed ?? 0)/\(programProgress?.total ?? 0) workouts")
        print("🟠 Next workout day: \(programProgress?.nextWorkoutDay ?? 1)")
        
        // Trigger UI update
        objectWillChange.send()
        
        print("🟠 ✅ UI update triggered")
        print("🟠 ===== REFRESH COMPLETE =====\n")
    }
    
    // DEPRECATED: Use refreshProgramProgress() instead
    // This method is kept for backwards compatibility but should not be used
    func completeWorkout(
        programId: UUID,
        workoutDay: Int,
        distanceMiles: Double,
        weightLbs: Double,
        durationMinutes: Int,
        notes: String? = nil
    ) {
        print("⚠️ completeWorkout() is deprecated. Use refreshProgramProgress() instead.")
        refreshProgramProgress()
    }
    
    // MARK: - Helper Methods
    
    func isEnrolledIn(programId: UUID) -> Bool {
        return enrollment.enrolledProgramId() == programId
    }
    
    func getEnrolledProgramId() -> UUID? {
        return enrollment.enrolledProgramId()
    }
    
    func getProgramWeeks(programId: UUID) -> [LocalProgramWeek] {
        return catalog.programWeeks(programId: programId)
    }
    
    func getProgramTitle(programId: UUID) -> String? {
        return catalog.programTitle(programId: programId)
    }
    
    // MARK: - Testing
    
    func testWeekLoading(programId: UUID) {
        print("\n🧪 Testing Week Loading for Program: \(programId)")
        
        let weekLoader = LocalWeekLoader.shared
        let weeks = weekLoader.getWeeks(forProgramId: programId)
        
        print("📅 Total weeks loaded: \(weeks.count)")
        
        for week in weeks {
            print("  Week \(week.weekNumber):")
            print("    Weight: \(week.baseWeightLbs ?? 0) lbs")
            print("    Description: \(week.description ?? "None")")
            print("    Workouts: \(week.workouts.count)")
        }
        
        print("✅ Week loading test complete\n")
    }
    
    func testWorkoutIntegration(programId: UUID) {
        print("\n🧪 Testing Workout Integration for Program: \(programId)")
        
        guard let program = programs.first(where: { $0.id == programId }) else {
            print("❌ Program not found")
            return
        }
        
        print("📚 Program: \(program.title)")
        print("📅 Duration: \(program.durationWeeks) weeks")
        
        let workouts = loadProgramWorkouts(programId: programId)
        print("💪 Total workouts loaded: \(workouts.count)")
        
        // Group by week
        let workoutsByWeek = Dictionary(grouping: workouts) { workout in
            // Find which week this workout belongs to
            let weeks = catalog.programWeeks(programId: programId)
            return weeks.first { $0.id == workout.weekId }?.weekNumber ?? 0
        }
        
        // Print summary by week
        for weekNumber in 1...program.durationWeeks {
            let weekWorkouts = workoutsByWeek[weekNumber] ?? []
            print("  Week \(weekNumber): \(weekWorkouts.count) workouts")
            
            for workout in weekWorkouts.sorted(by: { $0.dayNumber < $1.dayNumber }) {
                let type = workout.workoutType.rawValue
                let distance = workout.distanceMiles.map { "\($0) mi" } ?? "N/A"
                print("    Day \(workout.dayNumber): \(type) - \(distance)")
            }
        }
        
        print("✅ Integration test complete\n")
    }

    // MARK: - Personalized Program Rehydration

    private func ensurePersistedPersonalizedProgramsInCatalog() {
        // If the user is enrolled in the MARCH program, ensure the generated weeks are
        // rehydrated into the in-memory catalog so `enrolledProgram` can be resolved.
        guard enrollment.enrolledProgramId() == MarchPlanGenerator.programId else { return }
        guard let persisted = personalized.loadPersistedMarchProgram() else { return }

        catalog.upsertProgram(persisted)
        programs.removeAll { $0.id == persisted.id }
        programs.append(persisted.toProgram())
    }
}
