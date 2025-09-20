// SupabaseManager.swift
import Supabase
import Foundation

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
        
        // Check if user is already logged in
        Task {
            await checkAuthStatus()
        }
    }
    
    @MainActor
    private func checkAuthStatus() async {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
            self.isAuthenticated = true
        } catch {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
}
