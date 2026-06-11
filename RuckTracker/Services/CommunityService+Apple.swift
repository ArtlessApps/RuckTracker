import Foundation
import Supabase

// MARK: - Sign in with Apple
//
// This extension adds two methods to CommunityService:
//
// 1. signInWithApple()  — hands Apple's identity token to Supabase.
//                         Returns true if the user still needs a username
//                         (i.e. they are brand new).
//
// 2. setUsernameAfterAppleSignIn() — called right after, if needed.
//
// Both are called from ProfileCreationStep after the native Apple sheet closes.

extension CommunityService {

    /// Exchange Apple's identity token for a Supabase session.
    ///
    /// - Parameters:
    ///   - idToken: The JWT string from `ASAuthorizationAppleIDCredential.identityToken`
    ///   - nonce:   The plain-text nonce you generated — Supabase re-hashes it to verify
    ///   - email:   Only present on the FIRST Apple sign-in. Nil on all subsequent ones.
    ///   - fullName: Same — only present once, then Apple stops sending it.
    ///
    /// - Returns: `true` if this user has no username yet and needs to pick one.
    func signInWithApple(
        idToken: String,
        nonce: String,
        email: String?,
        fullName: PersonNameComponents?
    ) async throws -> Bool {

        // Hand the token to Supabase. It verifies it with Apple's servers,
        // then creates or restores the user's session automatically.
        try await supabaseClient.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        print("✅ [Apple] Supabase session created — user: \(supabaseClient.auth.currentUser?.id.uuidString ?? "unknown")")

        // Try loading their profile. A brand-new Apple user may not have one yet
        // if the DB trigger hasn't fired, so we allow this to fail silently.
        try? await loadCurrentProfile()

        // Wire up UserSettings and Premium to this user's account
        if let userId = supabaseClient.auth.currentUser?.id {
            await UserSettings.shared.switchToUser(userId)
            PremiumManager.shared.evaluatePremiumForNewUser()
        }

        // If the profile has no username, this user needs to pick one
        let username = currentProfile?.username.trimmingCharacters(in: .whitespaces) ?? ""
        return username.isEmpty
    }

    /// Saves a username for a user who just signed in with Apple for the first time.
    ///
    /// We use `upsert` rather than `update` because the DB trigger may not
    /// have created the profile row yet when Apple sign-in is fast.
    func setUsernameAfterAppleSignIn(_ username: String) async throws {
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }

        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw CommunityError.authenticationFailed("Username cannot be blank.")
        }

        if let available = try? await isUsernameAvailable(trimmed), !available {
            throw CommunityError.duplicateUsername
        }

        do {
            // Upsert: creates the row if missing, updates it if it already exists
            try await supabaseClient
                .from("profiles")
                .upsert(["id": userId.uuidString, "username": trimmed])
                .execute()
        } catch {
            throw CommunityError.fromSignUpError(error)
        }

        // Reload so currentProfile reflects the new username everywhere in the app
        try await loadCurrentProfile()
        try? await loadMyClubs()
        PremiumManager.shared.evaluatePremiumForNewUser()

        print("✅ [Apple] Username saved: \(trimmed)")
    }
}
