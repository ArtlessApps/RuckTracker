import SwiftUI

@main
struct RuckTracker_Watch_AppApp: App {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environmentObject(healthManager)
                .environmentObject(workoutManager)
                .onAppear {
                    print("🏥 Watch App launched - requesting HealthKit authorization...")
                    
                    // Delay the health request slightly to ensure the UI is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        healthManager.requestAuthorization()
                        workoutManager.setHealthManager(healthManager)
                    }
                }
        }
    }
}
