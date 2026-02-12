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

#Preview {
    SettingsView()
}
