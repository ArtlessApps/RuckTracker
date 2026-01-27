//
//  SettingsView.swift
//  MARCH
//
//  Created by Assistant on 9/13/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var healthManager: HealthManager
    
    @State private var bodyWeightInput: String = ""
    @State private var defaultRuckWeightInput: String = ""
    @State private var showingResetAlert = false
    @State private var showingValidationError = false
    @State private var validationMessage = ""
    @State private var showingDebugLogs = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                Form {
                // MARK: - Body Weight Section
                Section(header: Text("Body Weight"), footer: Text("Used for accurate calorie calculations")) {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Enter weight", text: $bodyWeightInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        
                        Picker("Unit", selection: $userSettings.preferredWeightUnit) {
                            ForEach(UserSettings.WeightUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 100)
                    }
                    
                    if !bodyWeightInput.isEmpty {
                        HStack {
                            Text("Current:")
                            Spacer()
                            Text(userSettings.bodyWeightDisplayString)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                
                // MARK: - Default Ruck Weight Section
                Section(header: Text("Default Ruck Weight"), footer: Text("Starting weight for new workouts")) {
                    HStack {
                        Text("Ruck Weight")
                        Spacer()
                        TextField("Enter weight", text: $defaultRuckWeightInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        
                        Text(userSettings.preferredWeightUnit.rawValue)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if !defaultRuckWeightInput.isEmpty {
                        HStack {
                            Text("Current:")
                            Spacer()
                            Text("\(String(format: "%.1f", userSettings.defaultRuckWeight)) \(userSettings.preferredWeightUnit.rawValue)")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                
                // MARK: - Units Section
                Section(header: Text("Preferred Units")) {
                    HStack {
                        Text("Weight Unit")
                        Spacer()
                        Picker("Weight Unit", selection: $userSettings.preferredWeightUnit) {
                            ForEach(UserSettings.WeightUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    HStack {
                        Text("Distance Unit")
                        Spacer()
                        Picker("Distance Unit", selection: $userSettings.preferredDistanceUnit) {
                            ForEach(UserSettings.DistanceUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                // MARK: - HealthKit Section
                Section(header: Text("HealthKit Integration"), footer: Text("HealthKit enables workout tracking and integration with the Health app")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: healthManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(healthManager.isAuthorized ? AppColors.accentGreen : AppColors.primary)
                                .font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("HealthKit Status")
                                    .font(.headline)
                                Text(healthManager.getHealthKitStatusMessage())
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                        }
                        
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
                    .padding(.vertical, 8)
                }
                
                // MARK: - Actions Section
                Section {
                    Button("Save Changes") {
                        saveSettings()
                    }
                    .disabled(!hasChanges())
                    
                    Button("Reset to Defaults") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                // MARK: - App Info Section
                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    HStack {
                        Text("Onboarding Status")
                        Spacer()
                        Text(userSettings.hasCompletedOnboarding ? "Completed" : "Pending")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                // MARK: - Debug Section
                Section(header: Text("Debug")) {
                    Button(action: {
                        showingDebugLogs = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("View Debug Logs")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if hasChanges() {
                            saveSettings()
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingDebugLogs) {
                DebugLogViewer()
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
            .onAppear {
                loadCurrentValues()
            }
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
                .foregroundColor(granted ? .green : .red)
                .font(.system(size: 14))
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(granted ? "Granted" : "Denied")
                .font(.caption)
                .foregroundColor(granted ? .green : .red)
        }
    }
}

#Preview {
    SettingsView()
}
