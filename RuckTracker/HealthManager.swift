import Foundation
import HealthKit

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() {
        print("🏥 iPhone: Requesting HealthKit authorization")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available")
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            print("🏥 iPhone authorization result - success: \(success)")
            if let error = error {
                print("❌ iPhone authorization error: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                self?.isAuthorized = success
                self?.checkAuthorizationStatus()
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("❌ Heart rate type unavailable")
            return
        }
        
        let status = healthStore.authorizationStatus(for: heartRateType)
        print("🏥 iPhone heart rate permission status: \(status.rawValue)")
        
        DispatchQueue.main.async { [weak self] in
            switch status {
            case .notDetermined:
                print("⚠️ iPhone: Permission not determined")
                self?.isAuthorized = false
            case .sharingDenied:
                print("❌ iPhone: Permission denied")
                self?.isAuthorized = false
            case .sharingAuthorized:
                print("✅ iPhone: Permission authorized")
                self?.isAuthorized = true
            @unknown default:
                print("❓ iPhone: Unknown permission status")
                self?.isAuthorized = false
            }
        }
    }
    
    func saveWorkout(startDate: Date, endDate: Date, calories: Double, distance: Double, weight: Double) {
        // Use modern HKWorkoutBuilder API (replaces deprecated HKWorkout initializer)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        builder.beginCollection(withStart: startDate) { [weak self] success, error in
            guard success else {
                print("❌ iPhone: Failed to begin workout collection: \(error?.localizedDescription ?? "")")
                return
            }
            
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
                        "AppName": "RuckTracker-iPhone",
                        "Terrain": "flat",
                        "GPS": "Limited"
                    ]
                )
                builder.add([calorieSample]) { _, _ in }
            }
            
            // End collection and finish workout
            builder.endCollection(withEnd: endDate) { success, error in
                if success {
                    builder.finishWorkout { workout, error in
                        if workout != nil {
                            print("✅ iPhone: Workout saved successfully using modern HKWorkoutBuilder")
                        } else {
                            print("❌ iPhone: Failed to save workout: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                } else {
                    print("❌ iPhone: Failed to end collection: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
}
