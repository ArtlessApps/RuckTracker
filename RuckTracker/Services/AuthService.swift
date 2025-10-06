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
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        
        await MainActor.run {
            self.isAuthenticated = false
            SupabaseManager.shared.currentUser = nil
            SupabaseManager.shared.isAuthenticated = false
        }
    }
}
