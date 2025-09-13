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

class WorkoutManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isActive = false
    @Published var isPaused = false
    @Published var ruckWeight: Double = 20.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0
    @Published var calories: Double = 0
    @Published var currentHeartRate: Double = 120
    
    // Settings
    private let userSettings = UserSettings.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Workout session data
    private var startDate: Date?
    private var timer: Timer?
    let healthStore = HKHealthStore()
    
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
    init() {
        setupUserSettings()
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
    
    // MARK: - Workout Control (Simplified for Phone)
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
        
        print("📱 Phone: Started workout setup with \(weight) lbs")
        // Note: On phone, this is mainly for UI state
        // Real workout tracking should happen on watch
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
        
        print("📱 Phone: Workout paused")
    }
    
    func resumeWorkout() {
        isPaused = false
        isActive = true
        startTimer()
        
        print("📱 Phone: Workout resumed")
    }
    
    func endWorkout() {
        isActive = false
        isPaused = true
        timer?.invalidate()
        
        if let startDate = startDate {
            let endDate = Date()
            
            // Save to both HealthKit and local CoreData
            saveWorkoutToHealth(startDate: startDate, endDate: endDate)
            saveWorkoutToLocalStorage(startDate: startDate)
        }
        
        print("📱 Phone: Workout ended - \(formattedElapsedTime)")
        resetWorkout()
    }
    
    // MARK: - Timer (Simplified)
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            
            self.elapsedTime += 1
            
            // Simplified updates for phone UI
            if Int(self.elapsedTime) % 10 == 0 {
                self.updateSimplifiedMetrics()
            }
        }
    }
    
    private func updateSimplifiedMetrics() {
        // Simplified calorie calculation for phone UI
        // (Watch will do the real calculation)
        calories = CalorieCalculator.calculateRuckingCalories(
            bodyWeightKg: userSettings.bodyWeightInKg,
            ruckWeightPounds: ruckWeight,
            timeMinutes: elapsedTime / 60.0,
            distanceMiles: distance,
        )
        
        // Simulated distance for phone (watch has real GPS)
        distance = (elapsedTime / 3600) * 3.0 // Assume 3 mph walking speed
        
        // Simulated heart rate
        currentHeartRate = 120 + Double.random(in: -10...30)
    }
    
    // MARK: - Local Data Storage
    private func saveWorkoutToLocalStorage(startDate: Date) {
        // Calculate average heart rate (simplified for phone)
        let avgHeartRate = currentHeartRate
        
        // Save to CoreData
        WorkoutDataManager.shared.saveWorkout(
            date: startDate,
            duration: elapsedTime,
            distance: distance,
            calories: calories,
            ruckWeight: ruckWeight,
            heartRate: avgHeartRate
        )
        
        print("💾 Saved workout to local storage")
    }
    
    // MARK: - HealthKit (Basic)
    private func saveWorkoutToHealth(startDate: Date, endDate: Date) {
        // Use HKWorkoutBuilder instead of deprecated initializer
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: HKWorkoutConfiguration(), device: .local())
        
        builder.beginCollection(withStart: startDate) { [weak self] success, error in
            guard let self = self, success else {
                print("❌ Failed to begin workout collection: \(error?.localizedDescription ?? "")")
                return
            }
            
            // Add distance sample
            if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                let distanceQuantity = HKQuantity(unit: .mile(), doubleValue: self.distance)
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
                let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: self.calories)
                let calorieSample = HKQuantitySample(
                    type: calorieType,
                    quantity: calorieQuantity,
                    start: startDate,
                    end: endDate,
                    metadata: [
                        "RuckWeight": self.ruckWeight,
                        "AppName": "RuckTracker-Phone",
                        "Terrain": "Flat",
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
                            print("📱 Basic workout saved to HealthKit from phone")
                        } else {
                            print("📱 Failed to save workout: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                } else {
                    print("❌ Failed to end collection: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
    
    // MARK: - Cleanup
    private func resetWorkout() {
        elapsedTime = 0
        distance = 0
        calories = 0
        startDate = nil
        currentHeartRate = 120
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
