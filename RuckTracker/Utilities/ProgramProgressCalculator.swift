// Utilities/ProgramProgressCalculator.swift
import Foundation

/// Shared utility for calculating program progress across different views
struct ProgramProgressCalculator {
    
    /// Calculate the progress percentage for a program
    /// - Parameter program: The program to calculate progress for
    /// - Returns: A value between 0 and 1 representing completion percentage
    static func calculateProgress(for program: Program) -> Double {
        // Get total workouts from program JSON data
        let totalWorkouts = getTotalWorkoutsFromProgram(programId: program.id)
        guard totalWorkouts > 0 else { return 0 }
        
        // Get completed workouts from CoreData
        // IMPORTANT: Filter by program.id (the Program's ID), not userProgram.id
        let completedWorkouts = WorkoutDataManager.shared.workouts.filter {
            $0.programId == program.id.uuidString
        }.count
        
        return Double(completedWorkouts) / Double(totalWorkouts)
    }
    
    /// Get the total number of workouts for a program
    /// - Parameter programId: The program's UUID
    /// - Returns: Total number of workouts in the program
    static func getTotalWorkoutsFromProgram(programId: UUID) -> Int {
        // Get weeks for this program
        let weeks = LocalWeekLoader.shared.getWeeks(forProgramId: programId)
        
        // Get all workouts for this program using the workout loader
        let workoutLoader = LocalWorkoutLoader.shared
        let allWorkouts = workoutLoader.getAllWorkouts(forProgramId: programId, weeks: weeks)
        
        return allWorkouts.count
    }
    
    /// Get the count of completed workouts for a program
    /// - Parameter program: The program to check
    /// - Returns: Number of completed workouts
    static func getCompletedCount(for program: Program) -> Int {
        return WorkoutDataManager.shared.workouts.filter {
            $0.programId == program.id.uuidString
        }.count
    }
}

