// RuckTracker Watch App/RuckTrackerApp.swift
import SwiftUI

@main
struct RuckTracker_Watch_AppApp: App {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    @StateObject private var watchConnectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environmentObject(healthManager)
                .environmentObject(workoutManager)
                .environmentObject(workoutDataManager)
                .onAppear {
                    print("🏥 Watch App launched - requesting HealthKit authorization...")
                    
                    // Set up the connection between managers
                    workoutManager.setHealthManager(healthManager)
                    workoutManager.setWatchConnectivityManager(watchConnectivityManager)
                    watchConnectivityManager.setWorkoutDataManager(workoutDataManager)
                    
                    // Request permissions immediately like before
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        healthManager.requestAuthorization()
                    }
                }
        }
    }
}
