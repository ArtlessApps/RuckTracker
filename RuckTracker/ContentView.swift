import SwiftUI

struct ContentView: View {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some View {
        PhoneMainView()
            .environmentObject(healthManager)
            .environmentObject(workoutManager)
            .onAppear {
                healthManager.requestAuthorization()
            }
    }
}

#Preview {
    ContentView()
}
