//
//  PhoneOnboardingView.swift
//  MARCH
//
//  iPhone onboarding flow for permissions
//

import SwiftUI
import CoreLocation

struct PhoneOnboardingView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var workoutManager: WorkoutManager
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentStep = 0
    
    private let totalSteps = 3
    
    var body: some View {
        ZStack {
            Color("BackgroundDark")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                progressBar
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeStep(nextAction: nextStep)
                        .tag(0)
                    
                    HealthKitPermissionStep(
                        healthManager: healthManager,
                        nextAction: nextStep,
                        backAction: previousStep
                    )
                    .tag(1)
                    
                    LocationPermissionStep(
                        workoutManager: workoutManager,
                        onComplete: completeOnboarding
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }
    
    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Rectangle()
                    .fill(index <= currentStep ? Color("PrimaryMain") : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentStep < totalSteps - 1 {
                currentStep += 1
            }
        }
    }
    
    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentStep > 0 {
                currentStep -= 1
            }
        }
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

// MARK: - Welcome Step (MARCH Style)

struct WelcomeStep: View {
    let nextAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // MARCH branding (matches splash screen)
            VStack(spacing: 8) {
                Text("MARCH")
                    .font(.system(size: 72, weight: .black, design: .default))
                    .foregroundColor(Color("PrimaryMain"))
                    .tracking(2)
                
                Text("WALK STRONGER")
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(.white)
                    .tracking(4)
            }
            .padding(.bottom, 40)
            
            // Subtitle
            Text("Track your rucking workouts with\naccurate distance, calories, and heart rate.")
                .font(.system(size: 17))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Feature highlights
            VStack(spacing: 16) {
                FeatureHighlight(
                    icon: "figure.walk",
                    text: "Weight-adjusted calorie tracking"
                )
                
                FeatureHighlight(
                    icon: "location.fill",
                    text: "GPS distance tracking"
                )
                
                FeatureHighlight(
                    icon: "heart.fill",
                    text: "HealthKit integration"
                )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            
            Button(action: nextAction) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color("PrimaryMain"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

struct FeatureHighlight: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color("PrimaryMain"))
                .frame(width: 28)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

// MARK: - HealthKit Permission Step

struct HealthKitPermissionStep: View {
    @ObservedObject var healthManager: HealthManager
    let nextAction: () -> Void
    let backAction: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon with circle background (like your screenshots)
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 140, height: 140)
                
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color("BackgroundDark"))
                }
            }
            
            VStack(spacing: 12) {
                Text("Health Integration")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("RuckTracker saves your workouts to the Health app for complete fitness tracking.")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Permissions list with green checkmarks
            VStack(spacing: 16) {
                OnboardingPermissionRow(
                    icon: "figure.walk",
                    title: "Workouts",
                    description: "Save your ruck sessions",
                    isGranted: healthManager.isAuthorized
                )
                
                OnboardingPermissionRow(
                    icon: "flame.fill",
                    title: "Calories",
                    description: "Track energy burned",
                    isGranted: healthManager.isAuthorized
                )
                
                OnboardingPermissionRow(
                    icon: "location.fill",
                    title: "Distance",
                    description: "Record miles traveled",
                    isGranted: healthManager.isAuthorized
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            
            // Status and action buttons
            VStack(spacing: 12) {
                if healthManager.isAuthorized {
                    // Success state
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("HealthKit Connected")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 12)
                    
                    Button(action: nextAction) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color("PrimaryMain"))
                            .cornerRadius(16)
                    }
                } else {
                    // Needs permission state
                    Button(action: {
                        healthManager.requestAuthorization()
                    }) {
                        Text(healthManager.authorizationInProgress ? "Requesting..." : "Enable HealthKit")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(healthManager.authorizationInProgress ? Color.gray : Color.red)
                            .cornerRadius(16)
                    }
                    .disabled(healthManager.authorizationInProgress)
                    
                    if healthManager.authorizationInProgress {
                        Text("Check the Health app for the permission prompt")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                
                Button(action: backAction) {
                    Text("Back")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Location Permission Step

struct LocationPermissionStep: View {
    @ObservedObject var workoutManager: WorkoutManager
    let onComplete: () -> Void
    
    private var isLocationAuthorized: Bool {
        workoutManager.locationAuthorizationStatus == .authorizedWhenInUse ||
        workoutManager.locationAuthorizationStatus == .authorizedAlways
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon with circle background (like your screenshots)
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 140, height: 140)
                
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "location.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 12) {
                Text("GPS Tracking")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Enable location services for accurate distance tracking during your rucks.")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Permissions list with green checkmarks
            VStack(spacing: 16) {
                OnboardingPermissionRow(
                    icon: "map.fill",
                    title: "Route Mapping",
                    description: "Track your path",
                    isGranted: isLocationAuthorized
                )
                
                OnboardingPermissionRow(
                    icon: "ruler.fill",
                    title: "Distance Accuracy",
                    description: "Precise GPS measurements",
                    isGranted: isLocationAuthorized
                )
                
                OnboardingPermissionRow(
                    icon: "speedometer",
                    title: "Pace Tracking",
                    description: "Real-time speed data",
                    isGranted: isLocationAuthorized
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            
            // Status and action buttons
            VStack(spacing: 12) {
                if isLocationAuthorized {
                    // Success state
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Location Access Granted")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 12)
                    
                    Button(action: onComplete) {
                        Text("Start Rucking")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color("PrimaryMain"))
                            .cornerRadius(16)
                    }
                } else {
                    // Needs permission state
                    Button(action: {
                        workoutManager.requestLocationPermission()
                    }) {
                        Text("Enable Location")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                    
                    Text("Select 'Allow While Using App' when prompted")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                    
                    Button(action: onComplete) {
                        Text("Skip for Now")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Onboarding Permission Row (matching your design)

struct OnboardingPermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon in circle
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isGranted ? .green : .white.opacity(0.5))
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Checkmark
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    PhoneOnboardingView(hasCompletedOnboarding: .constant(false))
        .environmentObject(HealthManager.shared)
        .environmentObject(WorkoutManager())
}
