import SwiftUI

struct ContentView: View {
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @State private var showingSplash = true
    
    var body: some View {
        if showingSplash {
            SplashScreenView(showingSplash: $showingSplash)
                .environmentObject(healthManager)
                .environmentObject(workoutManager)
                .environmentObject(workoutDataManager)
                .environmentObject(premiumManager)
        } else {
            ImprovedPhoneMainView()
                .environmentObject(healthManager)
                .environmentObject(workoutManager)
                .environmentObject(workoutDataManager)
                .environmentObject(premiumManager)
        }
    }
}

#Preview {
    ContentView()
}
