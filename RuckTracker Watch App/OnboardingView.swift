//
//  OnboardingView.swift
//  MARCH Watch App
//
//  Clean onboarding flow with MARCH branding
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @EnvironmentObject var healthManager: HealthManager
    @State private var currentStep = 0
    @State private var bodyWeight: Double = 180.0
    @State private var ruckWeight: Double = 20.0
    @State private var selectedWeightUnit: UserSettings.WeightUnit = .pounds
    @State private var selectedDistanceUnit: UserSettings.DistanceUnit = .miles
    @State private var showingBodyWeightPicker = false
    @State private var showingRuckWeightPicker = false
    @State private var showingUnitsPicker = false
    
    private let totalSteps = 4
    
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
                    HealthKitPermissionStep(
                        healthManager: healthManager,
                        nextAction: nextStep,
                        backAction: previousStep
                    )
                case 3:
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
            bodyWeight = 81.6 // 180 lbs converted to kg
            ruckWeight = 9.0
        } else {
            selectedWeightUnit = .pounds
            selectedDistanceUnit = .miles
            bodyWeight = 180.0
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

// HealthKit Permission Step
struct HealthKitPermissionStep: View {
    @ObservedObject var healthManager: HealthManager
    let nextAction: () -> Void
    let backAction: () -> Void
    @State private var hasRequestedPermission = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Icon with circle background (MARCH style)
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 60, height: 60)
                    
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 6)
                
                // Title and description
                VStack(spacing: 4) {
                    Text("Health Integration")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("MARCH saves workouts to Health for fitness tracking.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
                
                // Permissions list with icons
                VStack(spacing: 6) {
                    PermissionRow(icon: "figure.walk", text: "Workouts", color: .green)
                    PermissionRow(icon: "flame.fill", text: "Calories", color: .orange)
                    PermissionRow(icon: "location.fill", text: "Distance", color: .blue)
                    PermissionRow(icon: "heart.fill", text: "Heart Rate", color: .red)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // Status message
                if healthManager.isAuthorized {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text("Connected")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    .padding(.bottom, 6)
                } else if healthManager.authorizationInProgress {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Requesting...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 6)
                } else if !hasRequestedPermission {
                    Button("Enable HealthKit") {
                        hasRequestedPermission = true
                        healthManager.requestAuthorization()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                } else {
                    Text("Enable later in Settings")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }
                
                // Navigation buttons
                HStack(spacing: 10) {
                    Button("Back") {
                        backAction()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("Continue") {
                        nextAction()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .background((hasRequestedPermission || healthManager.isAuthorized) ? Color.orange : Color.gray.opacity(0.5))
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!hasRequestedPermission && !healthManager.isAuthorized)
                    .opacity((hasRequestedPermission || healthManager.isAuthorized) ? 1.0 : 0.5)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(Color.black)
        .onAppear {
            // If already authorized from a previous session, mark as requested
            if healthManager.isAuthorized {
                hasRequestedPermission = true
            }
        }
    }
}

// Helper view for permission rows
struct PermissionRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

struct WelcomeStep: View {
    let nextAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // MARCH branding
            VStack(spacing: 4) {
                Text("MARCH")
                    .font(.system(size: 32, weight: .black, design: .default))
                    .foregroundColor(.orange)
                    .tracking(1)
                
                Text("WALK STRONGER")
                    .font(.system(size: 8, weight: .medium, design: .default))
                    .foregroundColor(.white)
                    .tracking(2)
            }
            .padding(.bottom, 16)
            
            // Subtitle
            Text("Track rucking workouts with distance, calories, and heart rate.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Spacer()
            
            // Get Started button
            Button("Get Started") {
                nextAction()
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .background(Color.orange)
            .cornerRadius(10)
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(Color.black)
    }
}

struct BodyWeightSetupStep: View {
    let bodyWeight: Double
    let weightUnit: UserSettings.WeightUnit
    @Binding var showingPicker: Bool
    let nextAction: () -> Void
    let backAction: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Body Weight")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                
                // Weight display with tap to edit
                Button {
                    showingPicker = true
                } label: {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", bodyWeight))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.orange)
                        Text(weightUnit.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                
                Text("Tap to adjust")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
                
                // Navigation buttons
                HStack(spacing: 10) {
                    Button("Back") {
                        backAction()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("Next") {
                        nextAction()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(Color.black)
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
        ScrollView {
            VStack(spacing: 12) {
                Text("Preferences")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                // Ruck Weight
                Button {
                    showingRuckPicker = true
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Default Ruck Weight")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(String(format: "%.0f %@", ruckWeight, weightUnit.rawValue))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                
                // Units
                Button {
                    showingUnitsPicker = true
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Units")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Weight:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(weightUnit.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            HStack {
                                Text("Distance:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(distanceUnit.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // Navigation buttons
                HStack(spacing: 10) {
                    Button("Back") {
                        backAction()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("Complete") {
                        completeAction()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(Color.black)
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
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
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
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(10)
                .buttonStyle(PlainButtonStyle())
                
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.black)
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
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
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
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(10)
                .buttonStyle(PlainButtonStyle())
                
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.black)
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
        VStack(spacing: 0) {
            HStack {
                Text("Units")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.orange)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            List {
                Section {
                    ForEach(UserSettings.WeightUnit.allCases, id: \.self) { unit in
                        Button {
                            selectedWeightUnit = unit
                        } label: {
                            HStack {
                                Text(unit.rawValue.capitalized)
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedWeightUnit == unit {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } header: {
                    Text("Weight")
                        .foregroundColor(.secondary)
                }
                
                Section {
                    ForEach(UserSettings.DistanceUnit.allCases, id: \.self) { unit in
                        Button {
                            selectedDistanceUnit = unit
                        } label: {
                            HStack {
                                Text(unit.rawValue.capitalized)
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedDistanceUnit == unit {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } header: {
                    Text("Distance")
                        .foregroundColor(.secondary)
                }
            }
        }
        .background(Color.black)
    }
}

#Preview {
    OnboardingView()
}
