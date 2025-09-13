import Foundation
import HealthKit

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available on this device")
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKWorkoutType.workoutType()
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        print("🏥 Requesting HealthKit authorization...")
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            print("🏥 Authorization request completed. Success: \(success)")
            if let error = error {
                print("❌ Authorization error: \(error.localizedDescription)")
            }
            
            // Check individual authorization statuses
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.checkAuthorizationStatus()
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        // Check multiple data types to get a complete picture
        let workoutType = HKWorkoutType.workoutType()
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        let workoutStatus = healthStore.authorizationStatus(for: workoutType)
        let heartRateStatus = healthStore.authorizationStatus(for: heartRateType)
        let caloriesStatus = healthStore.authorizationStatus(for: caloriesType)
        
        print("🏥 Authorization Status:")
        print("  - Workout: \(workoutStatus.rawValue)")
        print("  - Heart Rate: \(heartRateStatus.rawValue)")
        print("  - Calories: \(caloriesStatus.rawValue)")
        
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = workoutStatus
            
            // Consider authorized if we can write workout data
            // (Note: Heart rate read permission may show as denied even when available)
            let isWorkoutAuthorized = workoutStatus == .sharingAuthorized
            let isCaloriesAuthorized = caloriesStatus == .sharingAuthorized
            
            self?.isAuthorized = isWorkoutAuthorized && isCaloriesAuthorized
            
            print("🏥 Final authorization status: \(self?.isAuthorized ?? false)")
        }
    }
    
    // Method to check if we need to request authorization
    func checkAndRequestAuthorizationIfNeeded() {
        if authorizationStatus == .notDetermined {
            print("🏥 Authorization not determined, requesting...")
            requestAuthorization()
        } else {
            print("🏥 Authorization already determined: \(authorizationStatus.rawValue)")
        }
    }
    
    func saveWorkout(startDate: Date, endDate: Date, calories: Double, distance: Double, weight: Double) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        builder.beginCollection(withStart: startDate) { success, error in
            guard success else { return }
            
            // Add distance sample
            if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                let distanceQuantity = HKQuantity(unit: .mile(), doubleValue: distance)
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
                let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
                let calorieSample = HKQuantitySample(
                    type: calorieType,
                    quantity: calorieQuantity,
                    start: startDate,
                    end: endDate,
                    metadata: [
                        "RuckWeight": weight,
                        "AppName": "RuckTracker-Watch",
                        "WorkoutType": "Rucking"
                    ]
                )
                builder.add([calorieSample]) { _, _ in }
            }
            
            // End collection and finish workout
            builder.endCollection(withEnd: endDate) { success, error in
                if success {
                    builder.finishWorkout { _, _ in
                        // Workout saved
                    }
                }
            }
        }
    }
}
