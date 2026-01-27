//
//  OnboardingView.swift
//  MARCH Watch App
//
//  Clean onboarding flow with MARCH branding - USES APPCOLORS
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
        // CHANGED: Uses AppColors.background instead of .black
        .background(AppColors.background)
    }
    
    private func nextStep() {
        withAnimation {
            currentStep += 1
        }
    }
    
    private func previousStep() {
        withAnimation {
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

// MARK: - Welcome Step
struct WelcomeStep: View {
    let nextAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // MARCH branding
            VStack(spacing: 4) {
                // CHANGED: Uses AppColors.primary (electric green) instead of .orange
                Text("MARCH")
                    .font(.system(size: 32, weight: .black, design: .default))
                    .foregroundColor(AppColors.primary)
                    .tracking(1)
                
                // CHANGED: Uses AppColors.textPrimary instead of .white
                Text("WALK STRONGER")
                    .font(.system(size: 8, weight: .medium, design: .default))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(2)
            }
            .padding(.bottom, 16)
            
            // Subtitle
            // CHANGED: Uses AppColors.textSecondary instead of .white
            Text("Track rucking workouts with distance, calories, and heart rate.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Spacer()
            
            // CTA Button
            Button("Get Started") {
                nextAction()
            }
            .frame(maxWidth: .infinity)
            // CHANGED: Uses AppColors.textPrimary instead of .white
            .foregroundColor(AppColors.textPrimary)
            .padding(.vertical, 10)
            // CHANGED: Uses AppColors.primary instead of .orange
            .background(AppColors.primary)
            .cornerRadius(8)
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        // CHANGED: Uses AppColors.background instead of .black
        .background(AppColors.background)
    }
}

// MARK: - Body Weight Setup Step
struct BodyWeightSetupStep: View {
    let bodyWeight: Double
    let weightUnit: UserSettings.WeightUnit
    @Binding var showingPicker: Bool
    let nextAction: () -> Void
    let backAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // CHANGED: Uses AppColors.textPrimary instead of .white
            Text("Body Weight")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 16)
            
            Spacer()
            
            VStack(spacing: 8) {
                // CHANGED: Uses AppColors.textPrimary instead of .white
                Text(String(format: "%.0f", bodyWeight))
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                // CHANGED: Uses AppColors.textSecondary instead of .gray
                Text(weightUnit.rawValue)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 10) {
                Button("Back") {
                    backAction()
                }
                .frame(maxWidth: .infinity)
                // CHANGED: Uses AppColors.textPrimary instead of .white
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 10)
                // CHANGED: Uses AppColors.surface instead of .gray.opacity(0.5)
                .background(AppColors.surface)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                
                Button("Next") {
                    nextAction()
                }
                .frame(maxWidth: .infinity)
                // CHANGED: Uses AppColors.textPrimary instead of .white
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 10)
                // CHANGED: Uses AppColors.primary instead of .orange
                .background(AppColors.primary)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        // CHANGED: Uses AppColors.background instead of .black
        .background(AppColors.background)
    }
}

// MARK: - HealthKit Permission Step
struct HealthKitPermissionStep: View {
    @ObservedObject var healthManager: HealthManager
    @State private var hasRequestedPermission = false
    let nextAction: () -> Void
    let backAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // CHANGED: Uses AppColors.textPrimary instead of .white
            Text("Health Access")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // CHANGED: Uses AppColors.textSecondary instead of .white
                    Text("MARCH needs access to:")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, 8)
                    
                    // CHANGED: Uses AppColors.primary instead of .orange
                    PermissionRow(icon: "heart.fill", text: "Heart Rate", color: AppColors.primary)
                    PermissionRow(icon: "flame.fill", text: "Active Calories", color: AppColors.primary)
                    PermissionRow(icon: "figure.walk", text: "Workouts", color: AppColors.primary)
                    
                    if healthManager.isAuthorized {
                        HStack(spacing: 6) {
                            // CHANGED: Uses AppColors.successGreen instead of .green
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.successGreen)
                            // CHANGED: Uses AppColors.successGreen instead of .green
                            Text("Authorized")
                                .font(.caption)
                                .foregroundColor(AppColors.successGreen)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
            
            // Request Permission Button
            if !healthManager.isAuthorized {
                Button("Allow Access") {
                    healthManager.requestAuthorization()
                    hasRequestedPermission = true
                }
                .frame(maxWidth: .infinity)
                // CHANGED: Uses AppColors.textPrimary instead of .white
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 10)
                // CHANGED: Uses AppColors.primary instead of .orange
                .background(AppColors.primary)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            // Navigation buttons
            HStack(spacing: 10) {
                Button("Back") {
                    backAction()
                }
                .frame(maxWidth: .infinity)
                // CHANGED: Uses AppColors.textPrimary instead of .white
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 10)
                // CHANGED: Uses AppColors.surface instead of .gray.opacity(0.5)
                .background(AppColors.surface)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                
                Button("Next") {
                    nextAction()
                }
                .frame(maxWidth: .infinity)
                // CHANGED: Uses AppColors.textPrimary instead of .white
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 10)
                // CHANGED: Uses conditional AppColors instead of orange/gray
                .background(
                    (hasRequestedPermission || healthManager.isAuthorized) ? 
                    AppColors.primary : AppColors.surface
                )
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                .disabled(!hasRequestedPermission && !healthManager.isAuthorized)
                .opacity((hasRequestedPermission || healthManager.isAuthorized) ? 1.0 : 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        // CHANGED: Uses AppColors.background instead of .black
        .background(AppColors.background)
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
            
            // CHANGED: Uses AppColors.textPrimary instead of .white
            Text(text)
                .font(.caption)
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
        }
    }
}

// MARK: - Preferences Setup Step
struct PreferencesSetupStep: View {
    let ruckWeight: Double
    let weightUnit: UserSettings.WeightUnit
    let distanceUnit: UserSettings.DistanceUnit
    @Binding var showingRuckPicker: Bool
    @Binding var showingUnitsPicker: Bool
    let completeAction: () -> Void
    let backAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // CHANGED: Uses AppColors.textPrimary instead of .white
            Text("Preferences")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Ruck Weight
                    VStack(alignment: .leading, spacing: 4) {
                        // CHANGED: Uses AppColors.textSecondary instead of .gray
                        Text("Default Ruck Weight")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Button(action: {
                            showingRuckPicker = true
                        }) {
                            HStack {
                                // CHANGED: Uses AppColors.textPrimary instead of .white
                                Text(String(format: "%.0f %@", ruckWeight, weightUnit.rawValue))
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    // CHANGED: Uses AppColors.textSecondary instead of .gray
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        // CHANGED: Uses AppColors surface with opacity
                        .background(AppColors.surface.opacity(0.5))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Distance Unit
                    VStack(alignment: .leading, spacing: 4) {
                        // CHANGED: Uses AppColors.textSecondary instead of .gray
                        Text("Distance Unit")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Button(action: {
                            showingUnitsPicker = true
                        }) {
                            HStack {
                                // CHANGED: Uses AppColors.textPrimary instead of .white
                                Text(distanceUnit.rawValue)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    // CHANGED: Uses AppColors.textSecondary instead of .gray
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        // CHANGED: Uses AppColors surface with opacity
                        .background(AppColors.surface.opacity(0.5))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 10) {
                Button("Back") {
                    backAction()
                }
                .frame(maxWidth: .infinity)
                // CHANGED: Uses AppColors.textPrimary instead of .white
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 10)
                // CHANGED: Uses AppColors.surface instead of .gray.opacity(0.5)
                .background(AppColors.surface)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
                
                Button("Complete") {
                    completeAction()
                }
                .frame(maxWidth: .infinity)
                // CHANGED: Uses AppColors.textPrimary instead of .white
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 10)
                // CHANGED: Uses AppColors.primary instead of .orange
                .background(AppColors.primary)
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        // CHANGED: Uses AppColors.background instead of .black
        .background(AppColors.background)
    }
}

// MARK: - Onboarding Picker Views
struct OnboardingBodyWeightPicker: View {
    @Binding var selectedWeight: Double
    let weightUnit: UserSettings.WeightUnit
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // CHANGED: Uses AppColors.textPrimary instead of .white
            Text("Body Weight")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 16)
            
            Picker("Weight", selection: $selectedWeight) {
                ForEach(weightOptions, id: \.self) { weight in
                    Text(String(format: weightUnit == .pounds ? "%.0f" : "%.1f", weight))
                }
            }
            .pickerStyle(WheelPickerStyle())
            
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
            .frame(maxWidth: .infinity)
            // CHANGED: Uses AppColors.textPrimary instead of .white
            .foregroundColor(AppColors.textPrimary)
            .padding(.vertical, 10)
            // CHANGED: Uses AppColors.primary instead of .orange
            .background(AppColors.primary)
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        // CHANGED: Uses AppColors.background instead of .black
        .background(AppColors.background)
    }
    
    private var weightOptions: [Double] {
        if weightUnit == .pounds {
            return Array(stride(from: 80.0, through: 400.0, by: 1.0))
        } else {
            return Array(stride(from: 35.0, through: 180.0, by: 0.5))
        }
    }
}
