//
//  ProfileView.swift
//  RuckTracker
//
//  Created by Assistant on 9/13/25.
//

import SwiftUI

// MARK: - Keyboard Dismissal Helper
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authService: AuthService
    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var userSettings = UserSettings.shared
    @EnvironmentObject private var supabaseManager: SupabaseManager
    @State private var showingLoginOptions = false
    @State private var showingUsernameEditor = false
    @State private var tempUsername: String = ""
    @State private var showingLogoutAlert = false
    @State private var activeSheet: ActiveSheet? = nil
    
    enum ActiveSheet: Identifiable {
        case loginOptions
        case usernameEditor
        case addEmail
        
        var id: Int {
            switch self {
            case .loginOptions: return 0
            case .usernameEditor: return 1
            case .addEmail: return 2
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Streamlined Profile Info
                    profileHeaderSection
                    
                    // Subscription Details (if premium or show upgrade)
                    subscriptionDetailsSection
                    
                    // Actions
                    actionsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .loginOptions:
                LoginOptionsView(mode: .signIn)
                    .environmentObject(authService)
            case .usernameEditor:
                UsernameEditorView(currentUsername: userSettings.username) { newUsername in
                    userSettings.username = newUsername
                }
            case .addEmail:
                AddEmailView()
                    .environmentObject(authService)
                    .environmentObject(supabaseManager)
            }
        }
        .alert("Disconnect Account", isPresented: $showingLogoutAlert) {
            Button("Disconnect", role: .destructive) {
                Task {
                    try? await authService.signOut()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Disconnecting will create a new anonymous session. You'll need to connect again to access your current synced data.\n\nNote: Your premium subscription is tied to your Apple ID and will remain active.")
        }
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
        .onAppear {
            print("📱 ProfileView appeared - isAuthenticated: \(supabaseManager.isAuthenticated), hasEmail: \(supabaseManager.hasEmail), isAnonymous: \(supabaseManager.isAnonymousUser)")
            print("📱 AuthService isAuthenticated: \(authService.isAuthenticated)")
        }
        .onChange(of: supabaseManager.isAuthenticated) { isAuthenticated in
            print("🔄 ProfileView detected auth state change: \(isAuthenticated)")
        }
        .onChange(of: supabaseManager.hasEmail) { hasEmail in
            print("🔄 ProfileView detected email state change: \(hasEmail)")
        }
        .onChange(of: supabaseManager.isAnonymousUser) { isAnonymous in
            print("🔄 ProfileView detected anonymous state change: \(isAnonymous)")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns user-friendly account status text
    /// App User: Anonymous user without email
    /// Connected: User with email
    /// Premium: Based on subscription status (independent of email)
    private var accountStatusText: String {
        // Premium status (subscription tier)
        let premiumStatus: String = {
            if premiumManager.isPremiumUser {
                if premiumManager.isInFreeTrial {
                    return "Premium (Trial)"
                } else {
                    return "Premium"
                }
            } else {
                return "Free"
            }
        }()
        
        // Connection status (authentication tier)
        if supabaseManager.hasEmail {
            return premiumStatus // "Free" or "Premium" or "Premium (Trial)"
        } else {
            // Anonymous users show same status (remove "Guest" terminology)
            return premiumStatus
        }
    }
    
    /// Returns color for account status badge
    private var accountStatusColor: Color {
        if premiumManager.isPremiumUser {
            return .green // Premium = green
        } else if supabaseManager.hasEmail {
            return .blue // Connected (free) = blue
        } else {
            return .orange // App User (free) = orange
        }
    }
    
    /// Returns connection status for display
    private var connectionStatusText: String {
        supabaseManager.hasEmail ? "Connected" : "App User"
    }
    
    /// Returns connection status color
    private var connectionStatusColor: Color {
        supabaseManager.hasEmail ? .green : .orange
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        VStack(spacing: 20) {
            // Username with edit button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let username = userSettings.username, !username.isEmpty {
                        Text(username)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    } else {
                        Text("Not Set")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    tempUsername = userSettings.username ?? ""
                    activeSheet = .usernameEditor
                } label: {
                    Text("Edit")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            Divider()
            
            // Subscription Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(accountStatusText)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(accountStatusColor)
                        
                        if premiumManager.isPremiumUser {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Account - Only show if connected (email address)
            if supabaseManager.hasEmail {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(supabaseManager.userEmail ?? "Connected")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    
    // MARK: - Subscription Details Section
    
    private var subscriptionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subscription")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if premiumManager.isPremiumUser {
                activeSubscriptionView
            } else {
                freeUserView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    @ViewBuilder
    private var activeSubscriptionView: some View {
        VStack(spacing: 12) {
            HStack {
                PremiumBadge(size: .medium)
                Spacer()
                if let expiryDate = premiumManager.subscriptionExpiryDate,
                   expiryDate != Date.distantFuture {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Expires")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(expiryDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            
            Text("You have access to all premium features")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if premiumManager.isInFreeTrial {
                if let daysRemaining = premiumManager.freeTrialDaysRemaining {
                    Text("\(daysRemaining) days left in free trial")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
            
            Button("Manage Subscription") {
                // This would open App Store subscription management
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var freeUserView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "crown")
                    .foregroundColor(.orange)
                Text("Free Plan")
                    .fontWeight(.medium)
                Spacer()
            }
            
            Text("Upgrade to unlock training programs, advanced analytics, and more")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Upgrade to Pro") {
                premiumManager.showPaywall(context: .settings)
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
        }
    }
    
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
            // For App Users (anonymous without email): Show prominent "Connect Account" card
            if !supabaseManager.hasEmail {
                Button {
                    activeSheet = .addEmail
                } label: {
                    HStack {
                        Image(systemName: "link.circle.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connect Account")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Sync your data across all devices")
                                .font(.caption)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
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
                
                // Info about data
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Your data is saved on this device. Connect an account to sync across devices.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
            
            // For Connected Users: Show disconnect button
            if supabaseManager.hasEmail {
                Button("Disconnect Account") {
                    showingLogoutAlert = true
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - Supporting Views

struct AccountInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color
    let action: (() -> Void)?
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text(value)
                        .font(.caption)
                        .foregroundColor(valueColor)
                }
                
                Spacer()
                
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}


// MARK: - Login Options View

enum LoginMode {
    case signUp
    case signIn
}

struct LoginOptionsView: View {
    let mode: LoginMode
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @State private var isLoading = false
    @State private var showingEmailLogin = false
    @State private var email = ""
    @State private var password = ""
    @State private var activeSheet: ActiveSheet? = nil
    
    enum ActiveSheet: Identifiable {
        case emailLogin
        
        var id: Int { 0 }
    }
    
    init(mode: LoginMode = .signUp) {
        self.mode = mode
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text(mode == .signUp ? "Get Started with RuckTracker" : "Welcome Back")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(mode == .signUp ? "Create an account to sync your data across devices and access all features" : "Sign in to access your account and sync your data")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    // Email/Password Authentication
                    Button {
                        activeSheet = .emailLogin
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                                .font(.title2)
                            Text(mode == .signUp ? "Create Account" : "Sign In")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Anonymous Sign In
                    Button {
                        Task {
                            isLoading = true
                            do {
                                try await authService.signInAnonymously()
                                print("✅ Anonymous authentication successful")
                                isLoading = false
                                dismiss()
                            } catch {
                                print("❌ Anonymous authentication failed: \(error)")
                                isLoading = false
                                // Don't dismiss on error - let user try again
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.circle")
                                .font(.title2)
                            Text("Continue as Guest")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                }
                
                Spacer()
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
            .onTapGesture {
                // Dismiss keyboard when tapping outside text fields
                hideKeyboard()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .emailLogin:
                EmailLoginView(mode: mode) { email, password in
                    Task {
                        isLoading = true
                        do {
                            if mode == .signUp {
                                try await authService.signUpWithEmail(email: email, password: password)
                            } else {
                                try await authService.signInWithEmail(email: email, password: password)
                            }
                            isLoading = false
                            dismiss()
                        } catch {
                            isLoading = false
                            // Handle error - you might want to show an alert
                            print("Authentication error: \(error)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Username Editor View

struct UsernameEditorView: View {
    let currentUsername: String?
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Set Username")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Choose a username for leaderboards and community features")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.headline)
                    
                        TextField("Enter username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .submitLabel(.done)
                    
                    Text("3-20 characters, letters and numbers only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button {
                        saveUsername()
                    } label: {
                        Text("Save Username")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .disabled(username.isEmpty || username == currentUsername)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                username = currentUsername ?? ""
            }
            .alert("Invalid Username", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside text fields
                hideKeyboard()
            }
        }
    }
    
    private func saveUsername() {
        // Basic validation
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
        
        // Check for valid characters (letters and numbers only)
        let validCharacters = CharacterSet.alphanumerics
        if username.rangeOfCharacter(from: validCharacters.inverted) != nil {
            errorMessage = "Username can only contain letters and numbers"
            showingError = true
            return
        }
        
        onSave(username)
        dismiss()
    }
}

// MARK: - Add Email View

struct AddEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var supabaseManager: SupabaseManager
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showingSuccessAlert = false
    @State private var isSignInMode = false // Toggle between sign in and create account
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: isSignInMode ? "person.circle.fill" : "envelope.badge.shield.half.filled")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text(isSignInMode ? "Sign In" : "Connect Account")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(isSignInMode ? "Sign in to access your account and sync your data across all devices." : "Add an email and password to secure your account and sync your data across all your devices.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Benefits list (only show for new accounts)
                if !isSignInMode {
                    VStack(alignment: .leading, spacing: 12) {
                        SimpleBenefitRow(icon: "icloud", text: "Sync data across devices")
                        SimpleBenefitRow(icon: "lock.shield", text: "Secure your account")
                        SimpleBenefitRow(icon: "arrow.clockwise", text: "Never lose your progress")
                        SimpleBenefitRow(icon: "checkmark.circle", text: "Keep all your current data")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                        
                        TextField("Enter email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .submitLabel(.next)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                        
                        SecureField("Enter password (min 6 characters)", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .submitLabel(.next)
                    }
                    
                    // Only show confirm password for new accounts
                    if !isSignInMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.headline)
                            
                            SecureField("Confirm password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .submitLabel(.done)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button {
                        if isSignInMode {
                            signIn()
                        } else {
                            addEmail()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text(isSignInMode ? "Sign In" : "Connect Account")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(
                        LinearGradient(
                            colors: isSignInMode ? [.blue, .purple] : [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .disabled(!isFormValid || isLoading)
                    .opacity(isFormValid && !isLoading ? 1.0 : 0.6)
                    
                    // Toggle between sign in and create account
                    Button {
                        isSignInMode.toggle()
                        // Clear confirm password when switching to sign in
                        if isSignInMode {
                            confirmPassword = ""
                        }
                    } label: {
                        Text(isSignInMode ? "Need an account? Connect account" : "Already have an account? Sign in")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    Button("Maybe Later") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
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
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Check Your Email! ✉️", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("We've sent a confirmation email to \(email).\n\nPlease check your inbox and click the confirmation link to complete your account setup. Once confirmed, you'll be able to sign in on all your devices!")
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    private var isFormValid: Bool {
        if isSignInMode {
            // Sign in only needs email and password
            return !email.isEmpty && !password.isEmpty
        } else {
            // Create account needs email, password, and matching confirmation
            return !email.isEmpty && 
                   !password.isEmpty && 
                   password.count >= 6 &&
                   password == confirmPassword
        }
    }
    
    private func addEmail() {
        // Validate email format
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address"
            showingError = true
            return
        }
        
        // Validate passwords match
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            showingError = true
            return
        }
        
        // Validate password length
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authService.linkEmailToAnonymousAccount(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func signIn() {
        // Validate email format
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address"
            showingError = true
            return
        }
        
        // Validate password
        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authService.signInWithEmail(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Sign in failed. Please check your email and password."
                    showingError = true
                }
            }
        }
    }
}

struct SimpleBenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

// MARK: - Email Login View

struct EmailLoginView: View {
    let mode: LoginMode
    let onAuthenticate: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text(mode == .signUp ? "Create Account" : "Sign In")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(mode == .signUp ? "Create an account to sync your data" : "Sign in to access your account")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                        
                        TextField("Enter email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .submitLabel(.next)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                        
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .submitLabel(.done)
                    }
                    
                    if mode == .signUp {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.headline)
                            
                            SecureField("Confirm password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .submitLabel(.done)
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button {
                        authenticate()
                    } label: {
                        Text(mode == .signUp ? "Create Account" : "Sign In")
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
                    
                    // Toggle removed - users now choose from main screen
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .alert("Authentication Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside text fields
                hideKeyboard()
            }
        }
    }
    
    private var isFormValid: Bool {
        if email.isEmpty || password.isEmpty {
            return false
        }
        
        if mode == .signUp {
            return password == confirmPassword && password.count >= 6
        }
        
        return true
    }
    
    private func authenticate() {
        // Basic validation
        if email.isEmpty || password.isEmpty {
            errorMessage = "Please fill in all fields"
            showingError = true
            return
        }
        
        if mode == .signUp {
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
        }
        
        onAuthenticate(email, password)
    }
}

#Preview {
    ProfileView()
}
