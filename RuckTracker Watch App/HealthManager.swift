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
        print("🏥 === MODERN WATCH HEALTHKIT AUTHORIZATION ===")
        print("🏥 Modern watchOS requires SEPARATE permissions from iPhone")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available")
            return
        }
        
        // In modern watchOS architecture, we MUST request permissions directly
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
        
        print("🏥 Requesting Watch-specific HealthKit permissions...")
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            print("🏥 Watch permission request completed:")
            print("   - Success: \(success)")
            print("   - Error: \(error?.localizedDescription ?? "none")")
            
            if let error = error {
                print("❌ Authorization error: \(error.localizedDescription)")
            }
            
            // Check status after request with delays for Watch UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.checkAuthorizationStatus()
                
                // Check again after longer delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self?.checkAuthorizationStatus()
                    
                    if !(self?.isAuthorized ?? false) {
                        print("⚠️ Still not authorized - permission may have been denied")
                        print("💡 Check: Settings → Privacy & Security → Health → Data Access → RuckTracker")
                    }
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("❌ Heart rate type unavailable")
            return
        }
        
        let status = healthStore.authorizationStatus(for: heartRateType)
        print("🏥 Watch heart rate permission status: \(status.rawValue)")
        
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
            
            switch status {
            case .notDetermined:
                print("⚠️ Watch: Permission not determined")
                self?.isAuthorized = false
            case .sharingDenied:
                print("❌ Watch: Permission DENIED")
                self?.isAuthorized = false
            case .sharingAuthorized:
                print("✅ Watch: Permission GRANTED!")
                self?.isAuthorized = true
                self?.testHeartRateAccess() // Test immediately when granted
            @unknown default:
                print("❓ Watch: Unknown permission status")
                self?.isAuthorized = false
            }
        }
    }
    
    // Test actual heart rate access
    private func testHeartRateAccess() {
        print("🧪 Testing actual heart rate data access...")
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("❌ Heart rate type unavailable for testing")
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-3600),
            end: Date(),
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        ) { query, samples, error in
            
            if let error = error {
                print("❌ Heart rate test query failed: \(error.localizedDescription)")
            } else {
                let count = samples?.count ?? 0
                print("✅ Heart rate test query succeeded - found \(count) recent samples")
                
                if count > 0, let latest = samples?.first as? HKQuantitySample {
                    let heartRate = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    print("💓 Latest heart rate: \(Int(heartRate)) bpm")
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    // Force permission request - useful for debugging or retry scenarios
    func forcePermissionRequest() {
        print("🔄 Force requesting Watch HealthKit permissions...")
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { [weak self] success, error in
            print("🏥 Force request result - success: \(success)")
            if let error = error {
                print("❌ Force request error: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.checkAuthorizationStatus()
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
                print("❌ Failed to begin workout collection: \(error?.localizedDescription ?? "")")
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
                        "AppName": "RuckTracker-Watch"
                    ]
                )
                builder.add([calorieSample]) { _, _ in }
            }
            
            // End collection and finish workout
            builder.endCollection(withEnd: endDate) { success, error in
                if success {
                    builder.finishWorkout { _, error in
                        if error == nil {
                            print("✅ Workout saved successfully using modern HKWorkoutBuilder")
                        } else {
                            print("❌ Failed to save workout: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                } else {
                    print("❌ Failed to end collection: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
}
