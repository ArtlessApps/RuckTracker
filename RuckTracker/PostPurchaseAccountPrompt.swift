import SwiftUI

struct PostPurchaseAccountPrompt: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService()
    @EnvironmentObject private var supabaseManager: SupabaseManager
    @State private var showingEmailSignUp = false
    @State private var showingUsernameSetup = false
    @State private var isCreatingAccount = false
    @State private var activeSheet: ActiveSheet? = nil
    
    enum ActiveSheet: Identifiable {
        case emailSignUp
        case usernameSetup
        case addEmail  // New: for linking email to anonymous account
        
        var id: Int {
            switch self {
            case .emailSignUp: return 0
            case .usernameSetup: return 1
            case .addEmail: return 2
            }
        }
    }
    
    let onAccountCreated: () -> Void
    let onSkip: () -> Void
    
    // Check if user is currently anonymous
    private var isAnonymousUser: Bool {
        supabaseManager.isAnonymousUser
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header with celebration
                headerSection
                
                // Benefits section
                benefitsSection
                
                // Action buttons
                actionButtonsSection
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        onSkip()
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addEmail:
                // Link email to existing anonymous account
                AddEmailView()
                    .environmentObject(authService)
                    .environmentObject(supabaseManager)
                    .onDisappear {
                        // If they successfully added email, consider it as account created
                        if supabaseManager.hasEmail {
                            onAccountCreated()
                            dismiss()
                        }
                    }
            case .emailSignUp:
                PostPurchaseEmailSignUpView { email, password in
                    Task {
                        isCreatingAccount = true
                        do {
                            try await authService.signUpWithEmail(email: email, password: password)
                            isCreatingAccount = false
                            activeSheet = .usernameSetup
                        } catch {
                            isCreatingAccount = false
                            print("Account creation failed: \(error)")
                        }
                    }
                }
            case .usernameSetup:
                PostPurchaseUsernameSetupView {
                    onAccountCreated()
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Celebration animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(1.1)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: UUID())
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Welcome to Pro!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("You now have access to all premium features")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Benefits Section
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isAnonymousUser ? "Secure Your Subscription" : "Protect Your Progress")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(isAnonymousUser ? 
                 "Add an email to secure your premium subscription and sync your data across all your devices" :
                 "Create a free account to backup your workout data and sync across all your devices")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            VStack(spacing: 16) {
                BenefitRow(
                    icon: "icloud.and.arrow.up",
                    title: "Cloud Backup",
                    description: "Never lose your workout history"
                )
                
                BenefitRow(
                    icon: "iphone.and.arrow.forward",
                    title: "Cross-Device Sync",
                    description: "Access your data on phone, watch, and iPad"
                )
                
                BenefitRow(
                    icon: "person.2.fill",
                    title: "Community Features",
                    description: "Join leaderboards and challenges"
                )
                
                BenefitRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Advanced Analytics",
                    description: "Track your progress over time"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Add Email or Create Account Button
            Button {
                // For anonymous users, show add email flow
                // For others (shouldn't happen in new flow), show sign up
                activeSheet = isAnonymousUser ? .addEmail : .emailSignUp
            } label: {
                HStack {
                    if isCreatingAccount {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isAnonymousUser ? "envelope.badge.shield.half.filled" : "person.badge.plus")
                            .font(.title2)
                    }
                    
                    Text(isAnonymousUser ? "Add Email to Sync" : "Create an Account")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: isAnonymousUser ? [.orange, .red] : [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(isCreatingAccount)
            
            // Maybe Later Button
            Button {
                onSkip()
                dismiss()
            } label: {
                Text("Maybe later")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .disabled(isCreatingAccount)
            
            // Info text for anonymous users
            if isAnonymousUser {
                Text("Your premium features are active! Add an email to keep them safe.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Supporting Views

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Post-Purchase Email Sign Up

struct PostPurchaseEmailSignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onSignUp: (String, String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Create Your Account")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Just a few details to secure your workout data")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                        
                        SecureField("Create a password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.headline)
                        
                        SecureField("Confirm your password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button {
                        signUp()
                    } label: {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .disabled(!isFormValid)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Sign Up Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        return !email.isEmpty && 
               !password.isEmpty && 
               password == confirmPassword && 
               password.count >= 6
    }
    
    private func signUp() {
        if email.isEmpty || password.isEmpty {
            errorMessage = "Please fill in all fields"
            showingError = true
            return
        }
        
        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            showingError = true
            return
        }
        
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters"
            showingError = true
            return
        }
        
        onSignUp(email, password)
    }
}

// MARK: - Post-Purchase Username Setup

struct PostPurchaseUsernameSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userSettings = UserSettings.shared
    @State private var username = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onComplete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Account Created!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Now set a username for leaderboards and community features")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.headline)
                    
                    TextField("Enter a username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Text("3-20 characters, letters and numbers only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button {
                        saveUsername()
                    } label: {
                        Text("Complete Setup")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .disabled(username.isEmpty)
                    
                    Button("Skip for Now") {
                        onComplete()
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .alert("Invalid Username", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveUsername() {
        if username.count < 3 {
            errorMessage = "Username must be at least 3 characters long"
            showingError = true
            return
        }
        
        if username.count > 20 {
            errorMessage = "Username must be 20 characters or less"
            showingError = true
            return
        }
        
        let validCharacters = CharacterSet.alphanumerics
        if username.rangeOfCharacter(from: validCharacters.inverted) != nil {
            errorMessage = "Username can only contain letters and numbers"
            showingError = true
            return
        }
        
        userSettings.username = username
        onComplete()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    PostPurchaseAccountPrompt(
        onAccountCreated: { print("Account created") },
        onSkip: { print("Skipped") }
    )
}
