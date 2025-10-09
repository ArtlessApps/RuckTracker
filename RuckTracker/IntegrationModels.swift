//
//  IntegrationModels.swift
//  RuckTracker
//
//  Supporting data models for ProgramIntegrationLayer
//

import Foundation
import HealthKit

// MARK: - Core Integration Models

// Supporting types for unified integration
struct ActiveProgramSession: Codable {
    let id: UUID
    let programId: UUID
    let userProgramId: UUID
    let startedAt: Date
    let currentWeek: Int
    let currentDay: Int
    let isActive: Bool
}

struct ProgramAnalytics: Codable {
    let programId: UUID
    let totalWorkouts: Int
    let completedWorkouts: Int
    let completionPercentage: Double
    let averageDistance: Double
    let averageWeight: Double
    let lastWorkoutDate: Date?
}

struct IntegrationWorkflow: Codable {
    let id: UUID
    let programId: UUID
    let workouts: [WorkoutStep]
    let estimatedDuration: TimeInterval
}

struct WorkoutStep: Codable {
    let id: UUID
    let dayNumber: Int
    let weekNumber: Int
    let workoutType: String
    let distanceMiles: Double?
    let targetWeightLbs: Double?
}

struct UnifiedProgramResult {
    let session: ActiveProgramSession
    let workflow: IntegrationWorkflow
    let healthKitSynced: Bool
    let premiumFeatures: Bool
}

struct WorkoutRecordResult {
    let recorded: Bool
    let healthKitWorkout: HKWorkout?
    let adaptationTriggered: Bool
    let syncedToServer: Bool
}

struct UnifiedProgressData {
    let programAnalytics: ProgramAnalytics
    let healthKitData: HealthKitProgressData?
    let challengeCorrelations: ChallengeCorrelationData?
    let lastUpdated: Date
}

struct HealthKitProgressData {
    let totalWorkouts: Int
    let totalDistance: Double
    let averageHeartRate: Double
    let caloriesBurned: Double
    let dateRange: ClosedRange<Date>
}

struct ChallengeCorrelationData {
    let activeEnrollments: Int
    let correlationScore: Double
    let recommendations: [String]
}

// MARK: - Challenge Integration Models

struct ActiveChallengeSession: Codable {
    let id: UUID
    let challengeId: UUID
    let userChallengeId: UUID
    let startedAt: Date
    let currentDay: Int
    let isActive: Bool
}

struct ChallengeAnalytics: Codable {
    let challengeId: UUID
    let totalDays: Int
    let completedDays: Int
    let completionPercentage: Double
    let averageDistance: Double
    let averageWeight: Double
    let lastWorkoutDate: Date?
}

struct ChallengeWorkflow: Codable {
    let id: UUID
    let challengeId: UUID
    let workouts: [ChallengeWorkoutStep]
    let estimatedDuration: TimeInterval
}

struct ChallengeWorkoutStep: Codable {
    let id: UUID
    let dayNumber: Int
    let workoutType: String
    let distanceMiles: Double?
    let targetWeightLbs: Double?
    let targetPaceMinutes: Double?
}

struct UnifiedChallengeResult {
    let session: ActiveChallengeSession
    let workflow: ChallengeWorkflow
    let healthKitSynced: Bool
    let premiumFeatures: Bool
}

struct ChallengeRecordResult {
    let recorded: Bool
    let healthKitWorkout: HKWorkout?
    let adaptationTriggered: Bool
    let syncedToServer: Bool
}

struct UnifiedChallengeProgressData {
    let challengeAnalytics: ChallengeAnalytics
    let healthKitData: HealthKitProgressData?
    let programCorrelations: ProgramCorrelationData?
    let lastUpdated: Date
}

struct ProgramCorrelationData {
    let activePrograms: Int
    let correlationScore: Double
    let recommendations: [String]
}

struct PendingOperation: Identifiable, Codable {
    let id: UUID
    let type: OperationType
    let data: [String: Any]
    let createdAt: Date
    var retryCount: Int
    var lastError: String?
    
    // Custom coding to handle [String: Any]
    enum CodingKeys: String, CodingKey {
        case id, type, createdAt, retryCount, lastError
    }
    
    init(id: UUID, type: OperationType, data: [String: Any], createdAt: Date, retryCount: Int) {
        self.id = id
        self.type = type
        self.data = data
        self.createdAt = createdAt
        self.retryCount = retryCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(OperationType.self, forKey: .type)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        retryCount = try container.decode(Int.self, forKey: .retryCount)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        data = [:] // Simplified for this example
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(retryCount, forKey: .retryCount)
        try container.encodeIfPresent(lastError, forKey: .lastError)
    }
}

struct IntegrationConfiguration {
    let backgroundSyncInterval: TimeInterval = 300 // 5 minutes
    let maxRetries: Int = 3
    let maxConcurrentPrograms: Int = 2
    let offlineDataRetentionDays: Int = 30
    let healthKitSyncEnabled: Bool = true
    let premiumSyncEnabled: Bool = true
}

// MARK: - Enums

enum IntegrationStatus {
    case initializing
    case ready
    case failed(Error)
    
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(Error)
    case offline
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed), (.offline, .offline):
            return true
        case (.failed(_), .failed(_)):
            return true // Simplified comparison for errors
        default:
            return false
        }
    }
}

enum ServiceType: String, CaseIterable, Codable {
    case programService = "Program Service"
    case challengeService = "Challenge Service"
    case workflowEngine = "Workflow Engine"
    case healthKit = "HealthKit"
    case premium = "Premium"
    case supabase = "Supabase"
    case network = "Network"
}

enum ServiceHealth: Equatable {
    case unknown
    case healthy
    case degraded(String)
    case error(Error)
    
    static func == (lhs: ServiceHealth, rhs: ServiceHealth) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.healthy, .healthy):
            return true
        case (.degraded(let lhsReason), .degraded(let rhsReason)):
            return lhsReason == rhsReason
        case (.error(_), .error(_)):
            return true // Simplified comparison
        default:
            return false
        }
    }
    
    var isHealthy: Bool {
        if case .healthy = self { return true }
        return false
    }
}

enum OperationType: String, Codable, CaseIterable {
    case programEnrollment = "Program Enrollment"
    case challengeEnrollment = "Challenge Enrollment"
    case workoutRecord = "Workout Record"
    case progressSync = "Progress Sync"
    case healthKitSync = "HealthKit Sync"
}

enum IntegrationError: Error {
    case premiumRequired
    case enrollmentFailed(Error)
    case workoutRecordFailed(Error)
    case recommendationsFailed(Error)
    case progressDataNotFound
    case progressDataFailed(Error)
    case syncFailed(Error)
    case offlineMode
    case invalidWeight
    case programNotAvailable
    case alreadyEnrolled
    case tooManyActivePrograms
    case operationFailed(PendingOperation, Error)
    case criticalFailure(Error)
    case serviceUnavailable(ServiceType)
    case healthKitNotAuthorized
    case networkTimeout
    case authenticationFailed
    case dataCorruption
    case insufficientStorage
    case rateLimitExceeded
    
    var localizedDescription: String {
        switch self {
        case .premiumRequired:
            return "Premium subscription required for this program"
        case .enrollmentFailed(let error):
            return "Failed to enroll in program: \(error.localizedDescription)"
        case .workoutRecordFailed(let error):
            return "Failed to record workout: \(error.localizedDescription)"
        case .recommendationsFailed(let error):
            return "Failed to get program recommendations: \(error.localizedDescription)"
        case .progressDataNotFound:
            return "Progress data not found"
        case .progressDataFailed(let error):
            return "Failed to get progress data: \(error.localizedDescription)"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .offlineMode:
            return "Operation not available in offline mode"
        case .invalidWeight:
            return "Invalid weight value (must be between 10-200 lbs)"
        case .programNotAvailable:
            return "Program is not currently available"
        case .alreadyEnrolled:
            return "Already enrolled in this program"
        case .tooManyActivePrograms:
            return "Too many active programs (maximum 2)"
        case .operationFailed(let operation, let error):
            return "Operation \(operation.type.rawValue) failed: \(error.localizedDescription)"
        case .criticalFailure(let error):
            return "Critical system failure: \(error.localizedDescription)"
        case .serviceUnavailable(let service):
            return "Service unavailable: \(service.rawValue)"
        case .healthKitNotAuthorized:
            return "HealthKit authorization required"
        case .networkTimeout:
            return "Network request timed out"
        case .authenticationFailed:
            return "Authentication failed"
        case .dataCorruption:
            return "Data corruption detected"
        case .insufficientStorage:
            return "Insufficient storage space"
        case .rateLimitExceeded:
            return "Rate limit exceeded, please try again later"
        }
    }
    
    var isCritical: Bool {
        switch self {
        case .criticalFailure, .dataCorruption, .authenticationFailed:
            return true
        default:
            return false
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkTimeout, .rateLimitExceeded, .syncFailed, .enrollmentFailed, .workoutRecordFailed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Network and Auth Errors

enum NetworkError: Error {
    case noConnection
    case slowConnection
    case timeout
    case serverError(Int)
    case invalidResponse
    case dataCorrupted
    
    var localizedDescription: String {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .slowConnection:
            return "Slow internet connection"
        case .timeout:
            return "Request timed out"
        case .serverError(let code):
            return "Server error: \(code)"
        case .invalidResponse:
            return "Invalid server response"
        case .dataCorrupted:
            return "Data corruption detected"
        }
    }
}

enum AuthError: Error {
    case notAuthenticated
    case tokenExpired
    case invalidCredentials
    case accountSuspended
    case rateLimitExceeded
    
    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .tokenExpired:
            return "Authentication token expired"
        case .invalidCredentials:
            return "Invalid credentials"
        case .accountSuspended:
            return "Account suspended"
        case .rateLimitExceeded:
            return "Too many authentication attempts"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
    static let criticalProgramError = Notification.Name("criticalProgramError")
    static let serviceHealthChanged = Notification.Name("serviceHealthChanged")
    static let syncStatusChanged = Notification.Name("syncStatusChanged")
    static let offlineModeChanged = Notification.Name("offlineModeChanged")
    static let programEnrollmentCompleted = Notification.Name("programEnrollmentCompleted")
    static let workoutRecorded = Notification.Name("workoutRecorded")
    static let progressDataUpdated = Notification.Name("progressDataUpdated")
}

// MARK: - Extensions for Enhanced Functionality

extension ServiceHealth {
    var statusIcon: String {
        switch self {
        case .unknown:
            return "questionmark.circle"
        case .healthy:
            return "checkmark.circle.fill"
        case .degraded:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    var statusColor: String {
        switch self {
        case .unknown:
            return "gray"
        case .healthy:
            return "green"
        case .degraded:
            return "yellow"
        case .error:
            return "red"
        }
    }
    
    var description: String {
        switch self {
        case .unknown:
            return "Status unknown"
        case .healthy:
            return "Service healthy"
        case .degraded(let reason):
            return "Service degraded: \(reason)"
        case .error(let error):
            return "Service error: \(error.localizedDescription)"
        }
    }
}

extension IntegrationStatus {
    var isInitialized: Bool {
        switch self {
        case .ready:
            return true
        default:
            return false
        }
    }
    
    var statusMessage: String {
        switch self {
        case .initializing:
            return "Initializing services..."
        case .ready:
            return "All services ready"
        case .failed(let error):
            return "Initialization failed: \(error.localizedDescription)"
        }
    }
}

extension SyncStatus {
    var isActive: Bool {
        switch self {
        case .syncing:
            return true
        default:
            return false
        }
    }
    
    var statusMessage: String {
        switch self {
        case .idle:
            return "Sync idle"
        case .syncing:
            return "Syncing data..."
        case .completed:
            return "Sync completed"
        case .failed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .offline:
            return "Offline mode"
        }
    }
}

extension PendingOperation {
    var shouldRetry: Bool {
        return retryCount < 3 && Date().timeIntervalSince(createdAt) < 24 * 60 * 60 // 24 hours
    }
    
    var timeSinceCreated: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }
    
    var retryDelay: TimeInterval {
        // Exponential backoff: 1, 2, 4, 8 minutes
        return TimeInterval(pow(2.0, Double(retryCount)) * 60)
    }
}

// MARK: - Health Check Utilities

struct ServiceHealthReport {
    let timestamp: Date
    let overallHealth: ServiceHealth
    let serviceStatuses: [ServiceType: ServiceHealth]
    let criticalIssues: [IntegrationError]
    let recommendations: [String]
    
    var healthyServicesCount: Int {
        return serviceStatuses.values.filter { $0.isHealthy }.count
    }
    
    var totalServicesCount: Int {
        return serviceStatuses.count
    }
    
    var healthPercentage: Double {
        return Double(healthyServicesCount) / Double(totalServicesCount) * 100
    }
}

// MARK: - Offline Support

struct OfflineDataSnapshot {
    let timestamp: Date
    let programs: [Program]
    let userPrograms: [UserProgram]
    let challenges: [Challenge]
    let userChallenges: [UserChallenge]
    let userEnrollments: [UserChallengeEnrollment]
    let pendingOperations: [PendingOperation]
    
    var dataAge: TimeInterval {
        return Date().timeIntervalSince(timestamp)
    }
    
    var isStale: Bool {
        return dataAge > 24 * 60 * 60 // 24 hours
    }
}

// MARK: - Performance Metrics

struct IntegrationPerformanceMetrics {
    let syncDuration: TimeInterval
    let operationSuccessRate: Double
    let averageResponseTime: TimeInterval
    let errorRate: Double
    let offlineModePercentage: Double
    let lastCalculated: Date
    
    var isHealthy: Bool {
        return operationSuccessRate > 0.9 && errorRate < 0.1
    }
}

// MARK: - Debug and Diagnostics

struct IntegrationDiagnostics {
    let serviceVersions: [ServiceType: String]
    let configuration: IntegrationConfiguration
    let performanceMetrics: IntegrationPerformanceMetrics
    let healthReport: ServiceHealthReport
    let offlineData: OfflineDataSnapshot?
    let systemInfo: SystemInfo
    
    struct SystemInfo {
        let deviceModel: String
        let osVersion: String
        let appVersion: String
        let availableStorage: Int64
        let networkType: String
    }
}

// MARK: - Error Recovery Strategies

enum ErrorRecoveryStrategy {
    case retry
    case fallback
    case offlineMode
    case userIntervention
    case serviceRestart
    case dataReset
    
    var description: String {
        switch self {
        case .retry:
            return "Retry the operation"
        case .fallback:
            return "Use fallback method"
        case .offlineMode:
            return "Enable offline mode"
        case .userIntervention:
            return "Requires user intervention"
        case .serviceRestart:
            return "Restart the service"
        case .dataReset:
            return "Reset corrupted data"
        }
    }
}

extension IntegrationError {
    var recoveryStrategy: ErrorRecoveryStrategy {
        switch self {
        case .networkTimeout, .rateLimitExceeded:
            return .retry
        case .offlineMode:
            return .offlineMode
        case .authenticationFailed:
            return .userIntervention
        case .dataCorruption:
            return .dataReset
        case .serviceUnavailable:
            return .serviceRestart
        default:
            return .fallback
        }
    }
}
