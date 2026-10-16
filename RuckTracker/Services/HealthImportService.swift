//
//  HealthImportService.swift
//  MARCH
//
//  Imports rucks recorded on other watches (Garmin, COROS, Polar, Suunto...)
//  by watching Apple Health for walking/hiking workouts that MARCH didn't record.
//  The user confirms the pack weight (one tap from a notification), then the
//  workout is saved locally and credited to programs, challenges, and clubs.
//

import Foundation
import HealthKit
import UIKit
import UserNotifications

/// A walking/hiking workout another app saved to Apple Health that might be a ruck
struct ImportCandidate: Identifiable, Codable, Equatable {
    let id: UUID                  // HKWorkout UUID
    let sourceName: String        // e.g. "COROS", "Connect"
    let activityName: String      // "Walk" / "Hike"
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distanceMiles: Double
    let activeCalories: Double    // 0 when the source didn't write energy
    let averageHeartRate: Double  // 0 when unavailable
    let elevationGainFeet: Double
}

@MainActor
final class HealthImportService: ObservableObject {
    static let shared = HealthImportService()

    // MARK: - Notification identifiers

    static let notificationCategory = "RUCK_IMPORT"
    private static let notificationPrefix = "ruck_import_"
    private static let candidateIdKey = "candidateId"

    enum NotificationAction {
        static let log = "RUCK_IMPORT_LOG"
        static let edit = "RUCK_IMPORT_EDIT"
        static let dismiss = "RUCK_IMPORT_DISMISS"
    }

    // MARK: - Filters

    private static let importableActivityTypes: [HKWorkoutActivityType] = [.walking, .hiking]
    private static let minimumDistanceMiles = 1.0
    private static let minimumDuration: TimeInterval = 15 * 60
    /// How far back to look the first time the feature runs. Older workouts are
    /// listed for review but never trigger notifications or auto-logging.
    private static let backlogDays = 14

    // MARK: - Published state

    @Published private(set) var pending: [ImportCandidate] = []
    @Published var showingReview = false

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            if isEnabled {
                refresh()
                requestNotificationPermissionIfNeeded()
            } else {
                stop()
            }
        }
    }

    /// Log new workouts at the last-used weight without asking
    @Published var autoLog: Bool {
        didSet { defaults.set(autoLog, forKey: Keys.autoLog) }
    }

    /// Also consider workouts from Apple's own Workout app (off by default so
    /// Apple Watch users don't get asked about every auto-detected walk)
    @Published var includeAppleWorkouts: Bool {
        didSet {
            defaults.set(includeAppleWorkouts, forKey: Keys.includeApple)
            // Re-scan so previously skipped Apple workouts get picked up
            defaults.removeObject(forKey: Keys.anchor)
            Task { await checkForNewWorkouts() }
        }
    }

    /// Pack weight used for one-tap logging, remembered from the last import
    @Published private(set) var lastWeightLbs: Double

    // MARK: - Private

    private enum Keys {
        static let enabled = "healthImport.enabled"
        static let autoLog = "healthImport.autoLog"
        static let includeApple = "healthImport.includeAppleWorkouts"
        static let lastWeight = "healthImport.lastWeightLbs"
        static let anchor = "healthImport.anchor"
        static let enabledAt = "healthImport.enabledAt"
        static let handledIds = "healthImport.handledIds"
        static let pending = "healthImport.pending"
    }

    private let defaults = UserDefaults.standard
    private let healthStore = HealthManager.shared.healthStore
    private var observerQuery: HKObserverQuery?
    private var isChecking = false
    private var needsRecheck = false
    private var didBecomeActiveObserver: NSObjectProtocol?

    private init() {
        defaults.register(defaults: [Keys.enabled: true])
        isEnabled = defaults.bool(forKey: Keys.enabled)
        autoLog = defaults.bool(forKey: Keys.autoLog)
        includeAppleWorkouts = defaults.bool(forKey: Keys.includeApple)

        let savedWeight = defaults.double(forKey: Keys.lastWeight)
        lastWeightLbs = savedWeight > 0 ? savedWeight : UserSettings.shared.defaultRuckWeightInPounds()

        if let data = defaults.data(forKey: Keys.pending),
           let saved = try? JSONDecoder().decode([ImportCandidate].self, from: data) {
            pending = saved
        }
        
        // The observer query only fires on new writes; also catch up whenever the app
        // opens (e.g. Health access was granted after the observer started).
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: - Lifecycle

    /// Must be called at app launch so HealthKit background delivery can wake the app.
    func start() {
        guard isEnabled, HKHealthStore.isHealthDataAvailable(), observerQuery == nil else { return }

        if defaults.object(forKey: Keys.enabledAt) == nil {
            defaults.set(Date(), forKey: Keys.enabledAt)
        }

        registerNotificationCategory()

        // Fires once immediately, then whenever any app writes a workout
        let query = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { [weak self] _, completionHandler, error in
            if let error {
                // e.g. Health access not granted yet on first launch. A failed observer
                // query stays dead, so drop it and let refresh() start a new one.
                print("⌚️ [Import] Observer query error: \(error.localizedDescription)")
                completionHandler()
                Task { @MainActor in self?.resetObserver() }
                return
            }
            Task { @MainActor in
                await self?.checkForNewWorkouts()
                completionHandler()
            }
        }
        observerQuery = query
        healthStore.execute(query)

        healthStore.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate) { success, error in
            if let error {
                print("⌚️ [Import] Background delivery not enabled: \(error.localizedDescription)")
            } else {
                print("⌚️ [Import] Background delivery enabled: \(success)")
            }
        }
    }

    private func stop() {
        resetObserver()
        healthStore.disableBackgroundDelivery(for: .workoutType()) { _, _ in }
    }
    
    private func resetObserver() {
        if let observerQuery {
            healthStore.stop(observerQuery)
        }
        observerQuery = nil
    }
    
    /// Restart the observer if needed and catch up on anything missed.
    /// Called when the app opens and after Health access is granted.
    func refresh() {
        start()
        Task { await checkForNewWorkouts() }
    }

    // MARK: - Discovery

    func checkForNewWorkouts() async {
        guard isEnabled else { return }
        guard !isChecking else {
            needsRecheck = true
            return
        }
        isChecking = true
        defer { isChecking = false }

        repeat {
            needsRecheck = false
            await runAnchoredQuery()
        } while needsRecheck
    }

    private func runAnchoredQuery() async {
        let enabledAt = defaults.object(forKey: Keys.enabledAt) as? Date ?? Date()
        let backlogStart = Calendar.current.date(byAdding: .day, value: -Self.backlogDays, to: enabledAt) ?? enabledAt

        let typePredicates = Self.importableActivityTypes.map { HKQuery.predicateForWorkouts(with: $0) }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: backlogStart, end: nil),
            NSCompoundPredicate(orPredicateWithSubpredicates: typePredicates)
        ])

        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.workout(predicate)],
            anchor: loadAnchor()
        )

        let result: HKAnchoredObjectQueryDescriptor<HKWorkout>.Result
        do {
            result = try await descriptor.result(for: healthStore)
        } catch {
            print("⌚️ [Import] Anchored query failed: \(error.localizedDescription)")
            return
        }

        var handled = handledIds
        var newCandidates: [ImportCandidate] = []

        for workout in result.addedSamples where shouldConsider(workout, handled: handled) {
            let candidate = makeCandidate(from: workout)
            guard candidate.distanceMiles >= Self.minimumDistanceMiles,
                  candidate.duration >= Self.minimumDuration,
                  !overlapsLocalWorkout(candidate) else { continue }
            newCandidates.append(candidate)
            handled.insert(candidate.id)  // never surface the same workout twice
        }

        // Workouts deleted from Apple Health shouldn't linger in the review list
        let deletedIds = Set(result.deletedObjects.map(\.uuid))

        saveAnchor(result.newAnchor)
        handledIds = handled

        guard !newCandidates.isEmpty || !deletedIds.isEmpty else { return }
        print("⌚️ [Import] Found \(newCandidates.count) candidate workout(s)")

        pending.removeAll { deletedIds.contains($0.id) }

        for candidate in newCandidates.sorted(by: { $0.startDate < $1.startDate }) {
            let isNew = candidate.endDate > enabledAt
            if isNew && autoLog {
                log(candidate, weightLbs: lastWeightLbs)
            } else {
                pending.append(candidate)
                if isNew { await notify(about: candidate) }
            }
        }
        pending.sort { $0.startDate > $1.startDate }
        savePending()

        if !newCandidates.isEmpty, UIApplication.shared.applicationState == .active {
            requestNotificationPermissionIfNeeded()
        }
    }

    private func shouldConsider(_ workout: HKWorkout, handled: Set<UUID>) -> Bool {
        guard !handled.contains(workout.uuid) else { return false }

        #if DEBUG
        if workout.metadata?[Self.debugMetadataKey] != nil { return true }
        #endif
        
        let bundleId = workout.sourceRevision.source.bundleIdentifier
        // MARCH's own iPhone and Watch (<app id>.watchkitapp) workouts are already saved locally
        if let appBundleId = Bundle.main.bundleIdentifier, bundleId.hasPrefix(appBundleId) { return false }
        if !includeAppleWorkouts && bundleId.hasPrefix("com.apple.") { return false }
        return true
    }

    private func makeCandidate(from workout: HKWorkout) -> ImportCandidate {
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let energyType = HKQuantityType(.activeEnergyBurned)
        let heartRateType = HKQuantityType(.heartRate)

        // Some apps only set the workout's total distance without distance samples
        let distanceMiles = workout.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .mile())
            ?? workout.totalDistance?.doubleValue(for: .mile())
            ?? 0
        let calories = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        let heartRate = workout.statistics(for: heartRateType)?.averageQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
        let elevationFeet = (workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?
            .doubleValue(for: .foot()) ?? 0

        return ImportCandidate(
            id: workout.uuid,
            sourceName: workout.sourceRevision.source.name,
            activityName: workout.workoutActivityType == .hiking ? "Hike" : "Walk",
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            distanceMiles: distanceMiles,
            activeCalories: calories,
            averageHeartRate: heartRate,
            elevationGainFeet: elevationFeet
        )
    }

    /// Skip workouts the user also tracked in MARCH (e.g. COROS on the wrist + MARCH on the phone)
    private func overlapsLocalWorkout(_ candidate: ImportCandidate) -> Bool {
        WorkoutDataManager.shared.workouts.contains { workout in
            guard let start = workout.date else { return false }
            let end = start.addingTimeInterval(workout.duration)
            return start < candidate.endDate && end > candidate.startDate
        }
    }

    // MARK: - Logging

    /// Save the workout as a ruck and credit programs, challenges, leaderboard, and clubs.
    func log(_ candidate: ImportCandidate, weightLbs: Double) {
        let settings = UserSettings.shared
        let minutes = candidate.duration / 60.0

        // Prefer the watch's measured calories plus the load adjustment MARCH applies to
        // its own workouts; fall back to MARCH's MET estimate when none were recorded.
        let calories: Double
        if candidate.activeCalories > 0 {
            calories = candidate.activeCalories + CalorieCalculator.additionalLoadCalories(
                bodyWeightKg: settings.bodyWeightInKg,
                ruckWeightPounds: weightLbs,
                timeMinutes: minutes
            )
        } else {
            calories = CalorieCalculator.calculateRuckingCalories(
                bodyWeightKg: settings.bodyWeightInKg,
                ruckWeightPounds: weightLbs,
                timeMinutes: minutes,
                distanceMiles: candidate.distanceMiles
            )
        }

        let programService = LocalProgramService.shared
        let challengeService = LocalChallengeService.shared
        let programId = programService.getEnrolledProgramId()
        let programDay = programId == nil ? nil : programService.programProgress.map { $0.completed + 1 }
        let challengeId = challengeService.getEnrolledChallengeId()
        let challengeDay = challengeId == nil ? nil : challengeService.challengeProgress.map { $0.completed + 1 }

        let workoutId = WorkoutDataManager.shared.saveWorkout(
            date: candidate.startDate,
            duration: candidate.duration,
            distance: candidate.distanceMiles,
            calories: calories,
            ruckWeight: weightLbs,
            heartRate: candidate.averageHeartRate,
            elevationGain: candidate.elevationGainFeet,
            programId: programId,
            programWorkoutDay: programDay,
            challengeId: challengeId,
            challengeDay: challengeDay
        )

        if programId != nil { programService.refreshProgramProgress() }
        // The challenge metadata is already on the saved workout; just recompute progress.
        // (LocalChallengeService.completeWorkout re-tags the newest workout, which may not be this one.)
        if challengeId != nil { challengeService.loadEnrollmentStatus() }

        // Logging from a notification action runs with the app in the background,
        // possibly before the Supabase session has been restored.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "RuckImportPost")
        Task {
            defer { UIApplication.shared.endBackgroundTask(backgroundTask) }
            let community = CommunityService.shared
            if community.currentProfile == nil {
                await community.restoreSessionIfNeeded()
            }
            await WorkoutManager.postWorkoutToCommunity(
                workoutId: workoutId,
                distance: candidate.distanceMiles,
                duration: Int(minutes),
                weight: weightLbs,
                calories: Int(calories),
                elevationGain: candidate.elevationGainFeet
            )
        }

        lastWeightLbs = weightLbs
        defaults.set(weightLbs, forKey: Keys.lastWeight)
        resolve(candidate)
        print("⌚️ [Import] Logged \(candidate.sourceName) \(candidate.activityName.lowercased()) as a ruck at \(Int(weightLbs)) lbs")
    }

    /// "Not a ruck"
    func dismiss(_ candidate: ImportCandidate) {
        resolve(candidate)
        print("⌚️ [Import] Dismissed \(candidate.sourceName) workout")
    }

    private func resolve(_ candidate: ImportCandidate) {
        pending.removeAll { $0.id == candidate.id }
        savePending()
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [Self.notificationPrefix + candidate.id.uuidString]
        )
    }

    // MARK: - Notifications

    private func registerNotificationCategory() {
        let center = UNUserNotificationCenter.current()
        let category = UNNotificationCategory(
            identifier: Self.notificationCategory,
            actions: [
                UNNotificationAction(identifier: NotificationAction.log, title: "Log Ruck", options: []),
                UNNotificationAction(identifier: NotificationAction.edit, title: "Change Weight", options: [.foreground]),
                UNNotificationAction(identifier: NotificationAction.dismiss, title: "Not a Ruck", options: [.destructive])
            ],
            intentIdentifiers: [],
            options: []
        )
        // Merge so other features' categories (e.g. event reminders) survive
        center.getNotificationCategories { existing in
            var categories = existing.filter { $0.identifier != Self.notificationCategory }
            categories.insert(category)
            center.setNotificationCategories(categories)
        }
    }

    private func notify(about candidate: ImportCandidate) async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Was that a ruck?"
        content.body = "\(Self.formatDistance(candidate.distanceMiles)) \(candidate.activityName.lowercased()) from \(candidate.sourceName), \(Self.formatDuration(candidate.duration)). Log it at \(Int(lastWeightLbs)) lbs?"
        content.sound = .default
        content.categoryIdentifier = Self.notificationCategory
        content.userInfo = [Self.candidateIdKey: candidate.id.uuidString]

        let request = UNNotificationRequest(
            identifier: Self.notificationPrefix + candidate.id.uuidString,
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            print("⌚️ [Import] Failed to schedule notification: \(error.localizedDescription)")
        }
    }

    /// Returns true if the response belonged to this feature.
    func handleNotificationResponse(_ response: UNNotificationResponse) -> Bool {
        let content = response.notification.request.content
        guard content.categoryIdentifier == Self.notificationCategory else { return false }

        let candidate = (content.userInfo[Self.candidateIdKey] as? String)
            .flatMap(UUID.init(uuidString:))
            .flatMap { id in pending.first { $0.id == id } }

        switch response.actionIdentifier {
        case NotificationAction.log:
            if let candidate { log(candidate, weightLbs: lastWeightLbs) }
        case NotificationAction.dismiss:
            if let candidate { dismiss(candidate) }
        default:
            // Tapped the notification or "Change Weight"
            showingReview = true
        }
        return true
    }

    /// Asked once the user has finished onboarding and there's something to log,
    /// so the prompt has context instead of appearing on the welcome screen.
    func requestNotificationPermissionIfNeeded() {
        guard UserSettings.shared.hasCompletedOnboarding else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    // MARK: - Persistence

    private var handledIds: Set<UUID> {
        get {
            let strings = defaults.stringArray(forKey: Keys.handledIds) ?? []
            return Set(strings.compactMap(UUID.init(uuidString:)))
        }
        set {
            defaults.set(newValue.map(\.uuidString), forKey: Keys.handledIds)
        }
    }

    private func savePending() {
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: Keys.pending)
        }
    }

    private func loadAnchor() -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: Keys.anchor) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func saveAnchor(_ anchor: HKQueryAnchor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            defaults.set(data, forKey: Keys.anchor)
        }
    }

    // MARK: - Debug
    
    #if DEBUG
    private static let debugMetadataKey = "MARCHDebugImport"
    
    /// Writes a walk to Apple Health that the importer treats as coming from another
    /// watch, so the flow can be tested in the simulator without a Garmin/COROS.
    func addDebugWatchWorkout() async {
        let end = Date()
        let start = end.addingTimeInterval(-48 * 60)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: nil)
        do {
            try await builder.beginCollection(at: start)
            try await builder.addSamples([
                HKQuantitySample(type: HKQuantityType(.distanceWalkingRunning),
                                 quantity: HKQuantity(unit: .mile(), doubleValue: 2.4),
                                 start: start, end: end),
                HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                 quantity: HKQuantity(unit: .kilocalorie(), doubleValue: 260),
                                 start: start, end: end)
            ])
            try await builder.addMetadata([Self.debugMetadataKey: true])
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
            print("⌚️ [Import] Debug watch workout written to Apple Health")
        } catch {
            print("⌚️ [Import] Debug workout failed: \(error.localizedDescription)")
        }
    }
    #endif
    
    // MARK: - Formatting

    static func formatDistance(_ miles: Double) -> String {
        let settings = UserSettings.shared
        if settings.preferredDistanceUnit == .kilometers {
            return String(format: "%.1f km", miles / UserSettings.DistanceUnit.kilometers.conversionToMiles)
        }
        return String(format: "%.1f mi", miles)
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes) min"
    }
}
