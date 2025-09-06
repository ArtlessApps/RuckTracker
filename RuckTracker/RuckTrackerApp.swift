import SwiftUI

@main
struct RuckTrackerApp: App {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
                .environmentObject(workoutManager)
                .onAppear {
                    healthManager.requestAuthorization()
                }
        }
    }
}
