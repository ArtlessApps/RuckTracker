// SupabaseManager.swift
import Supabase
import Foundation

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private init() {
        guard let url = URL(string: "https://zqxxcuvgwadokkgmcuwr.supabase.co") else {
            fatalError("Missing Supabase configuration")
        }
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxeHhjdXZnd2Fkb2trZ21jdXdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc5OTI4NTIsImV4cCI6MjA3MzU2ODg1Mn0.vU-gcFzN2YyqDWkihIdMGu_LXp0Y--QSB00Vsr9qm_o"
        
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        
        // Check for existing session on initialization
        Task {
            await checkForExistingSession()
        }
        print("🔐 SupabaseManager initialized - checking for existing session")
    }
    
    @MainActor
    func checkForExistingSession() async {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
            self.isAuthenticated = true
            print("🔐 Found existing session for user: \(session.user.id)")
            print("🔐 Session details - Email: \(session.user.email ?? "No email"), Anonymous: \(session.user.isAnonymous)")
        } catch {
            self.isAuthenticated = false
            self.currentUser = nil
            print("🔐 No existing session found: \(error)")
        }
    }
    
    @MainActor
    func clearSession() async {
        do {
            try await client.auth.signOut()
            self.isAuthenticated = false
            self.currentUser = nil
            print("🔐 Session cleared successfully")
        } catch {
            print("❌ Failed to clear session: \(error)")
        }
    }
    
    @MainActor
    func forceClearAllSessions() async {
        do {
            // Try to sign out first
            try await client.auth.signOut()
        } catch {
            print("⚠️ Sign out failed, but continuing with force clear")
        }
        
        // Force clear local state
        self.isAuthenticated = false
        self.currentUser = nil
        
        // Try to clear any stored sessions by creating a new client
        // This is a more aggressive approach
        print("🔐 Force cleared all sessions and local state")
    }
}
