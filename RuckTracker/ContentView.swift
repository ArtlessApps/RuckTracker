import SwiftUI

struct ContentView: View {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    
    var body: some View {
        ImprovedPhoneMainView()
            .environmentObject(healthManager)
            .environmentObject(workoutManager)
            .environmentObject(workoutDataManager)
            .onAppear {
                healthManager.requestAuthorization()
            }
    }
}

#Preview {
    ContentView()
}
