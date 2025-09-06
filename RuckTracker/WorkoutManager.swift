import Foundation
import Combine
import SwiftUI
import HealthKit

class WorkoutManager: ObservableObject {
    @Published var isActive = false
    @Published var isPaused = true
    @Published var ruckWeight: Double = 20.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0
    @Published var calories: Double = 0
    @Published var currentHeartRate: Double = 120
    
    private var startDate: Date?
    private var timer: Timer?
    private var workoutSession: HKWorkoutSession?
    private let healthStore = HKHealthStore()
    
    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) % 3600 / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedPace: String {
        guard distance > 0 else { return "--:--" }
        let paceInSeconds = elapsedTime / distance
        let minutes = Int(paceInSeconds) / 60
        let seconds = Int(paceInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var paceColor: Color {
        guard distance > 0 else { return .gray }
        let paceInMinutes = (elapsedTime / distance) / 60
        
        if paceInMinutes < 14 { return .orange } // Too fast
        if paceInMinutes <= 20 { return .green } // Good pace
        return .red // Too slow
    }
    
    func startWorkout() {
        guard !isActive else { return }
        
        isActive = true
        isPaused = false
        startDate = Date()
        elapsedTime = 0
        distance = 0
        calories = 0
        
        startTimer()
        startWorkoutSession()
    }
    
    func togglePause() {
        isPaused.toggle()
        
        if isPaused {
            timer?.invalidate()
        } else {
            startTimer()
        }
    }
    
    func endWorkout() {
        isActive = false
        isPaused = true
        timer?.invalidate()
        
        if let startDate = startDate {
            let endDate = Date()
            saveWorkoutToHealth(startDate: startDate, endDate: endDate)
        }
        
        endWorkoutSession()
        resetWorkout()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            
            self.elapsedTime += 1
            self.updateMetrics()
        }
    }
    
    private func updateMetrics() {
        // Simulate distance based on average walking speed (3 mph)
        distance = (elapsedTime / 3600) * 3.0
        
        // Calculate calories with weight adjustment
        let baseCalories = distance * 100 // Base calories per mile
        let weightMultiplier = 1 + (ruckWeight / 100) // Increase based on weight
        calories = baseCalories * weightMultiplier
        
        // Simulate heart rate variation
        currentHeartRate = 120 + Double.random(in: -10...30)
    }
    
    private func startWorkoutSession() {
        #if os(watchOS)
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.startActivity(with: Date())
        } catch {
            print("Failed to start workout session: \(error)")
        }
        #endif
    }
    
    private func endWorkoutSession() {
        #if os(watchOS)
        workoutSession?.end()
        workoutSession = nil
        #endif
    }
    
    private func saveWorkoutToHealth(startDate: Date, endDate: Date) {
        let workout = HKWorkout(
            activityType: .walking,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
            totalDistance: HKQuantity(unit: .mile(), doubleValue: distance),
            metadata: [
                "RuckWeight": ruckWeight,
                "AppName": "RuckTracker"
            ]
        )
        
        healthStore.save(workout) { success, error in
            if success {
                print("Workout saved to HealthKit")
            } else {
                print("Failed to save workout: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func resetWorkout() {
        elapsedTime = 0
        distance = 0
        calories = 0
        startDate = nil
    }
}
