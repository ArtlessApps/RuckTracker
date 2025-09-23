//
//  WorkoutTransferModel.swift
//  RuckTracker
//
//  Model for transferring workout data between iPhone and Apple Watch
//

import Foundation
import CoreData

// MARK: - Workout Transfer Model
struct WorkoutTransferData: Codable {
    let date: Date
    let duration: TimeInterval
    let distance: Double
    let calories: Double
    let ruckWeight: Double
    let heartRate: Double
    
    // Convert from WorkoutEntity
    init(from workout: WorkoutEntity) {
        self.date = workout.date ?? Date()
        self.duration = workout.duration
        self.distance = workout.distance
        self.calories = workout.calories
        self.ruckWeight = workout.ruckWeight
        self.heartRate = workout.heartRate
    }
    
    // Convert to WorkoutEntity context
    func toWorkoutEntity(context: NSManagedObjectContext) -> WorkoutEntity {
        let workout = WorkoutEntity(context: context)
        workout.date = self.date
        workout.duration = self.duration
        workout.distance = self.distance
        workout.calories = self.calories
        workout.ruckWeight = self.ruckWeight
        workout.heartRate = self.heartRate
        return workout
    }
}

// MARK: - WatchConnectivity Keys
struct WatchConnectivityKeys {
    static let workoutData = "workoutData"
    static let requestWorkouts = "requestWorkouts"
    static let sendAllWorkouts = "sendAllWorkouts"
    static let startWorkout = "startWorkout"
}
