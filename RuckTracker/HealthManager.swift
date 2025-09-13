import Foundation
import HealthKit

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var errorManager = HealthKitErrorManager()
    @Published var authorizationInProgress = false
    
    // Track which permissions we have
    @Published var hasWorkoutPermission = false
    @Published var hasHeartRatePermission = false
    @Published var hasCaloriesPermission = false
    @Published var hasDistancePermission = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() {
        print("🏥 iPhone: Requesting HealthKit authorization")
        
        // Clear any previous errors
        errorManager.clearError()
        
        guard HKHealthStore.isHealthDataAvailable() else {
            let error = HealthKitError.healthDataNotAvailable
            errorManager.handleError(error, context: "Authorization Request")
            return
        }
        
        authorizationInProgress = true
        
        // Safely get health data types
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            let error = HealthKitError.quantityTypeUnavailable(identifier: "health data types")
            errorManager.handleError(error, context: "Authorization Request")
            authorizationInProgress = false
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            heartRateType,
            caloriesType,
            distanceType
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            caloriesType,
            distanceType
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.authorizationInProgress = false
                
                if let error = error {
                    let healthKitError = error.asHealthKitError
                    self?.errorManager.handleError(healthKitError, context: "Authorization Request")
                    self?.isAuthorized = false
                } else if !success {
                    let healthKitError = HealthKitError.authorizationFailed(underlying: nil)
                    self?.errorManager.handleError(healthKitError, context: "Authorization Request")
                    self?.isAuthorized = false
                } else {
                    print("🏥 iPhone authorization completed successfully")
                    self?.checkAuthorizationStatus()
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        // Safely get health data types
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            let error = HealthKitError.quantityTypeUnavailable(identifier: "health data types")
            errorManager.handleError(error, context: "Authorization Check")
            return
        }
        
        let workoutType = HKWorkoutType.workoutType()
        
        // Check individual permissions
        let heartRateStatus = healthStore.authorizationStatus(for: heartRateType)
        let caloriesStatus = healthStore.authorizationStatus(for: caloriesType)
        let distanceStatus = healthStore.authorizationStatus(for: distanceType)
        let workoutStatus = healthStore.authorizationStatus(for: workoutType)
        
        print("🏥 iPhone Authorization Status:")
        print("  - Heart Rate: \(heartRateStatus.rawValue)")
        print("  - Calories: \(caloriesStatus.rawValue)")
        print("  - Distance: \(distanceStatus.rawValue)")
        print("  - Workout: \(workoutStatus.rawValue)")
        
        DispatchQueue.main.async { [weak self] in
            // Update individual permission status
            self?.hasHeartRatePermission = heartRateStatus == .sharingAuthorized
            self?.hasCaloriesPermission = caloriesStatus == .sharingAuthorized
            self?.hasDistancePermission = distanceStatus == .sharingAuthorized
            self?.hasWorkoutPermission = workoutStatus == .sharingAuthorized
            
            // Check for permission issues
            var deniedPermissions: [String] = []
            var notDeterminedPermissions: [String] = []
            
            if heartRateStatus == .sharingDenied {
                deniedPermissions.append("Heart Rate")
            } else if heartRateStatus == .notDetermined {
                notDeterminedPermissions.append("Heart Rate")
            }
            
            if caloriesStatus == .sharingDenied {
                deniedPermissions.append("Active Calories")
            } else if caloriesStatus == .notDetermined {
                notDeterminedPermissions.append("Active Calories")
            }
            
            if distanceStatus == .sharingDenied {
                deniedPermissions.append("Distance")
            } else if distanceStatus == .notDetermined {
                notDeterminedPermissions.append("Distance")
            }
            
            if workoutStatus == .sharingDenied {
                deniedPermissions.append("Workouts")
            } else if workoutStatus == .notDetermined {
                notDeterminedPermissions.append("Workouts")
            }
            
            // Handle errors for denied permissions
            if !deniedPermissions.isEmpty {
                let error = HealthKitError.authorizationDenied(dataType: deniedPermissions.joined(separator: ", "))
                self?.errorManager.handleError(error, context: "Permission Check")
            }
            
            // Handle not determined permissions
            if !notDeterminedPermissions.isEmpty {
                let error = HealthKitError.authorizationNotDetermined
                self?.errorManager.handleError(error, context: "Permission Check")
            }
            
            // Consider authorized if we have essential permissions (workout and calories)
            let hasEssentialPermissions = workoutStatus == .sharingAuthorized && caloriesStatus == .sharingAuthorized
            self?.isAuthorized = hasEssentialPermissions
            
            if !hasEssentialPermissions && deniedPermissions.isEmpty && notDeterminedPermissions.isEmpty {
                // Unknown authorization failure
                let error = HealthKitError.authorizationFailed(underlying: nil)
                self?.errorManager.handleError(error, context: "Permission Check")
            }
            
            print("🏥 iPhone: Final authorization status: \(self?.isAuthorized ?? false)")
        }
    }
    
    func saveWorkout(startDate: Date, endDate: Date, calories: Double, distance: Double, weight: Double) {
        // Check if we're authorized before attempting to save
        guard isAuthorized else {
            let error = HealthKitError.insufficientPermissions(requiredTypes: ["Workouts", "Active Calories"])
            errorManager.handleError(error, context: "Workout Save")
            return
        }
        
        // Ensure HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            let error = HealthKitError.healthDataNotAvailable
            errorManager.handleError(error, context: "Workout Save")
            return
        }
        
        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        builder.beginCollection(withStart: startDate) { [weak self] success, error in
            guard let self = self else { return }
            
            if let error = error {
                let healthKitError = HealthKitError.workoutDataCollectionFailed(underlying: error)
                DispatchQueue.main.async {
                    self.errorManager.handleError(healthKitError, context: "Workout Collection Start")
                }
                return
            }
            
            guard success else {
                let healthKitError = HealthKitError.workoutBuilderCreationFailed(underlying: nil)
                DispatchQueue.main.async {
                    self.errorManager.handleError(healthKitError, context: "Workout Collection Start")
                }
                return
            }
            
            // Track which samples we successfully add
            var samplesAdded = 0
            let totalSamples = 2 // distance + calories
            
            // Add distance sample if we have permission
            if self.hasDistancePermission,
               let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                let distanceQuantity = HKQuantity(unit: .mile(), doubleValue: distance)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: startDate,
                    end: endDate
                )
                
                builder.add([distanceSample]) { success, error in
                    if let error = error {
                        let healthKitError = HealthKitError.workoutDataCollectionFailed(underlying: error)
                        DispatchQueue.main.async {
                            self.errorManager.handleError(healthKitError, context: "Distance Sample")
                        }
                    } else if success {
                        samplesAdded += 1
                        print("✅ iPhone: Distance sample added")
                    }
                }
            } else {
                print("⚠️ iPhone: Skipping distance sample - no permission or type unavailable")
            }
            
            // Add calorie sample if we have permission
            if self.hasCaloriesPermission,
               let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
                let calorieSample = HKQuantitySample(
                    type: calorieType,
                    quantity: calorieQuantity,
                    start: startDate,
                    end: endDate,
                    metadata: [
                        "RuckWeight": weight,
                        "AppName": "RuckTracker-iPhone",
                        "Terrain": "Flat",
                        "GPS": "Limited"
                    ]
                )
                
                builder.add([calorieSample]) { success, error in
                    if let error = error {
                        let healthKitError = HealthKitError.workoutDataCollectionFailed(underlying: error)
                        DispatchQueue.main.async {
                            self.errorManager.handleError(healthKitError, context: "Calorie Sample")
                        }
                    } else if success {
                        samplesAdded += 1
                        print("✅ iPhone: Calorie sample added")
                    }
                }
            } else {
                print("⚠️ iPhone: Skipping calorie sample - no permission or type unavailable")
            }
            
            // End collection and finish workout
            builder.endCollection(withEnd: endDate) { success, error in
                if let error = error {
                    let healthKitError = HealthKitError.workoutDataCollectionFailed(underlying: error)
                    DispatchQueue.main.async {
                        self.errorManager.handleError(healthKitError, context: "Workout Collection End")
                    }
                    return
                }
                
                guard success else {
                    let healthKitError = HealthKitError.workoutSaveFailed(underlying: nil)
                    DispatchQueue.main.async {
                        self.errorManager.handleError(healthKitError, context: "Workout Collection End")
                    }
                    return
                }
                
                builder.finishWorkout { workout, error in
                    if let error = error {
                        let healthKitError = HealthKitError.workoutSaveFailed(underlying: error)
                        DispatchQueue.main.async {
                            self.errorManager.handleError(healthKitError, context: "Workout Finish")
                        }
                    } else if let workout = workout {
                        print("✅ iPhone: Workout saved successfully using modern HKWorkoutBuilder")
                        print("📊 iPhone: Saved workout with ID: \(workout.uuid)")
                        
                        // Clear any previous save errors
                        DispatchQueue.main.async {
                            self.errorManager.clearError()
                        }
                    } else {
                        let healthKitError = HealthKitError.workoutSaveFailed(underlying: nil)
                        DispatchQueue.main.async {
                            self.errorManager.handleError(healthKitError, context: "Workout Finish")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Error Recovery Methods
    
    /// Retry authorization if previous attempt failed
    func retryAuthorization() {
        if errorManager.retryOperation() {
            print("🔄 iPhone: Retrying HealthKit authorization...")
            requestAuthorization()
        }
    }
    
    /// Check if we can save workouts with current permissions
    func canSaveWorkouts() -> Bool {
        return isAuthorized && hasWorkoutPermission && hasCaloriesPermission
    }
    
    /// Get a user-friendly status message
    func getHealthKitStatusMessage() -> String {
        if !HKHealthStore.isHealthDataAvailable() {
            return "HealthKit is not available on this device"
        }
        
        if authorizationInProgress {
            return "Requesting HealthKit permissions..."
        }
        
        if let currentError = errorManager.currentError {
            return currentError.localizedDescription
        }
        
        if isAuthorized {
            return "HealthKit is connected and ready"
        }
        
        return "HealthKit permissions needed"
    }
}
