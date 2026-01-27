import SwiftUI

struct WatchMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        Group {
            if userSettings.hasCompletedOnboarding {
                // Main workout interface
                if workoutManager.showPostWorkoutSummary {
                    PostWorkoutSummaryView()
                        .environmentObject(workoutManager)
                        .onAppear {
                            print("📱 PostWorkoutSummaryView appeared")
                        }
                } else {
                    WorkoutView()
                        .environmentObject(workoutManager)
                }
            } else {
                // Show onboarding for first-time users
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.5), value: userSettings.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.3), value: workoutManager.showPostWorkoutSummary)
    }
}

#Preview {
    WatchMainView()
        .environmentObject(WorkoutManager())
}
