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
    
    // MARK: - Program Progress
    
    func getProgramProgress(programId: UUID) -> ProgramProgress {
        let workouts = getCompletedProgramWorkouts(programId: programId)
        let totalWorkouts = getTotalWorkoutCount(programId: programId)
        
        let completionPercentage = totalWorkouts > 0 
            ? (Double(workouts.count) / Double(totalWorkouts)) * 100.0 
            : 0.0
        
        let currentWeek = calculateCurrentWeek(completedWorkouts: workouts.count)
        
        return ProgramProgress(
            programId: programId,
            completedWorkouts: workouts.count,
            totalWorkouts: totalWorkouts,
            completionPercentage: completionPercentage,
            currentWeek: currentWeek
        )
    }
    
    // MARK: - Workout Completions
    
    private func getCompletedProgramWorkouts(programId: UUID) -> [WorkoutEntity] {
        // Get workouts from CoreData that belong to this program
        let allWorkouts = WorkoutDataManager.shared.workouts
        
        // Filter workouts that have matching program metadata
        // (We'll add programId field to WorkoutEntity in next step)
        return allWorkouts.filter { workout in
            // For now, match by date range of enrollment
            guard let enrollmentDate = getEnrollmentDate(),
                  let workoutDate = workout.date,
                  workoutDate >= enrollmentDate else {
                return false
            }
            return true
        }
    }
    
    private func getTotalWorkoutCount(programId: UUID) -> Int {
        // This will be calculated from Programs.json
        // For now, return a placeholder
        return 40 // ~8 weeks * 5 workouts per week
    }
    
    private func calculateCurrentWeek(completedWorkouts: Int) -> Int {
        // Assuming 5 workouts per week
        return (completedWorkouts / 5) + 1
    }
}

// MARK: - Progress Model

struct ProgramProgress {
    let programId: UUID
    let completedWorkouts: Int
    let totalWorkouts: Int
    let completionPercentage: Double
    let currentWeek: Int
}
