import Foundation
import CoreData

class LocalProgramStorage {
    static let shared = LocalProgramStorage()
    
    private let defaults = UserDefaults.standard
    private let enrollmentKey = "enrolled_program_id"
    private let startingWeightKey = "program_starting_weight"
    private let enrollmentDateKey = "program_enrollment_date"
    
    private init() {}
    
    // MARK: - Program Enrollment
    
    func enrollInProgram(_ programId: UUID, startingWeight: Double) {
        defaults.set(programId.uuidString, forKey: enrollmentKey)
        defaults.set(startingWeight, forKey: startingWeightKey)
        defaults.set(Date(), forKey: enrollmentDateKey)
        print("✅ Enrolled in program: \(programId)")
    }
    
    func getEnrolledProgramId() -> UUID? {
        guard let idString = defaults.string(forKey: enrollmentKey),
              let uuid = UUID(uuidString: idString) else {
            return nil
        }
        return uuid
    }
    
    func getStartingWeight() -> Double {
        return defaults.double(forKey: startingWeightKey)
    }
    
    func getEnrollmentDate() -> Date? {
        return defaults.object(forKey: enrollmentDateKey) as? Date
    }
    
    func unenrollFromProgram() {
        defaults.removeObject(forKey: enrollmentKey)
        defaults.removeObject(forKey: startingWeightKey)
        defaults.removeObject(forKey: enrollmentDateKey)
        print("✅ Unenrolled from program")
    }
    
    func getAllUserPrograms() -> [UserProgram] {
        // For now, return a single user program if enrolled
        guard let programId = getEnrolledProgramId() else {
            return []
        }
        
        let userProgram = UserProgram(
            programId: programId,
            targetWeight: getStartingWeight(),
            isActive: true
        )
        
        return [userProgram]
    }
    
    // MARK: - Program Progress
    
    func getProgramProgress(programId: UUID) -> ProgramProgress {
        let weekLoader = LocalWeekLoader.shared
        let weeks = weekLoader.getWeeks(forProgramId: programId)
        
        let completedWorkouts = getCompletedProgramWorkouts(programId: programId)
        let totalWorkouts = getTotalWorkoutCount(programId: programId)
        
        // Calculate current week based on start date
        guard let startDate = getEnrollmentDate() else {
            return ProgramProgress(completed: 0, total: totalWorkouts, completionPercentage: 0, currentWeek: 1, nextWorkoutDay: 1)
        }
        
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        let currentWeek = min((daysSinceStart / 7) + 1, weeks.count)
        
        // Get current week's base weight
        let currentWeekData = weeks.first { $0.weekNumber == currentWeek }
        let currentWeight = currentWeekData?.baseWeightLbs ?? getStartingWeight()
        
        let completionPercentage = totalWorkouts > 0 
            ? Double(completedWorkouts.count) / Double(totalWorkouts) * 100.0
            : 0.0
        
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
        return WorkoutDataManager.shared.workouts.filter { workout in
            workout.programId == programId.uuidString
        }
    }
    
    private func getTotalWorkoutCount(programId: UUID) -> Int {
        // Mock implementation - should be based on actual program data
        // For now, assume programs have 12 weeks with 5 workouts each
        return 60
    }
    
}
