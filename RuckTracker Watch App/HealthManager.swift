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
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.checkAuthorizationStatus()
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return
        }
        
        let status = healthStore.authorizationStatus(for: heartRateType)
        
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
            
            switch status {
            case .notDetermined:
                self?.isAuthorized = false
            case .sharingDenied:
                // Note: Due to watchOS HealthKit API bug, this may incorrectly show denied
                // even when permissions actually work. The WorkoutManager will test actual access.
                self?.isAuthorized = false
            case .sharingAuthorized:
                self?.isAuthorized = true
            @unknown default:
                self?.isAuthorized = false
            }
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
