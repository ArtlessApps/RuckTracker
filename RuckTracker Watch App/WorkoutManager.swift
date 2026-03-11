//
//  WorkoutManager.swift
//  RuckTracker Watch App
//
//  Updated to use HKLiveWorkoutBuilder for Apple's native distance/pace calculations
//

import Foundation
import Combine
import SwiftUI
import HealthKit
import CoreData
import CoreMotion

// MARK: - Watch App Types
// TerrainType enum removed for MVP - using flat terrain only

@MainActor
class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    // MARK: - Published Properties
    @Published var isActive = false
    @Published var isPaused = false
    @Published var showPostWorkoutSummary = false
    @Published var isHealthKitAuthorized = false
    @Published var ruckWeight: Double = 20.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0
    @Published var calories: Double = 0
    @Published var currentHeartRate: Double = 0
    @Published var elevationGain: Double = 0 // Total elevation gain in feet (from barometric altimeter)
    @Published var errorManager = HealthKitErrorManager()
    
    // Final workout stats for post-workout summary
    @Published var finalElapsedTime: TimeInterval = 0
    @Published var finalDistance: Double = 0
    @Published var finalCalories: Double = 0
    @Published var finalRuckWeight: Double = 0
    @Published var finalElevationGain: Double = 0
    
    // Settings
    private let userSettings = UserSettings.shared
    private var cancellables = Set<AnyCancellable>()
    
    // HealthKit workout session using modern HKLiveWorkoutBuilder
    private var healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    // Health manager reference
    private var healthManager: HealthManager?
    
    // WatchConnectivity manager
    private var watchConnectivityManager: WatchConnectivityManager?
    
    // Timer for elapsed time tracking
    private var workoutTimer: Timer?
    private var startTime: Date?
    private var pausedTime: TimeInterval = 0
    
    // Immediate timer support - for instant UI feedback
    private var manualStartTime: Date?        // When user pressed start (immediate)
    private var healthKitStartTime: Date?     // When HealthKit actually started (delayed)
    private var isHealthKitReady = false      // Track if HealthKit is ready
    
    // Barometric altimeter for precise elevation tracking
    private let altimeter = CMAltimeter()
    private var altitudeBaseline: Double?                // Settled reference altitude (meters)
    private var lastAltitudeTimestamp: Date?             // For velocity-based sanity check
    private var totalElevationGainMeters: Double = 0     // Cumulative elevation gain
    // Threshold applied to accumulated change from the baseline, not per-callback delta.
    // CMAltimeter can fire many times/second, so per-delta thresholds filter out real gain.
    private let altitudeFilterThreshold: Double = 0.3    // ~1 foot; filters sensor noise
    // Physically impossible to climb faster than ~5 m/s even sprinting stairs. This guards
    // against the documented Apple bug where relativeAltitude spikes during/after HKWorkoutSession
    // pause (offsets from 1.5 m to 1000 m still present in watchOS 11.5 — FB7972487).
    private let maxReasonableClimbRateMetersPerSecond: Double = 5.0
    
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
    
    // Apple's calculated pace (much more stable than our GPS calculation)
    var currentPaceMinutesPerMile: Double? {
        guard distance > 0 && elapsedTime > 0 else { return nil }
        return (elapsedTime / 60.0) / distance // minutes per mile from Apple's distance
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
        case 0..<14: return .orange   // Too fast for sustainable rucking
        case 14..<18: return .green   // Good rucking pace
        case 18..<25: return .yellow  // Acceptable pace
        default: return .red          // Too slow
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupUserSettings()
    }
    
    func setHealthManager(_ manager: HealthManager) {
        self.healthManager = manager
        self.healthStore = manager.healthStore
        
        // Observe authorization changes
        manager.$isAuthorized
            .sink { [weak self] isAuthorized in
                DispatchQueue.main.async {
                    self?.isHealthKitAuthorized = isAuthorized
                    print("🏥 WorkoutManager: HealthKit authorization updated to \(isAuthorized)")
                }
            }
            .store(in: &cancellables)
    }
    
    func setWatchConnectivityManager(_ manager: WatchConnectivityManager) {
        self.watchConnectivityManager = manager
    }
    
    private func setupUserSettings() {
        ruckWeight = userSettings.defaultRuckWeightInPounds()
        
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
        print("🏋️ Starting workout with \(weight) lbs")
        guard !isActive else { return }
        
        // 1. IMMEDIATE response (no delay)
        self.ruckWeight = weight
        isActive = true
        isPaused = false
        elapsedTime = 0
        distance = 0
        calories = 0
        elevationGain = 0
        pausedTime = 0
        manualStartTime = Date()           // Start manual timer immediately
        startTime = manualStartTime        // Use manual start time for consistency
        isHealthKitReady = false
        
        // Start UI timer immediately for instant feedback
        startElapsedTimeTracking()
        
        // Start barometric altimeter for precise elevation tracking
        startAltimeterTracking()
        
        // 2. BACKGROUND HealthKit setup (async - can take 2-3 seconds)
        DispatchQueue.global(qos: .userInitiated).async {
            self.startWorkoutSession()
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
        
        if let manualStartTime = manualStartTime {
            pausedTime += Date().timeIntervalSince(manualStartTime)
        }
        
        isPaused = true
        session?.pause()
        // Nil the baseline now so the first reading after resume re-establishes a clean
        // reference, discarding the spike Apple's bug injects during pause (FB7972487).
        resetAltitudeBaselineForResume()
        print("⏸️ Workout paused")
    }
    
    func resumeWorkout() {
        guard isPaused else { return }
        
        manualStartTime = Date()
        startTime = manualStartTime
        
        isPaused = false
        session?.resume()
        print("▶️ Workout resumed")
    }
    
    func endWorkout() {
        print("🏁 Ending workout...")
        
        // Stop altimeter tracking
        stopAltimeterTracking()
        
        // Use fallback calorie calculation if needed before saving final stats
        updateCaloriesWithFallback()
        
        // Save final stats before resetting
        finalElapsedTime = elapsedTime
        finalDistance = distance
        finalCalories = calories
        finalRuckWeight = ruckWeight
        finalElevationGain = elevationGain
        
        print("📊 Final stats saved: time=\(finalElapsedTime), distance=\(finalDistance), calories=\(finalCalories), elevation=\(finalElevationGain)")
        
        // Stop the timer first
        workoutTimer?.invalidate()
        workoutTimer = nil
        
        // Update UI state immediately
        isActive = false
        isPaused = true
        
        // Save workout locally first to ensure data is not lost
        saveWorkoutToLocalStorage()
        
        // Show summary immediately - don't wait for HealthKit
        print("🎯 Showing post-workout summary immediately")
        showPostWorkoutSummary = true
        print("🎯 showPostWorkoutSummary set to: \(showPostWorkoutSummary)")
        
        // Handle the async completion properly (in background)
        if let builder = builder {
            print("✅ Builder exists, ending collection...")
            // End collection first, then end session
            builder.endCollection(withEnd: Date()) { [weak self] success, error in
                guard let self = self else { return }
                
                if let error = error {
                    let healthKitError = HealthKitError.workoutDataCollectionFailed(underlying: error)
                    DispatchQueue.main.async {
                        print("❌ HealthKit collection failed: \(error.localizedDescription)")
                        self.errorManager.handleError(healthKitError, context: "Workout End Collection")
                        self.session?.end()
                        self.resetWorkout()
                    }
                    return
                }
                
                guard success else {
                    let healthKitError = HealthKitError.workoutSaveFailed(underlying: nil)
                    DispatchQueue.main.async {
                        print("❌ HealthKit collection unsuccessful")
                        self.errorManager.handleError(healthKitError, context: "Workout End Collection")
                        self.session?.end()
                        self.resetWorkout()
                    }
                    return
                }
                
                print("✅ HealthKit collection successful, finishing workout...")
                
                // Save elevation as HealthKit metadata so it appears in Health/Fitness apps.
                // Apple's mechanism for hiking elevation: HKMetadataKeyElevationAscended.
                let elevationMeters = self.finalElevationGain / 3.28084
                let elevationQuantity = HKQuantity(unit: .meter(), doubleValue: elevationMeters)
                let elevationMetadata: [String: Any] = [
                    HKMetadataKeyElevationAscended: elevationQuantity
                ]
                builder.addMetadata(elevationMetadata) { _, _ in }
                
                builder.finishWorkout { workout, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ HealthKit finish failed: \(error.localizedDescription)")
                            let healthKitError = HealthKitError.workoutSaveFailed(underlying: error)
                            self.errorManager.handleError(healthKitError, context: "Workout Finish")
                        } else if let workout = workout {
                            print("✅ Workout saved to HealthKit with Apple's calculations")
                            if let distance = workout.totalDistance?.doubleValue(for: .mile()) {
                                print("📊 HealthKit stats: \(String(format: "%.2f", distance)) mi, \(Int(self.finalCalories)) cal, \(Int(self.finalElevationGain)) ft elevation")
                            }
                            self.errorManager.clearError()
                        } else {
                            print("❌ HealthKit finish returned no workout and no error")
                            let healthKitError = HealthKitError.workoutSaveFailed(underlying: nil)
                            self.errorManager.handleError(healthKitError, context: "Workout Finish")
                        }
                        
                        self.session?.end()
                        self.resetWorkout()
                    }
                }
            }
        } else {
            // No builder - this shouldn't happen but handle gracefully
            print("❌ No builder found")
            let healthKitError = HealthKitError.workoutBuilderCreationFailed(underlying: nil)
            errorManager.handleError(healthKitError, context: "Workout End")
            
            // Clean up session immediately since no HealthKit operations to wait for
            session?.end()
            resetWorkout()
        }
    }
    
    // MARK: - Barometric Altimeter for Elevation
    private func startAltimeterTracking() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            print("⚠️ Barometric altimeter not available on this device")
            return
        }
        
        // Reset elevation tracking
        altitudeBaseline = nil
        lastAltitudeTimestamp = nil
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
            
            let currentAltitude = data.relativeAltitude.doubleValue
            let now = Date()
            
            // Velocity sanity check — guards against Apple's documented relativeAltitude
            // spike bug when HKWorkoutSession is paused (FB7972487, still present watchOS 11.5).
            if let lastTimestamp = self.lastAltitudeTimestamp,
               let baseline = self.altitudeBaseline {
                let elapsed = now.timeIntervalSince(lastTimestamp)
                if elapsed > 0 {
                    let climbRate = abs(currentAltitude - baseline) / elapsed
                    if climbRate > self.maxReasonableClimbRateMetersPerSecond {
                        // Physically impossible — almost certainly a post-pause spike.
                        // Reset baseline to this reading and discard the delta.
                        print("⚠️ Altimeter spike rejected (\(String(format: "%.1f", climbRate)) m/s) — resetting baseline")
                        self.altitudeBaseline = currentAltitude
                        self.lastAltitudeTimestamp = now
                        return
                    }
                }
            }
            
            self.lastAltitudeTimestamp = now
            
            guard let baseline = self.altitudeBaseline else {
                // First reading — establish baseline
                self.altitudeBaseline = currentAltitude
                return
            }
            
            let delta = currentAltitude - baseline
            
            if delta > self.altitudeFilterThreshold {
                // Moved uphill enough relative to the baseline — count the gain
                self.totalElevationGainMeters += delta
                self.elevationGain = self.totalElevationGainMeters * 3.28084
                self.altitudeBaseline = currentAltitude
                print("⛰️ Elevation: +\(String(format: "%.1f", delta))m, Total: \(Int(self.elevationGain)) ft")
            } else if delta < -self.altitudeFilterThreshold {
                // Moved downhill past the noise floor — shift baseline down without counting gain
                self.altitudeBaseline = currentAltitude
            }
            // If |delta| < threshold, ignore (sensor noise) and keep baseline where it is
        }
        
        print("✅ Started barometric altimeter for elevation tracking")
    }
    
    // Call on pause: nils the baseline so that after resume the first reading
    // re-establishes a clean reference, discarding any spike from the Apple bug.
    private func resetAltitudeBaselineForResume() {
        altitudeBaseline = nil
        lastAltitudeTimestamp = nil
        print("⛰️ Altitude baseline reset for resume")
    }
    
    private func stopAltimeterTracking() {
        altimeter.stopRelativeAltitudeUpdates()
        print("🛑 Stopped altimeter tracking. Final elevation: \(Int(elevationGain)) ft")
    }
    
    // MARK: - HKLiveWorkoutBuilder Integration
    private func startWorkoutSession() {
        // ⚠️ DEFENSIVE CLEANUP - Always clean up before creating new session
        // This prevents double-beginCollection() calls if session/builder weren't properly cleaned up
        if session != nil || builder != nil {
            print("⚠️ Found existing workout session/builder - cleaning up before starting new workout")
            print("   Session exists: \(session != nil), Builder exists: \(builder != nil)")
            
            // Attempt to end the old session gracefully
            session?.end()
            
            // Force cleanup to prevent any lingering references
            session = nil
            builder = nil
            
            print("✅ Cleanup complete - safe to create new workout session")
        }
        
        // Clear any previous workout session errors
        errorManager.clearError()
        
        guard HKHealthStore.isHealthDataAvailable() else {
            let error = HealthKitError.healthDataNotAvailable
            errorManager.handleError(error, context: "Workout Session Start")
            return
        }
        
        // Check if we have authorization
        guard isHealthKitAuthorized else {
            let error = HealthKitError.insufficientPermissions(requiredTypes: ["Workouts", "Distance", "Calories"])
            errorManager.handleError(error, context: "Workout Session Start")
            
            print("⚠️ HealthKit not authorized - workout will run in manual mode (timer only)")
            // Note: We still return here to maintain the current behavior, but this could be 
            // modified to allow timer-only workouts in the future
            return
        }
        
        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .hiking  // Better represents rucking intensity
        configuration.locationType = .outdoor   // Enable GPS
        
        do {
            // Create session and builder
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            
            // Verify builder creation
            guard let builder = builder else {
                let error = HealthKitError.workoutBuilderCreationFailed(underlying: nil)
                errorManager.handleError(error, context: "Workout Session Start")
                return
            }
            
            // Set delegates
            session?.delegate = self
            builder.delegate = self
            
            // Set up data source - this is KEY for getting Apple's calculated distance/pace
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // Start the session
            session?.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { [weak self] success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        let healthKitError = HealthKitError.workoutDataCollectionFailed(underlying: error)
                        self?.errorManager.handleError(healthKitError, context: "Workout Collection Start")
                    } else if success {
                        print("✅ Started HKLiveWorkoutBuilder - will get Apple's distance/pace calculations")
                        // Clear any previous errors on successful start
                        self?.errorManager.clearError()
                    } else {
                        let healthKitError = HealthKitError.workoutBuilderCreationFailed(underlying: nil)
                        self?.errorManager.handleError(healthKitError, context: "Workout Collection Start")
                    }
                }
            }
            
        } catch {
            let healthKitError = HealthKitError.workoutSessionCreationFailed(underlying: error)
            errorManager.handleError(healthKitError, context: "Workout Session Creation")
        }
    }
    
    private func startElapsedTimeTracking() {
        // Stop any existing timer
        workoutTimer?.invalidate()
        
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            
            if isActive && !isPaused {
                // Use manual start time for immediate UI feedback
                // This ensures the timer starts instantly when user presses start
                if let manualStartTime = manualStartTime {
                    elapsedTime = pausedTime + Date().timeIntervalSince(manualStartTime)
                }
                
                // Check if we need to use fallback calorie calculation
                updateCaloriesWithFallback()
            }
            
            if !isActive {
                timer.invalidate()
                workoutTimer = nil
            }
        }
    }
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isActive = true
                self.isPaused = false
                print("🏃 Workout session running")
            case .paused:
                self.isPaused = true
                print("⏸️ Workout session paused")
            case .ended:
                self.isActive = false
                self.isPaused = true
                print("🏁 Workout session ended")
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ Workout session failed: \(error.localizedDescription)")
        
        let healthKitError = HealthKitError.workoutSessionCreationFailed(underlying: error)
        DispatchQueue.main.async {
            self.errorManager.handleError(healthKitError, context: "Workout Session")
            
            // If the session fails, we should stop the workout gracefully
            self.isActive = false
            self.isPaused = true
        }
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Mark HealthKit as ready when we start receiving data
        if !isHealthKitReady {
            DispatchQueue.main.async {
                self.isHealthKitReady = true
                self.healthKitStartTime = Date()
                print("✅ HealthKit is now ready - data collection started")
            }
        }
        
        print("📊 HealthKit collected data for \(collectedTypes.count) types: \(collectedTypes.map { $0.identifier }.joined(separator: ", "))")
        
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            DispatchQueue.main.async {
                switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    if let heartRateUnit = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                        self.currentHeartRate = heartRateUnit
                    }
                    
                case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                    // This is Apple's calculated distance - much more stable than raw GPS
                    if let distanceValue = statistics?.sumQuantity()?.doubleValue(for: .mile()) {
                        self.distance = distanceValue
                        print("📏 Apple distance: \(String(format: "%.3f", distanceValue)) mi")
                    }
                    
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    // Use Apple's calorie calculation as base, then adjust for ruck weight
                    if let appleCalories = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        self.calories = self.adjustCaloriesForRuckWeight(baseCalories: appleCalories)
                        print("🔥 Adjusted calories: \(Int(self.calories)) (Apple: \(Int(appleCalories)))")
                    }
                    
                // Note: Elevation is now tracked via CMAltimeter (barometric altimeter)
                // for more precise readings than flightsClimbed
                    
                default:
                    break
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events (lap, pause, resume, etc.)
    }
    
    // MARK: - Calorie Adjustment for Ruck Weight
    private func adjustCaloriesForRuckWeight(baseCalories: Double) -> Double {
        // Apple gives us base walking calories
        // We add the extra load from ruck weight using our calculation
        
        guard ruckWeight > 0 else { return baseCalories }
        
        let timeHours = elapsedTime / 3600.0
        let bodyWeightKg = userSettings.bodyWeightInKg
        let bodyWeightPounds = bodyWeightKg * 2.20462
        
        // Calculate additional calories from ruck weight
        let loadPercentage = ruckWeight / bodyWeightPounds
        let additionalCaloriesPerHour = bodyWeightKg * loadPercentage * 6.0 // MET adjustment
        let additionalCalories = additionalCaloriesPerHour * timeHours
        
        return baseCalories + additionalCalories
    }
    
    // MARK: - Fallback Calorie Calculation
    private func updateCaloriesWithFallback() {
        // If we have distance and HealthKit isn't providing calories,
        // calculate them ourselves using the CalorieCalculator
        if distance > 0.01 && calories < 1.0 {
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
    private func saveWorkoutToLocalStorage() {
        guard let startTime = startTime else {
            print("❌ Cannot save workout: no start time")
            return
        }
        
        // Calculate average heart rate if we have data
        let avgHeartRate = currentHeartRate > 0 ? currentHeartRate : 120.0
        
        // Save to CoreData using final stats
        WorkoutDataManager.shared.saveWorkout(
            date: startTime,
            duration: finalElapsedTime,
            distance: finalDistance,
            calories: finalCalories,
            ruckWeight: finalRuckWeight,
            heartRate: avgHeartRate,
            elevationGain: finalElevationGain
        )
        
        print("💾 Watch: Saved workout to local storage (elevation: \(Int(finalElevationGain)) ft)")
        
        // Send workout to phone via WatchConnectivity
        sendWorkoutToPhone(startTime: startTime, avgHeartRate: avgHeartRate)
    }
    
    private func sendWorkoutToPhone(startTime: Date, avgHeartRate: Double) {
        // Create a temporary WorkoutEntity to send to phone
        let tempWorkout = WorkoutEntity(context: WorkoutDataManager.shared.context)
        tempWorkout.date = startTime
        tempWorkout.duration = finalElapsedTime
        tempWorkout.distance = finalDistance
        tempWorkout.calories = finalCalories
        tempWorkout.ruckWeight = finalRuckWeight
        tempWorkout.heartRate = avgHeartRate
        tempWorkout.elevationGain = finalElevationGain
        
        // Send to phone
        watchConnectivityManager?.sendWorkoutToPhone(tempWorkout)
        
        // Clean up temporary object
        WorkoutDataManager.shared.context.delete(tempWorkout)
    }
    
    // MARK: - Post-Workout Navigation
    func dismissPostWorkoutSummary() {
        print("🔄 Dismissing post-workout summary")
        showPostWorkoutSummary = false
        
        // Reset workout state to clean slate
        isActive = false
        isPaused = false
        
        // Reset final stats
        finalElapsedTime = 0
        finalDistance = 0
        finalCalories = 0
        finalRuckWeight = 0
        finalElevationGain = 0
    }
    
    // MARK: - Cleanup
    private func resetWorkout() {
        // Stop any running timer
        workoutTimer?.invalidate()
        workoutTimer = nil
        
        // Reset workout data
        elapsedTime = 0
        distance = 0
        calories = 0
        currentHeartRate = 0
        elevationGain = 0
        startTime = nil
        pausedTime = 0
        
        // Reset immediate timer properties
        manualStartTime = nil
        healthKitStartTime = nil
        isHealthKitReady = false
        
        // Reset altimeter tracking
        altitudeBaseline = nil
        lastAltitudeTimestamp = nil
        totalElevationGainMeters = 0
        
        // Clean up HealthKit objects
        session = nil
        builder = nil
    }
    
    // MARK: - Utility
    func getCalorieComparison() -> (ours: Double, appleEstimate: Double, difference: Double) {
        let appleCalories = builder?.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        
        return (calories, appleCalories, calories - appleCalories)
    }
}

// MARK: - Enhanced HealthKit Integration
extension WorkoutManager {
    
    private func addEnhancedMetadataToWorkout() -> [String: Any] {
        return [
            // Core rucking data
            "RuckWeight": ruckWeight,
            "RuckWeightUnit": "lbs",
            "AppName": "MARCH",
            "WorkoutType": "Rucking",
            "Version": "1.0",
            
            // Help Apple understand this is more intense than normal walking
            "ActivityIntensity": calculateActivityIntensity(),
            "EquipmentUsed": "Weighted Backpack",
            "ExerciseType": "Cardio + Strength",
            
            // Elevation tracking
            "ElevationGain": elevationGain,
            "ElevationGainUnit": "ft",
            
            // Average metrics for Apple's ML algorithms
            "AverageHeartRateZone": heartRateZone,
            "PerceivedExertion": calculatePerceivedExertion(),
            
            // Distance and pace context
            "PrimaryActivity": "Hiking",
            "SecondaryActivity": "Load Carrying",
            
            // Help categorize for Fitness+ recommendations
            "FitnessCategory": "Outdoor",
            "WorkoutStyle": "Endurance"
        ]
    }
    
    private func calculateActivityIntensity() -> String {
        let bodyWeightPounds = userSettings.bodyWeightInKg * 2.20462
        let weightPercentage = ruckWeight / bodyWeightPounds
        
        switch weightPercentage {
        case 0..<0.15: return "Moderate"    // < 15% body weight
        case 0.15..<0.25: return "Vigorous" // 15-25%
        default: return "High"              // > 25%
        }
    }
    
    private var heartRateZone: String {
        guard currentHeartRate > 0 else { return "Unknown" }
        
        // Rough HR zones (could be personalized based on user age)
        switch currentHeartRate {
        case 0..<100: return "Recovery"
        case 100..<130: return "Aerobic"
        case 130..<150: return "Threshold"
        case 150..<170: return "VO2 Max"
        default: return "Neuromuscular"
        }
    }
    
    private func calculatePerceivedExertion() -> Int {
        // RPE scale 1-10 based on ruck weight percentage of body weight
        let bodyWeightPounds = userSettings.bodyWeightInKg * 2.20462
        let weightPercentage = ruckWeight / bodyWeightPounds
        
        switch weightPercentage {
        case 0..<0.1: return 3      // < 10% body weight
        case 0.1..<0.15: return 4   // 10-15%
        case 0.15..<0.2: return 5   // 15-20%
        case 0.2..<0.25: return 6   // 20-25%
        case 0.25..<0.3: return 7   // 25-30%
        default: return 8           // > 30%
        }
    }
    
    private func calculateExerciseMinutes() -> Double {
        let totalMinutes = elapsedTime / 60.0
        
        // If carrying significant weight, count all time as exercise
        let bodyWeightPounds = userSettings.bodyWeightInKg * 2.20462
        let weightPercentage = ruckWeight / bodyWeightPounds
        
        if weightPercentage >= 0.15 { // 15%+ body weight
            return totalMinutes
        } else if weightPercentage >= 0.1 { // 10-15% body weight
            return totalMinutes * 0.8
        } else {
            return totalMinutes * 0.6 // Light ruck or bodyweight only
        }
    }
    
    func generateHealthSummary() -> String {
        let bodyWeightPounds = userSettings.bodyWeightInKg * 2.20462
        let weightPercentage = Int(ruckWeight / bodyWeightPounds * 100)
        
        return """
        Rucking Workout Summary:
        • Duration: \(formattedElapsedTime)
        • Distance: \(String(format: "%.2f", distance)) miles
        • Elevation Gain: \(Int(elevationGain)) ft
        • Ruck Weight: \(Int(ruckWeight)) lbs (\(weightPercentage)% body weight)
        • Calories: \(Int(calories)) (adjusted for load)
        • Avg Pace: \(formattedPace) per mile
        
        This workout contributes to your:
        ✅ Move Ring (Active Calories)
        ✅ Exercise Ring (Exercise Minutes)
        ✅ Stand Ring (Active Movement)
        """
    }
    
    // MARK: - Activity Ring Optimization (Disabled to prevent feedback loop)
    // Note: Activity Ring contributions are handled automatically by HealthKit
    // when using HKLiveWorkoutBuilder with proper metadata in the workout configuration
}
