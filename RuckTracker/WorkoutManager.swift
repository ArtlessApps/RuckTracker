//
//  WorkoutManager.swift
//  RuckTracker (iPhone)
//
//  Uses HKWorkoutSession + HKLiveWorkoutBuilder for Apple's sensor-fused
//  distance, calorie, and heart-rate calculations — the same architecture
//  as the Watch app. CLLocationManager is retained as a fallback GPS source
//  and for future route display. CMAltimeter provides barometric elevation.
//

import Foundation
import Combine
import SwiftUI
import HealthKit
import CoreData
import CoreLocation
import CoreMotion

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
    @Published var elevationGain: Double = 0 // Total elevation gain in feet
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Post-workout summary state
    @Published var showingPostWorkoutSummary = false
    @Published var finalElapsedTime: TimeInterval = 0
    @Published var finalDistance: Double = 0
    @Published var finalCalories: Double = 0
    @Published var finalRuckWeight: Double = 0
    @Published var finalElevationGain: Double = 0
    
    // MARK: - Private Properties
    
    // Settings
    private let userSettings = UserSettings.shared
    private var cancellables = Set<AnyCancellable>()
    
    // HealthKit workout session (Apple's sensor-fused tracking)
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var healthKitProvidingDistance = false
    private var healthKitProvidingCalories = false
    
    // Location manager (backup GPS + future route tracking)
    private let locationManager = CLLocationManager()
    private var startLocation: CLLocation?
    private var lastLocation: CLLocation?
    private var totalGPSDistance: Double = 0
    
    // Barometric altimeter for precise elevation tracking
    private let altimeter = CMAltimeter()
    private var lastAltitude: Double?
    private var totalElevationGainMeters: Double = 0
    private let altitudeFilterThreshold: Double = 1.0 // meters
    
    // Timer
    private var startDate: Date?
    private var timer: Timer?
    
    // Optional override to tag the next workout with specific program context
    private var overrideProgramContext: (programId: UUID, day: Int)?
    
    // Movement detection for fallback calorie validation
    private var lastDistanceUpdateTime: Date?
    private var lastDistanceValue: Double = 0
    private var lastCalorieUpdate: TimeInterval = 0
    
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
        return (elapsedTime / 60.0) / distance // minutes per mile
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
        case 0..<14: return Color("PrimaryMain")   // Fast
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
        locationManager.distanceFilter = 5.0
        locationAuthorizationStatus = locationManager.authorizationStatus
    }
    
    // Allow delegate assignment despite main actor isolation
    nonisolated func setLocationManagerDelegate() {
        Task { @MainActor in
            locationManager.delegate = self
        }
    }
    
    private func setupUserSettings() {
        ruckWeight = userSettings.defaultRuckWeightInPounds()
    }
    
    // MARK: - Workout Control
    func startWorkout(weight: Double) {
        let startMsg = "\n🏋️‍♀️ ===== STARTING WORKOUT (HKWorkoutSession) ====="
        print(startMsg)
        DebugLogger.shared.log(startMsg)
        
        let weightMsg = "🏋️‍♀️ Weight: \(weight) lbs"
        print(weightMsg)
        DebugLogger.shared.log(weightMsg)
        
        ruckWeight = weight
        
        guard !isActive else {
            let msg = "⚠️ Workout already active - ignoring start request"
            print(msg)
            DebugLogger.shared.log(msg)
            return
        }
        
        // 1. Immediate UI response
        isActive = true
        isPaused = false
        startDate = Date()
        elapsedTime = 0
        distance = 0
        totalGPSDistance = 0
        calories = 0
        currentHeartRate = 0
        elevationGain = 0
        totalElevationGainMeters = 0
        healthKitProvidingDistance = false
        healthKitProvidingCalories = false
        lastCalorieUpdate = 0
        
        // Reset location tracking
        startLocation = nil
        lastLocation = nil
        lastAltitude = nil
        
        // Reset movement detection
        lastDistanceUpdateTime = nil
        lastDistanceValue = 0
        
        // Start timer immediately for instant UI feedback
        startTimer()
        
        // Request location permission if needed
        requestLocationPermissionIfNeeded()
        
        // Start backup GPS tracking
        let trackMsg = "📍 Starting backup GPS tracking..."
        print(trackMsg)
        DebugLogger.shared.log(trackMsg)
        startLocationTracking()
        
        // Start barometric altimeter for elevation
        startAltimeterTracking()
        
        // 2. Start HKWorkoutSession (may take 1-2 seconds to initialize)
        startWorkoutSession()
        
        let completeMsg = "🏋️‍♀️ ===== WORKOUT START COMPLETE =====\n"
        print(completeMsg)
        DebugLogger.shared.log(completeMsg)
    }
    
    /// Set program context for the next workout save (used when starting from a plan row)
    func setProgramContext(programId: UUID?, day: Int?) {
        if let programId, let day {
            overrideProgramContext = (programId, day)
        } else {
            overrideProgramContext = nil
        }
    }
    
    func togglePause() {
        if isPaused {
            resumeWorkout()
        } else {
            pauseWorkout()
        }
    }
    
    func pauseWorkout() {
        guard !isPaused else { return }
        
        isPaused = true
        session?.pause()
        locationManager.stopUpdatingLocation()
        
        let msg = "⏸️ Workout paused"
        print(msg)
        DebugLogger.shared.log(msg)
    }
    
    func resumeWorkout() {
        guard isPaused else { return }
        
        isPaused = false
        session?.resume()
        
        if locationAuthorizationStatus == .authorizedWhenInUse || locationAuthorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
        
        let msg = "▶️ Workout resumed"
        print(msg)
        DebugLogger.shared.log(msg)
    }
    
    func endWorkout() {
        // Stop altimeter tracking
        stopAltimeterTracking()
        
        // Use fallback calorie calculation if needed before saving final stats
        updateCaloriesWithFallback()
        
        // Capture final stats before resetting
        finalElapsedTime = elapsedTime
        finalDistance = distance
        finalCalories = calories
        finalRuckWeight = ruckWeight
        finalElevationGain = elevationGain
        
        let statsMsg = "📊 Final stats: \(String(format: "%.2f", distance)) mi, \(Int(calories)) cal, \(Int(elevationGain)) ft elev"
        print(statsMsg)
        DebugLogger.shared.log(statsMsg)
        
        // Stop timer
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
        
        // End HKWorkoutSession in background (async — don't block UI)
        endHealthKitSession()
        
        // Update program progress if active
        Task {
            await updateProgramProgressIfActive()
        }
        
        // Show post-workout summary immediately
        showingPostWorkoutSummary = true
        
        // Reset workout data (final* properties are preserved for summary)
        resetWorkoutData()
    }
    
    // MARK: - HKWorkoutSession Setup
    private func startWorkoutSession() {
        // Defensive cleanup — prevent duplicate sessions
        if session != nil || builder != nil {
            let msg = "⚠️ Found existing workout session/builder - cleaning up before starting"
            print(msg)
            DebugLogger.shared.log(msg)
            session?.end()
            session = nil
            builder = nil
        }
        
        guard HKHealthStore.isHealthDataAvailable() else {
            let msg = "⚠️ HealthKit not available - using GPS-only mode"
            print(msg)
            DebugLogger.shared.log(msg)
            return
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .hiking  // Best match for rucking intensity
        configuration.locationType = .outdoor
        
        do {
            // Create session and get the associated live workout builder
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            
            guard let builder = builder else {
                let msg = "❌ Failed to create HKLiveWorkoutBuilder - using GPS-only mode"
                print(msg)
                DebugLogger.shared.log(msg)
                return
            }
            
            // Set delegates
            session?.delegate = self
            builder.delegate = self
            
            // HKLiveWorkoutDataSource automatically collects distance, calories, heart rate
            // from the iPhone's sensors (GPS + pedometer + motion coprocessor)
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // Start the workout session and begin data collection
            let workoutStartDate = startDate ?? Date()
            session?.startActivity(with: workoutStartDate)
            builder.beginCollection(withStart: workoutStartDate) { [weak self] success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        let msg = "❌ HKWorkoutSession collection failed: \(error.localizedDescription) - using GPS fallback"
                        print(msg)
                        DebugLogger.shared.log(msg)
                    } else if success {
                        let msg = "✅ HKWorkoutSession active — Apple sensor fusion providing distance/calories"
                        print(msg)
                        DebugLogger.shared.log(msg)
                    }
                }
            }
            
        } catch {
            let msg = "❌ Failed to create HKWorkoutSession: \(error.localizedDescription) - using GPS-only mode"
            print(msg)
            DebugLogger.shared.log(msg)
        }
    }
    
    /// End the HealthKit session and finalize the workout (async, non-blocking)
    private func endHealthKitSession() {
        // Capture strong references before resetWorkoutData() nils them
        guard let builder = self.builder, let session = self.session else { return }
        
        builder.endCollection(withEnd: Date()) { success, error in
            if let error = error {
                print("❌ HealthKit collection end failed: \(error.localizedDescription)")
                session.end()
                return
            }
            
            guard success else {
                print("❌ HealthKit collection end unsuccessful")
                session.end()
                return
            }
            
            builder.finishWorkout { workout, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ HealthKit finish failed: \(error.localizedDescription)")
                    } else if let workout = workout {
                        if let dist = workout.totalDistance?.doubleValue(for: .mile()) {
                            print("✅ HealthKit workout saved: \(String(format: "%.2f", dist)) mi")
                        } else {
                            print("✅ HealthKit workout saved")
                        }
                    }
                    session.end()
                }
            }
        }
    }
    
    // MARK: - Timer
    private func startTimer() {
        timer?.invalidate()
        lastCalorieUpdate = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timerInstance in
            guard let self = self else {
                timerInstance.invalidate()
                return
            }
            
            if self.isActive && !self.isPaused {
                if let startDate = self.startDate {
                    self.elapsedTime = Date().timeIntervalSince(startDate)
                    
                    // Fallback calorie updates every 5 seconds (only when HealthKit isn't providing them)
                    if !self.healthKitProvidingCalories {
                        let timeSinceLastCalorieUpdate = self.elapsedTime - self.lastCalorieUpdate
                        if timeSinceLastCalorieUpdate >= 5.0 {
                            self.updateCaloriesWithFallback()
                            self.lastCalorieUpdate = self.elapsedTime
                        }
                    }
                }
            }
            
            if !self.isActive {
                timerInstance.invalidate()
                self.timer = nil
            }
        }
    }
    
    // MARK: - Location Management (Backup GPS + Route)
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
            let msg = "⚠️ Cannot start location tracking - authorization: \(locationAuthorizationStatus.rawValue)"
            print(msg)
            DebugLogger.shared.log(msg)
            return
        }
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0
        locationManager.activityType = .fitness
        
        if hasBackgroundLocationCapability() {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
            let msg = "✅ Background location updates ENABLED with indicator"
            print(msg)
            DebugLogger.shared.log(msg)
        }
        
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - Barometric Altimeter
    private func startAltimeterTracking() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            let msg = "⚠️ Barometric altimeter not available on this device"
            print(msg)
            DebugLogger.shared.log(msg)
            return
        }
        
        lastAltitude = nil
        totalElevationGainMeters = 0
        elevationGain = 0
        
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else {
                if let error = error {
                    print("❌ Altimeter error: \(error.localizedDescription)")
                }
                return
            }
            
            // Only track when workout is active and not paused
            guard self.isActive && !self.isPaused else { return }
            
            let currentAltitude = data.relativeAltitude.doubleValue // meters from start
            
            if let previousAltitude = self.lastAltitude {
                let altitudeChange = currentAltitude - previousAltitude
                
                // Only count significant uphill changes
                if altitudeChange > self.altitudeFilterThreshold {
                    self.totalElevationGainMeters += altitudeChange
                    self.elevationGain = self.totalElevationGainMeters * 3.28084
                    let elevMsg = "⛰️ Elevation: +\(String(format: "%.1f", altitudeChange))m | Total: \(Int(self.elevationGain)) ft"
                    print(elevMsg)
                    DebugLogger.shared.log(elevMsg)
                }
            }
            
            self.lastAltitude = currentAltitude
        }
        
        let msg = "✅ Started barometric altimeter for elevation tracking"
        print(msg)
        DebugLogger.shared.log(msg)
    }
    
    private func stopAltimeterTracking() {
        altimeter.stopRelativeAltitudeUpdates()
        let msg = "🛑 Stopped altimeter. Final elevation: \(Int(elevationGain)) ft"
        print(msg)
        DebugLogger.shared.log(msg)
    }
    
    // MARK: - Calorie Adjustment for Ruck Weight
    /// Apple provides base walking/hiking calories. We add the extra energy cost
    /// of carrying ruck weight, matching the Watch app's calculation.
    private func adjustCaloriesForRuckWeight(baseCalories: Double) -> Double {
        guard ruckWeight > 0 else { return baseCalories }
        
        let timeHours = elapsedTime / 3600.0
        let bodyWeightKg = userSettings.bodyWeightInKg
        let bodyWeightPounds = bodyWeightKg * 2.20462
        
        // Additional calories from carrying the ruck weight
        let loadPercentage = ruckWeight / bodyWeightPounds
        let additionalCaloriesPerHour = bodyWeightKg * loadPercentage * 6.0 // MET adjustment
        let additionalCalories = additionalCaloriesPerHour * timeHours
        
        return baseCalories + additionalCalories
    }
    
    /// Fallback calorie calculation when HealthKit isn't providing data
    private func updateCaloriesWithFallback() {
        // If HealthKit is already providing calories, don't override
        guard !healthKitProvidingCalories else { return }
        guard elapsedTime > 0 else { return }
        
        let timeMinutes = elapsedTime / 60.0
        
        if distance > 0.01 {
            // Distance-based calculation (most accurate fallback)
            calories = CalorieCalculator.calculateRuckingCalories(
                bodyWeightKg: userSettings.bodyWeightInKg,
                ruckWeightPounds: ruckWeight,
                timeMinutes: timeMinutes,
                distanceMiles: distance
            )
        }
    }
    
    // MARK: - Local Data Storage
    private func saveWorkoutToLocalStorage(startDate: Date) {
        // Use actual heart rate if available, otherwise 0 (will show as N/A)
        let avgHeartRate = currentHeartRate > 0 ? currentHeartRate : 0
        
        // Check if currently enrolled in a program, allowing an explicit override set by UI
        let programId = overrideProgramContext?.programId ?? LocalProgramService.shared.getEnrolledProgramId()
        let programWorkoutDay = overrideProgramContext?.day ?? calculateCurrentProgramWorkoutDay()
        
        // Check if currently enrolled in a challenge
        let challengeId = LocalChallengeService.shared.getEnrolledChallengeId()
        let challengeWorkoutDay = calculateCurrentChallengeWorkoutDay()
        
        #if DEBUG
        print("\n🟣 ===== WORKOUT MANAGER: SAVING WORKOUT =====")
        print("🟣 Start Date: \(startDate), Elapsed: \(Int(elapsedTime))s, Distance: \(String(format: "%.2f", distance))mi")
        print("🟣 Program: \(programId?.uuidString ?? "NONE"), Day: \(programWorkoutDay?.description ?? "NONE")")
        print("🟣 Challenge: \(challengeId?.uuidString ?? "NONE"), Day: \(challengeWorkoutDay?.description ?? "NONE")")
        #endif
        
        let savedWorkoutId = WorkoutDataManager.shared.saveWorkout(
            date: startDate,
            duration: elapsedTime,
            distance: distance,
            calories: calories,
            ruckWeight: ruckWeight,
            heartRate: avgHeartRate,
            elevationGain: elevationGain,
            programId: programId,
            programWorkoutDay: programWorkoutDay,
            challengeId: challengeId,
            challengeDay: challengeWorkoutDay
        )
        
        // Auto-share to community clubs (background)
        Task {
            await shareWorkoutToClubs(
                workoutId: savedWorkoutId,
                distance: finalDistance,
                duration: Int(finalElapsedTime / 60),
                weight: finalRuckWeight,
                calories: Int(finalCalories),
                elevationGain: finalElevationGain
            )
        }
        
        // Clear override once persisted
        overrideProgramContext = nil
        
        // If this was a program workout, update progress
        if let programId = programId, let day = programWorkoutDay {
            Task { @MainActor in
                LocalProgramService.shared.refreshProgramProgress()
            }
        }
        
        // If this was a challenge workout, mark it complete
        if let challengeId = challengeId, let day = challengeWorkoutDay {
            LocalChallengeService.shared.completeWorkout(
                challengeId: challengeId,
                workoutDay: day,
                distanceMiles: distance,
                weightLbs: ruckWeight,
                durationMinutes: Int(elapsedTime / 60)
            )
        }
    }
    
    private func calculateCurrentProgramWorkoutDay() -> Int? {
        guard let progress = LocalProgramService.shared.programProgress else {
            return nil
        }
        return progress.completed + 1
    }
    
    private func calculateCurrentChallengeWorkoutDay() -> Int? {
        guard let progress = LocalChallengeService.shared.challengeProgress else {
            return nil
        }
        return progress.completed + 1
    }
    
    // MARK: - Program Progress Tracking
    private func updateProgramProgressIfActive() async {
        // Program completion is handled in saveWorkoutToLocalStorage()
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
        elevationGain = 0
        totalElevationGainMeters = 0
        healthKitProvidingDistance = false
        healthKitProvidingCalories = false
        
        // Reset location tracking
        startLocation = nil
        lastLocation = nil
        lastAltitude = nil
        
        // Reset movement detection
        lastDistanceUpdateTime = nil
        lastDistanceValue = 0
        
        // Clean up HealthKit objects
        session = nil
        builder = nil
    }
    
    private func resetWorkout() {
        elapsedTime = 0
        distance = 0
        totalGPSDistance = 0
        calories = 0
        startDate = nil
        currentHeartRate = 0
        lastCalorieUpdate = 0
        elevationGain = 0
        totalElevationGainMeters = 0
        healthKitProvidingDistance = false
        healthKitProvidingCalories = false
        
        // Reset location tracking
        startLocation = nil
        lastLocation = nil
        lastAltitude = nil
        
        // Reset movement detection
        lastDistanceUpdateTime = nil
        lastDistanceValue = 0
        
        // Clean up HealthKit objects
        session = nil
        builder = nil
        
        // Reset post-workout summary state
        showingPostWorkoutSummary = false
        finalElapsedTime = 0
        finalDistance = 0
        finalCalories = 0
        finalRuckWeight = 0
        finalElevationGain = 0
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

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            switch toState {
            case .running:
                let msg = "🏃 HKWorkoutSession → running"
                print(msg)
                DebugLogger.shared.log(msg)
            case .paused:
                let msg = "⏸️ HKWorkoutSession → paused"
                print(msg)
                DebugLogger.shared.log(msg)
            case .ended:
                let msg = "🏁 HKWorkoutSession → ended"
                print(msg)
                DebugLogger.shared.log(msg)
            default:
                break
            }
        }
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            let msg = "❌ HKWorkoutSession failed: \(error.localizedDescription) — falling back to GPS"
            print(msg)
            DebugLogger.shared.log(msg)
            
            // Fall back to GPS-only tracking
            self.healthKitProvidingDistance = false
            self.healthKitProvidingCalories = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }
                
                let statistics = workoutBuilder.statistics(for: quantityType)
                
                switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    if let heartRateValue = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                        self.currentHeartRate = heartRateValue
                    }
                    
                case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                    // Apple's sensor-fused distance (GPS + pedometer + motion coprocessor)
                    if let distanceValue = statistics?.sumQuantity()?.doubleValue(for: .mile()) {
                        self.healthKitProvidingDistance = true
                        self.distance = distanceValue
                        
                        // Track for movement detection
                        self.lastDistanceUpdateTime = Date()
                        self.lastDistanceValue = distanceValue
                        
                        let msg = "📏 Apple distance: \(String(format: "%.3f", distanceValue)) mi"
                        print(msg)
                        DebugLogger.shared.log(msg)
                    }
                    
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    // Use Apple's calorie calculation as base, then adjust for ruck weight
                    if let appleCalories = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        self.healthKitProvidingCalories = true
                        self.calories = self.adjustCaloriesForRuckWeight(baseCalories: appleCalories)
                        let msg = "🔥 Adjusted calories: \(Int(self.calories)) (Apple base: \(Int(appleCalories)))"
                        print(msg)
                        DebugLogger.shared.log(msg)
                    }
                    
                default:
                    break
                }
            }
        }
    }
    
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events (pause, resume, etc.) if needed
    }
}

// MARK: - CLLocationManagerDelegate (Backup GPS + Route)
extension WorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard !locations.isEmpty else { return }
            if self.isPaused { return }
            
            // Process ALL locations in the batch for accurate path distance.
            // When the app is in background, iOS batches location updates.
            if locations.count > 1 {
                let batchMsg = "📍 GPS batch: received \(locations.count) locations"
                print(batchMsg)
                DebugLogger.shared.log(batchMsg)
            }
            
            let sortedLocations = locations.sorted { $0.timestamp < $1.timestamp }
            
            for location in sortedLocations {
                // Allow older timestamps for batched background updates (up to 60 seconds)
                guard location.timestamp.timeIntervalSinceNow > -60.0,
                      location.horizontalAccuracy > 0,
                      location.horizontalAccuracy < 50.0 else {
                    continue
                }
                
                if self.startLocation == nil {
                    self.startLocation = location
                    self.lastLocation = location
                    let msg = "📍 GPS: First location acquired | Accuracy: \(String(format: "%.1f", location.horizontalAccuracy))m"
                    print(msg)
                    DebugLogger.shared.log(msg)
                    continue
                }
                
                if let lastLoc = self.lastLocation {
                    let distanceMeters = location.distance(from: lastLoc)
                    
                    // Filter out GPS jumps (>500m) and tiny movements (<5m)
                    if distanceMeters > 5.0 && distanceMeters < 500.0 {
                        self.totalGPSDistance += distanceMeters
                        
                        // Only use GPS distance when HealthKit isn't providing it
                        if !self.healthKitProvidingDistance {
                            let gpsDistanceMiles = self.totalGPSDistance * 0.000621371
                            self.distance = gpsDistanceMiles
                            
                            // Track for movement detection
                            self.lastDistanceUpdateTime = Date()
                            self.lastDistanceValue = self.distance
                        }
                        
                        self.lastLocation = location
                    } else if distanceMeters >= 500.0 {
                        // GPS jump — update reference but don't count distance
                        let msg = "⚠️ GPS jump: \(String(format: "%.0f", distanceMeters))m - skipping"
                        print(msg)
                        DebugLogger.shared.log(msg)
                        self.lastLocation = location
                    }
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let msg = "❌ Location error: \(error.localizedDescription)"
            print(msg)
            DebugLogger.shared.log(msg)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.locationAuthorizationStatus = status
            
            // If we just got authorized and workout is active, start GPS tracking
            if (status == .authorizedWhenInUse || status == .authorizedAlways) && self.isActive && !self.isPaused {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
                self.locationManager.distanceFilter = 5.0
                self.locationManager.activityType = .fitness
                
                if self.hasBackgroundLocationCapability() {
                    self.locationManager.allowsBackgroundLocationUpdates = true
                    self.locationManager.showsBackgroundLocationIndicator = true
                }
                
                self.locationManager.pausesLocationUpdatesAutomatically = false
                self.locationManager.startUpdatingLocation()
            }
        }
    }
}
