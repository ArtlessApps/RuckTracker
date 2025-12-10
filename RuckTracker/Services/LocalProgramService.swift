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
    
    private let storage = LocalProgramStorage.shared
    private let workoutLoader = LocalWorkoutLoader.shared
    private var localPrograms: [LocalProgram] = []
    private var customProgram: LocalProgram?
    
    private init() {
        loadPrograms()
        loadUserPrograms()
        loadEnrollmentStatus()
    }
    
    // MARK: - Program Loading
    
    func loadPrograms() {
        isLoading = true
        errorMessage = nil
        
        do {
            let result: Result<[LocalProgram], Error> = Bundle.main.decodeWithCustomDecoder("Programs.json")
            
            switch result {
            case .success(var loadedPrograms):
                // ENHANCEMENT: Add week data to programs
                let weekLoader = LocalWeekLoader.shared
                
                for i in 0..<loadedPrograms.count {
                    let weeks = weekLoader.getWeeks(forProgramId: loadedPrograms[i].id)
                    
                    // Update workouts for each week
                    var updatedWeeks: [LocalProgramWeek] = []
                    for week in weeks {
                        // Use the workouts that are already loaded in the week data
                        // The week data from LocalWeekLoader already has empty workouts array
                        // We'll populate it with workouts from the workout loader
                        let programWorkouts = workoutLoader.getWorkouts(forWeekId: week.id)
                        
                        // Convert ProgramWorkout to LocalProgramWorkout
                        let localWorkouts = programWorkouts.map { programWorkout in
                            LocalProgramWorkout(
                                id: programWorkout.id,
                                dayNumber: programWorkout.dayNumber,
                                workoutType: programWorkout.workoutType.rawValue,
                                distanceMiles: programWorkout.distanceMiles,
                                targetPaceMinutes: programWorkout.targetPaceMinutes,
                                instructions: programWorkout.instructions
                            )
                        }
                        
                        let updatedWeek = LocalProgramWeek(
                            id: week.id,
                            weekNumber: week.weekNumber,
                            baseWeightLbs: week.baseWeightLbs,
                            description: week.description,
                            workouts: localWorkouts
                        )
                        updatedWeeks.append(updatedWeek)
                    }
                    
                    loadedPrograms[i].weeks = updatedWeeks
                }
                
                localPrograms = loadedPrograms
                programs = loadedPrograms.map { $0.toProgram() }
                print("✅ Loaded \(programs.count) programs with week data")
                
            case .failure(let error):
                errorMessage = "Failed to load programs: \(error.localizedDescription)"
                programs = []
            }
        }
        
        isLoading = false
    }

    /// Inject or replace the personalized MARCH program in memory.
    func upsertMarchProgram(_ generated: MarchPlanGenerator.GeneratedPlan) {
        customProgram = generated.program
        
        // Replace any existing instance.
        localPrograms.removeAll { $0.id == MarchPlanGenerator.programId }
        programs.removeAll { $0.id == MarchPlanGenerator.programId }
        
        localPrograms.append(generated.program)
        programs.append(generated.program.toProgram())
        
        // Persist enrollment metadata so schedule anchoring works.
        storage.enrollInProgram(generated.program.id)
        LocalProgramStorage.shared.setGeneratedWeeks(programId: generated.program.id, weeks: generated.weeks)
        
        objectWillChange.send()
        print("✅ Upserted MARCH personalized plan with \(generated.weeks.count) weeks")
    }
    
    func loadUserPrograms() {
        userPrograms = storage.getAllUserPrograms()
        print("✅ Loaded \(userPrograms.count) user programs")
    }
    
    func loadEnrollmentStatus() {
        guard let programId = storage.getEnrolledProgramId() else {
            enrolledProgram = nil
            programProgress = nil
            return
        }
        
        // Find the enrolled program
        enrolledProgram = programs.first { $0.id == programId }
        
        // Calculate progress
        if enrolledProgram != nil {
            programProgress = storage.getProgramProgress(programId: programId)
        }
        
        print("✅ Loaded enrollment status: \(enrolledProgram?.title ?? "None")")
    }
    
    // MARK: - Program Enrollment
    
    func enrollInProgram(_ program: Program) {
        storage.enrollInProgram(program.id)
        enrolledProgram = program
        programProgress = storage.getProgramProgress(programId: program.id)
        
        // Update user programs to reflect enrollment
        loadUserPrograms()
        
        // Send notification for enrollment change
        NotificationCenter.default.post(name: .programEnrollmentCompleted, object: program)
        
        // Trigger UI update
        objectWillChange.send()
        
        print("✅ Enrolled in program: \(program.title)")
    }
    
    func unenrollFromProgram() {
        storage.unenrollFromProgram()
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
        // Find program in local data
        guard let localProgram = localPrograms.first(where: { $0.id == programId }) else {
            print("❌ Program not found: \(programId)")
            return []
        }
        
        // If this is the generated MARCH program, use embedded workouts.
        if programId == MarchPlanGenerator.programId {
            let workouts = localProgram.weeks.flatMap { week in
                week.workouts.map { workout in
                    ProgramWorkout(
                        id: workout.id,
                        weekId: week.id,
                        dayNumber: workout.dayNumber,
                        workoutType: ProgramWorkout.WorkoutType(rawValue: workout.workoutType) ?? .ruck,
                        distanceMiles: workout.distanceMiles,
                        targetPaceMinutes: workout.targetPaceMinutes,
                        instructions: workout.instructions
                    )
                }
            }
            print("✅ Loaded \(workouts.count) generated workouts for program: \(localProgram.title)")
            return workouts.sorted { $0.dayNumber < $1.dayNumber }
        }
        
        // Get all workouts for this program using the workout loader
        let workouts = workoutLoader.getAllWorkouts(
            forProgramId: programId,
            weeks: localProgram.weeks
        )
        
        print("✅ Loaded \(workouts.count) workouts for program: \(localProgram.title)")
        return workouts
    }
    
    func loadProgramWorkouts(programId: UUID) async -> [ProgramWorkout] {
        // Find program in local data
        guard let localProgram = localPrograms.first(where: { $0.id == programId }) else {
            print("❌ Program not found: \(programId)")
            return []
        }
        
        if programId == MarchPlanGenerator.programId {
            let workouts = localProgram.weeks.flatMap { week in
                week.workouts.map { workout in
                    ProgramWorkout(
                        id: workout.id,
                        weekId: week.id,
                        dayNumber: workout.dayNumber,
                        workoutType: ProgramWorkout.WorkoutType(rawValue: workout.workoutType) ?? .ruck,
                        distanceMiles: workout.distanceMiles,
                        targetPaceMinutes: workout.targetPaceMinutes,
                        instructions: workout.instructions
                    )
                }
            }
            print("✅ Loaded \(workouts.count) generated workouts for program: \(localProgram.title)")
            return workouts.sorted { $0.dayNumber < $1.dayNumber }
        }
        
        // Get all workouts for this program using the workout loader
        let workouts = workoutLoader.getAllWorkouts(
            forProgramId: programId,
            weeks: localProgram.weeks
        )
        
        print("✅ Loaded \(workouts.count) workouts for program: \(localProgram.title)")
        return workouts
    }
    
    func loadWorkoutCompletions(userProgramId: UUID) -> [WorkoutCompletion] {
        // Get workouts from CoreData that belong to this program
        let programWorkouts = WorkoutDataManager.shared.workouts.filter { workout in
            workout.programId == userProgramId.uuidString
        }
        
        // Convert to WorkoutCompletion models
        let completions = programWorkouts.compactMap { workout -> WorkoutCompletion? in
            guard let date = workout.date else { return nil }
            
            return WorkoutCompletion(
                id: UUID(),
                userId: UUID(), // Not needed for local
                userProgramId: userProgramId,
                programWorkoutId: UUID(), // Match by day number instead
                completedAt: date,
                actualDistanceMiles: workout.distance,
                actualWeightLbs: workout.ruckWeight,
                actualDurationMinutes: Int(workout.duration / 60),
                performanceScore: nil,
                notes: nil
            )
        }
        
        print("✅ Loaded \(completions.count) workout completions")
        return completions
    }
    
    // MARK: - Workout Completion
    
    /// Refresh program progress after a workout is completed
    /// Note: The workout is already saved to CoreData by WorkoutManager with program metadata
    func refreshProgramProgress() {
        print("\n🟠 ===== REFRESHING PROGRAM PROGRESS =====")
        let enrolledProgramId = storage.getEnrolledProgramId()
            ?? (UserSettings.shared.activeProgramID.flatMap { UUID(uuidString: $0) })
        
        guard let enrolledProgramId else {
            print("🟠 ❌ No enrolled program found (storage or activeProgramID)")
            print("🟠 ===== REFRESH ABORTED =====\n")
            return
        }
        
        print("🟠 Enrolled Program ID: \(enrolledProgramId.uuidString)")
        print("🟠 About to call storage.getProgramProgress()...")
        
        // Recalculate progress based on workouts in CoreData
        programProgress = storage.getProgramProgress(programId: enrolledProgramId)
        
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
        return storage.getEnrolledProgramId() == programId
    }
    
    func getEnrolledProgramId() -> UUID? {
        return storage.getEnrolledProgramId()
    }
    
    func getProgramWeeks(programId: UUID) -> [LocalProgramWeek] {
        return localPrograms.first(where: { $0.id == programId })?.weeks ?? []
    }
    
    func getProgramTitle(programId: UUID) -> String? {
        return programs.first(where: { $0.id == programId })?.title
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
            guard let localProgram = localPrograms.first(where: { $0.id == programId }) else {
                return 0
            }
            return localProgram.weeks.first { $0.id == workout.weekId }?.weekNumber ?? 0
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
}
