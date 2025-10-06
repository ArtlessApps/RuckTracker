//
//  WorkoutManager.swift
//  RuckTracker (iPhone)
//
//  Created by Nick on 9/6/25.
//

import Foundation
import Combine
import SwiftUI
import HealthKit
import CoreData
import CoreLocation

@MainActor
class WorkoutManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isActive = false
    @Published var isPaused = false
    @Published var ruckWeight: Double = 20.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0
    @Published var calories: Double = 0
    @Published var currentHeartRate: Double = 0
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Post-workout summary state
    @Published var showingPostWorkoutSummary = false
    @Published var finalElapsedTime: TimeInterval = 0
    @Published var finalDistance: Double = 0
    @Published var finalCalories: Double = 0
    @Published var finalRuckWeight: Double = 0
    
    // Settings
    private let userSettings = UserSettings.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Location and workout session data
    private var startDate: Date?
    private var timer: Timer?
    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    
    // HealthKit workout builder - using simpler HKWorkoutBuilder for iPhone
    private var workoutBuilder: HKWorkoutBuilder?
    
    // GPS backup tracking (in case HealthKit distance isn't available)
    private var startLocation: CLLocation?
    private var lastLocation: CLLocation?
    private var totalGPSDistance: Double = 0
    
    // MARK: - Computed Properties
    var hours: Int { Int(elapsedTime) / 3600 }
    var minutes: Int { (Int(elapsedTime) % 3600) / 60 }
    var seconds: Int { Int(elapsedTime) % 60 }
    var heartRate: Double { currentHeartRate }
    
    var formattedHeartRate: String {
        return currentHeartRate > 0 ? "\(Int(currentHeartRate))" : "N/A"
    }
    
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
        return elapsedTime / (distance * 60)
    }
    
    var formattedPace: String {
        guard let pace = currentPaceMinutesPerMile else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var paceColor: Color {
        guard let pace = currentPaceMinutesPerMile else { return .gray }
        
        switch pace {
        case 0..<14: return .orange   // Too fast
        case 14..<18: return .green   // Good pace
        case 18..<25: return .yellow  // Acceptable
        default: return .red          // Too slow
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
        setupUserSettings()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // Update every 5 meters
        locationAuthorizationStatus = locationManager.authorizationStatus
    }
    
    // Allow delegate assignment despite main actor isolation
    nonisolated func setLocationManagerDelegate() {
        Task { @MainActor in
            locationManager.delegate = self
        }
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
    
    // MARK: - Workout Control (Full HealthKit + GPS Implementation)
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
        totalGPSDistance = 0
        calories = 0
        currentHeartRate = 0
        
        // Reset location tracking
        startLocation = nil
        lastLocation = nil
        
        print("🏁 ========== WORKOUT STARTING ==========")
        print("🏁 Weight: \(weight) lbs")
        print("🏁 Location auth status: \(locationAuthorizationStatus)")
        print("🏁 HealthKit available: \(HKHealthStore.isHealthDataAvailable())")
        
        // Request location permission if needed
        requestLocationPermissionIfNeeded()
        
        // Start location tracking
        startLocationTracking()
        
        // Prepare HealthKit workout builder
        prepareHealthKitWorkout()
        
        // Start timer
        startTimer()
        
        print("📱 Phone: Started full workout with \(weight) lbs - GPS + HealthKit")
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
        guard !isPaused else { return }
        
        isPaused = true
        
        // Pause location updates
        locationManager.stopUpdatingLocation()
        
        print("📱 iPhone: Workout paused")
    }
    
    func resumeWorkout() {
        guard isPaused else { return }
        
        isPaused = false
        
        // Resume location updates
        if locationAuthorizationStatus == .authorizedWhenInUse || locationAuthorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
        
        print("📱 iPhone: Workout resumed")
    }
    
    func endWorkout() {
        print("🏁 ========== ENDING WORKOUT ==========")
        print("🏁 Final Stats:")
        print("🏁   Distance: \(String(format: "%.3f", distance)) mi")
        print("🏁   GPS Total Distance (backup): \(String(format: "%.3f", totalGPSDistance * 0.000621371)) mi")
        print("🏁   Duration: \(formattedElapsedTime)")
        print("🏁   Calories: \(Int(calories))")
        
        // Capture final stats before resetting
        finalElapsedTime = elapsedTime
        finalDistance = distance
        finalCalories = calories
        finalRuckWeight = ruckWeight
        
        // Stop timer first
        timer?.invalidate()
        timer = nil
        
        // Stop location tracking
        locationManager.stopUpdatingLocation()
        print("🏁 Stopped location tracking")
        
        // Update UI state
        isActive = false
        isPaused = true
        
        // Save workout locally first to ensure data is not lost
        if let startDate = startDate {
            saveWorkoutToLocalStorage(startDate: startDate)
        }
        
        // Save HealthKit workout
        saveHealthKitWorkout()
        
        print("📱 Phone: Workout ended - \(formattedElapsedTime)")
        
        // Show post-workout summary
        showingPostWorkoutSummary = true
        
        // Reset workout data (but keep final stats for summary)
        resetWorkoutData()
    }
    
    // MARK: - Timer
    private func startTimer() {
        // Stop any existing timer
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timerInstance in
            guard let self = self else {
                timerInstance.invalidate()
                return
            }
            
            Task { @MainActor in
                if self.isActive && !self.isPaused {
                    if let startDate = self.startDate {
                        self.elapsedTime = Date().timeIntervalSince(startDate)
                        
                        // Update calories every 10 seconds
                        if Int(self.elapsedTime) % 10 == 0 {
                            self.updateCalories()
                        }
                    }
                }
                
                if !self.isActive {
                    timerInstance.invalidate()
                    self.timer = nil
                }
            }
        }
    }
    
    // MARK: - Location Management
    private func requestLocationPermissionIfNeeded() {
        print("📍 Checking location permission... Current status: \(locationAuthorizationStatus)")
        
        switch locationAuthorizationStatus {
        case .notDetermined:
            print("📍 🔔 Requesting location permission from user...")
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("⚠️ ❌ Location access denied/restricted - workout will use HealthKit data only")
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location access already granted")
        @unknown default:
            print("⚠️ Unknown location authorization status")
            break
        }
    }
    
    private func startLocationTracking() {
        print("📍 Attempting to start location tracking...")
        print("📍 Current auth status: \(locationAuthorizationStatus)")
        
        guard locationAuthorizationStatus == .authorizedWhenInUse || locationAuthorizationStatus == .authorizedAlways else {
            print("⚠️ ❌ Location not authorized - using HealthKit motion data only")
            print("⚠️ Status is: \(locationAuthorizationStatus.rawValue)")
            return
        }
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // Update every 5 meters
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = false
        
        locationManager.startUpdatingLocation()
        print("📍 ✅ GPS tracking started with desiredAccuracy=Best, distanceFilter=5m")
    }
    
    // MARK: - CLLocationManagerDelegate
}

// MARK: - CLLocationManagerDelegate
extension WorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            print("📍 Location update received - count: \(locations.count)")
            
            guard let location = locations.last else {
                print("📍 ❌ No location in array")
                return
            }
            
            if self.isPaused {
                print("📍 ⏸️ Ignoring - workout is paused")
                return
            }
            
            let age = abs(location.timestamp.timeIntervalSinceNow)
            let accuracy = location.horizontalAccuracy
            
            print("📍 Location: age=\(String(format: "%.1f", age))s, accuracy=\(String(format: "%.1f", accuracy))m")
            
            // Filter out old or inaccurate readings
            guard location.timestamp.timeIntervalSinceNow > -5.0,
                  location.horizontalAccuracy < 50.0 else {
                print("📍 ❌ Location filtered out (age: \(String(format: "%.1f", age))s, accuracy: \(String(format: "%.1f", accuracy))m)")
                return
            }
            
            if self.startLocation == nil {
                self.startLocation = location
                self.lastLocation = location
                print("📍 ✅ Starting location set")
                return
            }
            
            if let lastLoc = self.lastLocation {
                let distanceMeters = location.distance(from: lastLoc)
                print("📍 Distance from last: \(String(format: "%.1f", distanceMeters))m")
                
                if distanceMeters > 5.0 { // Only update for significant movement
                    self.totalGPSDistance += distanceMeters
                    let gpsDistanceMiles = self.totalGPSDistance * 0.000621371
                    
                    // Always update distance with GPS data (HealthKit doesn't auto-collect on iPhone)
                    self.distance = gpsDistanceMiles
                    print("📍 GPS Distance: \(String(format: "%.3f", gpsDistanceMiles)) mi")
                    
                    self.lastLocation = location
                } else {
                    print("📍 ⏭️ Movement too small (<5m), not counting")
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ Location error: \(error.localizedDescription)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.locationAuthorizationStatus = status
            print("📍 Location authorization changed to: \(status)")
            
            // If we just got authorized and workout is active, start GPS tracking now!
            if (status == .authorizedWhenInUse || status == .authorizedAlways) && self.isActive && !self.isPaused {
                print("📍 ✅ Authorization granted during active workout - starting GPS tracking now!")
                self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
                self.locationManager.distanceFilter = 5.0
                self.locationManager.allowsBackgroundLocationUpdates = false
                self.locationManager.pausesLocationUpdatesAutomatically = false
                self.locationManager.startUpdatingLocation()
            }
        }
    }
    
    
    // MARK: - HealthKit Workout Builder Setup (Simple API for iPhone)
    private func prepareHealthKitWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available on this device")
            return
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .hiking
        configuration.locationType = .outdoor
        
        workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        // Start collecting data - FIX: Only call beginCollection ONCE at the start
        if let startDate = startDate {
            workoutBuilder?.beginCollection(withStart: startDate) { [weak self] success, error in
                if let error = error {
                    print("❌ Failed to begin HealthKit collection: \(error.localizedDescription)")
                    return
                }
                
                guard success else {
                    print("❌ Failed to begin HealthKit collection")
                    return
                }
                
                print("✅ HealthKit workout builder started collecting data")
            }
        }
    }
    
    
    private func adjustCaloriesForRuckWeight(baseCalories: Double) -> Double {
        // Apple gives us base walking calories
        // Add extra load from ruck weight
        guard ruckWeight > 0 else { return baseCalories }
        
        // Calculate multiplier based on ruck weight
        // Research shows ruck adds ~10% calories per 10 lbs
        let weightMultiplier = 1.0 + (ruckWeight / 100.0)
        return baseCalories * weightMultiplier
    }
    
    private func saveHealthKitWorkout() {
        guard let workoutBuilder = workoutBuilder,
              let startDate = startDate else {
            print("❌ No workout builder or start date available")
            return
        }
        
        let endDate = Date()
        
        // Add final distance sample if we have GPS data
        if distance > 0, let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            let distanceQuantity = HKQuantity(unit: .mile(), doubleValue: distance)
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: distanceQuantity,
                start: startDate,
                end: endDate
            )
            workoutBuilder.add([distanceSample]) { _, _ in }
        }
        
        // Add calorie sample
        if calories > 0, let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            let calorieSample = HKQuantitySample(
                type: calorieType,
                quantity: calorieQuantity,
                start: startDate,
                end: endDate
            )
            workoutBuilder.add([calorieSample]) { _, _ in }
        }
        
        // End collection and finish workout
        workoutBuilder.endCollection(withEnd: endDate) { [weak self] success, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to end HealthKit collection: \(error.localizedDescription)")
                return
            }
            
            guard success else {
                print("❌ HealthKit collection unsuccessful")
                return
            }
            
            workoutBuilder.finishWorkout { workout, error in
                if let error = error {
                    print("❌ Failed to save HealthKit workout: \(error.localizedDescription)")
                } else if let workout = workout {
                    print("✅ Workout saved to HealthKit from iPhone")
                    print("📊 Saved: \(String(format: "%.2f", self.distance)) mi, \(Int(self.calories)) cal")
                }
            }
        }
    }
    
    // MARK: - Calorie Calculation
    private func updateCalories() {
        // Calculate calories based on distance and ruck weight
        if distance > 0.01 {
            calories = CalorieCalculator.calculateRuckingCalories(
                bodyWeightKg: userSettings.bodyWeightInKg,
                ruckWeightPounds: ruckWeight,
                timeMinutes: elapsedTime / 60.0,
                distanceMiles: distance
            )
            print("📊 Using fallback calorie calculation: \(Int(calories))")
        }
    }
    
    // MARK: - Local Data Storage
    private func saveWorkoutToLocalStorage(startDate: Date) {
        // Use actual heart rate if available, otherwise 0 (will show as N/A)
        let avgHeartRate = currentHeartRate > 0 ? currentHeartRate : 0
        
        // Save to CoreData
        WorkoutDataManager.shared.saveWorkout(
            date: startDate,
            duration: elapsedTime,
            distance: distance,
            calories: calories,
            ruckWeight: ruckWeight,
            heartRate: avgHeartRate
        )
        
        print("💾 iPhone: Saved workout to local storage")
        
        // Update leaderboards after successful save
        updateLeaderboardsAfterSave()
    }
    
    
    // MARK: - Post-Workout Summary
    func dismissPostWorkoutSummary() {
        showingPostWorkoutSummary = false
        resetWorkout()
    }
    
    // MARK: - Cleanup
    private func resetWorkoutData() {
        elapsedTime = 0
        distance = 0
        totalGPSDistance = 0
        calories = 0
        startDate = nil
        currentHeartRate = 0
        
        // Reset location tracking
        startLocation = nil
        lastLocation = nil
        
        // Clean up HealthKit objects
        workoutBuilder = nil
    }
    
    private func resetWorkout() {
        elapsedTime = 0
        distance = 0
        totalGPSDistance = 0
        calories = 0
        startDate = nil
        currentHeartRate = 0
        
        // Reset location tracking
        startLocation = nil
        lastLocation = nil
        
        // Clean up HealthKit objects
        workoutBuilder = nil
        
        // Reset post-workout summary state
        showingPostWorkoutSummary = false
        finalElapsedTime = 0
        finalDistance = 0
        finalCalories = 0
        finalRuckWeight = 0
    }
    
    // MARK: - Utility
    func getCalorieComparison() -> (ours: Double, appleEstimate: Double, difference: Double) {
        return CalorieCalculator.comparisonWithAppleWatch(
            bodyWeightKg: userSettings.bodyWeightInKg,
            ruckWeightPounds: ruckWeight,
            timeMinutes: elapsedTime / 60.0,
            distanceMiles: distance
        )
    }
}
