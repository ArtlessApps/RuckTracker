//
//  HealthKitErrorView.swift
//  RuckTracker Watch App
//
//  User-friendly error display for HealthKit issues
//

import SwiftUI
import HealthKit

struct HealthKitErrorView: View {
    @ObservedObject var errorManager: HealthKitErrorManager
    @EnvironmentObject var healthManager: HealthManager
    let isMinimal: Bool
    
    init(errorManager: HealthKitErrorManager, isMinimal: Bool = false) {
        self.errorManager = errorManager
        self.isMinimal = isMinimal
    }
    
    var body: some View {
        if let currentError = errorManager.currentError {
            VStack(spacing: isMinimal ? 4 : 8) {
                // Error icon and title
                HStack(spacing: 6) {
                    Image(systemName: currentError.severity.icon)
                        .foregroundColor(currentError.severity.color)
                        .font(.system(size: isMinimal ? 12 : 16, weight: .semibold))
                    
                    if !isMinimal {
                        Text("HealthKit Issue")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(currentError.severity.color)
                    }
                    
                    Spacer()
                    
                    // Dismiss button
                    Button(action: {
                        errorManager.clearError()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: isMinimal ? 10 : 12))
                    }
                }
                
                // Error message
                Text(currentError.localizedDescription)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(isMinimal ? 2 : 3)
                
                if !isMinimal {
                    // Recovery suggestion (abbreviated for watch)
                    if currentError.recoverySuggestion != nil {
                        Text(getWatchRecoverySuggestion(for: currentError))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                    }
                    
                    // Action buttons (compact for watch)
                    HStack(spacing: 8) {
                        // Retry button (if applicable)
                        if currentError.shouldRetry && errorManager.retryCount < 3 {
                            Button(action: {
                                switch currentError {
                                case .authorizationFailed, .authorizationNotDetermined:
                                    healthManager.retryAuthorization()
                                default:
                                    _ = errorManager.retryOperation()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption2)
                                    .padding(4)
                                    .background(currentError.severity.color.opacity(0.2))
                                    .foregroundColor(currentError.severity.color)
                                    .clipShape(Circle())
                            }
                        }
                        
                        Spacer()
                        
                        // Settings hint (for permission issues)
                        if isPermissionError(currentError) {
                            Text("Check iPhone Health app")
                                .font(.caption2)
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
            }
            .padding(isMinimal ? 6 : 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(currentError.severity.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(currentError.severity.color.opacity(0.4), lineWidth: 0.5)
                    )
            )
            .animation(.easeInOut(duration: 0.3), value: currentError)
        }
    }
    
    private func isPermissionError(_ error: HealthKitError) -> Bool {
        switch error {
        case .authorizationDenied, .authorizationNotDetermined, .insufficientPermissions, .permissionRevoked:
            return true
        default:
            return false
        }
    }
    
    private func getWatchRecoverySuggestion(for error: HealthKitError) -> String {
        switch error {
        case .authorizationDenied, .permissionRevoked:
            return "Open Health app on iPhone"
        case .authorizationNotDetermined:
            return "Grant permissions"
        case .workoutSessionCreationFailed, .workoutBuilderCreationFailed:
            return "End other workouts & restart"
        case .workoutSaveFailed:
            return "Data saved locally"
        case .networkError:
            return "Check connection"
        default:
            return "App will continue"
        }
    }
}

// MARK: - Health Status Banner for Watch
struct WatchHealthKitStatusBanner: View {
    @EnvironmentObject var healthManager: HealthManager
    let isMinimal: Bool
    
    init(isMinimal: Bool = false) {
        self.isMinimal = isMinimal
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Show error if there is one
            HealthKitErrorView(errorManager: healthManager.errorManager, isMinimal: isMinimal)
            
            // Show authorization status if no error
            if healthManager.errorManager.currentError == nil {
                if healthManager.authorizationInProgress {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Requesting permissions...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(isMinimal ? 6 : 8)
                } else if !healthManager.isAuthorized {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.circle")
                                .foregroundColor(AppColors.accentWarm)
                                .font(.system(size: 14))
                            
                            Text("HealthKit Setup")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.accentWarm)
                            
                            Spacer()
                        }
                        
                        if !isMinimal {
                            Text("Tap to enable workout tracking")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Show recovery instructions if there have been failed attempts
                            if healthManager.errorManager.currentError != nil {
                                Text(healthManager.getRecoveryInstructions())
                                    .font(.caption2)
                                    .foregroundColor(AppColors.accentWarm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding(isMinimal ? 6 : 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.accentWarm.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AppColors.accentWarm.opacity(0.4), lineWidth: 0.5)
                            )
                    )
                    .onTapGesture {
                        healthManager.requestAuthorization()
                    }
                }
            }
        }
    }
}

// MARK: - Workout Error Display (specific to workout issues)
struct WorkoutErrorView: View {
    @ObservedObject var workoutErrorManager: HealthKitErrorManager
    
    var body: some View {
        if let currentError = workoutErrorManager.currentError,
           isWorkoutError(currentError) {
            HStack(spacing: 6) {
                Image(systemName: currentError.severity.icon)
                    .foregroundColor(currentError.severity.color)
                    .font(.system(size: 12))
                
                Text(getShortErrorMessage(for: currentError))
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                if currentError.shouldRetry {
                    Button(action: {
                        _ = workoutErrorManager.retryOperation()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(currentError.severity.color.opacity(0.1))
            )
        }
    }
    
    private func isWorkoutError(_ error: HealthKitError) -> Bool {
        switch error {
        case .workoutSessionCreationFailed, .workoutBuilderCreationFailed, 
             .workoutDataCollectionFailed, .workoutSaveFailed:
            return true
        default:
            return false
        }
    }
    
    private func getShortErrorMessage(for error: HealthKitError) -> String {
        switch error {
        case .workoutSessionCreationFailed:
            return "Session failed"
        case .workoutBuilderCreationFailed:
            return "Builder failed"
        case .workoutDataCollectionFailed:
            return "Data collection issue"
        case .workoutSaveFailed:
            return "Save failed - data kept locally"
        default:
            return "HealthKit issue"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        WatchHealthKitStatusBanner()
            .environmentObject({
                let healthManager = HealthManager()
                healthManager.errorManager.handleError(.authorizationDenied(dataType: "Heart Rate"), context: "Test")
                return healthManager
            }())
        
        WorkoutErrorView(workoutErrorManager: {
            let errorManager = HealthKitErrorManager()
            errorManager.handleError(.workoutSaveFailed(underlying: nil), context: "Test")
            return errorManager
        }())
    }
    .padding()
}
