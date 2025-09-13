// RuckTracker Watch App/RuckTrackerApp.swift
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
                    
                    // Set up the connection between managers
                    workoutManager.setHealthManager(healthManager)
                    
                    // Request permissions
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        healthManager.requestAuthorization()
                    }
                }
        }
    }
}
