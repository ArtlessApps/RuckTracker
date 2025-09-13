import SwiftUI

@main
struct RuckTrackerApp: App {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
                .environmentObject(workoutManager)
                .environmentObject(workoutDataManager)
                .onAppear {
                    healthManager.requestAuthorization()
                }
        }
    }
}
