import SwiftUI

struct ContentView: View {
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    @ObservedObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var authService = AuthService()
    
    var body: some View {
        // Always show main view - users always have a session (anonymous or authenticated)
        ImprovedPhoneMainView()
            .environmentObject(healthManager)
            .environmentObject(workoutManager)
            .environmentObject(workoutDataManager)
            .environmentObject(supabaseManager)
            .environmentObject(authService)
            .onAppear {
                print("📱 ContentView appeared - isAuthenticated: \(supabaseManager.isAuthenticated)")
                healthManager.requestAuthorization()
                
                // Auto-create anonymous session if no session exists
                Task {
                    await ensureUserSession()
                }
            }
            .onChange(of: supabaseManager.isAuthenticated) { isAuthenticated in
                print("🔄 ContentView detected auth state change: \(isAuthenticated)")
                print("🔄 Current SupabaseManager state - isAuthenticated: \(supabaseManager.isAuthenticated), currentUser: \(supabaseManager.currentUser?.id.uuidString ?? "nil")")
            }
    }
    
    // Ensure user always has a session (anonymous or authenticated)
    private func ensureUserSession() async {
        // First check if there's an existing session
        await supabaseManager.checkForExistingSession()
        
        // If no session exists, automatically create an anonymous one
        if !supabaseManager.isAuthenticated {
            do {
                try await authService.signInAnonymously()
                print("✅ Auto-created anonymous session for new user")
            } catch {
                print("❌ Failed to create anonymous session: \(error)")
            }
        } else {
            print("✅ User has existing session")
        }
    }
}

#Preview {
    ContentView()
}
