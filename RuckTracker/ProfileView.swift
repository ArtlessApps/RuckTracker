//
//  ProfileView.swift
//  RuckTracker
//
//  Created by Assistant on 9/13/25.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var authService = AuthService()
    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var userSettings = UserSettings.shared
    @State private var showingLoginOptions = false
    @State private var showingUsernameEditor = false
    @State private var tempUsername: String = ""
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    profileHeaderSection
                    
                    // Account Information
                    accountInformationSection
                    
                    // Subscription Details
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
        .sheet(isPresented: $showingLoginOptions) {
            LoginOptionsView()
        }
        .sheet(isPresented: $showingUsernameEditor) {
            UsernameEditorView(currentUsername: userSettings.username) { newUsername in
                userSettings.username = newUsername
            }
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await authService.signOut()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access your data.")
        }
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
    }
    
    // MARK: - Computed Properties
    
    private var accountStatusText: String {
        if !authService.isAuthenticated {
            return "Guest"
        }
        
        if premiumManager.isPremiumUser {
            if premiumManager.isInFreeTrial {
                return "Premium (Trial)"
            } else {
                return "Premium"
            }
        } else {
            return "Free"
        }
    }
    
    private var accountStatusColor: Color {
        if !authService.isAuthenticated {
            return .orange
        }
        
        if premiumManager.isPremiumUser {
            return .green
        } else {
            return .blue
        }
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Avatar
            VStack(spacing: 12) {
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
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 4) {
                    if let username = userSettings.username, !username.isEmpty {
                        Text(username)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    } else {
                        Text("Set Username")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(authService.isAuthenticated ? "Signed In" : "Guest User")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    // MARK: - Account Information Section
    
    private var accountInformationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Information")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Account Status
                AccountInfoRow(
                    icon: "person.circle",
                    title: "Account Status",
                    value: accountStatusText,
                    valueColor: accountStatusColor,
                    action: authService.isAuthenticated ? nil : {
                        showingLoginOptions = true
                    }
                )
                
                // Email Address
                AccountInfoRow(
                    icon: "envelope",
                    title: "Email",
                    value: userSettings.email?.isEmpty == false ? userSettings.email! : "Not Set",
                    valueColor: userSettings.email?.isEmpty == false ? .blue : .secondary,
                    action: nil // Email editing would require re-authentication
                )
                
                // Username
                AccountInfoRow(
                    icon: "person.badge.plus",
                    title: "Username",
                    value: userSettings.username?.isEmpty == false ? userSettings.username! : "Not Set",
                    valueColor: userSettings.username?.isEmpty == false ? .blue : .secondary,
                    action: {
                        tempUsername = userSettings.username ?? ""
                        showingUsernameEditor = true
                    }
                )
                
                // User ID (if authenticated)
                if authService.isAuthenticated {
                    AccountInfoRow(
                        icon: "key",
                        title: "User ID",
                        value: "••••••••",
                        valueColor: .secondary,
                        action: nil
                    )
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
        VStack(spacing: 12) {
            if authService.isAuthenticated {
                Button("Sign Out") {
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

struct LoginOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService()
    @State private var isLoading = false
    @State private var showingEmailLogin = false
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Get Started with RuckTracker")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Create an account to sync your data across devices and access all features")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    // Email/Password Sign Up
                    Button {
                        showingEmailLogin = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                                .font(.title2)
                            Text("Create Account")
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
        }
        .sheet(isPresented: $showingEmailLogin) {
            EmailLoginView(isSignUp: $isSignUp) { email, password in
                Task {
                    isLoading = true
                    do {
                        if isSignUp {
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

// MARK: - Email Login View

struct EmailLoginView: View {
    @Binding var isSignUp: Bool
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
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(isSignUp ? "Create an account to sync your data" : "Sign in to access your account")
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
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                        
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    if isSignUp {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.headline)
                            
                            SecureField("Confirm password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button {
                        authenticate()
                    } label: {
                        Text(isSignUp ? "Create Account" : "Sign In")
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
                    
                    Button {
                        isSignUp.toggle()
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.blue)
                    }
                    
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
        }
    }
    
    private var isFormValid: Bool {
        if email.isEmpty || password.isEmpty {
            return false
        }
        
        if isSignUp {
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
        
        if isSignUp {
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
