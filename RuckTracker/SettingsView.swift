//
//  SettingsView.swift
//  RuckTracker
//
//  Created by Assistant on 9/13/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var tempBodyWeight: String = ""
    @State private var tempDefaultRuckWeight: String = ""
    @State private var showingResetAlert = false
    @State private var showingValidationError = false
    @State private var validationMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Body Weight Section
                Section(header: Text("Body Weight"), footer: Text("Used for accurate calorie calculations")) {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Enter weight", text: $tempBodyWeight)
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
                    
                    if !tempBodyWeight.isEmpty {
                        HStack {
                            Text("Current:")
                            Spacer()
                            Text(userSettings.bodyWeightDisplayString)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // MARK: - Default Ruck Weight Section
                Section(header: Text("Default Ruck Weight"), footer: Text("Starting weight for new workouts")) {
                    HStack {
                        Text("Ruck Weight")
                        Spacer()
                        TextField("Enter weight", text: $tempDefaultRuckWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        
                        Text(userSettings.preferredWeightUnit.rawValue)
                            .foregroundColor(.secondary)
                    }
                    
                    if !tempDefaultRuckWeight.isEmpty {
                        HStack {
                            Text("Current:")
                            Spacer()
                            Text("\(String(format: "%.1f", userSettings.defaultRuckWeight)) \(userSettings.preferredWeightUnit.rawValue)")
                                .foregroundColor(.secondary)
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
                
                // MARK: - Weight Recommendations Section
                Section(header: Text("Rucking Guidelines"), footer: Text("Military and fitness recommendations for safe rucking")) {
                    VStack(alignment: .leading, spacing: 8) {
                        RecommendationRow(title: "Beginner", weight: "10-15% body weight", color: .green)
                        RecommendationRow(title: "Intermediate", weight: "15-20% body weight", color: .orange)
                        RecommendationRow(title: "Advanced", weight: "20-25% body weight", color: .red)
                        RecommendationRow(title: "Military Standard", weight: "35+ lbs", color: .blue)
                    }
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
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Onboarding Status")
                        Spacer()
                        Text(userSettings.hasCompletedOnboarding ? "Completed" : "Pending")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if hasChanges() {
                            saveSettings()
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
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
        tempBodyWeight = String(format: "%.1f", userSettings.bodyWeight)
        tempDefaultRuckWeight = String(format: "%.1f", userSettings.defaultRuckWeight)
    }
    
    private func hasChanges() -> Bool {
        guard let bodyWeight = Double(tempBodyWeight),
              let ruckWeight = Double(tempDefaultRuckWeight) else {
            return false
        }
        
        return abs(bodyWeight - userSettings.bodyWeight) > 0.1 ||
               abs(ruckWeight - userSettings.defaultRuckWeight) > 0.1
    }
    
    private func saveSettings() {
        guard let bodyWeight = Double(tempBodyWeight),
              let ruckWeight = Double(tempDefaultRuckWeight) else {
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

struct RecommendationRow: View {
    let title: String
    let weight: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(title)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(weight)
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

#Preview {
    SettingsView()
}
