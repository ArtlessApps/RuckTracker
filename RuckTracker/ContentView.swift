//
//  ContentView.swift
//  MARCH
//
//  Updated with onboarding flow
//

import SwiftUI

struct ContentView: View {
    @StateObject private var healthManager = HealthManager.shared
    @EnvironmentObject var workoutManager: WorkoutManager
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var showingSplash = true
    
    var body: some View {
        Group {
            if showingSplash {
                SplashScreenView(showingSplash: $showingSplash)
                    .environmentObject(healthManager)
                    .environmentObject(workoutManager)
                    .environmentObject(workoutDataManager)
                    .environmentObject(premiumManager)
            } else if !userSettings.hasCompletedOnboarding {
                PhoneOnboardingView(hasCompletedOnboarding: $userSettings.hasCompletedOnboarding)
                    .environmentObject(healthManager)
                    .environmentObject(workoutManager)
                    .environmentObject(workoutDataManager)
                    .environmentObject(premiumManager)
            } else {
                MainTabView()
                    .environmentObject(healthManager)
                    .environmentObject(workoutManager)
                    .environmentObject(workoutDataManager)
                    .environmentObject(premiumManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
