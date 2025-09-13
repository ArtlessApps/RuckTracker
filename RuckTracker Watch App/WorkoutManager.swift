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

class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    // MARK: - Published Properties
    @Published var isActive = false
    @Published var isPaused = false
    @Published var ruckWeight: Double = 20.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0
    @Published var calories: Double = 0
    @Published var currentHeartRate: Double = 0
    @Published var selectedTerrain: TerrainType = .flat
    
    // Settings
    private let userSettings = UserSettings.shared
    private var cancellables = Set<AnyCancellable>()
    
    // HealthKit workout session using modern HKLiveWorkoutBuilder
    private var healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    // Health manager reference
    private var healthManager: HealthManager?
    
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
        
        startWorkoutSession()
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
        session?.pause()
        print("⏸️ Workout paused")
    }
    
    func resumeWorkout() {
        isPaused = false
        session?.resume()
        print("▶️ Workout resumed")
    }
    
    func endWorkout() {
        print("🏁 Ending workout...")
        isActive = false
        isPaused = true
        
        // End the session and builder
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] success, error in
            if success {
                self?.builder?.finishWorkout { workout, error in
                    if let workout = workout {
                        print("✅ Workout saved with Apple's calculations")
                        if let distance = workout.totalDistance?.doubleValue(for: .mile()) {
                            print("📊 Final stats: \(String(format: "%.2f", distance)) mi, \(Int(self?.calories ?? 0)) cal")
                        } else {
                            print("📊 Final stats: \(String(format: "%.2f", self?.distance ?? 0)) mi, \(Int(self?.calories ?? 0)) cal")
                        }
                    } else {
                        print("❌ Failed to save workout: \(error?.localizedDescription ?? "")")
                    }
                }
            }
        }
        
        resetWorkout()
    }
    
    // MARK: - HKLiveWorkoutBuilder Integration
    private func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available")
            return
        }
        
        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking  // Use walking for rucking
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
                    DispatchQueue.main.async {
                        self?.startElapsedTimeTracking()
                    }
                } else {
                    print("❌ Failed to start builder: \(error?.localizedDescription ?? "")")
                }
            }
            
        } catch {
            print("❌ Failed to create workout session: \(error)")
        }
    }
    
    private func startElapsedTimeTracking() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.isActive && !self.isPaused {
                self.elapsedTime = self.builder?.elapsedTime ?? 0
            }
            
            if !self.isActive {
                timer.invalidate()
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
    
    // MARK: - Cleanup
    private func resetWorkout() {
        elapsedTime = 0
        distance = 0
        calories = 0
        currentHeartRate = 0
        session = nil
        builder = nil
    }
    
    // MARK: - Utility
    func getCalorieComparison() -> (ours: Double, appleEstimate: Double, difference: Double) {
        let appleCalories = builder?.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        
        return (calories, appleCalories, calories - appleCalories)
    }
}
