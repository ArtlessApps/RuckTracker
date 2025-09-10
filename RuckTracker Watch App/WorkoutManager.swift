//
//  WorkoutManager.swift
//  RuckTracker Watch App
//
//  Created by Nick on 9/6/25.
//

import Foundation
import Combine
import SwiftUI
import HealthKit

class WorkoutManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isActive = false
    @Published var isPaused = false
    @Published var ruckWeight: Double = 20.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0
    @Published var calories: Double = 0
    @Published var currentHeartRate: Double = 120
    @Published var selectedTerrain: TerrainType = .flat
    
    // Location manager for GPS tracking
    @Published var locationManager = LocationManager()
    
    // Settings
    private let userSettings = UserSettings.shared
    private var cancellables = Set<AnyCancellable>()
    
    // HealthKit workout session
    private var workoutSession: HKWorkoutSession?
    
    // Health manager reference (injected from environment)
    private var healthManager: HealthManager?
    
    // Workout session data
    private var startDate: Date?
    private var timer: Timer?
    
    // Real-time metrics
    private var lastCalorieUpdate: Date = Date()
    private var totalCaloriesBurned: Double = 0
    
    // Heart rate monitoring
    private var heartRateQuery: HKAnchoredObjectQuery?
    
    // MARK: - Computed Properties
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
    
    var currentPaceMinutesPerMile: Double? {
        guard distance > 0 && elapsedTime > 0 else { return nil }
        return elapsedTime / (distance * 60) // Convert to minutes per mile
    }
    
    var formattedPace: String {
        guard let pace = currentPaceMinutesPerMile else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var paceColor: Color {
        guard let pace = currentPaceMinutesPerMile else { return .gray }
        
        // Good rucking pace is typically 15-20 minutes per mile
        switch pace {
        case 0..<14: return .orange   // Too fast for sustainable rucking
        case 14..<18: return .green   // Good rucking pace
        case 18..<25: return .yellow  // Acceptable pace
        default: return .red          // Too slow
        }
    }
    
    // MARK: - Initialization
    init() {
        setupLocationTracking()
        setupUserSettings()
    }
    
    // Method to set health manager reference
    func setHealthManager(_ manager: HealthManager) {
        self.healthManager = manager
    }
    
    private func setupLocationTracking() {
        // Subscribe to location manager's distance updates
        locationManager.$distanceTraveled
            .sink { [weak self] newDistance in
                self?.distance = newDistance
                self?.updateCaloriesFromDistance()
            }
            .store(in: &cancellables)
        
        locationManager.requestLocationPermission()
    }
    
    private func setupUserSettings() {
        // Initialize ruck weight from user settings
        ruckWeight = userSettings.defaultRuckWeightInPounds()
        
        // Subscribe to settings changes
        userSettings.$defaultRuckWeight
            .sink { [weak self] newWeight in
                if !(self?.isActive ?? false) {
                    self?.ruckWeight = self?.userSettings.defaultRuckWeightInPounds() ?? 20.0
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Workout Control
    func startWorkout() {
        startWorkout(weight: ruckWeight)
    }
    
    func startWorkout(weight: Double) {
        print("DEBUG: startWorkout called with weight \(weight)")
        guard !isActive else { return }
        
        self.ruckWeight = weight
        isActive = true
        isPaused = false
        startDate = Date()
        elapsedTime = 0
        distance = 0
        calories = 0
        totalCaloriesBurned = 0
        lastCalorieUpdate = Date()
        
        startTimer()
        startWorkoutSession()
        startHeartRateQuery()
        locationManager.startTracking()
        
        print("Started workout with \(weight) lbs ruck weight")
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
        
        // Update final calories before pausing
        updateCaloriesFromTime()
        
        print("Workout paused at \(formattedElapsedTime)")
    }
    
    func resumeWorkout() {
        isPaused = false
        isActive = true
        lastCalorieUpdate = Date()
        startTimer()
        locationManager.resumeTracking()
        
        print("Workout resumed")
    }
    
    func endWorkout() {
        isActive = false
        isPaused = true
        timer?.invalidate()
        locationManager.stopTracking()
        stopHeartRateQuery()
        
        // Final calorie calculation
        updateCaloriesFromTime()
        
        if let startDate = startDate {
            let endDate = Date()
            saveWorkoutToHealth(startDate: startDate, endDate: endDate)
        }
        
        endWorkoutSession()
        
        print("Workout ended: \(formattedElapsedTime), \(String(format: "%.2f", distance)) mi, \(Int(calories)) cal")
        
        resetWorkout()
    }
    
    // MARK: - Timer and Updates
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            
            self.elapsedTime += 1
            
            // Update calories every 10 seconds
            if Int(self.elapsedTime) % 10 == 0 {
                self.updateCaloriesFromTime()
            }
        }
    }
    
    // MARK: - HealthKit Integration (Simple Version)
    private func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable(),
              let healthManager = healthManager else { return }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthManager.healthStore, configuration: configuration)
            workoutSession?.startActivity(with: Date())
            print("✅ Started HealthKit workout session")
        } catch {
            print("❌ Failed to start workout session: \(error)")
        }
    }
    
    private func endWorkoutSession() {
        workoutSession?.end()
        workoutSession = nil
        print("⏹️ Ended HealthKit workout session")
    }
    
    private func saveWorkoutToHealth(startDate: Date, endDate: Date) {
        guard let healthManager = healthManager else { return }
        
        let builder = HKWorkoutBuilder(healthStore: healthManager.healthStore, configuration: HKWorkoutConfiguration(), device: .local())
        
        builder.beginCollection(withStart: startDate) { [weak self] success, error in
            guard let self = self, success else {
                print("❌ Failed to begin workout collection: \(error?.localizedDescription ?? "")")
                return
            }
            
            // Add distance sample
            if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                let distanceQuantity = HKQuantity(unit: HKUnit.mile(), doubleValue: self.distance)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: startDate,
                    end: endDate
                )
                builder.add([distanceSample]) { _, _ in }
            }
            
            // Add calorie sample
            if let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let calorieQuantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: self.calories)
                let calorieSample = HKQuantitySample(
                    type: calorieType,
                    quantity: calorieQuantity,
                    start: startDate,
                    end: endDate,
                    metadata: [
                        "RuckWeight": self.ruckWeight,
                        "AppName": "RuckTracker",
                        "GPS": self.locationManager.isTracking ? "Enabled" : "Disabled",
                        "Terrain": self.selectedTerrain.rawValue,
                        "AvgPace": self.currentPaceMinutesPerMile ?? 0,
                        "AvgHeartRate": self.currentHeartRate
                    ]
                )
                builder.add([calorieSample]) { _, _ in }
            }
            
            // End collection and finish workout
            builder.endCollection(withEnd: endDate) { success, error in
                if success {
                    builder.finishWorkout { workout, error in
                        if let workout = workout {
                            print("✅ Workout saved to HealthKit with enhanced metadata")
                        } else {
                            print("❌ Failed to save workout: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                } else {
                    print("❌ Failed to end collection: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
    
    // MARK: - Heart Rate Monitoring (Real Sensor Data)
    private func startHeartRateQuery() {
        print("DEBUG: startHeartRateQuery called")
        
        guard let healthManager = healthManager else {
            print("❌ Health manager not available")
            return
        }
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("❌ Heart rate type not available")
            return
        }
        
        // Check authorization status first
        let authStatus = healthManager.healthStore.authorizationStatus(for: heartRateType)
        print("💓 Heart rate authorization status: \(authStatus.rawValue)")
        
        if authStatus == .notDetermined {
            print("❌ Heart rate permission not determined - requesting...")
            healthManager.forcePermissionRequest()
            return
        } else if authStatus == .sharingDenied {
            print("❌ Heart rate permission denied")
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
            end: nil,
            options: .strictStartDate
        )
        
        heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            
            if let error = error {
                print("❌ Heart rate query error: \(error.localizedDescription)")
                return
            }
            
            guard let samples = samples as? [HKQuantitySample] else {
                print("❌ No heart rate samples received")
                return
            }
            
            print("💓 Received \(samples.count) heart rate samples")
            
            DispatchQueue.main.async {
                if let latestSample = samples.last {
                    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                    let heartRate = latestSample.quantity.doubleValue(for: heartRateUnit)
                    self?.currentHeartRate = heartRate
                    print("❤️ Real HR: \(Int(heartRate)) bpm")
                }
            }
        }
        
        heartRateQuery?.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            if let error = error {
                print("❌ Heart rate update error: \(error.localizedDescription)")
                return
            }
            
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            DispatchQueue.main.async {
                if let latestSample = samples.last {
                    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                    let heartRate = latestSample.quantity.doubleValue(for: heartRateUnit)
                    self?.currentHeartRate = heartRate
                    print("❤️ Updated HR: \(Int(heartRate)) bpm")
                }
            }
        }
        
        healthManager.healthStore.execute(heartRateQuery!)
        print("✅ Started real heart rate monitoring")
    }
    
    private func stopHeartRateQuery() {
        guard let healthManager = healthManager else { return }
        
        if let query = heartRateQuery {
            healthManager.healthStore.stop(query)
            heartRateQuery = nil
            print("⏹️ Stopped heart rate monitoring")
        }
    }
    
    // MARK: - Calorie Calculations
    private func updateCaloriesFromTime() {
        let newCalories = CalorieCalculator.calculateRuckingCalories(
            bodyWeightKg: userSettings.bodyWeightInKg,
            ruckWeightPounds: ruckWeight,
            timeMinutes: elapsedTime / 60.0,
            distanceMiles: distance,
            terrain: selectedTerrain
        )
        
        // Smooth calorie updates to avoid jumps
        calories = newCalories
        
        // Validate the calculation
        if !CalorieCalculator.validateCalculation(
            bodyWeightKg: userSettings.bodyWeightInKg,
            ruckWeightPounds: ruckWeight,
            timeMinutes: elapsedTime / 60.0,
            calculatedCalories: calories
        ) {
            print("Warning: Calorie calculation seems unreasonable")
        }
        
        lastCalorieUpdate = Date()
    }
    
    private func updateCaloriesFromDistance() {
        // Recalculate calories when distance updates (more accurate with GPS data)
        guard elapsedTime > 0 else { return }
        updateCaloriesFromTime()
    }
    
    // MARK: - Cleanup
    private func resetWorkout() {
        elapsedTime = 0
        distance = 0
        calories = 0
        totalCaloriesBurned = 0
        startDate = nil
        currentHeartRate = 120 // Reset to default until next workout starts
    }
    
    // MARK: - Debugging and Validation
    func getCalorieComparison() -> (ours: Double, appleEstimate: Double, difference: Double) {
        return CalorieCalculator.comparisonWithAppleWatch(
            bodyWeightKg: userSettings.bodyWeightInKg,
            ruckWeightPounds: ruckWeight,
            timeMinutes: elapsedTime / 60.0,
            distanceMiles: distance
        )
    }
    
    func getCurrentBurnRate() -> Double {
        return CalorieCalculator.calculateCurrentBurnRate(
            bodyWeightKg: userSettings.bodyWeightInKg,
            ruckWeightPounds: ruckWeight,
            currentPaceMinutesPerMile: currentPaceMinutesPerMile,
            terrain: selectedTerrain
        )
    }
}
