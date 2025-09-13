import SwiftUI

struct WatchMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        Group {
            if workoutManager.showPostWorkoutSummary {
                PostWorkoutSummaryView()
                    .environmentObject(workoutManager)
            } else {
                WorkoutView()
                    .environmentObject(workoutManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: workoutManager.showPostWorkoutSummary)
    }
}

#Preview {
    WatchMainView()
        .environmentObject(WorkoutManager())
}
