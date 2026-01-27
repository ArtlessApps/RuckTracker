//
//  SettingsView.swift
//  RuckTracker Watch App
//
//  Clean, simple layout for Apple Watch
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var healthManager: HealthManager
    
    @State private var showingBodyWeightPicker = false
    @State private var showingRuckWeightPicker = false
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Body Weight
                Section("Body Weight") {
                    Button {
                        showingBodyWeightPicker = true
                    } label: {
                        HStack {
                            Text(userSettings.bodyWeightDisplayString)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Ruck Weight
                Section("Default Ruck Weight") {
                    Button {
                        showingRuckWeightPicker = true
                    } label: {
                        HStack {
                            Text("\(String(format: "%.0f", userSettings.defaultRuckWeight)) \(userSettings.preferredWeightUnit.rawValue)")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Units
                Section("Units") {
                    NavigationLink("Weight & Distance", destination: UnitsSettingsView())
                }
                
                // HealthKit Status
                Section("HealthKit") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: healthManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(healthManager.isAuthorized ? AppColors.successGreen : AppColors.accentWarm)
                                .font(.system(size: 14))
                            
                            Text(healthManager.getHealthKitStatusMessage())
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        if !healthManager.isAuthorized {
                            Button("Grant Permissions") {
                                healthManager.requestAuthorization()
                            }
                            .font(.caption2)
                            .foregroundColor(AppColors.primary)
                        }
                        
                        // Show error display if there are issues
                        WatchHealthKitStatusBanner(isMinimal: true)
                    }
                    .padding(.vertical, 2)
                }
                
                // Reset
                Section {
                    Button("Reset to Defaults") {
                        showingResetAlert = true
                    }
                    .foregroundColor(AppColors.destructiveRed)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingBodyWeightPicker) {
                BodyWeightPickerView()
            }
            .sheet(isPresented: $showingRuckWeightPicker) {
                RuckWeightPickerView()
            }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) {
                    userSettings.resetToDefaults()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Reset all settings to defaults?")
            }
        }
    }
}

// MARK: - Body Weight Picker (Completely Redesigned)
struct BodyWeightPickerView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedWeight: Double = 150.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Weight picker
            Picker("Weight", selection: $selectedWeight) {
                ForEach(weightOptions, id: \.self) { weight in
                    Text(String(format: "%.1f", weight))
                        .tag(weight)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            // Save/Cancel buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppColors.surface)
                .foregroundColor(AppColors.textPrimary)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                
                Button("Save") {
                    userSettings.bodyWeight = selectedWeight
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppColors.primary)
                .foregroundColor(AppColors.textPrimary)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationBarHidden(true)
        .onAppear {
            selectedWeight = userSettings.bodyWeight
        }
    }
    
    private var weightOptions: [Double] {
        if userSettings.preferredWeightUnit == .pounds {
            return Array(stride(from: 80.0, through: 400.0, by: 1.0))
        } else {
            return Array(stride(from: 36.0, through: 180.0, by: 0.5))
        }
    }
}

// MARK: - Ruck Weight Picker (Completely Redesigned)
struct RuckWeightPickerView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedWeight: Double = UserSettings.shared.defaultRuckWeight
    
    var body: some View {
        VStack(spacing: 0) {
            // Weight picker
            Picker("Ruck Weight", selection: $selectedWeight) {
                ForEach(weightOptions, id: \.self) { weight in
                    Text(String(format: "%.0f", weight))
                        .tag(weight)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            // Save/Cancel buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppColors.surface)
                .foregroundColor(AppColors.textPrimary)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                
                Button("Save") {
                    userSettings.defaultRuckWeight = selectedWeight
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppColors.primary)
                .foregroundColor(AppColors.textPrimary)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationBarHidden(true)
        .onAppear {
            // On appear, load last workout weight
            if let lastWorkout = WorkoutDataManager.shared.workouts.first {
                selectedWeight = lastWorkout.ruckWeight
            } else {
                selectedWeight = userSettings.defaultRuckWeight
            }
        }
    }
    
    private var weightOptions: [Double] {
        if userSettings.preferredWeightUnit == .pounds {
            return Array(stride(from: 0.0, through: 100.0, by: 5.0))
        } else {
            return Array(stride(from: 0.0, through: 45.0, by: 2.5))
        }
    }
}

// MARK: - Units Settings
struct UnitsSettingsView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        List {
            Section("Weight") {
                ForEach(UserSettings.WeightUnit.allCases, id: \.self) { unit in
                    Button {
                        userSettings.preferredWeightUnit = unit
                    } label: {
                        HStack {
                            Text(unit.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if userSettings.preferredWeightUnit == unit {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Section("Distance") {
                ForEach(UserSettings.DistanceUnit.allCases, id: \.self) { unit in
                    Button {
                        userSettings.preferredDistanceUnit = unit
                    } label: {
                        HStack {
                            Text(unit.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if userSettings.preferredDistanceUnit == unit {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .navigationTitle("Units")
    }
}

#Preview {
    SettingsView()
}
