import SwiftUI

struct ContentView: View {
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    
    var body: some View {
        ImprovedPhoneMainView()
            .environmentObject(healthManager)
            .environmentObject(workoutManager)
            .environmentObject(workoutDataManager)
            .environmentObject(premiumManager)
    }
}

#Preview {
    ContentView()
}
