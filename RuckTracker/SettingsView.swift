//
//  SettingsView.swift
//  MARCH
//
//  Created by Assistant on 9/13/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @StateObject private var communityService = CommunityService.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var tabSelection: MainTabSelection
    
    @State private var bodyWeightInput: String = ""
    @State private var defaultRuckWeightInput: String = ""
    @State private var showingResetAlert = false
    @State private var showingValidationError = false
    @State private var validationMessage = ""
    @State private var showingDebugLogs = false
    @State private var showingLogoutAlert = false
    @State private var showingAuth = false
    @State private var showingDeleteAccount = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Account Section (moved to top)
                        accountSection
                        
                        // MARK: - Body Weight Section
                        bodyWeightSection
                        
                        // MARK: - Default Ruck Weight Section
                        defaultRuckWeightSection
                        
                        // MARK: - Units Section
                        unitsSection
                        
                        // MARK: - HealthKit Section
                        healthKitSection
                        
                        // MARK: - Actions Section
                        actionsSection
                        
                        // MARK: - App Info Section
                        aboutSection
                        
                        // MARK: - Debug Section
                        debugSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if hasChanges() {
                            saveSettings()
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                }
            }
            .sheet(isPresented: $showingDebugLogs) {
                DebugLogViewer()
            }
            .sheet(isPresented: $showingAuth) {
                AuthenticationView(onLoginSuccess: {
                    tabSelection.selectedTab = .ruck
                    dismiss()
                })
            }
            .sheet(isPresented: $showingDeleteAccount) {
                DeleteAccountSheet(onDeleted: {
                    dismiss()
                })
            }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) {
                    userSettings.resetToDefaults()
                    loadCurrentValues()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
            .alert("Invalid Input", isPresented: $showingValidationError) {
                Button("OK") { }
            } message: {
                Text(validationMessage)
            }
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out? You'll need to sign in again to access community features.")
            }
            .onAppear {
                loadCurrentValues()
            }
        }
    }
    
    // MARK: - Tier Badge
    
    private var tierBadge: some View {
        Group {
            switch premiumManager.premiumSource {
            case .ambassador:
                HStack(spacing: 4) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 12))
                    Text("AMBASSADOR")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(6)
            case .subscription:
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                    Text("PRO")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.primary)
                .cornerRadius(6)
            case .none:
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                    Text("FREE")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.textSecondary.opacity(0.15))
                .cornerRadius(6)
            }
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
            
            if communityService.isAuthenticated {
                // Logged in state - show username and logout
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.primary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signed in as")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text(communityService.currentProfile?.username ?? "User")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        Spacer()
                        
                        // Tier badge
                        tierBadge
                    }
                    
                    Divider()
                        .background(AppColors.textSecondary.opacity(0.3))
                    
                    Button(action: {
                        showingLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16))
                            Text("Sign Out")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    
                    Divider()
                        .background(AppColors.textSecondary.opacity(0.3))
                    
                    // Delete Account — required by Apple App Store guideline
                    // 5.1.1(v).  Tapping opens a dedicated sheet with full
                    // disclosure and a typed-confirmation step.
                    Button(action: {
                        showingDeleteAccount = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                            Text("Delete Account")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.red.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.surface)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                )
            } else {
                // Not logged in - show login button
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.circle")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.textSecondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Not signed in")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text("Sign in to access community features")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                        .background(AppColors.textSecondary.opacity(0.3))
                    
                    Button(action: {
                        showingAuth = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16))
                            Text("Sign In or Create Account")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(AppColors.textOnLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.primary)
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.surface)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                )
            }
        }
    }
    
    // MARK: - Body Weight Section
    
    private var bodyWeightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Body Weight")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                
                Text("Used for accurate calorie calculations")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Weight")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    TextField("Enter weight", text: $bodyWeightInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Picker("Unit", selection: $userSettings.preferredWeightUnit) {
                        ForEach(UserSettings.WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 100)
                }
                
                if !bodyWeightInput.isEmpty {
                    Divider()
                        .background(AppColors.textSecondary.opacity(0.3))
                    
                    HStack {
                        Text("Current:")
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Text(userSettings.bodyWeightDisplayString)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Default Ruck Weight Section
    
    private var defaultRuckWeightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Default Ruck Weight")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                
                Text("Starting weight for new workouts")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Ruck Weight")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    TextField("Enter weight", text: $defaultRuckWeightInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(userSettings.preferredWeightUnit.rawValue)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                if !defaultRuckWeightInput.isEmpty {
                    Divider()
                        .background(AppColors.textSecondary.opacity(0.3))
                    
                    HStack {
                        Text("Current:")
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Text("\(String(format: "%.1f", userSettings.defaultRuckWeight)) \(userSettings.preferredWeightUnit.rawValue)")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Units Section
    
    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferred Units")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Weight Unit")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Picker("Weight Unit", selection: $userSettings.preferredWeightUnit) {
                        ForEach(UserSettings.WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Divider()
                    .background(AppColors.textSecondary.opacity(0.3))
                
                HStack {
                    Text("Distance Unit")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Picker("Distance Unit", selection: $userSettings.preferredDistanceUnit) {
                        ForEach(UserSettings.DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - HealthKit Section
    
    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HealthKit Integration")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                
                Text("HealthKit enables workout tracking and integration with the Health app")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: healthManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(healthManager.isAuthorized ? AppColors.accentGreen : AppColors.primary)
                        .font(.system(size: 18))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HealthKit Status")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        Text(healthManager.getHealthKitStatusMessage())
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                    .background(AppColors.textSecondary.opacity(0.3))
                
                // Permission details
                VStack(alignment: .leading, spacing: 6) {
                    PermissionRow(title: "Workouts", granted: healthManager.hasWorkoutPermission)
                    PermissionRow(title: "Heart Rate", granted: healthManager.hasHeartRatePermission)
                    PermissionRow(title: "Active Calories", granted: healthManager.hasCaloriesPermission)
                    PermissionRow(title: "Distance", granted: healthManager.hasDistancePermission)
                }
                
                if !healthManager.isAuthorized {
                    Button(action: {
                        healthManager.requestAuthorization()
                    }) {
                        Text("Grant HealthKit Permissions")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(AppColors.textPrimary)
                            .cornerRadius(10)
                    }
                }
                
                // Error display
                HealthKitStatusBanner()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                saveSettings()
            }) {
                Text("Save Changes")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(hasChanges() ? AppColors.primary : AppColors.surface)
                    .foregroundColor(hasChanges() ? AppColors.textOnLight : AppColors.textSecondary)
                    .cornerRadius(12)
            }
            .disabled(!hasChanges())
            
            Button(action: {
                showingResetAlert = true
            }) {
                Text("Reset to Defaults")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
            
            VStack(spacing: 12) {
                HStack {
                    Text("App Version")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("1.0")
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Divider()
                    .background(AppColors.textSecondary.opacity(0.3))
                
                HStack {
                    Text("Onboarding Status")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(userSettings.hasCompletedOnboarding ? "Completed" : "Pending")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Debug Section
    
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Debug")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
            
            Button(action: {
                showingDebugLogs = true
            }) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(AppColors.textPrimary)
                    Text("View Debug Logs")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.surface)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                )
            }
        }
    }
    
    // MARK: - Sign Out
    private func signOut() async {
        do {
            try await communityService.signOut()
            premiumManager.resetPremiumStatusForSignOut()
            dismiss()
        } catch {
            print("❌ Sign out failed: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    private func loadCurrentValues() {
        bodyWeightInput = String(format: "%.1f", userSettings.bodyWeight)
        defaultRuckWeightInput = String(format: "%.1f", userSettings.defaultRuckWeight)
    }
    
    private func hasChanges() -> Bool {
        guard let bodyWeight = Double(bodyWeightInput),
              let ruckWeight = Double(defaultRuckWeightInput) else {
            return false
        }
        
        return abs(bodyWeight - userSettings.bodyWeight) > 0.1 ||
               abs(ruckWeight - userSettings.defaultRuckWeight) > 0.1
    }
    
    private func saveSettings() {
        guard let bodyWeight = Double(bodyWeightInput),
              let ruckWeight = Double(defaultRuckWeightInput) else {
            validationMessage = "Please enter valid numbers for both weights."
            showingValidationError = true
            return
        }
        
        // Validate body weight
        if !userSettings.isValidBodyWeight(bodyWeight) {
            let minWeight = userSettings.preferredWeightUnit == .pounds ? 80 : 36
            let maxWeight = userSettings.preferredWeightUnit == .pounds ? 400 : 180
            validationMessage = "Body weight must be between \(minWeight) and \(maxWeight) \(userSettings.preferredWeightUnit.rawValue)."
            showingValidationError = true
            return
        }
        
        // Validate ruck weight
        if !userSettings.isValidRuckWeight(ruckWeight) {
            let maxWeight = userSettings.preferredWeightUnit == .pounds ? 100 : 45
            validationMessage = "Ruck weight must be between 0 and \(maxWeight) \(userSettings.preferredWeightUnit.rawValue)."
            showingValidationError = true
            return
        }
        
        // Save the settings
        userSettings.bodyWeight = bodyWeight
        userSettings.defaultRuckWeight = ruckWeight
        
        // Mark onboarding as completed if this is the first time setting body weight
        if !userSettings.hasCompletedOnboarding {
            userSettings.hasCompletedOnboarding = true
        }
    }
}

struct PermissionRow: View {
    let title: String
    let granted: Bool
    
    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(granted ? AppColors.accentGreen : .red)
                .font(.system(size: 14))
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
            
            Text(granted ? "Granted" : "Denied")
                .font(.caption)
                .foregroundColor(granted ? AppColors.accentGreen : .red)
        }
    }
}

// MARK: - Delete Account Sheet

/// Permanent account deletion flow.
///
/// Apple App Store guideline 5.1.1(v) requires every app that supports
/// account creation to also offer in-app account deletion.  This sheet
/// shows the user exactly what will be deleted, discloses that App Store
/// subscriptions live on the Apple ID and must be cancelled separately,
/// and requires the user to type "DELETE" before the destructive action
/// becomes enabled — preventing accidental deletions while still keeping
/// the flow entirely self-service.
struct DeleteAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communityService = CommunityService.shared
    
    /// Called after the account has been successfully deleted, so the
    /// caller (Settings) can dismiss itself and return to a logged-out
    /// state.
    let onDeleted: () -> Void
    
    @State private var confirmationText: String = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    
    private let confirmationKeyword = "DELETE"
    
    private var isConfirmationValid: Bool {
        confirmationText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() == confirmationKeyword
    }
    
    private var canDelete: Bool {
        isConfirmationValid && !isDeleting
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        whatWillBeDeletedSection
                        subscriptionDisclosureSection
                        confirmationFieldSection
                        
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                        
                        deleteButton
                        
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .disabled(isDeleting)
                }
            }
            .interactiveDismissDisabled(isDeleting)
        }
    }
    
    // MARK: Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.red)
            
            Text("Delete Your Account")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            Text("This will permanently delete your MARCH account and all of your data. This action cannot be undone.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var whatWillBeDeletedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What will be deleted")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
            
            DeleteAccountBulletRow(icon: "person.fill", text: "Your profile, username, and avatar")
            DeleteAccountBulletRow(icon: "list.bullet.rectangle", text: "All your posts, comments, and likes")
            DeleteAccountBulletRow(icon: "calendar", text: "Your events and RSVPs")
            DeleteAccountBulletRow(icon: "trophy.fill", text: "Your leaderboard entries and badges")
            DeleteAccountBulletRow(icon: "person.3.fill", text: "Your club memberships")
            DeleteAccountBulletRow(icon: "flag.fill", text: "Any clubs you founded (and all of their data)")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
        )
    }
    
    private var subscriptionDisclosureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("About your subscription")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text("App Store subscriptions are managed by Apple and are NOT cancelled when you delete your account. To cancel, open the iOS Settings app, tap your name at the top, then tap Subscriptions.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
    
    private var confirmationFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type DELETE to confirm")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
            
            TextField("DELETE", text: $confirmationText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundColor(AppColors.textPrimary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isConfirmationValid ? Color.red.opacity(0.6) : AppColors.textSecondary.opacity(0.25),
                            lineWidth: 1
                        )
                )
                .disabled(isDeleting)
        }
    }
    
    private var deleteButton: some View {
        Button(action: deleteAccount) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "trash.fill")
                }
                Text(isDeleting ? "Deleting…" : "Permanently Delete My Account")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canDelete ? Color.red : Color.red.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canDelete)
    }
    
    // MARK: Action
    
    private func deleteAccount() {
        Task {
            isDeleting = true
            errorMessage = nil
            do {
                try await communityService.deleteAccount()
                isDeleting = false
                onDeleted()
                dismiss()
            } catch {
                isDeleting = false
                errorMessage = error.localizedDescription
                print("❌ Account deletion failed: \(error)")
            }
        }
    }
}

private struct DeleteAccountBulletRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 20)
                .foregroundColor(.red.opacity(0.85))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    SettingsView()
}

#Preview("Delete Account Sheet") {
    DeleteAccountSheet(onDeleted: {})
}
