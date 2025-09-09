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
    @Published var isPaused = true
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
    
    // Workout session data
    private var startDate: Date?
    private var timer: Timer?
    private var workoutSession: HKWorkoutSession?
    private let healthStore = HKHealthStore()
    
    // Real-time metrics
    private var lastCalorieUpdate: Date = Date()
    private var totalCaloriesBurned: Double = 0
    
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
            self.updateHeartRate()
            
            // Update calories every 10 seconds or when distance changes significantly
            if Int(self.elapsedTime) % 10 == 0 {
                self.updateCaloriesFromTime()
            }
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
    
    // MARK: - Heart Rate Simulation
    private func updateHeartRate() {
        let baseRate: Double
        let bodyWeightPounds = userSettings.bodyWeightInKg * 2.20462
        let loadPercentage = ruckWeight / bodyWeightPounds
        
        // Base heart rate increases with load
        baseRate = 100 + (loadPercentage * 40) // Higher base rate with more relative weight
        
        // Pace influence on heart rate
        let paceInfluence: Double
        if let pace = currentPaceMinutesPerMile {
            switch pace {
            case 0..<15: paceInfluence = 25  // Fast pace
            case 15..<18: paceInfluence = 15 // Moderate pace
            case 18..<22: paceInfluence = 5  // Easy pace
            default: paceInfluence = 0       // Very easy
            }
        } else {
            paceInfluence = 10 // Default moderate effort
        }
        
        // Terrain influence
        let terrainInfluence = (selectedTerrain.multiplier - 1.0) * 20
        
        // Time-based adaptation (heart rate rises over time)
        let timeEffect = min(elapsedTime / 1800, 1.0) * 10 // Max 10 bpm increase over 30 minutes
        
        // Random variation
        let variability = Double.random(in: -5...5)
        
        let targetRate = baseRate + paceInfluence + terrainInfluence + timeEffect + variability
        currentHeartRate = max(90, min(targetRate, 180)) // Keep in reasonable range
    }
    
    // MARK: - HealthKit Integration
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
                "GPS": locationManager.isTracking ? "Enabled" : "Disabled",
                "Terrain": selectedTerrain.rawValue,
                "AvgPace": currentPaceMinutesPerMile ?? 0
            ]
        )
        
        healthStore.save(workout) { success, error in
            if success {
                print("✅ Workout saved to HealthKit with enhanced metadata")
            } else {
                print("❌ Failed to save workout: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    // MARK: - Cleanup
    private func resetWorkout() {
        elapsedTime = 0
        distance = 0
        calories = 0
        totalCaloriesBurned = 0
        startDate = nil
        currentHeartRate = 120
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
