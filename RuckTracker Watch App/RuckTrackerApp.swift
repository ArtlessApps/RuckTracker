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
                    print("🏥 Watch App launched - setting up managers...")
                    
                    // Set up the connection between managers
                    workoutManager.setHealthManager(healthManager)
                    workoutManager.setWatchConnectivityManager(watchConnectivityManager)
                    watchConnectivityManager.setWorkoutDataManager(workoutDataManager)
                    
                    // Note: HealthKit authorization now happens during onboarding flow
                    // This provides better user experience with proper context
                }
        }
    }
}
