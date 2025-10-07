import SwiftUI

/// ContentView - Main entry point for the app
///
/// Key Behavior:
/// - NO authentication wall - users start using immediately
/// - Auto-creates anonymous session on first launch
/// - Users are ALWAYS authenticated (either anonymous or connected)
/// - Never blocks user from accessing the app
struct ContentView: View {
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    @ObservedObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var authService = AuthService()
    
    var body: some View {
        // Always show main view - no authentication gate
        // Users always have a session (anonymous or connected)
        ImprovedPhoneMainView()
            .environmentObject(healthManager)
            .environmentObject(workoutManager)
            .environmentObject(workoutDataManager)
            .environmentObject(supabaseManager)
            .environmentObject(authService)
            .onAppear {
                print("📱 ContentView appeared")
                print("📱 Authentication state: \(supabaseManager.userTypeDisplay)")
                healthManager.requestAuthorization()
                
                // Ensure user has a session (create anonymous if needed)
                Task {
                    await ensureUserSession()
                }
            }
            .onChange(of: supabaseManager.isAuthenticated) { isAuthenticated in
                print("🔄 Authentication state changed: \(supabaseManager.userTypeDisplay)")
                print("🔄 User ID: \(supabaseManager.currentUser?.id.uuidString ?? "none")")
                print("🔄 Has email: \(supabaseManager.hasEmail)")
                print("🔄 Is anonymous: \(supabaseManager.isAnonymousUser)")
            }
    }
    
    /// Ensures user always has a session
    /// - New users: Creates anonymous session automatically
    /// - Returning users: Restores existing session
    private func ensureUserSession() async {
        print("🔐 Checking for existing session...")
        
        // Check for existing session (anonymous or connected)
        await supabaseManager.checkForExistingSession()
        
        // If no session exists, create a new anonymous session
        // This ensures first-time users can start using the app immediately
        if !supabaseManager.isAuthenticated {
            do {
                try await authService.signInAnonymously()
                print("✅ Created new anonymous session (App User)")
                print("✅ User ID: \(supabaseManager.currentUser?.id.uuidString ?? "unknown")")
            } catch {
                print("❌ Failed to create anonymous session: \(error)")
            }
        } else {
            print("✅ Restored existing session: \(supabaseManager.userTypeDisplay)")
            print("✅ User ID: \(supabaseManager.currentUser?.id.uuidString ?? "unknown")")
        }
    }
}

#Preview {
    ContentView()
}
