// SupabaseManager.swift
import Supabase
import Foundation

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private init() {
        guard let url = URL(string: "YOUR_SUPABASE_URL"),
              let key = "YOUR_SUPABASE_ANON_KEY" else {
            fatalError("Missing Supabase configuration")
        }
        
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
