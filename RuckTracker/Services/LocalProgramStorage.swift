import Foundation
import CoreData

class LocalProgramStorage {
    static let shared = LocalProgramStorage()
    
    private let defaults = UserDefaults.standard
    private let enrollmentKey = "enrolled_program_id"
    private let enrollmentDateKey = "program_enrollment_date"
    private let generatedWeeksKey = "march_generated_weeks"
    
    private init() {}
    
    // MARK: - Program Enrollment
    
    func enrollInProgram(_ programId: UUID) {
        print("\n🟢 ===== ENROLLING IN PROGRAM =====")
        print("🟢 Program ID: \(programId.uuidString)")
        print("🟢 Enrollment Date: \(Date())")
        
        // Delete any existing workouts for this program FIRST
        print("🟢 About to delete old workouts for this program...")
        WorkoutDataManager.shared.deleteWorkoutsForProgram(programId)
        print("🟢 Old workouts deleted")
        
        // Then set the new enrollment
        defaults.set(programId.uuidString, forKey: enrollmentKey)
        defaults.set(Date(), forKey: enrollmentDateKey)
        
        print("🟢 Enrollment data saved to UserDefaults")
        print("🟢 ===== ENROLLMENT COMPLETE =====\n")
    }
    
    func getEnrolledProgramId() -> UUID? {
        guard let idString = defaults.string(forKey: enrollmentKey),
              let uuid = UUID(uuidString: idString) else {
            return nil
        }
        return uuid
    }
    
    
    func getEnrollmentDate() -> Date? {
        return defaults.object(forKey: enrollmentDateKey) as? Date
    }
    
    func unenrollFromProgram() {
        // Get the enrolled program ID before clearing
        if let programId = getEnrolledProgramId() {
            // Delete all associated workouts
            WorkoutDataManager.shared.deleteWorkoutsForProgram(programId)
            
            // Clear completion tracking
            UserDefaults.standard.removeObject(forKey: "completed_workouts_\(programId)")
        }
        
        // Clear enrollment data
        defaults.removeObject(forKey: enrollmentKey)
        defaults.removeObject(forKey: enrollmentDateKey)
        defaults.removeObject(forKey: generatedWeeksKey)
        
        print("✅ Unenrolled from program and deleted all associated workouts")
    }
    
    func getAllUserPrograms() -> [UserProgram] {
        // For now, return a single user program if enrolled
        guard let programId = getEnrolledProgramId() else {
            return []
        }
        
        let userProgram = UserProgram(
            programId: programId,
            targetWeight: WorkoutDataManager.shared.workouts.first?.ruckWeight ?? 20.0,
            isActive: true
        )
        
        return [userProgram]
    }
    
    // MARK: - Program Progress
    
    func getProgramProgress(programId: UUID) -> ProgramProgress {
        print("\n🟡 ===== CALCULATING PROGRAM PROGRESS =====")
        print("🟡 Program ID: \(programId.uuidString)")
        
        let weekLoader = LocalWeekLoader.shared
        let generatedWeeks = getGeneratedWeeks(programId: programId)
        let weeks = generatedWeeks.isEmpty ? weekLoader.getWeeks(forProgramId: programId) : generatedWeeks
        
        let completedWorkouts = getCompletedProgramWorkouts(programId: programId)
        print("🟡 Found \(completedWorkouts.count) completed workouts in CoreData")
        
        let totalWorkouts = getTotalWorkoutCount(programId: programId)
        print("🟡 Total workouts expected: \(totalWorkouts)")
        
        // Calculate current week based on start date
        guard let startDate = getEnrollmentDate() else {
            print("🟡 No enrollment date found")
            print("🟡 ===== PROGRESS CALCULATION COMPLETE =====\n")
            return ProgramProgress(completed: 0, total: totalWorkouts, completionPercentage: 0, currentWeek: 1, nextWorkoutDay: 1)
        }
        
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        let currentWeek = min((daysSinceStart / 7) + 1, weeks.count)
        print("🟡 Days since enrollment: \(daysSinceStart)")
        print("🟡 Current week: \(currentWeek)")
        
        // Get current week's base weight
        let currentWeekData = weeks.first { $0.weekNumber == currentWeek }
        let currentWeight = currentWeekData?.baseWeightLbs ?? (WorkoutDataManager.shared.workouts.first?.ruckWeight ?? 20.0)
        
        let completionPercentage = totalWorkouts > 0 
            ? Double(completedWorkouts.count) / Double(totalWorkouts) * 100.0
            : 0.0
        
        print("🟡 Completion percentage: \(String(format: "%.1f", completionPercentage))%")
        print("🟡 Next workout day: \(completedWorkouts.count + 1)")
        print("🟡 ===== PROGRESS CALCULATION COMPLETE =====\n")
        
        return ProgramProgress(
            completed: completedWorkouts.count,
            total: totalWorkouts,
            completionPercentage: completionPercentage,
            currentWeek: currentWeek,
            nextWorkoutDay: completedWorkouts.count + 1
        )
    }
    
    // MARK: - Workout Completions
    
    private func getCompletedProgramWorkouts(programId: UUID) -> [WorkoutEntity] {
        let filtered = WorkoutDataManager.shared.workouts.filter { workout in
            workout.programId == programId.uuidString
        }
        
        print("🟡 Filtering workouts for programId: \(programId.uuidString)")
        print("🟡 Total workouts in CoreData: \(WorkoutDataManager.shared.workouts.count)")
        print("🟡 Workouts matching this program: \(filtered.count)")
        for (index, workout) in filtered.enumerated() {
            print("🟡   Workout \(index + 1): Day \(workout.programWorkoutDay), Date: \(workout.date?.formatted() ?? "nil")")
        }
        
        return filtered
    }
    
    private func getTotalWorkoutCount(programId: UUID) -> Int {
        let generatedWeeks = getGeneratedWeeks(programId: programId)
        if !generatedWeeks.isEmpty {
            return generatedWeeks.reduce(0) { $0 + $1.workouts.count }
        }
        
        // Mock fallback
        return 60
    }
    
    // MARK: - Generated plan persistence
    func setGeneratedWeeks(programId: UUID, weeks: [LocalProgramWeek]) {
        guard programId == MarchPlanGenerator.programId else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(weeks) {
            defaults.set(data, forKey: generatedWeeksKey)
        }
    }
    
    func getGeneratedWeeks(programId: UUID) -> [LocalProgramWeek] {
        guard programId == MarchPlanGenerator.programId,
              let data = defaults.data(forKey: generatedWeeksKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([LocalProgramWeek].self, from: data)) ?? []
    }
    
}
