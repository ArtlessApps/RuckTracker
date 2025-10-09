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
        let workouts = getCompletedProgramWorkouts(programId: programId)
        let totalWorkouts = getTotalWorkoutCount(programId: programId)
        
        let completionPercentage = totalWorkouts > 0 
            ? Double(workouts.count) / Double(totalWorkouts) * 100.0
            : 0.0
        
        let currentWeek = (workouts.count / 5) + 1  // Assuming 5 workouts per week
        let nextWorkoutDay = workouts.count + 1
        
        return ProgramProgress(
            completed: workouts.count,
            total: totalWorkouts,
            completionPercentage: completionPercentage,
            currentWeek: currentWeek,
            nextWorkoutDay: nextWorkoutDay <= totalWorkouts ? nextWorkoutDay : nil
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
