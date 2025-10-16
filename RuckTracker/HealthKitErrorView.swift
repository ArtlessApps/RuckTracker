//
//  HealthKitErrorView.swift
//  RuckTracker
//
//  User-friendly error display for HealthKit issues
//

import SwiftUI
import HealthKit

struct HealthKitErrorView: View {
    @ObservedObject var errorManager: HealthKitErrorManager
    @EnvironmentObject var healthManager: HealthManager
    let isCompact: Bool
    
    init(errorManager: HealthKitErrorManager, isCompact: Bool = false) {
        self.errorManager = errorManager
        self.isCompact = isCompact
    }
    
    var body: some View {
        if let currentError = errorManager.currentError {
            VStack(spacing: isCompact ? 8 : 12) {
                // Error icon and title
                HStack(spacing: 8) {
                    Image(systemName: currentError.severity.icon)
                        .foregroundColor(currentError.severity.color)
                        .font(.system(size: isCompact ? 16 : 20, weight: .semibold))
                    
                    if !isCompact {
                        Text("HealthKit Issue")
                            .font(.headline)
                            .foregroundColor(currentError.severity.color)
                    }
                    
                    Spacer()
                    
                    // Dismiss button
                    Button(action: {
                        errorManager.clearError()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: isCompact ? 14 : 16))
                    }
                }
                
                if !isCompact {
                    // Error message
                    Text(currentError.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Recovery suggestion
                    if let recoverySuggestion = currentError.recoverySuggestion {
                        Text(recoverySuggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
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
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(currentError.severity.color.opacity(0.1))
                                .foregroundColor(currentError.severity.color)
                                .cornerRadius(8)
                            }
                        }
                        
                        // Settings button (for permission issues)
                        if isPermissionError(currentError) {
                            Button(action: {
                                openHealthSettings()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "gear")
                                    Text("Settings")
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    // Compact view - just show the error message
                    Text(currentError.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            .padding(isCompact ? 8 : 12)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 6 : 10)
                    .fill(currentError.severity.color.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 6 : 10)
                            .stroke(currentError.severity.color.opacity(0.3), lineWidth: 1)
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
    
    private func openHealthSettings() {
        #if os(iOS)
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
        #else
        // On watchOS, we can't directly open settings, so provide instructions
        // This would typically trigger a more detailed instruction view
        #endif
    }
}

// MARK: - Health Status Banner
struct HealthKitStatusBanner: View {
    @EnvironmentObject var healthManager: HealthManager
    let isCompact: Bool
    
    init(isCompact: Bool = false) {
        self.isCompact = isCompact
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Show error if there is one
            HealthKitErrorView(errorManager: healthManager.errorManager, isCompact: isCompact)
            
            // Show authorization status if no error
            if healthManager.errorManager.currentError == nil {
                if healthManager.authorizationInProgress {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(isCompact ? 0.8 : 1.0)
                        Text("Requesting HealthKit permissions...")
                            .font(isCompact ? .caption : .subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(isCompact ? 8 : 12)
                } else if !healthManager.isAuthorized {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.circle")
                            .foregroundColor(Color("PrimaryMain"))
                            .font(.system(size: isCompact ? 16 : 20))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HealthKit Connection")
                                .font(isCompact ? .caption : .subheadline)
                                .fontWeight(.medium)
                            Text("Grant permissions for workout tracking")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Enable") {
                            healthManager.requestAuthorization()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    .padding(isCompact ? 8 : 12)
                    .background(
                        RoundedRectangle(cornerRadius: isCompact ? 6 : 10)
                            .fill(Color("PrimaryMain").opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: isCompact ? 6 : 10)
                                    .stroke(Color("PrimaryMain").opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HealthKitStatusBanner()
            .environmentObject({
                let healthManager = HealthManager.shared
                healthManager.errorManager.handleError(.authorizationDenied(dataType: "Heart Rate"), context: "Test")
                return healthManager
            }())
        
        HealthKitStatusBanner(isCompact: true)
            .environmentObject({
                let healthManager = HealthManager.shared
                healthManager.errorManager.handleError(.workoutSaveFailed(underlying: nil), context: "Test")
                return healthManager
            }())
    }
    .padding()
}
