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
    
    // Platform detection
    private var isWatchApp: Bool {
        #if os(watchOS)
        return true
        #else
        return false
        #endif
    }
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() {
        print("🏥 \(platformName): Requesting HealthKit authorization")
        
        // Guard against duplicate requests
        guard !authorizationInProgress else {
            print("⚠️ \(platformName): Authorization already in progress, skipping duplicate request")
            return
        }
        
        // Don't request again if already authorized
        guard !isAuthorized else {
            print("ℹ️ \(platformName): Already authorized, skipping request")
            return
        }
        
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
        
        // Different permission sets for iPhone vs Watch
        let typesToRead: Set<HKObjectType>
        let typesToWrite: Set<HKSampleType>
        
        if isWatchApp {
            // Watch can read and write everything
            typesToRead = [
                heartRateType,
                caloriesType,
                distanceType,
                HKWorkoutType.workoutType()
            ]
            typesToWrite = [
                HKWorkoutType.workoutType(),
                caloriesType,
                distanceType,
                heartRateType
            ]
        } else {
            // iPhone: Don't request heart rate (it will be denied anyway)
            typesToRead = [
                caloriesType,
                distanceType,
                HKWorkoutType.workoutType()
            ]
            typesToWrite = [
                HKWorkoutType.workoutType(),
                caloriesType,
                distanceType
            ]
        }
        
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
                    print("🏥 \(self?.platformName ?? "Unknown") authorization completed successfully")
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
        
        print("🏥 \(platformName) Authorization Status:")
        print("  - Heart Rate: \(heartRateStatus.rawValue) \(heartRateStatus.description)")
        print("  - Calories: \(caloriesStatus.rawValue) \(caloriesStatus.description)")
        print("  - Distance: \(distanceStatus.rawValue) \(distanceStatus.description)")
        print("  - Workout: \(workoutStatus.rawValue) \(workoutStatus.description)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update individual permission status
            self.hasHeartRatePermission = heartRateStatus == .sharingAuthorized
            self.hasCaloriesPermission = caloriesStatus == .sharingAuthorized
            self.hasDistancePermission = distanceStatus == .sharingAuthorized
            self.hasWorkoutPermission = workoutStatus == .sharingAuthorized
            
            // Handle permission issues (but ignore heart rate denial on iPhone)
            var deniedPermissions: [String] = []
            var notDeterminedPermissions: [String] = []
            
            // Only check heart rate permissions on Watch
            if self.isWatchApp {
                if heartRateStatus == .sharingDenied {
                    deniedPermissions.append("Heart Rate")
                } else if heartRateStatus == .notDetermined {
                    notDeterminedPermissions.append("Heart Rate")
                }
            } else {
                // On iPhone, heart rate denial is expected - don't treat as error
                if heartRateStatus == .sharingDenied {
                    print("ℹ️ iPhone: Heart rate access denied (expected - requires Apple Watch)")
                }
            }
            
            // Check other permissions
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
            
            // Clear any existing heart rate errors if we're on iPhone
            if !self.isWatchApp {
                self.errorManager.clearError()
            }
            
            // Handle errors for denied permissions (excluding expected iPhone heart rate)
            if !deniedPermissions.isEmpty {
                let error = HealthKitError.authorizationDenied(dataType: deniedPermissions.joined(separator: ", "))
                self.errorManager.handleError(error, context: "Permission Check")
            }
            
            // Handle not determined permissions
            if !notDeterminedPermissions.isEmpty {
                let error = HealthKitError.authorizationNotDetermined
                self.errorManager.handleError(error, context: "Permission Check")
            }
            
            // Consider authorized if we have essential permissions
            let hasEssentialPermissions: Bool
            if self.isWatchApp {
                // Watch needs workout, calories, and distance - heart rate is optional but preferred
                // Don't block workout functionality if user denies heart rate permission
                hasEssentialPermissions = workoutStatus == .sharingAuthorized &&
                                        caloriesStatus == .sharingAuthorized &&
                                        distanceStatus == .sharingAuthorized
                                        // Note: heartRateStatus is checked separately and logged but not required
            } else {
                // iPhone needs workout, calories, and distance (heart rate not available)
                hasEssentialPermissions = workoutStatus == .sharingAuthorized &&
                                        caloriesStatus == .sharingAuthorized &&
                                        distanceStatus == .sharingAuthorized
            }
            
            self.isAuthorized = hasEssentialPermissions
            
            if !hasEssentialPermissions && deniedPermissions.isEmpty && notDeterminedPermissions.isEmpty {
                // Unknown authorization failure
                let error = HealthKitError.authorizationFailed(underlying: nil)
                self.errorManager.handleError(error, context: "Permission Check")
            }
            
            print("🏥 \(self.platformName): Final authorization status: \(self.isAuthorized)")
            
            // Log platform-specific status
            if self.isWatchApp {
                if heartRateStatus == .sharingAuthorized {
                    print("📱 Watch: Full HealthKit integration available (including heart rate)")
                } else {
                    print("📱 Watch: HealthKit available but heart rate permission missing")
                    print("   Heart Rate Status: \(heartRateStatus.description)")
                    print("   Workouts will still function, but heart rate data won't be collected")
                }
            } else {
                print("📱 iPhone: Limited HealthKit (no heart rate) - use Watch for full tracking")
            }
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
                        print("✅ \(self.platformName): Distance sample added")
                    }
                }
            } else {
                print("⚠️ \(self.platformName): Skipping distance sample - no permission or type unavailable")
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
                        "AppName": "RuckTracker-\(self.platformName)",
                        "Terrain": "Flat",
                        "GPS": self.isWatchApp ? "Full" : "Limited"
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
                        print("✅ \(self.platformName): Calorie sample added")
                    }
                }
            } else {
                print("⚠️ \(self.platformName): Skipping calorie sample - no permission or type unavailable")
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
                        print("✅ \(self.platformName): Workout saved successfully using modern HKWorkoutBuilder")
                        print("📊 \(self.platformName): Saved workout with ID: \(workout.uuid)")
                        
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
            print("🔄 \(platformName): Retrying HealthKit authorization...")
            requestAuthorization()
        }
    }
    
    /// Check if we can save workouts with current permissions
    func canSaveWorkouts() -> Bool {
        return isAuthorized && hasWorkoutPermission && hasCaloriesPermission && hasDistancePermission
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
            // Don't show heart rate errors on iPhone
            if !isWatchApp, case .authorizationDenied(let dataType) = currentError, dataType.contains("Heart Rate") {
                return "HealthKit connected (heart rate requires Apple Watch)"
            }
            return currentError.localizedDescription
        }
        
        if isAuthorized {
            if isWatchApp {
                if hasHeartRatePermission {
                    return "HealthKit fully connected"
                } else {
                    return "HealthKit connected (heart rate optional)"
                }
            } else {
                return "HealthKit connected (use Apple Watch for heart rate)"
            }
        }
        
        // Not authorized - provide specific guidance
        if isWatchApp {
            var missingPermissions: [String] = []
            if !hasWorkoutPermission { missingPermissions.append("Workouts") }
            if !hasCaloriesPermission { missingPermissions.append("Calories") }
            if !hasDistancePermission { missingPermissions.append("Distance") }
            
            if missingPermissions.isEmpty {
                return "Grant HealthKit permissions to start tracking"
            } else {
                return "Missing: \(missingPermissions.joined(separator: ", "))"
            }
        } else {
            return "HealthKit permissions needed"
        }
    }
    
    /// Get recovery instructions for when permissions are denied
    func getRecoveryInstructions() -> String {
        if isAuthorized {
            return "HealthKit is working properly"
        }
        
        if authorizationInProgress {
            return "Please wait for authorization to complete"
        }
        
        var instructions: [String] = []
        
        if !hasWorkoutPermission || !hasCaloriesPermission || !hasDistancePermission {
            if isWatchApp {
                instructions.append("1. Open Health app on your iPhone")
                instructions.append("2. Go to Sharing > Apps > RuckTracker")
                instructions.append("3. Enable required permissions")
                instructions.append("4. Restart RuckTracker on Apple Watch")
            } else {
                instructions.append("1. Open Health app on iPhone")
                instructions.append("2. Go to Sharing > Apps > RuckTracker")
                instructions.append("3. Enable Workouts, Calories, and Distance")
            }
        }
        
        if instructions.isEmpty {
            instructions.append("Try restarting the app and granting permissions again")
        }
        
        return instructions.joined(separator: "\n")
    }
    
    /// Check if we should show a fallback mode (local-only tracking)
    var shouldOfferFallbackMode: Bool {
        // If HealthKit is completely unavailable or user has denied critical permissions
        return !HKHealthStore.isHealthDataAvailable() || 
               (!isAuthorized && errorManager.currentError != nil)
    }
    
    // MARK: - Helper Properties
    
    private var platformName: String {
        return isWatchApp ? "Watch" : "iPhone"
    }
}

// MARK: - HKAuthorizationStatus Extension
extension HKAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "(not determined)"
        case .sharingDenied:
            return "(denied)"
        case .sharingAuthorized:
            return "(authorized)"
        @unknown default:
            return "(unknown)"
        }
    }
}
