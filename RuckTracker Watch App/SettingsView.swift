//
//  SettingsView.swift
//  RuckTracker Watch App
//
//  Created by Assistant on 9/13/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingBodyWeightPicker = false
    @State private var showingRuckWeightPicker = false
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Quick Overview
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.orange)
                            Text("RuckTracker")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        
                        Text("Configure your settings")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - Body Weight
                Section("Body Weight") {
                    Button {
                        showingBodyWeightPicker = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your Weight")
                                    .foregroundColor(.primary)
                                Text(userSettings.bodyWeightDisplayString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // MARK: - Default Ruck Weight
                Section("Default Ruck Weight") {
                    Button {
                        showingRuckWeightPicker = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Starting Weight")
                                    .foregroundColor(.primary)
                                Text("\(String(format: "%.0f", userSettings.defaultRuckWeight)) \(userSettings.preferredWeightUnit.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // MARK: - Units
                Section("Units") {
                    NavigationLink("Weight & Distance", destination: UnitsSettingsView())
                }
                
                // MARK: - Actions
                Section {
                    Button("Reset to Defaults") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Body Weight Picker
struct BodyWeightPickerView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedWeight: Double = 150.0
    
    private let weightRange: [Double] = {
        var range: [Double] = []
        for i in stride(from: 80.0, through: 400.0, by: 1.0) {
            range.append(i)
        }
        return range
    }()
    
    private let kgWeightRange: [Double] = {
        var range: [Double] = []
        for i in stride(from: 36.0, through: 180.0, by: 0.5) {
            range.append(i)
        }
        return range
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Unit selector
                HStack {
                    Text("Unit:")
                        .font(.caption)
                    Spacer()
                    ForEach(UserSettings.WeightUnit.allCases, id: \.self) { unit in
                        Button {
                            userSettings.preferredWeightUnit = unit
                        } label: {
                            Text(unit.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    userSettings.preferredWeightUnit == unit ? 
                                    Color.blue : Color.gray.opacity(0.3)
                                )
                                .foregroundColor(
                                    userSettings.preferredWeightUnit == unit ? 
                                    .white : .primary
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Weight picker
                Picker("Weight", selection: $selectedWeight) {
                    let range = userSettings.preferredWeightUnit == .pounds ? weightRange : kgWeightRange
                    ForEach(range, id: \.self) { weight in
                        Text("\(String(format: "%.1f", weight))")
                            .tag(weight)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                
                Text("\(String(format: "%.1f", selectedWeight)) \(userSettings.preferredWeightUnit.rawValue)")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .navigationTitle("Body Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if userSettings.isValidBodyWeight(selectedWeight) {
                            userSettings.bodyWeight = selectedWeight
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .onAppear {
                selectedWeight = userSettings.bodyWeight
            }
        }
    }
}

// MARK: - Ruck Weight Picker
struct RuckWeightPickerView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedWeight: Double = 20.0
    
    private let weightRange: [Double] = {
        var range: [Double] = []
        for i in stride(from: 0.0, through: 100.0, by: 5.0) {
            range.append(i)
        }
        return range
    }()
    
    private let kgWeightRange: [Double] = {
        var range: [Double] = []
        for i in stride(from: 0.0, through: 45.0, by: 2.5) {
            range.append(i)
        }
        return range
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Weight picker
                Picker("Ruck Weight", selection: $selectedWeight) {
                    let range = userSettings.preferredWeightUnit == .pounds ? weightRange : kgWeightRange
                    ForEach(range, id: \.self) { weight in
                        Text("\(String(format: "%.1f", weight))")
                            .tag(weight)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                
                Text("\(String(format: "%.1f", selectedWeight)) \(userSettings.preferredWeightUnit.rawValue)")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                // Recommendations
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommendations:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    let bodyWeightPounds = userSettings.bodyWeightInKg * 2.20462
                    let percentage = (selectedWeight / bodyWeightPounds) * 100
                    
                    Text("This is \(String(format: "%.0f", percentage))% of your body weight")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if percentage < 10 {
                        Text("• Light load - good for beginners")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else if percentage < 15 {
                        Text("• Moderate load - good starting point")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else if percentage < 20 {
                        Text("• Heavy load - intermediate level")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Text("• Very heavy load - advanced only")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Ruck Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if userSettings.isValidRuckWeight(selectedWeight) {
                            userSettings.defaultRuckWeight = selectedWeight
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .onAppear {
                selectedWeight = userSettings.defaultRuckWeight
            }
        }
    }
}

// MARK: - Units Settings
struct UnitsSettingsView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        List {
            Section("Weight Unit") {
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
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Section("Distance Unit") {
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
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}
