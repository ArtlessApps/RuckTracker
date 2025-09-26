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

class WorkoutManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Published Properties
    @Published var isActive = false
    @Published var isPaused = false
    @Published var ruckWeight: Double = 20.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0
    @Published var calories: Double = 0
    @Published var currentHeartRate: Double = 0
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Settings
    private let userSettings = UserSettings.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Location and workout session data
    private var startDate: Date?
    private var timer: Timer?
    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    
    // HealthKit workout builder for saving workouts
    private var workoutBuilder: HKWorkoutBuilder?
    
    // Location tracking
    private var startLocation: CLLocation?
    private var lastLocation: CLLocation?
    private var totalDistance: Double = 0
    
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
        totalDistance = 0
        calories = 0
        currentHeartRate = 0
        
        // Reset location tracking
        startLocation = nil
        lastLocation = nil
        
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
        
        // Note: Basic workout builder doesn't need pausing
        
        print("📱 Phone: Workout paused")
    }
    
    func resumeWorkout() {
        guard isPaused else { return }
        
        isPaused = false
        
        // Resume location updates
        if locationAuthorizationStatus == .authorizedWhenInUse || locationAuthorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
        
        // Note: Basic workout builder doesn't need resuming
        
        print("📱 Phone: Workout resumed")
    }
    
    func endWorkout() {
        print("🏁 Phone: Ending workout...")
        
        // Stop timer first
        timer?.invalidate()
        timer = nil
        
        // Stop location tracking
        locationManager.stopUpdatingLocation()
        
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
        resetWorkout()
    }
    
    // MARK: - Timer
    private func startTimer() {
        // Stop any existing timer
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            
            if isActive && !isPaused {
                if let startDate = startDate {
                    elapsedTime = Date().timeIntervalSince(startDate)
                    
                    // Update calories every 10 seconds
                    if Int(elapsedTime) % 10 == 0 {
                        updateCalories()
                    }
                }
            }
            
            if !isActive {
                timer.invalidate()
                self.timer = nil
            }
        }
    }
    
    // MARK: - Location Management
    private func requestLocationPermissionIfNeeded() {
        switch locationAuthorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("⚠️ Location access denied - workout will use HealthKit data only")
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location access granted")
        @unknown default:
            break
        }
    }
    
    private func startLocationTracking() {
        guard locationAuthorizationStatus == .authorizedWhenInUse || locationAuthorizationStatus == .authorizedAlways else {
            print("⚠️ Location not authorized - using HealthKit motion data only")
            return
        }
        
        locationManager.startUpdatingLocation()
        print("📍 Started GPS tracking")
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, !isPaused else { return }
        
        // Filter out old or inaccurate readings
        guard location.timestamp.timeIntervalSinceNow > -5.0,
              location.horizontalAccuracy < 50.0 else { return }
        
        if startLocation == nil {
            startLocation = location
            lastLocation = location
            return
        }
        
        if let lastLoc = lastLocation {
            let distanceMeters = location.distance(from: lastLoc)
            if distanceMeters > 5.0 { // Only update for significant movement
                totalDistance += distanceMeters
                distance = totalDistance * 0.000621371 // Convert to miles
                lastLocation = location
                
                print("📍 GPS Distance: \(String(format: "%.3f", distance)) mi")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.locationAuthorizationStatus = status
            print("📍 Location authorization changed to: \(status)")
        }
    }
    
    // MARK: - HealthKit Workout Preparation
    private func prepareHealthKitWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available")
            return
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .hiking
        configuration.locationType = .outdoor
        
        workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        print("✅ HealthKit workout builder prepared")
    }
    
    private func saveHealthKitWorkout() {
        guard let workoutBuilder = workoutBuilder,
              let startDate = startDate else {
            print("❌ No workout builder or start date available")
            return
        }
        
        let endDate = Date()
        
        workoutBuilder.beginCollection(withStart: startDate) { [weak self] success, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to begin HealthKit collection: \(error.localizedDescription)")
                return
            }
            
            guard success else {
                print("❌ Failed to begin HealthKit collection")
                return
            }
            
            // Add distance sample if we have GPS data
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
                    end: endDate,
                    metadata: [
                        "RuckWeight": ruckWeight,
                        "AppName": "RuckTracker-iPhone",
                        "TrackingMethod": locationAuthorizationStatus == .authorizedWhenInUse ? "GPS" : "Motion",
                        "Distance": distance
                    ]
                )
                workoutBuilder.add([calorieSample]) { _, _ in }
            }
            
            // End collection and finish workout
            workoutBuilder.endCollection(withEnd: endDate) { success, error in
                if let error = error {
                    print("❌ Failed to end HealthKit collection: \(error.localizedDescription)")
                    return
                }
                
                guard success else {
                    print("❌ HealthKit collection unsuccessful")
                    return
                }
                
                workoutBuilder.finishWorkout { workout, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ Failed to save HealthKit workout: \(error.localizedDescription)")
                        } else if let workout = workout {
                            print("✅ Workout saved to HealthKit from iPhone")
                            print("📊 Saved: \(String(format: "%.2f", self.distance)) mi, \(Int(self.calories)) cal")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Calorie Calculation
    private func updateCalories() {
        // Only calculate calories if we have meaningful distance or are moving
        if distance > 0.01 { // At least 50+ feet of movement
            calories = CalorieCalculator.calculateRuckingCalories(
                bodyWeightKg: userSettings.bodyWeightInKg,
                ruckWeightPounds: ruckWeight,
                timeMinutes: elapsedTime / 60.0,
                distanceMiles: distance
            )
        } else {
            // No meaningful movement = minimal calories (just basic metabolism)
            let timeHours = elapsedTime / 3600.0
            calories = userSettings.bodyWeightInKg * 1.2 * timeHours // Resting metabolic rate
            print("📊 No movement detected - using resting calories: \(Int(calories))")
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
    
    
    // MARK: - Cleanup
    private func resetWorkout() {
        elapsedTime = 0
        distance = 0
        totalDistance = 0
        calories = 0
        startDate = nil
        currentHeartRate = 0
        
        // Reset location tracking
        startLocation = nil
        lastLocation = nil
        
        // Clean up HealthKit objects
        workoutBuilder = nil
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
