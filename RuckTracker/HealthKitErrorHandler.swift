//
//  HealthKitErrorHandler.swift
//  RuckTracker
//
//  Comprehensive error handling for HealthKit failures
//

import Foundation
import HealthKit
import SwiftUI

// MARK: - HealthKit Error Types
enum HealthKitError: LocalizedError, Equatable {
    case healthDataNotAvailable
    case authorizationDenied(dataType: String)
    case authorizationNotDetermined
    case authorizationFailed(underlying: Error?)
    case quantityTypeUnavailable(identifier: String)
    case workoutSessionCreationFailed(underlying: Error?)
    case workoutBuilderCreationFailed(underlying: Error?)
    case workoutDataCollectionFailed(underlying: Error?)
    case workoutSaveFailed(underlying: Error?)
    case dataSourceUnavailable
    case permissionRevoked(dataType: String)
    case healthStoreUnavailable
    case networkError
    case insufficientPermissions(requiredTypes: [String])
    case deviceNotSupported
    case backgroundProcessingRestricted
    
    var errorDescription: String? {
        switch self {
        case .healthDataNotAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied(let dataType):
            return "Access to \(dataType) data was denied"
        case .authorizationNotDetermined:
            return "HealthKit authorization has not been requested"
        case .authorizationFailed(let error):
            if let error = error {
                return "HealthKit authorization failed: \(error.localizedDescription)"
            }
            return "HealthKit authorization failed"
        case .quantityTypeUnavailable(let identifier):
            return "Health data type '\(identifier)' is not available"
        case .workoutSessionCreationFailed(let error):
            if let error = error {
                return "Failed to create workout session: \(error.localizedDescription)"
            }
            return "Failed to create workout session"
        case .workoutBuilderCreationFailed(let error):
            if let error = error {
                return "Failed to create workout builder: \(error.localizedDescription)"
            }
            return "Failed to create workout builder"
        case .workoutDataCollectionFailed(let error):
            if let error = error {
                return "Failed to collect workout data: \(error.localizedDescription)"
            }
            return "Failed to collect workout data"
        case .workoutSaveFailed(let error):
            if let error = error {
                return "Failed to save workout: \(error.localizedDescription)"
            }
            return "Failed to save workout to HealthKit"
        case .dataSourceUnavailable:
            return "Workout data source is not available"
        case .permissionRevoked(let dataType):
            return "Permission for \(dataType) data has been revoked"
        case .healthStoreUnavailable:
            return "HealthKit store is not available"
        case .networkError:
            return "Network connection is required for HealthKit synchronization"
        case .insufficientPermissions(let types):
            return "Insufficient permissions for: \(types.joined(separator: ", "))"
        case .deviceNotSupported:
            return "This device does not support the required HealthKit features"
        case .backgroundProcessingRestricted:
            return "Background processing is restricted for HealthKit operations"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .healthDataNotAvailable:
            return "HealthKit is not supported on this device. Workout data will be saved locally only."
        case .authorizationDenied(let dataType):
            return "To enable \(dataType) tracking, go to Settings > Privacy & Security > Health > RuckTracker and allow access."
        case .authorizationNotDetermined:
            return "Please grant HealthKit permissions to track your workouts accurately."
        case .authorizationFailed:
            return "Try restarting the app and granting HealthKit permissions again."
        case .quantityTypeUnavailable:
            return "This health metric is not available on your device. The app will continue without it."
        case .workoutSessionCreationFailed, .workoutBuilderCreationFailed:
            return "Try ending any active workouts in the Health app and restart RuckTracker."
        case .workoutDataCollectionFailed:
            return "Some workout data may be missing. The workout will still be saved with available data."
        case .workoutSaveFailed:
            return "Workout data has been saved locally. HealthKit sync will be retried automatically."
        case .dataSourceUnavailable:
            return "Manual distance and calorie tracking will be used instead of GPS data."
        case .permissionRevoked:
            return "Go to Settings > Privacy & Security > Health > RuckTracker to restore permissions."
        case .healthStoreUnavailable:
            return "Restart the Health app and try again."
        case .networkError:
            return "Check your internet connection and try again."
        case .insufficientPermissions:
            return "Grant additional HealthKit permissions in Settings > Privacy & Security > Health > RuckTracker."
        case .deviceNotSupported:
            return "Use an Apple Watch for full workout tracking capabilities."
        case .backgroundProcessingRestricted:
            return "Enable background app refresh for RuckTracker in Settings > General > Background App Refresh."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .healthDataNotAvailable, .deviceNotSupported:
            return .info
        case .authorizationDenied, .permissionRevoked, .insufficientPermissions:
            return .warning
        case .workoutDataCollectionFailed, .dataSourceUnavailable, .quantityTypeUnavailable:
            return .warning
        case .authorizationFailed, .workoutSessionCreationFailed, .workoutBuilderCreationFailed:
            return .error
        case .workoutSaveFailed, .healthStoreUnavailable, .networkError:
            return .error
        case .authorizationNotDetermined, .backgroundProcessingRestricted:
            return .info
        }
    }
    
    var shouldRetry: Bool {
        switch self {
        case .networkError, .healthStoreUnavailable, .workoutSaveFailed:
            return true
        case .workoutSessionCreationFailed, .workoutBuilderCreationFailed, .authorizationFailed:
            return true
        default:
            return false
        }
    }
    
    // Equatable implementation
    static func == (lhs: HealthKitError, rhs: HealthKitError) -> Bool {
        switch (lhs, rhs) {
        case (.healthDataNotAvailable, .healthDataNotAvailable):
            return true
        case (.authorizationDenied(let lhsType), .authorizationDenied(let rhsType)):
            return lhsType == rhsType
        case (.authorizationNotDetermined, .authorizationNotDetermined):
            return true
        case (.quantityTypeUnavailable(let lhsId), .quantityTypeUnavailable(let rhsId)):
            return lhsId == rhsId
        case (.permissionRevoked(let lhsType), .permissionRevoked(let rhsType)):
            return lhsType == rhsType
        case (.insufficientPermissions(let lhsTypes), .insufficientPermissions(let rhsTypes)):
            return lhsTypes == rhsTypes
        default:
            return false
        }
    }
}

// MARK: - Error Severity
enum ErrorSeverity {
    case info      // Informational, app continues normally
    case warning   // App continues with reduced functionality
    case error     // Significant issue, some features may not work
    case critical  // App may not function properly
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return Color("PrimaryMain")
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

// MARK: - Error State Management
class HealthKitErrorManager: ObservableObject {
    @Published var currentError: HealthKitError?
    @Published var errorHistory: [HealthKitErrorRecord] = []
    @Published var showErrorAlert: Bool = false
    @Published var retryCount: Int = 0
    
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    func handleError(_ error: HealthKitError, context: String = "") {
        print("🚨 HealthKit Error [\(context)]: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            // Record error
            let record = HealthKitErrorRecord(
                error: error,
                context: context,
                timestamp: Date()
            )
            self.errorHistory.append(record)
            
            // Update current error if it's more severe
            if self.currentError == nil || error.severity.rawValue > (self.currentError?.severity.rawValue ?? 0) {
                self.currentError = error
                
                // Show alert for errors and critical issues
                if error.severity == .error || error.severity == .critical {
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.showErrorAlert = false
            self.retryCount = 0
        }
    }
    
    func retryOperation() -> Bool {
        guard let error = currentError, error.shouldRetry else {
            return false
        }
        
        retryCount += 1
        
        if retryCount <= maxRetries {
            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay * Double(retryCount)) {
                // Clear error to allow retry
                self.currentError = nil
            }
            return true
        }
        
        return false
    }
    
    func getErrorMessage() -> String {
        guard let error = currentError else { return "" }
        return error.localizedDescription
    }
    
    func getRecoverySuggestion() -> String {
        guard let error = currentError else { return "" }
        return error.recoverySuggestion ?? "Please try again later."
    }
}

// MARK: - Error Record
struct HealthKitErrorRecord {
    let error: HealthKitError
    let context: String
    let timestamp: Date
    let id = UUID()
}

// MARK: - Error Severity Extension
extension ErrorSeverity: Comparable {
    static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var rawValue: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .error: return 2
        case .critical: return 3
        }
    }
}

// MARK: - HealthKit Utility Extensions
extension HKAuthorizationStatus {
    var healthKitError: HealthKitError? {
        switch self {
        case .notDetermined:
            return .authorizationNotDetermined
        case .sharingDenied:
            return nil // This should be handled contextually with specific data type
        case .sharingAuthorized:
            return nil
        @unknown default:
            return .authorizationFailed(underlying: nil)
        }
    }
}

extension Error {
    var asHealthKitError: HealthKitError {
        if let hkError = self as? HealthKitError {
            return hkError
        }
        
        // Convert HKError to HealthKitError
        if let hkError = self as? HKError {
            switch hkError.code {
            case .errorHealthDataUnavailable:
                return .healthDataNotAvailable
            case .errorAuthorizationDenied:
                return .authorizationDenied(dataType: "health data")
            case .errorAuthorizationNotDetermined:
                return .authorizationNotDetermined
            case .errorDatabaseInaccessible:
                return .healthStoreUnavailable
            default:
                return .authorizationFailed(underlying: self)
            }
        }
        
        return .authorizationFailed(underlying: self)
    }
}
