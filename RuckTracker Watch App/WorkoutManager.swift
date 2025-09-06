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
    
    // Location manager for GPS tracking
    @Published var locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    private var startDate: Date?
    private var timer: Timer?
    private var workoutSession: HKWorkoutSession?
    private let healthStore = HKHealthStore()
    
    // Computed properties for time display
    var hours: Int { Int(elapsedTime) / 3600 }
    var minutes: Int { (Int(elapsedTime) % 3600) / 60 }
    var seconds: Int { Int(elapsedTime) % 60 }
    var heartRate: Double { currentHeartRate }
    
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
    
    init() {
        // Subscribe to location manager's distance updates
        locationManager.$distanceTraveled
            .sink { [weak self] newDistance in
                self?.distance = newDistance
            }
            .store(in: &cancellables)
        
        // Request location permission on init
        locationManager.requestLocationPermission()
    }
    
    func startWorkout() {
        startWorkout(weight: ruckWeight)
    }
    
    func startWorkout(weight: Double) {
        guard !isActive else { return }
        
        self.ruckWeight = weight
        isActive = true
        isPaused = false
        startDate = Date()
        elapsedTime = 0
        distance = 0
        calories = 0
        
        startTimer()
        startWorkoutSession()
        locationManager.startTracking()
    }
    
    func togglePause() {
        isPaused.toggle()
        
        if isPaused {
            pauseWorkout()
        } else {
            resumeWorkout()
        }
    }
    
    func pauseWorkout() {
        isPaused = true
        isActive = false
        timer?.invalidate()
        locationManager.pauseTracking()
    }
    
    func resumeWorkout() {
        isPaused = false
        isActive = true
        startTimer()
        locationManager.resumeTracking()
    }
    
    func endWorkout() {
        isActive = false
        isPaused = true
        timer?.invalidate()
        locationManager.stopTracking()
        
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
        // Calculate calories with weight adjustment
        // Note: distance is now coming from GPS via LocationManager
        let timeInHours = elapsedTime / 3600
        
        // Enhanced calorie calculation
        let baseMET = 5.0 // Base MET for hiking/walking
        let weightMET = ruckWeight > 15 ? (ruckWeight / 20.0) : 1.0 // Additional MET based on weight
        let totalMET = baseMET + weightMET
        
        // Calories = MET × weight in kg × time in hours
        let bodyWeightKg = 70.0 // Average person weight (could be user configurable)
        calories = totalMET * bodyWeightKg * timeInHours
        
        // Simulate heart rate variation based on activity and weight
        updateHeartRate()
    }
    
    private func updateHeartRate() {
        // Simulate realistic heart rate during rucking
        let baseRate = 110 + (ruckWeight * 0.5) // Higher base rate with more weight
        let timeEffect = min(elapsedTime / 600, 1.0) // Gradual increase over 10 minutes
        let variability = Double.random(in: -3...3) // Random variation
        
        currentHeartRate = baseRate + (timeEffect * 15) + variability
        currentHeartRate = max(95, min(currentHeartRate, 155)) // Keep in reasonable range
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
                "AppName": "RuckTracker",
                "GPS": "Enabled"
            ]
        )
        
        healthStore.save(workout) { success, error in
            if success {
                print("Workout saved to HealthKit with GPS data")
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
        currentHeartRate = 120
    }
}
