import SwiftUI

struct ContentView: View {
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    @ObservedObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var authService = AuthService()
    
    var body: some View {
        Group {
            if supabaseManager.isAuthenticated {
                ImprovedPhoneMainView()
                    .environmentObject(healthManager)
                    .environmentObject(workoutManager)
                    .environmentObject(workoutDataManager)
                    .environmentObject(supabaseManager)
                    .environmentObject(authService)
            } else {
                AuthenticationRequiredView()
                    .environmentObject(authService)
                    .environmentObject(supabaseManager)
            }
        }
        .onAppear {
            print("📱 ContentView appeared - isAuthenticated: \(supabaseManager.isAuthenticated)")
            healthManager.requestAuthorization()
        }
        .onChange(of: supabaseManager.isAuthenticated) { isAuthenticated in
            print("🔄 ContentView detected auth state change: \(isAuthenticated)")
        }
    }
}

#Preview {
    ContentView()
}
