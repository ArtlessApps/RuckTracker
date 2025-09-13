//
//  OnboardingView.swift
//  RuckTracker Watch App
//
//  Clean onboarding flow matching SettingsView design
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var currentStep = 0
    @State private var bodyWeight: Double = 155.0
    @State private var ruckWeight: Double = 20.0
    @State private var selectedWeightUnit: UserSettings.WeightUnit = .pounds
    @State private var selectedDistanceUnit: UserSettings.DistanceUnit = .miles
    @State private var showingBodyWeightPicker = false
    @State private var showingRuckWeightPicker = false
    @State private var showingUnitsPicker = false
    
    private let totalSteps = 3
    
    var body: some View {
        NavigationView {
            Group {
                switch currentStep {
                case 0:
                    WelcomeStep(nextAction: nextStep)
                case 1:
                    BodyWeightSetupStep(
                        bodyWeight: bodyWeight,
                        weightUnit: selectedWeightUnit,
                        showingPicker: $showingBodyWeightPicker,
                        nextAction: nextStep,
                        backAction: previousStep
                    )
                case 2:
                    PreferencesSetupStep(
                        ruckWeight: ruckWeight,
                        weightUnit: selectedWeightUnit,
                        distanceUnit: selectedDistanceUnit,
                        showingRuckPicker: $showingRuckWeightPicker,
                        showingUnitsPicker: $showingUnitsPicker,
                        completeAction: completeOnboarding,
                        backAction: previousStep
                    )
                default:
                    EmptyView()
                }
            }
        }
        .onAppear {
            setupDefaults()
        }
        .sheet(isPresented: $showingBodyWeightPicker) {
            OnboardingBodyWeightPicker(
                selectedWeight: $bodyWeight,
                weightUnit: selectedWeightUnit
            )
        }
        .sheet(isPresented: $showingRuckWeightPicker) {
            OnboardingRuckWeightPicker(
                selectedWeight: $ruckWeight,
                weightUnit: selectedWeightUnit
            )
        }
        .sheet(isPresented: $showingUnitsPicker) {
            OnboardingUnitsPicker(
                selectedWeightUnit: $selectedWeightUnit,
                selectedDistanceUnit: $selectedDistanceUnit
            )
        }
    }
    
    private func setupDefaults() {
        // Smart defaults based on locale
        if Locale.current.measurementSystem == .metric {
            selectedWeightUnit = .kilograms
            selectedDistanceUnit = .kilometers
            bodyWeight = 70.0
            ruckWeight = 9.0
        } else {
            selectedWeightUnit = .pounds
            selectedDistanceUnit = .miles
            bodyWeight = 155.0
            ruckWeight = 20.0
        }
    }
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep += 1
        }
    }
    
    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep -= 1
        }
    }
    
    private func completeOnboarding() {
        userSettings.bodyWeight = bodyWeight
        userSettings.defaultRuckWeight = ruckWeight
        userSettings.preferredWeightUnit = selectedWeightUnit
        userSettings.preferredDistanceUnit = selectedDistanceUnit
        userSettings.hasCompletedOnboarding = true
    }
}

// MARK: - Clean Onboarding Steps
struct WelcomeStep: View {
    let nextAction: () -> Void
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 8) {
                        Text("Welcome to")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("RuckTracker")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Let's set up your profile for accurate tracking of weighted walks.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }
            
            Section {
                Button("Get Started") {
                    nextAction()
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle("Setup")
    }
}

struct BodyWeightSetupStep: View {
    let bodyWeight: Double
    let weightUnit: UserSettings.WeightUnit
    @Binding var showingPicker: Bool
    let nextAction: () -> Void
    let backAction: () -> Void
    
    var body: some View {
        List {
            Section {
                Button {
                    showingPicker = true
                } label: {
                    HStack {
                        Text(String(format: "%.1f %@", bodyWeight, weightUnit.rawValue))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Section {
                HStack(spacing: 16) {
                    Button("Back") {
                        backAction()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .background(Color.gray)
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("Next") {
                        nextAction()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .navigationTitle("Body Weight")
    }
}

struct PreferencesSetupStep: View {
    let ruckWeight: Double
    let weightUnit: UserSettings.WeightUnit
    let distanceUnit: UserSettings.DistanceUnit
    @Binding var showingRuckPicker: Bool
    @Binding var showingUnitsPicker: Bool
    let completeAction: () -> Void
    let backAction: () -> Void
    
    var body: some View {
        List {
            Section("Default Ruck Weight") {
                Button {
                    showingRuckPicker = true
                } label: {
                    HStack {
                        Text(String(format: "%.0f %@", ruckWeight, weightUnit.rawValue))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Section("Units") {
                Button {
                    showingUnitsPicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weight: \(weightUnit.rawValue)")
                                .foregroundColor(.primary)
                            Text("Distance: \(distanceUnit.rawValue)")
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Section {
                HStack(spacing: 16) {
                    Button("Back") {
                        backAction()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .background(Color.gray)
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("Complete") {
                        completeAction()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        //.navigationTitle("Preferences")
    }
}

// MARK: - Onboarding Picker Views
struct OnboardingBodyWeightPicker: View {
    @Binding var selectedWeight: Double
    let weightUnit: UserSettings.WeightUnit
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Body Weight")
                .font(.headline)
                .padding(.top, 16)
            
            Picker("Weight", selection: $selectedWeight) {
                ForEach(weightOptions, id: \.self) { weight in
                    Text(String(format: weightUnit == .pounds ? "%.0f" : "%.1f", weight))
                        .tag(weight)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 80)
            .clipped()
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationBarHidden(true)
    }
    
    private var weightOptions: [Double] {
        if weightUnit == .pounds {
            return Array(stride(from: 80.0, through: 400.0, by: 5.0))
        } else {
            return Array(stride(from: 36.0, through: 180.0, by: 1.0))
        }
    }
}

struct OnboardingRuckWeightPicker: View {
    @Binding var selectedWeight: Double
    let weightUnit: UserSettings.WeightUnit
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Ruck Weight")
                .font(.headline)
                .padding(.top, 16)
            
            Picker("Ruck Weight", selection: $selectedWeight) {
                ForEach(weightOptions, id: \.self) { weight in
                    Text(String(format: weightUnit == .pounds ? "%.0f" : "%.1f", weight))
                        .tag(weight)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 80)
            .clipped()
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationBarHidden(true)
    }
    
    private var weightOptions: [Double] {
        if weightUnit == .pounds {
            return Array(stride(from: 0.0, through: 100.0, by: 5.0))
        } else {
            return Array(stride(from: 0.0, through: 45.0, by: 2.5))
        }
    }
}

struct OnboardingUnitsPicker: View {
    @Binding var selectedWeightUnit: UserSettings.WeightUnit
    @Binding var selectedDistanceUnit: UserSettings.DistanceUnit
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section("Weight") {
                    ForEach(UserSettings.WeightUnit.allCases, id: \.self) { unit in
                        Button {
                            selectedWeightUnit = unit
                        } label: {
                            HStack {
                                Text(unit.rawValue.capitalized)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedWeightUnit == unit {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Section("Distance") {
                    ForEach(UserSettings.DistanceUnit.allCases, id: \.self) { unit in
                        Button {
                            selectedDistanceUnit = unit
                        } label: {
                            HStack {
                                Text(unit.rawValue.capitalized)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedDistanceUnit == unit {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Units")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
}
