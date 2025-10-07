// Services/AuthService.swift
import Foundation
import SwiftUI
import Supabase

@MainActor
class AuthService: ObservableObject {
    private let supabase = SupabaseManager.shared.client
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    func signInAnonymously() async throws {
        print("🔄 Starting anonymous authentication...")
        isLoading = true
        defer { isLoading = false }
        
        do {
            let session = try await supabase.auth.signInAnonymously()
            print("✅ Supabase anonymous auth successful, user ID: \(session.user.id)")
            
            await MainActor.run {
                self.isAuthenticated = true
                SupabaseManager.shared.currentUser = session.user
                SupabaseManager.shared.isAuthenticated = true
                print("✅ AuthService and SupabaseManager updated - isAuthenticated: \(self.isAuthenticated)")
            }
        } catch {
            print("❌ Supabase anonymous auth failed: \(error)")
            throw error
        }
    }
    
    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let session = try await supabase.auth.signIn(email: email, password: password)
        
        await MainActor.run {
            self.isAuthenticated = true
            SupabaseManager.shared.currentUser = session.user
            SupabaseManager.shared.isAuthenticated = true
            
            // Update user settings with email
            UserSettings.shared.email = session.user.email
        }
    }
    
    func signUpWithEmail(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let session = try await supabase.auth.signUp(email: email, password: password)
        
        await MainActor.run {
            self.isAuthenticated = true
            SupabaseManager.shared.currentUser = session.user
            SupabaseManager.shared.isAuthenticated = true
            
            // Update user settings with email
            UserSettings.shared.email = session.user.email
        }
    }
    
    func linkEmailToAnonymousAccount(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Verify user is currently anonymous
        guard SupabaseManager.shared.isAnonymousUser else {
            throw NSError(domain: "AuthService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "User is not anonymous - cannot link email"
            ])
        }
        
        // Update the anonymous user with email and password
        try await SupabaseManager.shared.updateUserEmail(email: email, password: password)
        
        await MainActor.run {
            // Update user settings with new email
            UserSettings.shared.email = email
            print("✅ Successfully upgraded anonymous account to authenticated account")
        }
    }
    
    func signOut() async throws {
        print("🔄 Starting sign out process...")
        
        // Only sign out if user has an email (authenticated user)
        // Anonymous users should never truly "sign out"
        guard !SupabaseManager.shared.isAnonymousUser else {
            print("⚠️ Cannot sign out anonymous user - session preserved")
            return
        }
        
        // Clear the authenticated session
        await SupabaseManager.shared.clearSession()
        
        await MainActor.run {
            self.isAuthenticated = false
            print("✅ Signed out authenticated user")
        }
        
        // Automatically create a new anonymous session
        do {
            try await signInAnonymously()
            print("✅ Created new anonymous session after sign out")
        } catch {
            print("❌ Failed to create new anonymous session: \(error)")
            throw error
        }
    }
}
