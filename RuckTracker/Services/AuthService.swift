// Services/AuthService.swift
import Foundation
import SwiftUI
import Supabase

/// AuthService handles all authentication operations
/// 
/// User Types:
/// 1. Anonymous User (App User): Has session but no email - default state
/// 2. Connected User: Has session with email - can sync across devices
/// 
/// Premium Status: Independent of authentication - managed by StoreKit via Apple ID
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
    
    /// Sign out a connected user and create a new anonymous session
    /// 
    /// This method:
    /// 1. Only allows sign out for users with email (Connected Users)
    /// 2. Clears the current session
    /// 3. Creates a NEW anonymous session (fresh start)
    /// 4. Premium status persists if subscription is tied to Apple ID
    ///
    /// Note: Anonymous users (App Users) cannot sign out - they would lose their data
    func signOut() async throws {
        print("🔄 Starting sign out process...")
        
        // Only allow sign out for Connected Users (users with email)
        // Anonymous users cannot sign out to prevent data loss
        guard SupabaseManager.shared.canSignOut else {
            print("⚠️ Cannot sign out - user must have email to sign out (prevents data loss)")
            print("⚠️ Current state: isAuthenticated=\(SupabaseManager.shared.isAuthenticated), hasEmail=\(SupabaseManager.shared.hasEmail)")
            return
        }
        
        print("✅ User can sign out - proceeding...")
        
        // Clear the authenticated session
        await SupabaseManager.shared.clearSession()
        
        await MainActor.run {
            self.isAuthenticated = false
            print("✅ Signed out connected user")
        }
        
        // Automatically create a NEW anonymous session
        // This ensures user can continue using the app with a fresh anonymous account
        do {
            try await signInAnonymously()
            print("✅ Created new anonymous session after sign out")
            print("📊 New anonymous session - User ID: \(SupabaseManager.shared.currentUser?.id.uuidString ?? "unknown")")
        } catch {
            print("❌ Failed to create new anonymous session: \(error)")
            throw error
        }
    }
}
