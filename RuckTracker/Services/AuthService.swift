// Services/AuthService.swift
import Foundation
import SwiftUI
import Supabase

class AuthService: ObservableObject {
    private let supabase = SupabaseManager.shared.client
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    func signInAnonymously() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let session = try await supabase.auth.signInAnonymously()
        
        await MainActor.run {
            self.isAuthenticated = true
            SupabaseManager.shared.currentUser = session.user
            SupabaseManager.shared.isAuthenticated = true
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
    
    func signInWithApple() async throws {
        // Implement Apple Sign In
        // This will be important for subscription management
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
