import SwiftUI
import AuthenticationServices  // for SignInWithAppleButton and ASAuthorizationAppleIDCredential
import CryptoKit               // for SHA256 hashing of the nonce

// MARK: - ProfileCreationStep
//
// Step 10 of onboarding — shown right after the user pays.
//
// Offers two paths:
//   A) Continue with Apple  — one tap, no password, instant
//   B) Email + password     — traditional form
//
// After Apple sign-in, new users land on a lightweight username picker.
// Returning Apple users skip straight through.

struct ProfileCreationStep: View {

    /// Called when profile setup is complete (or skipped).
    var nextAction: () -> Void

    // Which screen is currently showing
    @State private var phase: Phase = .choosingMethod

    // ── Email/password form ──────────────────────────────────────────
    @State private var username = ""
    @State private var email    = ""
    @State private var password = ""

    // ── Apple sign-in ────────────────────────────────────────────────
    // The nonce is generated fresh each time the Apple button is tapped.
    // We store the plain-text version here so we can pass it to Supabase
    // after Apple returns the hashed version in the credential.
    @State private var appleNonce = ""

    // ── Username picker (shown after Apple auth for new users) ────────
    @State private var appleUsername = ""

    // ── Shared ───────────────────────────────────────────────────────
    @State private var isLoading    = false
    @State private var errorMessage: String?

    // MARK: - Phase enum

    enum Phase {
        case choosingMethod   // main screen — Apple button + email/password
        case needsUsername    // post-Apple, new user needs to pick a handle
    }

    // MARK: - Body

    var body: some View {
        switch phase {
        case .choosingMethod: choosingMethodView
        case .needsUsername:  usernamePickerView
        }
    }

    // MARK: - Choosing method

    private var choosingMethodView: some View {
        VStack(spacing: 0) {

            Spacer()

            // Header
            VStack(spacing: 12) {
                Text("🎉")
                    .font(.system(size: 52))

                Text("Trial started!")
                    .font(.title).bold()
                    .foregroundColor(AppColors.textPrimary)

                Text("Create a profile to track your ranking\nand connect with your ruck club.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 30)

            Spacer().frame(height: 32)

            VStack(spacing: 14) {

                // ── Apple button ────────────────────────────────────
                // SignInWithAppleButton is Apple's official SwiftUI component.
                // Using it keeps you compliant with Apple's HIG guidelines.
                SignInWithAppleButton(.continue) { request in
                    // Generate a fresh cryptographic nonce and store the plain-text
                    // version. We send the SHA-256 hash to Apple; Supabase re-hashes
                    // our plain-text to verify they match.
                    let nonce   = makeNonce()
                    appleNonce  = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce           = sha256(nonce)
                } onCompletion: { result in
                    Task { await handleAppleResult(result) }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(12)
                .disabled(isLoading)

                // ── Divider ─────────────────────────────────────────
                HStack {
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(AppColors.textSecondary.opacity(0.4))
                    Text("or")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(AppColors.textSecondary.opacity(0.4))
                }

                // ── Email/password form ─────────────────────────────
                VStack(spacing: 14) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)

                    SecureField("Password (6+ characters)", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                }

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 30)

            Spacer()

            // ── Bottom buttons ──────────────────────────────────────
            VStack(spacing: 12) {
                Button {
                    Task { await createWithEmail() }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                        }
                        Text("Create Profile")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primaryGradient)
                    .foregroundColor(AppColors.textPrimary)
                    .cornerRadius(12)
                }
                .disabled(isLoading || !isEmailFormValid)
                .opacity(isEmailFormValid ? 1.0 : 0.55)

                Button(action: nextAction) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Username picker (Apple new user)

    private var usernamePickerView: some View {
        VStack(spacing: 0) {

            Spacer()

            VStack(spacing: 12) {
                Text("One last thing")
                    .font(.title).bold()
                    .foregroundColor(AppColors.textPrimary)

                Text("Pick a username for the leaderboard.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)

            Spacer().frame(height: 32)

            TextField("Username", text: $appleUsername)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 30)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 8)
            }

            Spacer()

            Button {
                Task { await confirmAppleUsername() }
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    }
                    Text("Let's go")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.primaryGradient)
                .foregroundColor(AppColors.textPrimary)
                .cornerRadius(12)
            }
            .disabled(isLoading || appleUsername.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(appleUsername.trimmingCharacters(in: .whitespaces).isEmpty ? 0.55 : 1.0)
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Actions

    /// Email/password path
    private func createWithEmail() async {
        isLoading     = true
        errorMessage  = nil
        do {
            try await CommunityService.shared.signUp(
                email:    email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                password: password,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            nextAction()
        } catch {
            errorMessage = error.localizedDescription
            isLoading    = false
        }
    }

    /// Apple path — handles the ASAuthorization result from SignInWithAppleButton
    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        isLoading    = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            guard
                let credential  = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData   = credential.identityToken,
                let idToken     = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple sign-in failed. Please try again."
                isLoading    = false
                return
            }

            do {
                let needsUsername = try await CommunityService.shared.signInWithApple(
                    idToken:  idToken,
                    nonce:    appleNonce,
                    email:    credential.email,
                    fullName: credential.fullName
                )

                if needsUsername {
                    // New user — show the username picker
                    phase     = .needsUsername
                    isLoading = false
                } else {
                    // Returning user — skip straight into the app
                    nextAction()
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading    = false
            }

        case .failure(let error):
            // .canceled means the user dismissed the sheet — not a real error
            let authError = error as? ASAuthorizationError
            if authError?.code != .canceled {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Username picker confirm — Apple new user path
    private func confirmAppleUsername() async {
        isLoading    = true
        errorMessage = nil
        do {
            try await CommunityService.shared.setUsernameAfterAppleSignIn(appleUsername)
            nextAction()
        } catch {
            errorMessage = error.localizedDescription
            isLoading    = false
        }
    }

    // MARK: - Nonce helpers
    //
    // Apple requires a cryptographic nonce to prevent replay attacks.
    // We generate a random string, hash it with SHA-256, and send
    // the HASH to Apple. We keep the PLAIN TEXT and send it to Supabase,
    // which re-hashes it to verify both sides match.

    private func makeNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Validation

    private var isEmailFormValid: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6
    }
}
