// SupabaseManager.swift
import Supabase
import Foundation

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    // MARK: - User State Properties
    
    /// Indicates if the current user is anonymous (no email connected)
    /// This is the default state for new users - they have a session but no email
    var isAnonymousUser: Bool {
        guard let user = currentUser else { return false }
        return user.isAnonymous
    }
    
    /// Indicates if the user has connected an email (confirmed or pending confirmation)
    /// This determines if the user is a "Connected User" vs "App User" (anonymous)
    var hasEmail: Bool {
        guard let user = currentUser else { return false }
        // Check both email (confirmed) and newEmail (pending confirmation)
        let hasConfirmedEmail = user.email != nil && !(user.email?.isEmpty ?? true)
        let hasPendingEmail = user.newEmail != nil && !(user.newEmail?.isEmpty ?? true)
        return hasConfirmedEmail || hasPendingEmail
    }
    
    /// Returns the user's email address (confirmed or pending)
    var userEmail: String? {
        guard let user = currentUser else { return nil }
        // Return confirmed email if available, otherwise pending email
        if let email = user.email, !email.isEmpty {
            return email
        }
        return user.newEmail
    }
    
    /// User type for UI display purposes
    /// - Returns: "App User" for anonymous, "Connected" for users with email
    var userTypeDisplay: String {
        if !isAuthenticated {
            return "Not Connected"
        }
        return hasEmail ? "Connected" : "App User"
    }
    
    /// Indicates if user can sign out
    /// Anonymous users without email cannot sign out (would lose their data)
    var canSignOut: Bool {
        return isAuthenticated && hasEmail
    }
    
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
    func updateUserEmail(email: String, password: String) async throws {
        // For anonymous users, we need to convert them to a full authenticated account
        // The Supabase update method requires email confirmation by default
        // Instead, we'll use updateUser with email change confirmation disabled
        
        print("🔐 Attempting to update user with email: \(email)")
        
        // Update both email and password for the anonymous user
        // This should convert them to a full account
        let updatedUser = try await client.auth.update(
            user: UserAttributes(
                email: email,
                password: password,
                data: nil as [String: AnyJSON]?
            )
        )
        
        print("🔐 Update response received - User ID: \(updatedUser.id)")
        print("🔐 Update response - Email: \(updatedUser.email ?? "nil"), Anonymous: \(updatedUser.isAnonymous)")
        print("🔐 Update response - New Email: \(updatedUser.newEmail ?? "nil")")
        
        // Update local state with the new user info immediately
        self.currentUser = updatedUser
        
        // Note: If email confirmation is required in Supabase settings,
        // the email will be in user.newEmail until confirmed
        // For now, we'll treat the account as upgraded even if email is pending confirmation
        
        print("🔐 Successfully updated anonymous account")
        print("🔐 Updated user state - isAuthenticated: \(isAuthenticated), hasEmail: \(hasEmail), isAnonymous: \(isAnonymousUser)")
        print("🔐 Current user email: \(currentUser?.email ?? "nil")")
        print("🔐 Current user new email (pending confirmation): \(currentUser?.newEmail ?? "nil")")
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
