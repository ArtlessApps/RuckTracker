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
    private var lastCalorieUpdate: TimeInterval = 0
    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    
    // HealthKit workout builder - using simpler HKWorkoutBuilder for iPhone
    private var workoutBuilder: HKWorkoutBuilder?
    
    // GPS backup tracking (in case HealthKit distance isn't available)
    private var startLocation: CLLocation?
    private var lastLocation: CLLocation?
    private var totalGPSDistance: Double = 0
    
    // Movement detection for calorie validation
    private var lastDistanceUpdateTime: Date?
    private var lastDistanceValue: Double = 0
    
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
        case 0..<14: return Color("PrimaryMain")   // Too fast
        case 14..<18: return Color("AccentGreen")   // Good pace
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
        
    }
    
    // MARK: - Workout Control (Full HealthKit + GPS Implementation)
    func startWorkout(weight: Double) {
        let startMsg = "\n🏋️‍♀️ ===== STARTING WORKOUT ====="
        print(startMsg)
        DebugLogger.shared.log(startMsg)
        
        let weightMsg = "🏋️‍♀️ Weight: \(weight) lbs"
        print(weightMsg)
        DebugLogger.shared.log(weightMsg)
        
        let callerMsg = "🏋️‍♀️ Called from: \(Thread.callStackSymbols[1])"
        print(callerMsg)
        DebugLogger.shared.log(callerMsg)
        
        ruckWeight = weight  // Set from parameter
        
        guard !isActive else { 
            let msg = "⚠️ Workout already active - ignoring start request"
            print(msg)
            DebugLogger.shared.log(msg)
            return 
        }
        
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
        
        // Reset movement detection
        lastDistanceUpdateTime = nil
        lastDistanceValue = 0
        
        let authMsg = "🏋️‍♀️ Location authorization status: \(locationAuthorizationStatus.rawValue)"
        print(authMsg)
        DebugLogger.shared.log(authMsg)
        
        // Request location permission if needed
        requestLocationPermissionIfNeeded()
        
        // Start location tracking
        let trackMsg = "🏋️‍♀️ Starting location tracking..."
        print(trackMsg)
        DebugLogger.shared.log(trackMsg)
        startLocationTracking()
        
        // Prepare HealthKit workout builder
        prepareHealthKitWorkout()
        
        // Start timer
        startTimer()
        
        let completeMsg = "🏋️‍♀️ ===== WORKOUT START COMPLETE =====\n"
        print(completeMsg)
        DebugLogger.shared.log(completeMsg)
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
        
    }
    
    func resumeWorkout() {
        guard isPaused else { return }
        
        isPaused = false
        
        // Resume location updates
        if locationAuthorizationStatus == .authorizedWhenInUse || locationAuthorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
        
    }
    
    func endWorkout() {
        // Update calories one final time before saving
        updateCalories()
        
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
        
        // Update UI state
        isActive = false
        isPaused = true
        
        // Save workout locally first to ensure data is not lost
        if let startDate = startDate {
            saveWorkoutToLocalStorage(startDate: startDate)
        }
        
        // Save HealthKit workout
        saveHealthKitWorkout()
        
        // Update program progress if user is in an active program
        Task {
            await updateProgramProgressIfActive()
        }
        
        
        // Show post-workout summary
        showingPostWorkoutSummary = true
        
        // Reset workout data (but keep final stats for summary)
        resetWorkoutData()
    }
    
    // MARK: - Timer
    private var lastCalorieUpdate: TimeInterval = 0
    
    private func startTimer() {
        // Stop any existing timer
        timer?.invalidate()
        
        // Reset calorie update tracker
        lastCalorieUpdate = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timerInstance in
            guard let self = self else {
                timerInstance.invalidate()
                return
            }
            
            if self.isActive && !self.isPaused {
                if let startDate = self.startDate {
                    self.elapsedTime = Date().timeIntervalSince(startDate)
                    
                    // Update calories every 5 seconds (more responsive for user)
                    let timeSinceLastCalorieUpdate = self.elapsedTime - self.lastCalorieUpdate
                    if timeSinceLastCalorieUpdate >= 5.0 {
                        self.updateCalories()
                        self.lastCalorieUpdate = self.elapsedTime
                        let msg = "🔥 Real-time calorie update: \(Int(self.calories)) cal"
                        print(msg)
                        DebugLogger.shared.log(msg)
                    }
                }
            }
            
            if !self.isActive {
                timerInstance.invalidate()
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
            break
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    private func hasBackgroundLocationCapability() -> Bool {
        guard let infoPlist = Bundle.main.infoDictionary,
              let backgroundModes = infoPlist["UIBackgroundModes"] as? [String] else {
            return false
        }
        return backgroundModes.contains("location")
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func startLocationTracking() {
        
        guard locationAuthorizationStatus == .authorizedWhenInUse || locationAuthorizationStatus == .authorizedAlways else {
            let msg = "⚠️ Cannot start location tracking - authorization status: \(locationAuthorizationStatus.rawValue)"
            print(msg)
            DebugLogger.shared.log(msg)
            return
        }
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // Update every 5 meters
        
        // CRITICAL: Enable background location updates to prevent GPS suspension
        // This allows continuous tracking even when screen is locked
        let hasCapability = hasBackgroundLocationCapability()
        let msg1 = "📍 Background location capability: \(hasCapability)"
        print(msg1)
        DebugLogger.shared.log(msg1)
        
        if hasCapability {
            locationManager.allowsBackgroundLocationUpdates = true
            let msg2 = "✅ Background location updates ENABLED"
            print(msg2)
            DebugLogger.shared.log(msg2)
        } else {
            let msg2 = "⚠️ Background location NOT configured in app - GPS will suspend when screen locks!"
            print(msg2)
            DebugLogger.shared.log(msg2)
        }
        
        locationManager.pausesLocationUpdatesAutomatically = false
        
        let msg3 = "📍 Starting continuous location updates..."
        print(msg3)
        DebugLogger.shared.log(msg3)
        
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
}

// MARK: - CLLocationManagerDelegate
extension WorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            
            guard let location = locations.last else {
                return
            }
            
            if self.isPaused {
                return
            }
            
            let age = abs(location.timestamp.timeIntervalSinceNow)
            let accuracy = location.horizontalAccuracy
            
            
            // Filter out old or inaccurate readings
            guard location.timestamp.timeIntervalSinceNow > -5.0,
                  location.horizontalAccuracy < 50.0 else {
                return
            }
            
            if self.startLocation == nil {
                self.startLocation = location
                self.lastLocation = location
                let msg = "📍 GPS: First location acquired | Accuracy: \(String(format: "%.1f", location.horizontalAccuracy))m"
                print(msg)
                DebugLogger.shared.log(msg)
                return
            }
            
            if let lastLoc = self.lastLocation {
                let distanceMeters = location.distance(from: lastLoc)
                
                if distanceMeters > 5.0 { // Only update for significant movement
                    self.totalGPSDistance += distanceMeters
                    let gpsDistanceMiles = self.totalGPSDistance * 0.000621371
                    
                    // Always update distance with GPS data (HealthKit doesn't auto-collect on iPhone)
                    self.distance = gpsDistanceMiles
                    
                    // Track when distance was last updated (for movement detection)
                    self.lastDistanceUpdateTime = Date()
                    self.lastDistanceValue = self.distance
                    
                    self.lastLocation = location
                    let msg = "📍 GPS update: +\(String(format: "%.1f", distanceMeters))m | Total: \(String(format: "%.3f", gpsDistanceMiles)) mi | Accuracy: \(String(format: "%.1f", location.horizontalAccuracy))m"
                    print(msg)
                    DebugLogger.shared.log(msg)
                } else {
                    let msg = "📍 GPS update: movement < 5m (ignored)"
                    print(msg)
                    DebugLogger.shared.log(msg)
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.locationAuthorizationStatus = status
            
            // If we just got authorized and workout is active, start GPS tracking now!
            if (status == .authorizedWhenInUse || status == .authorizedAlways) && self.isActive && !self.isPaused {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
                self.locationManager.distanceFilter = 5.0
                
                // Only set background location updates if the app has the capability
                if self.hasBackgroundLocationCapability() {
                    self.locationManager.allowsBackgroundLocationUpdates = true
                }
                
                self.locationManager.pausesLocationUpdatesAutomatically = false
                self.locationManager.startUpdatingLocation()
            }
        }
    }
    
    
    // MARK: - HealthKit Workout Builder Setup (Simple API for iPhone)
    private func prepareHealthKitWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else {
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
                    return
                }
                
                guard success else {
                    return
                }
                
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
                return
            }
            
            guard success else {
                return
            }
            
            workoutBuilder.finishWorkout { workout, error in
                if let error = error {
                } else if let workout = workout {
                    print("📊 Saved: \(String(format: "%.2f", self.distance)) mi, \(Int(self.calories)) cal")
                }
            }
        }
    }
    
    // MARK: - Calorie Calculation
    private func updateCalories() {
        guard elapsedTime > 0 else { return }
        
        // Check if we're actually moving or just forgot to stop the workout
        let isMoving = isUserMoving()
        
        if distance > 0.01 {
            // PRIMARY: Distance-based calculation (most accurate)
            calories = CalorieCalculator.calculateRuckingCalories(
                bodyWeightKg: userSettings.bodyWeightInKg,
                ruckWeightPounds: ruckWeight,
                timeMinutes: elapsedTime / 60.0,
                distanceMiles: distance
            )
            let msg = "📊 Calorie calc (GPS): \(Int(calories)) cal | \(String(format: "%.3f", distance)) mi | \(String(format: "%.1f", elapsedTime/60)) min"
            print(msg)
            DebugLogger.shared.log(msg)
            
        } else if isMoving {
            // FALLBACK: Time-based but only if recent movement detected
            // Use minimal calorie rate for stationary/slow movement
            calories = CalorieCalculator.calculateRuckingCalories(
                bodyWeightKg: userSettings.bodyWeightInKg,
                ruckWeightPounds: ruckWeight,
                timeMinutes: elapsedTime / 60.0,
                distanceMiles: 0.0  // Will use base MET for stationary
            )
            let msg = "📊 Calorie calc (stationary): \(Int(calories)) cal | No GPS | \(String(format: "%.1f", elapsedTime/60)) min | Movement detected"
            print(msg)
            DebugLogger.shared.log(msg)
            
        } else {
            // NO MOVEMENT: Minimal calories (standing with ruck weight only)
            // Only account for carrying the load, not walking
            let standingCaloriesPerMinute = userSettings.bodyWeightInKg * 1.5 / 60.0 // Very low MET
            calories = standingCaloriesPerMinute * (elapsedTime / 60.0)
            let msg = "⚠️ Calorie calc (no movement): \(Int(calories)) cal | No GPS | No movement for 2+ min"
            print(msg)
            DebugLogger.shared.log(msg)
        }
    }
    
    /// Detects if user is actually moving based on GPS data
    private func isUserMoving() -> Bool {
        // If we have recent distance updates (within last 2 minutes), user is moving
        if let lastUpdate = lastDistanceUpdateTime {
            let timeSinceLastMovement = Date().timeIntervalSince(lastUpdate)
            return timeSinceLastMovement < 120 // 2 minutes grace period
        }
        
        // If no distance data yet, assume moving for first 2 minutes (GPS acquisition time)
        return elapsedTime < 120
    }
    
    // MARK: - Local Data Storage
    private func saveWorkoutToLocalStorage(startDate: Date) {
        print("\n🟣 ===== WORKOUT MANAGER: SAVING WORKOUT =====")
        print("🟣 Start Date: \(startDate)")
        print("🟣 Elapsed Time: \(Int(elapsedTime))s")
        print("🟣 Distance: \(String(format: "%.2f", distance))mi")
        print("🟣 Calories: \(Int(calories))")
        print("🟣 Ruck Weight: \(Int(ruckWeight))lbs")
        
        // Use actual heart rate if available, otherwise 0 (will show as N/A)
        let avgHeartRate = currentHeartRate > 0 ? currentHeartRate : 0
        print("🟣 Heart Rate: \(Int(avgHeartRate)) bpm")
        
        // Check if currently enrolled in a program
        let programId = LocalProgramService.shared.getEnrolledProgramId()
        let programWorkoutDay = calculateCurrentProgramWorkoutDay()
        print("🟣 Enrolled Program ID: \(programId?.uuidString ?? "NONE")")
        print("🟣 Program Workout Day: \(programWorkoutDay?.description ?? "NONE")")
        
        // Check if currently enrolled in a challenge
        let challengeId = LocalChallengeService.shared.getEnrolledChallengeId()
        let challengeWorkoutDay = calculateCurrentChallengeWorkoutDay()
        print("🟣 Enrolled Challenge ID: \(challengeId?.uuidString ?? "NONE")")
        print("🟣 Challenge Workout Day: \(challengeWorkoutDay?.description ?? "NONE")")
        
        // Save to CoreData with program and challenge metadata
        print("🟣 About to call WorkoutDataManager.saveWorkout()...")
        WorkoutDataManager.shared.saveWorkout(
            date: startDate,
            duration: elapsedTime,
            distance: distance,
            calories: calories,
            ruckWeight: ruckWeight,
            heartRate: avgHeartRate,
            programId: programId,
            programWorkoutDay: programWorkoutDay,
            challengeId: challengeId,
            challengeDay: challengeWorkoutDay
        )
        print("🟣 WorkoutDataManager.saveWorkout() completed")
        
        // If this was a program workout, update progress
        if let programId = programId, let day = programWorkoutDay {
            print("🟣 This was a program workout - refreshing progress...")
            // Workout is already saved with program metadata above
            // Just need to refresh the program progress
            Task { @MainActor in
                LocalProgramService.shared.refreshProgramProgress()
            }
            print("🟣 Program progress refresh initiated for day \(day)")
        } else {
            print("🟣 This was NOT a program workout (standalone workout)")
        }
        
        // If this was a challenge workout, mark it complete
        if let challengeId = challengeId, let day = challengeWorkoutDay {
            print("🟣 This was a challenge workout - marking complete...")
            LocalChallengeService.shared.completeWorkout(
                challengeId: challengeId,
                workoutDay: day,
                distanceMiles: distance,
                weightLbs: ruckWeight,
                durationMinutes: Int(elapsedTime / 60)
            )
            print("🟣 Challenge workout completion initiated")
        }
        
        print("🟣 ===== WORKOUT MANAGER: SAVE COMPLETE =====\n")
    }
    
    private func calculateCurrentProgramWorkoutDay() -> Int? {
        // Get the next workout day from program progress
        guard let progress = LocalProgramService.shared.programProgress else {
            print("🟣 calculateCurrentProgramWorkoutDay: No program progress found")
            return nil
        }
        let nextDay = progress.completed + 1
        print("🟣 calculateCurrentProgramWorkoutDay: Completed=\(progress.completed), NextDay=\(nextDay)")
        return nextDay
    }
    
    private func calculateCurrentChallengeWorkoutDay() -> Int? {
        // Get the next workout day from challenge progress
        guard let progress = LocalChallengeService.shared.challengeProgress else {
            return nil
        }
        return progress.completed + 1
    }
    
    // MARK: - Program Progress Tracking
    private func updateProgramProgressIfActive() async {
        // Program completion is now handled in saveWorkoutToLocalStorage()
        // This method is kept for potential future use but currently does nothing
        // to avoid duplicate program completion calls
        
        print("📱 Program progress already updated in saveWorkoutToLocalStorage()")
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
        lastCalorieUpdate = 0
        
        // Reset location tracking
        startLocation = nil
        lastLocation = nil
        
        // Reset movement detection
        lastDistanceUpdateTime = nil
        lastDistanceValue = 0
        
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
        lastCalorieUpdate = 0
        
        // Reset location tracking
        startLocation = nil
        lastLocation = nil
        
        // Reset movement detection
        lastDistanceUpdateTime = nil
        lastDistanceValue = 0
        
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
