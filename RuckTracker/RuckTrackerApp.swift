import SwiftUI

@main
struct RuckTrackerApp: App {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    @StateObject private var watchConnectivityManager = WatchConnectivityManager.shared
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
                .environmentObject(workoutManager)
                .environmentObject(workoutDataManager)
                .environmentObject(supabaseManager)
                .onAppear {
                    // Set up WatchConnectivity manager
                    watchConnectivityManager.setWorkoutDataManager(workoutDataManager)
                    
                    // Request HealthKit authorization
                    healthManager.requestAuthorization()
                    
                    // Request workouts from watch if available
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        watchConnectivityManager.requestWorkoutsFromWatch()
                    }
                }
        }
    }
}
