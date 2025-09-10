import Foundation
import HealthKit

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore() // Made public for WorkoutManager access
    @Published var isAuthorized = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() {
        print("DEBUG: requestAuthorization called")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("DEBUG: HealthKit not available")
            return
        }
        
        print("DEBUG: HealthKit available, requesting permissions")
        
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
        
        print("DEBUG: About to call requestAuthorization")
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            print("DEBUG: Authorization callback - success: \(success), error: \(error?.localizedDescription ?? "none")")
            
            // Check individual permissions
            if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                let heartRateStatus = self?.healthStore.authorizationStatus(for: heartRateType)
                print("DEBUG: Heart rate auth status after request: \(heartRateStatus?.rawValue ?? -1)")
            }
            
            DispatchQueue.main.async {
                self?.isAuthorized = success
                self?.checkAuthorizationStatus() // Refresh status
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("DEBUG: Heart rate type unavailable")
            return
        }
        
        let status = healthStore.authorizationStatus(for: heartRateType)
        print("DEBUG: checkAuthorizationStatus - Heart rate status: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            print("DEBUG: Heart rate permission not determined")
            isAuthorized = false
        case .sharingDenied:
            print("DEBUG: Heart rate permission denied")
            isAuthorized = false
        case .sharingAuthorized:
            print("DEBUG: Heart rate permission authorized")
            isAuthorized = true
        @unknown default:
            print("DEBUG: Unknown heart rate permission status")
            isAuthorized = false
        }
    }
    
    // Force permission request - call this if needed
    func forcePermissionRequest() {
        print("DEBUG: Force permission request called")
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { [weak self] success, error in
            print("DEBUG: Force request result - success: \(success), error: \(error?.localizedDescription ?? "none")")
            DispatchQueue.main.async {
                self?.checkAuthorizationStatus()
            }
        }
    }
    
    func saveWorkout(startDate: Date, endDate: Date, calories: Double, distance: Double, weight: Double) {
        // This function has the deprecated HKWorkout initializer
        // Should be updated to use HKWorkoutBuilder like in WorkoutManager
        print("DEBUG: saveWorkout called - consider using WorkoutManager's saveWorkoutToHealth instead")
        
        let workout = HKWorkout(
            activityType: .walking,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
            totalDistance: HKQuantity(unit: .mile(), doubleValue: distance),
            metadata: ["RuckWeight": weight]
        )
        
        healthStore.save(workout) { success, error in
            if success {
                print("Workout saved successfully")
            } else {
                print("Error saving workout: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}
