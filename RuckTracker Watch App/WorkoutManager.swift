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

// MARK: - Watch App Types
// TerrainType enum removed for MVP - using flat terrain only

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
    
    // Final workout stats for post-workout summary
    @Published var finalElapsedTime: TimeInterval = 0
    @Published var finalDistance: Double = 0
    @Published var finalCalories: Double = 0
    @Published var finalRuckWeight: Double = 0
    
    // Settings
    private let userSettings = UserSettings.shared
    private var cancellables = Set<AnyCancellable>()
    
    // HealthKit workout session using modern HKLiveWorkoutBuilder
    private var healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    // Health manager reference
    private var healthManager: HealthManager?
    
    // Timer for elapsed time tracking
    private var workoutTimer: Timer?
    private var startTime: Date?
    private var pausedTime: TimeInterval = 0
    
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
        
        self.ruckWeight = weight
        isActive = true
        isPaused = false
        elapsedTime = 0
        distance = 0
        calories = 0
        pausedTime = 0
        startTime = Date()
        
        startWorkoutSession()
        startElapsedTimeTracking()
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
        guard !isPaused else { return } // Prevent double pause
        
        // Add current elapsed time to paused time before pausing
        if let startTime = startTime {
            pausedTime += Date().timeIntervalSince(startTime)
        }
        
        isPaused = true
        session?.pause()
        print("⏸️ Workout paused")
    }
    
    func resumeWorkout() {
        guard isPaused else { return } // Prevent resume when not paused
        
        // Reset start time for resumed session
        startTime = Date()
        
        isPaused = false
        session?.resume()
        print("▶️ Workout resumed")
    }
    
    func endWorkout() {
        print("🏁 Ending workout...")
        
        // Save final stats before resetting
        finalElapsedTime = elapsedTime
        finalDistance = distance
        finalCalories = calories
        finalRuckWeight = ruckWeight
        
        // Stop the timer first
        workoutTimer?.invalidate()
        workoutTimer = nil
        
        // Update UI state immediately
        isActive = false
        isPaused = true
        
        // Handle the async completion properly
        if let builder = builder {
            // End collection first, then end session
            builder.endCollection(withEnd: Date()) { [weak self] success, error in
                if success {
                    builder.finishWorkout { workout, error in
                        DispatchQueue.main.async {
                            if let workout = workout {
                                print("✅ Workout saved with Apple's calculations")
                                if let distance = workout.totalDistance?.doubleValue(for: .mile()) {
                                    print("📊 Final stats: \(String(format: "%.2f", distance)) mi, \(Int(self?.finalCalories ?? 0)) cal")
                                } else {
                                    print("📊 Final stats: \(String(format: "%.2f", self?.finalDistance ?? 0)) mi, \(Int(self?.finalCalories ?? 0)) cal")
                                }
                            } else {
                                print("❌ Failed to save workout: \(error?.localizedDescription ?? "")")
                            }
                            
                            // Show post-workout summary
                            print("🎯 Showing post-workout summary")
                            self?.showPostWorkoutSummary = true
                            
                            // Clean up session after everything is done
                            self?.session?.end()
                            self?.resetWorkout()
                        }
                    }
                } else {
                    print("❌ Failed to end collection: \(error?.localizedDescription ?? "")")
                    DispatchQueue.main.async {
                        // Show post-workout summary even if save failed
                        print("🎯 Showing post-workout summary (despite save failure)")
                        self?.showPostWorkoutSummary = true
                        
                        // Clean up session
                        self?.session?.end()
                        self?.resetWorkout()
                    }
                }
            }
        } else {
            // No builder - show summary immediately
            DispatchQueue.main.async {
                print("🎯 Showing post-workout summary (no builder)")
                self.showPostWorkoutSummary = true
                
                // Clean up session
                self.session?.end()
                self.resetWorkout()
            }
        }
    }
    
    // MARK: - HKLiveWorkoutBuilder Integration
    private func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available")
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
            
            // Set delegates
            session?.delegate = self
            builder?.delegate = self
            
            // Set up data source - this is KEY for getting Apple's calculated distance/pace
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // Start the session
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { [weak self] success, error in
                if success {
                    print("✅ Started HKLiveWorkoutBuilder - will get Apple's distance/pace calculations")
                } else {
                    print("❌ Failed to start builder: \(error?.localizedDescription ?? "")")
                }
            }
            
        } catch {
            print("❌ Failed to create workout session: \(error)")
        }
    }
    
    private func startElapsedTimeTracking() {
        // Stop any existing timer
        workoutTimer?.invalidate()
        
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.isActive && !self.isPaused {
                if let startTime = self.startTime {
                    self.elapsedTime = self.pausedTime + Date().timeIntervalSince(startTime)
                }
            }
            
            if !self.isActive {
                timer.invalidate()
                self.workoutTimer = nil
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
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
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
        startTime = nil
        pausedTime = 0
        
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
            "AppName": "RuckTracker",
            "WorkoutType": "Rucking",
            "Version": "1.0",
            
            // Help Apple understand this is more intense than normal walking
            "ActivityIntensity": calculateActivityIntensity(),
            "EquipmentUsed": "Weighted Backpack",
            "ExerciseType": "Cardio + Strength",
            
            // Using flat terrain for MVP
            "TerrainType": "Flat",
            "TerrainMultiplier": 1.0,
            
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
        • Ruck Weight: \(Int(ruckWeight)) lbs (\(weightPercentage)% body weight)
        • Calories: \(Int(calories)) (adjusted for load)
        • Avg Pace: \(formattedPace) per mile
        • Terrain: Flat
        
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
