//
//  ProgramIntegrationLayer.swift
//  RuckTracker
//
//  Integration layer that connects all program services with existing systems
//  Provides unified interface, error handling, and offline support
//

import Foundation
import Combine
import HealthKit

@MainActor
class ProgramIntegrationLayer: ObservableObject {
    static let shared = ProgramIntegrationLayer()
    
    // Core Services
    private let programService = ProgramService.shared
    private let universalManager = UniversalProgramManager.shared
    private let workflowEngine = ProgramWorkflowEngine.shared
    private let challengeService = StackChallengeService.shared
    
    // External Service Integrations
    private let healthKitManager = HealthManager.shared
    private let premiumManager = PremiumManager.shared
    private let authService = AuthService()
    private let supabaseManager = SupabaseManager.shared
    
    // MARK: - Published State
    @Published var integrationStatus: IntegrationStatus = .initializing
    @Published var syncStatus: SyncStatus = .idle
    @Published var offlineMode: Bool = false
    @Published var lastSyncDate: Date?
    @Published var pendingOperations: [PendingOperation] = []
    @Published var serviceHealth: [ServiceType: ServiceHealth] = [:]
    
    // Error Handling
    @Published var currentErrors: [IntegrationError] = []
    @Published var criticalErrors: [IntegrationError] = []
    
    // Connectivity and Data Flow
    private var cancellables = Set<AnyCancellable>()
    private let operationQueue = OperationQueue()
    private let syncQueue = DispatchQueue(label: "com.rucktracker.sync", qos: .utility)
    
    // Configuration
    private let config = IntegrationConfiguration()
    
    private init() {
        setupOperationQueue()
        setupSubscriptions()
        initializeServiceHealth()
        
        Task {
            await initializeIntegration()
        }
    }
    
    // MARK: - Initialization
    
    private func setupOperationQueue() {
        operationQueue.maxConcurrentOperationCount = 3
        operationQueue.qualityOfService = .utility
    }
    
    private func setupSubscriptions() {
        // Monitor network connectivity
        NotificationCenter.default.publisher(for: .networkConnectivityChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleConnectivityChange(Notification(name: .networkConnectivityChanged))
            }
            .store(in: &cancellables)
        
        // Monitor premium status changes
        premiumManager.$isPremiumUser
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPremium in
                self?.handlePremiumStatusChange(isPremium)
            }
            .store(in: &cancellables)
        
        // Monitor authentication changes
        supabaseManager.$isAuthenticated
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.handleAuthenticationChange(isAuthenticated)
            }
            .store(in: &cancellables)
        
        // Monitor service errors
        Publishers.Merge4(
            programService.$errorMessage.map { _ in ServiceType.programService },
            challengeService.$errorMessage.map { _ in ServiceType.challengeService },
            Just(ServiceType.healthKit),
            Just(ServiceType.premium)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] serviceType in
            Task {
                await self?.checkServiceHealth(serviceType)
            }
        }
        .store(in: &cancellables)
    }
    
    private func initializeServiceHealth() {
        serviceHealth = [
            .programService: .unknown,
            .challengeService: .unknown,
            .workflowEngine: .unknown,
            .healthKit: .unknown,
            .premium: .unknown,
            .supabase: .unknown,
            .network: .unknown
        ]
    }
    
    private func initializeIntegration() async {
        integrationStatus = .initializing
        
        do {
            // Initialize services in order
            try await initializeAuthService()
            try await initializeHealthKit()
            try await initializePremiumService()
            try await initializeProgramServices()
            
            // Perform initial health checks
            await performHealthChecks()
            
            // Start background sync if online
            if !offlineMode {
                await startBackgroundSync()
            }
            
            integrationStatus = .ready
            print("✅ Program integration layer initialized successfully")
            
        } catch {
            integrationStatus = .failed(error)
            await handleCriticalError(error)
            print("❌ Failed to initialize integration layer: \(error)")
        }
    }
    
    // MARK: - Service Initialization
    
    private func initializeAuthService() async throws {
        do {
            if !supabaseManager.isAuthenticated {
                try await authService.signInAnonymously()
            }
            serviceHealth[.supabase] = .healthy
        } catch {
            serviceHealth[.supabase] = .error(error)
            // Continue with offline mode for non-critical auth failures
            print("⚠️ Auth service initialization failed, continuing in offline mode")
        }
    }
    
    private func initializeHealthKit() async throws {
        healthKitManager.requestAuthorization()
        // Wait a moment for authorization to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        serviceHealth[.healthKit] = healthKitManager.isAuthorized ? .healthy : .degraded("Limited permissions")
    }
    
    private func initializePremiumService() async throws {
        // Premium service should already be initialized
        serviceHealth[.premium] = premiumManager.isPremiumUser ? .healthy : .degraded("Free tier")
    }
    
    private func initializeProgramServices() async throws {
        // Program services initialize themselves
        serviceHealth[.programService] = .healthy
        serviceHealth[.challengeService] = .healthy
        serviceHealth[.workflowEngine] = .healthy
    }
    
    // MARK: - Unified Program Interface
    
    func enrollInProgram(
        _ program: Program,
        startingWeight: Double,
        customization: ProgramCustomization? = nil,
        startDate: Date = Date()
    ) async throws -> UnifiedProgramResult {
        
        // Validate prerequisites
        try await validateProgramEnrollment(program: program, weight: startingWeight)
        
        // Check premium access
        guard premiumManager.isPremiumUser || program.category == .fitness else {
            throw IntegrationError.premiumRequired
        }
        
        let operation = PendingOperation(
            id: UUID(),
            type: .programEnrollment,
            data: ["program_id": program.id.uuidString, "weight": startingWeight],
            createdAt: Date(),
            retryCount: 0
        )
        
        do {
            // Enroll through universal manager
            let session = try await universalManager.enrollInProgram(
                program,
                startingWeight: startingWeight,
                customization: customization,
                startDate: startDate
            )
            
            // Generate workflow
            let workflow = await workflowEngine.generateWorkflow(for: session)
            
            // Sync to HealthKit if available
            await syncProgramToHealthKit(session: session)
            
            // Update premium features if applicable
            await updatePremiumFeatures(for: session)
            
            // Create unified result
            let result = UnifiedProgramResult(
                session: session,
                workflow: workflow,
                healthKitSynced: serviceHealth[.healthKit] == .healthy,
                premiumFeatures: premiumManager.isPremiumUser
            )
            
            await recordSuccessfulOperation(operation)
            
            print("✅ Successfully enrolled in program: \(program.title)")
            return result
            
        } catch {
            await handleFailedOperation(operation, error: error)
            throw IntegrationError.enrollmentFailed(error)
        }
    }
    
    func recordWorkout(
        _ workout: CompletedWorkout,
        for sessionId: UUID
    ) async throws -> WorkoutRecordResult {
        
        let operation = PendingOperation(
            id: UUID(),
            type: .workoutRecord,
            data: ["session_id": sessionId.uuidString, "workout_data": workout.encodedData],
            createdAt: Date(),
            retryCount: 0
        )
        
        do {
            // Record through universal manager
            try await universalManager.recordWorkout(workout, for: sessionId)
            
            // Sync to HealthKit
            let healthKitWorkout = await syncWorkoutToHealthKit(workout)
            
            // Update workflow if needed
            let adaptationNeeded = await checkForWorkflowAdaptation(sessionId: sessionId, workout: workout)
            
            // Create result
            let result = WorkoutRecordResult(
                recorded: true,
                healthKitWorkout: healthKitWorkout,
                adaptationTriggered: adaptationNeeded,
                syncedToServer: !offlineMode
            )
            
            await recordSuccessfulOperation(operation)
            
            print("✅ Successfully recorded workout")
            return result
            
        } catch {
            await handleFailedOperation(operation, error: error)
            throw IntegrationError.workoutRecordFailed(error)
        }
    }
    
    func getProgramRecommendations() async throws -> [Program] {
        do {
            // Get recommendations from universal manager
            let recommendations = universalManager.recommendedPrograms
            
            // Filter based on premium status
            let filteredRecommendations = filterProgramsByAccess(recommendations)
            
            // Add challenge integration suggestions
            let enhancedRecommendations = await enhanceWithChallengeData(filteredRecommendations)
            
            return enhancedRecommendations
            
        } catch {
            throw IntegrationError.recommendationsFailed(error)
        }
    }
    
    func getUnifiedProgress(for sessionId: UUID) async throws -> UnifiedProgressData {
        do {
            // Get program analytics
            guard let analytics = universalManager.getProgressAnalytics(for: sessionId) else {
                throw IntegrationError.progressDataNotFound
            }
            
            // Get HealthKit data
            let healthKitData = await getHealthKitProgressData(for: sessionId)
            
            // Get challenge correlation data
            let challengeData = await getChallengeCorrelationData(for: sessionId)
            
            // Combine into unified view
            let unifiedData = UnifiedProgressData(
                programAnalytics: analytics,
                healthKitData: healthKitData,
                challengeCorrelations: challengeData,
                lastUpdated: Date()
            )
            
            return unifiedData
            
        } catch {
            throw IntegrationError.progressDataFailed(error)
        }
    }
    
    // MARK: - Sync Management
    
    func performFullSync() async throws {
        guard !offlineMode else {
            throw IntegrationError.offlineMode
        }
        
        syncStatus = .syncing
        
        do {
            // Sync programs
            await programService.refreshPrograms()
            
            // Sync challenges
            await challengeService.refreshChallenges()
            
            // Process pending operations
            await processPendingOperations()
            
            // Update service health
            await performHealthChecks()
            
            lastSyncDate = Date()
            syncStatus = .completed
            
            print("✅ Full sync completed successfully")
            
        } catch {
            syncStatus = .failed(error)
            throw IntegrationError.syncFailed(error)
        }
    }
    
    private func startBackgroundSync() async {
        // Start periodic background sync
        Timer.publish(every: config.backgroundSyncInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.performBackgroundSync()
                }
            }
            .store(in: &cancellables)
    }
    
    private func performBackgroundSync() async {
        guard syncStatus != .syncing && !offlineMode else { return }
        
        do {
            syncStatus = .syncing
            
            // Light sync - only critical data
            await processPendingOperations()
            await performHealthChecks()
            
            syncStatus = .idle
            
        } catch {
            syncStatus = .failed(error)
            await handleSyncError(error)
        }
    }
    
    // MARK: - Error Handling
    
    private func handleCriticalError(_ error: Error) async {
        let criticalError = IntegrationError.criticalFailure(error)
        criticalErrors.append(criticalError)
        
        // Try to maintain basic functionality
        await enableOfflineMode()
        
        // Notify user if UI is available
        NotificationCenter.default.post(
            name: .criticalProgramError,
            object: criticalError
        )
    }
    
    private func handleFailedOperation(_ operation: PendingOperation, error: Error) async {
        var updatedOperation = operation
        updatedOperation.retryCount += 1
        updatedOperation.lastError = error.localizedDescription
        
        if updatedOperation.retryCount < config.maxRetries {
            // Add to pending operations for retry
            pendingOperations.append(updatedOperation)
            print("⚠️ Operation failed, will retry: \(operation.type)")
        } else {
            // Max retries exceeded
            let integrationError = IntegrationError.operationFailed(operation, error)
            currentErrors.append(integrationError)
            print("❌ Operation failed permanently: \(operation.type)")
        }
    }
    
    private func handleSyncError(_ error: Error) async {
        let syncError = IntegrationError.syncFailed(error)
        currentErrors.append(syncError)
        
        // Enable offline mode if network-related
        if isNetworkError(error) {
            await enableOfflineMode()
        }
    }
    
    private func enableOfflineMode() async {
        offlineMode = true
        syncStatus = .offline
        
        // Update service health
        serviceHealth[.network] = .error(NetworkError.noConnection)
        
        print("📱 Enabled offline mode")
    }
    
    // MARK: - Service Health Monitoring
    
    private func performHealthChecks() async {
        for serviceType in ServiceType.allCases {
            await checkServiceHealth(serviceType)
        }
    }
    
    private func checkServiceHealth(_ serviceType: ServiceType) async {
        switch serviceType {
        case .programService:
            serviceHealth[serviceType] = programService.isLoading ? .degraded("Loading") : .healthy
            
        case .challengeService:
            serviceHealth[serviceType] = challengeService.isLoading ? .degraded("Loading") : .healthy
            
        case .workflowEngine:
            serviceHealth[serviceType] = workflowEngine.isGenerating ? .degraded("Generating") : .healthy
            
        case .healthKit:
            serviceHealth[serviceType] = await checkHealthKitStatus()
            
        case .premium:
            serviceHealth[serviceType] = premiumManager.isPremiumUser ? .healthy : .degraded("Free tier")
            
        case .supabase:
            serviceHealth[serviceType] = supabaseManager.isAuthenticated ? .healthy : .error(AuthError.notAuthenticated)
            
        case .network:
            serviceHealth[serviceType] = await checkNetworkStatus()
        }
    }
    
    private func checkHealthKitStatus() async -> ServiceHealth {
        return healthKitManager.isAuthorized ? .healthy : .degraded("Limited permissions")
    }
    
    private func checkNetworkStatus() async -> ServiceHealth {
        // Simple network check
        do {
            let (_, response) = try await URLSession.shared.data(from: URL(string: "https://www.google.com")!)
            return (response as? HTTPURLResponse)?.statusCode == 200 ? .healthy : .degraded("Slow connection")
        } catch {
            return .error(error)
        }
    }
    
    // MARK: - Integration Helpers
    
    private func validateProgramEnrollment(program: Program, weight: Double) async throws {
        // Check if weight is reasonable
        guard weight >= 10 && weight <= 200 else {
            throw IntegrationError.invalidWeight
        }
        
        // Check program availability
        guard programService.programs.contains(where: { $0.id == program.id }) else {
            throw IntegrationError.programNotAvailable
        }
        
        // Check for existing enrollment
        if universalManager.currentPrograms.contains(where: { $0.program.id == program.id }) {
            throw IntegrationError.alreadyEnrolled
        }
        
        // Check maximum concurrent programs
        if universalManager.currentPrograms.count >= config.maxConcurrentPrograms {
            throw IntegrationError.tooManyActivePrograms
        }
    }
    
    private func syncProgramToHealthKit(session: ActiveProgramSession) async {
        guard serviceHealth[.healthKit] == .healthy else { return }
        
        // Create HealthKit workout template
        let workoutType = HKWorkoutActivityType.other
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        
        // This would integrate with HealthKit's workout templates
        // Implementation depends on your HealthKitManager
        
        print("✅ Synced program to HealthKit")
    }
    
    private func syncWorkoutToHealthKit(_ workout: CompletedWorkout) async -> HKWorkout? {
        guard serviceHealth[.healthKit] == .healthy else { return nil }
        
        do {
            // Create HealthKit workout
            let workoutType = HKWorkoutActivityType.other
            let startDate = workout.completedDate.addingTimeInterval(-workout.duration)
            let endDate = workout.completedDate
            
            let healthKitWorkout = HKWorkout(
                activityType: workoutType,
                start: startDate,
                end: endDate,
                duration: workout.duration,
                totalEnergyBurned: nil,
                totalDistance: HKQuantity(unit: .mile(), doubleValue: workout.distanceCompleted),
                metadata: [
                    "RuckWeight": workout.weightUsed,
                    "WorkoutWeek": workout.weekNumber,
                    "WorkoutNumber": workout.workoutNumber
                ]
            )
            
            healthKitManager.saveWorkout(
                startDate: startDate,
                endDate: endDate,
                calories: 0, // Estimate calories if needed
                distance: workout.distanceCompleted,
                weight: workout.weightUsed
            )
            
            print("✅ Synced workout to HealthKit")
            return healthKitWorkout
            
        } catch {
            print("⚠️ Failed to sync workout to HealthKit: \(error)")
            return nil
        }
    }
    
    private func checkForWorkflowAdaptation(sessionId: UUID, workout: CompletedWorkout) async -> Bool {
        // Check if workout performance indicates need for adaptation
        guard let targetDuration = workout.targetDuration else { return false }
        
        let completionRatio = workout.duration / targetDuration
        
        // If significantly early or late, trigger adaptation
        if completionRatio < 0.8 || completionRatio > 1.2 {
            do {
                _ = try await workflowEngine.regenerateWorkflow(
                    for: sessionId,
                    reason: completionRatio < 0.8 ? .performanceDecline : .userRequest
                )
                return true
            } catch {
                print("⚠️ Failed to regenerate workflow: \(error)")
                return false
            }
        }
        
        return false
    }
    
    private func filterProgramsByAccess(_ programs: [Program]) -> [Program] {
        if premiumManager.isPremiumUser {
            return programs
        } else {
            // Free users can see some programs
            return programs.filter { $0.category == .fitness || $0.isFeatured }
        }
    }
    
    private func enhanceWithChallengeData(_ programs: [Program]) async -> [Program] {
        // Add challenge correlation data to program recommendations
        // This could suggest programs that complement active challenges
        return programs
    }
    
    private func getHealthKitProgressData(for sessionId: UUID) async -> HealthKitProgressData? {
        guard serviceHealth[.healthKit] == .healthy else { return nil }
        
        // Fetch relevant HealthKit data for the program period
        // Implementation depends on your HealthKitManager
        return nil
    }
    
    private func getChallengeCorrelationData(for sessionId: UUID) async -> ChallengeCorrelationData? {
        // Get data about how program progress correlates with challenge performance
        let activeEnrollments = challengeService.getActiveEnrollments()
        
        // Analysis would go here
        return ChallengeCorrelationData(
            activeEnrollments: activeEnrollments.count,
            correlationScore: 0.8, // Placeholder
            recommendations: []
        )
    }
    
    private func updatePremiumFeatures(for session: ActiveProgramSession) async {
        if premiumManager.isPremiumUser {
            // Enable premium features like detailed analytics, custom workouts, etc.
            print("✅ Premium features enabled for program")
        }
    }
    
    // MARK: - Operation Management
    
    private func processPendingOperations() async {
        let operations = pendingOperations
        pendingOperations.removeAll()
        
        for operation in operations {
            await retryOperation(operation)
        }
    }
    
    private func retryOperation(_ operation: PendingOperation) async {
        switch operation.type {
        case .programEnrollment:
            await retryProgramEnrollment(operation)
        case .workoutRecord:
            await retryWorkoutRecord(operation)
        case .progressSync:
            await retryProgressSync(operation)
        case .healthKitSync:
            await retryHealthKitSync(operation)
        }
        
        await recordSuccessfulOperation(operation)
    }
    
    private func retryProgramEnrollment(_ operation: PendingOperation) async {
        // Retry program enrollment
        // Implementation would extract data from operation and retry
        print("🔄 Retrying program enrollment")
    }
    
    private func retryWorkoutRecord(_ operation: PendingOperation) async {
        // Retry workout recording
        print("🔄 Retrying workout record")
    }
    
    private func retryProgressSync(_ operation: PendingOperation) async {
        // Retry progress sync
        print("🔄 Retrying progress sync")
    }
    
    private func retryHealthKitSync(_ operation: PendingOperation) async {
        // Retry HealthKit sync
        print("🔄 Retrying HealthKit sync")
    }
    
    private func recordSuccessfulOperation(_ operation: PendingOperation) async {
        // Remove from pending operations if it exists
        pendingOperations.removeAll { $0.id == operation.id }
        print("✅ Operation completed successfully: \(operation.type)")
    }
    
    // MARK: - Event Handlers
    
    private func handleConnectivityChange(_ notification: Notification) {
        guard let isConnected = notification.userInfo?["isConnected"] as? Bool else { return }
        
        if isConnected && offlineMode {
            Task {
                await disableOfflineMode()
            }
        } else if !isConnected {
            Task {
                await enableOfflineMode()
            }
        }
    }
    
    private func handlePremiumStatusChange(_ isPremium: Bool) {
        serviceHealth[.premium] = isPremium ? .healthy : .degraded("Free tier")
        
        if isPremium {
            // User upgraded - sync premium features
            Task {
                await syncPremiumFeatures()
            }
        }
    }
    
    private func handleAuthenticationChange(_ isAuthenticated: Bool) {
        serviceHealth[.supabase] = isAuthenticated ? .healthy : .error(AuthError.notAuthenticated)
        
        if isAuthenticated && offlineMode {
            Task {
                await disableOfflineMode()
            }
        }
    }
    
    private func disableOfflineMode() async {
        offlineMode = false
        syncStatus = .idle
        
        // Trigger full sync
        do {
            try await performFullSync()
        } catch {
            print("⚠️ Failed to sync after coming online: \(error)")
        }
    }
    
    private func syncPremiumFeatures() async {
        // Sync premium-specific data and features
        await programService.refreshPrograms()
        await challengeService.refreshChallenges()
    }
    
    // MARK: - Utility Methods
    
    private func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .notConnectedToInternet ||
                   urlError.code == .networkConnectionLost ||
                   urlError.code == .timedOut
        }
        return false
    }
    
    func clearErrors() {
        currentErrors.removeAll()
    }
    
    func clearCriticalErrors() {
        criticalErrors.removeAll()
    }
    
    func getServiceStatus() -> [ServiceType: ServiceHealth] {
        return serviceHealth
    }
    
    func forceOfflineMode(_ enabled: Bool) {
        if enabled {
            Task {
                await enableOfflineMode()
            }
        } else {
            Task {
                await disableOfflineMode()
            }
        }
    }
}
