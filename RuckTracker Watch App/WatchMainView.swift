import SwiftUI

struct WatchMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        // Go DIRECTLY to WorkoutView - no intermediate screen
        WorkoutView()
            .environmentObject(workoutManager)
    }
}

#Preview {
    WatchMainView()
        .environmentObject(WorkoutManager())
}
