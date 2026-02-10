import Foundation
import Combine
import Supabase

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    // MARK: - Coach Settings
    // The "Why" - Drives recommendation engine
    @Published var ruckingGoal: RuckingGoal = .longevity
    // The "How" - Intensity calibration
    @Published var experienceLevel: ExperienceLevel = .beginner
    // The "When" - Weekly cadence
    @Published var preferredTrainingDays: [Int] = [2, 4, 7] // Mon, Wed, Sat
    // The Result - Active plan assignment
    @Published var activeProgramID: String?
    // New personalization inputs
    @Published var targetEventDate: Date?
    @Published var baselinePaceMinutesPerMile: Double = 16.0
    @Published var baselineLongestDistanceMiles: Double = 4.0
    @Published var hasHillAccess: Bool = true
    @Published var hasStairsAccess: Bool = false
    @Published var injuryFlags: [String] = []
    
    // MARK: - Legacy Preferences
    @Published var bodyWeight: Double = 180.0 // lbs
    @Published var preferredWeightUnit: WeightUnit = .pounds
    @Published var preferredDistanceUnit: DistanceUnit = .miles
    @Published var defaultRuckWeight: Double = 20.0 // lbs
    @Published var username: String? = nil
    @Published var email: String? = nil
    @Published var hasCompletedOnboarding: Bool = false
    
    // MARK: - Per-User Suite Management
    
    /// The currently active UserDefaults store.
    /// Anonymous users → `UserDefaults.standard`
    /// Authenticated users → `UserDefaults(suiteName: "march_user_<UUID>")`
    private var userDefaults: UserDefaults = .standard
    
    /// The user ID whose suite is currently active, or nil for anonymous.
    private(set) var currentUserId: UUID?
    
    private var cancellables = Set<AnyCancellable>()
    
    enum WeightUnit: String, CaseIterable {
        case pounds = "lbs"
        case kilograms = "kg"
        
        var conversionToKg: Double {
            switch self {
            case .pounds: return 0.453592
            case .kilograms: return 1.0
            }
        }
    }
    
    enum DistanceUnit: String, CaseIterable {
        case miles = "mi"
        case kilometers = "km"
        
        var conversionToMiles: Double {
            switch self {
            case .miles: return 1.0
            case .kilometers: return 0.621371
            }
        }
    }
    
    private init() {
        loadSettings()
        setupObservers()
    }
    
    // MARK: - User Switching (Apple-aligned per-user suites)
    
    /// Switch to a per-user UserDefaults suite after sign-in.
    /// Migrates anonymous settings for first-time users, then loads from remote DB.
    @MainActor
    func switchToUser(_ userId: UUID) async {
        let previousDefaults = userDefaults
        
        print("🔄 Switching UserSettings to user: \(userId.uuidString.prefix(8))…")
        
        // Tear down current observers
        cancellables.removeAll()
        
        // Create per-user suite
        let suiteName = "march_user_\(userId.uuidString)"
        guard let suite = UserDefaults(suiteName: suiteName) else {
            print("❌ Failed to create UserDefaults suite for user, staying on standard")
            setupObservers()
            return
        }
        
        userDefaults = suite
        currentUserId = userId
        
        // Check if this suite has ever been populated on this device
        let suiteHasData = suite.object(forKey: "hasCompletedPhoneOnboarding") != nil
        
        if suiteHasData {
            // Returning user on same device — load their local settings
            print("🔄 Loading existing per-user settings from suite")
            loadSettings()
        } else {
            // First sign-in on this device — migrate anonymous settings to the per-user suite
            print("🔄 First sign-in on device — migrating anonymous settings to per-user suite")
            migrateSettings(from: previousDefaults)
        }
        
        // Re-attach observers (now writing to the per-user suite)
        setupObservers()
        
        // Load from remote DB (may override local if the user has cloud-synced prefs)
        await loadPreferencesFromRemote(userId: userId)
        
        // Reset the anonymous (standard) defaults so the next anonymous session starts clean
        clearStandardDefaults()
        
        print("🔄 User switch complete. Onboarding: \(hasCompletedOnboarding)")
    }
    
    /// Switch back to anonymous UserDefaults on sign-out.
    /// Saves current settings to remote DB before switching.
    @MainActor
    func switchToAnonymous() {
        guard let userId = currentUserId else {
            print("⚠️ switchToAnonymous called but no user is active")
            return
        }
        
        print("🔄 Switching UserSettings to anonymous (sign-out)")
        
        // Fire-and-forget: save current settings to DB before switching
        let preferencesRow = toPreferencesParams(userId: userId)
        Task {
            await savePreferencesToRemote(userId: userId, params: preferencesRow)
        }
        
        // Tear down observers
        cancellables.removeAll()
        
        // Switch back to standard defaults
        userDefaults = .standard
        currentUserId = nil
        
        // Reset to clean defaults for the next anonymous / new user
        applyDefaults()
        
        // Re-attach observers (now writing to standard defaults)
        setupObservers()
        
        print("🔄 Switched to anonymous. Onboarding reset to false.")
    }
    
    // MARK: - Settings Load / Save
    
    private func loadSettings() {
        bodyWeight = userDefaults.double(forKey: "bodyWeight")
        if bodyWeight == 0 { bodyWeight = 180.0 }
        
        if let weightUnitString = userDefaults.string(forKey: "preferredWeightUnit"),
           let weightUnit = WeightUnit(rawValue: weightUnitString) {
            preferredWeightUnit = weightUnit
        }
        
        if let distanceUnitString = userDefaults.string(forKey: "preferredDistanceUnit"),
           let distanceUnit = DistanceUnit(rawValue: distanceUnitString) {
            preferredDistanceUnit = distanceUnit
        }
        
        defaultRuckWeight = userDefaults.double(forKey: "defaultRuckWeight")
        if defaultRuckWeight == 0 { defaultRuckWeight = 20.0 }
        
        username = userDefaults.string(forKey: "username")
        email = userDefaults.string(forKey: "email")
        hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedPhoneOnboarding")
        targetEventDate = userDefaults.object(forKey: "targetEventDate") as? Date
        baselinePaceMinutesPerMile = userDefaults.double(forKey: "baselinePaceMinutesPerMile")
        if baselinePaceMinutesPerMile == 0 { baselinePaceMinutesPerMile = 16.0 }
        baselineLongestDistanceMiles = userDefaults.double(forKey: "baselineLongestDistanceMiles")
        if baselineLongestDistanceMiles == 0 { baselineLongestDistanceMiles = 4.0 }
        hasHillAccess = userDefaults.object(forKey: "hasHillAccess") as? Bool ?? true
        hasStairsAccess = userDefaults.object(forKey: "hasStairsAccess") as? Bool ?? false
        injuryFlags = userDefaults.stringArray(forKey: "injuryFlags") ?? []
        
        if let goalString = userDefaults.string(forKey: "ruckingGoal"),
           let goal = RuckingGoal(rawValue: goalString) {
            ruckingGoal = goal
        }
        
        if let experienceString = userDefaults.string(forKey: "experienceLevel"),
           let level = ExperienceLevel(rawValue: experienceString) {
            experienceLevel = level
        }
        
        if let days = userDefaults.array(forKey: "preferredTrainingDays") as? [Int], !days.isEmpty {
            preferredTrainingDays = days
        }
        
        activeProgramID = userDefaults.string(forKey: "activeProgramID")
    }
    
    /// Copy all settings from one UserDefaults store to the current store + in-memory properties.
    private func migrateSettings(from source: UserDefaults) {
        // Read from source
        let srcBodyWeight = source.double(forKey: "bodyWeight")
        let srcWeightUnit = source.string(forKey: "preferredWeightUnit")
        let srcDistanceUnit = source.string(forKey: "preferredDistanceUnit")
        let srcRuckWeight = source.double(forKey: "defaultRuckWeight")
        let srcUsername = source.string(forKey: "username")
        let srcEmail = source.string(forKey: "email")
        let srcOnboarding = source.bool(forKey: "hasCompletedPhoneOnboarding")
        let srcGoal = source.string(forKey: "ruckingGoal")
        let srcExperience = source.string(forKey: "experienceLevel")
        let srcDays = source.array(forKey: "preferredTrainingDays") as? [Int]
        let srcProgramID = source.string(forKey: "activeProgramID")
        let srcEventDate = source.object(forKey: "targetEventDate") as? Date
        let srcPace = source.double(forKey: "baselinePaceMinutesPerMile")
        let srcDistance = source.double(forKey: "baselineLongestDistanceMiles")
        let srcHills = source.object(forKey: "hasHillAccess") as? Bool
        let srcStairs = source.object(forKey: "hasStairsAccess") as? Bool
        let srcInjuries = source.stringArray(forKey: "injuryFlags")
        
        // Write to current suite (userDefaults)
        if srcBodyWeight > 0 {
            userDefaults.set(srcBodyWeight, forKey: "bodyWeight")
            bodyWeight = srcBodyWeight
        }
        if let unit = srcWeightUnit {
            userDefaults.set(unit, forKey: "preferredWeightUnit")
            preferredWeightUnit = WeightUnit(rawValue: unit) ?? .pounds
        }
        if let unit = srcDistanceUnit {
            userDefaults.set(unit, forKey: "preferredDistanceUnit")
            preferredDistanceUnit = DistanceUnit(rawValue: unit) ?? .miles
        }
        if srcRuckWeight > 0 {
            userDefaults.set(srcRuckWeight, forKey: "defaultRuckWeight")
            defaultRuckWeight = srcRuckWeight
        }
        if let name = srcUsername {
            userDefaults.set(name, forKey: "username")
            username = name
        }
        if let mail = srcEmail {
            userDefaults.set(mail, forKey: "email")
            email = mail
        }
        userDefaults.set(srcOnboarding, forKey: "hasCompletedPhoneOnboarding")
        hasCompletedOnboarding = srcOnboarding
        
        if let goal = srcGoal, let g = RuckingGoal(rawValue: goal) {
            userDefaults.set(goal, forKey: "ruckingGoal")
            ruckingGoal = g
        }
        if let exp = srcExperience, let e = ExperienceLevel(rawValue: exp) {
            userDefaults.set(exp, forKey: "experienceLevel")
            experienceLevel = e
        }
        if let days = srcDays, !days.isEmpty {
            userDefaults.set(days, forKey: "preferredTrainingDays")
            preferredTrainingDays = days
        }
        if let pid = srcProgramID {
            userDefaults.set(pid, forKey: "activeProgramID")
            activeProgramID = pid
        }
        if let date = srcEventDate {
            userDefaults.set(date, forKey: "targetEventDate")
            targetEventDate = date
        }
        if srcPace > 0 {
            userDefaults.set(srcPace, forKey: "baselinePaceMinutesPerMile")
            baselinePaceMinutesPerMile = srcPace
        }
        if srcDistance > 0 {
            userDefaults.set(srcDistance, forKey: "baselineLongestDistanceMiles")
            baselineLongestDistanceMiles = srcDistance
        }
        if let hills = srcHills {
            userDefaults.set(hills, forKey: "hasHillAccess")
            hasHillAccess = hills
        }
        if let stairs = srcStairs {
            userDefaults.set(stairs, forKey: "hasStairsAccess")
            hasStairsAccess = stairs
        }
        if let injuries = srcInjuries {
            userDefaults.set(injuries, forKey: "injuryFlags")
            injuryFlags = injuries
        }
    }
    
    /// Reset the anonymous (standard) UserDefaults so the next user doesn't inherit data.
    private func clearStandardDefaults() {
        let standard = UserDefaults.standard
        let keysToRemove = [
            "bodyWeight", "preferredWeightUnit", "preferredDistanceUnit",
            "defaultRuckWeight", "username", "email", "hasCompletedPhoneOnboarding",
            "ruckingGoal", "experienceLevel", "preferredTrainingDays", "activeProgramID",
            "targetEventDate", "baselinePaceMinutesPerMile", "baselineLongestDistanceMiles",
            "hasHillAccess", "hasStairsAccess", "injuryFlags"
        ]
        for key in keysToRemove {
            standard.removeObject(forKey: key)
        }
    }
    
    /// Set all in-memory properties back to factory defaults and write them to the current suite.
    private func applyDefaults() {
        bodyWeight = 180.0
        preferredWeightUnit = .pounds
        preferredDistanceUnit = .miles
        defaultRuckWeight = 20.0
        username = nil
        email = nil
        hasCompletedOnboarding = false
        ruckingGoal = .longevity
        experienceLevel = .beginner
        preferredTrainingDays = [2, 4, 7]
        activeProgramID = nil
        targetEventDate = nil
        baselinePaceMinutesPerMile = 16.0
        baselineLongestDistanceMiles = 4.0
        hasHillAccess = true
        hasStairsAccess = false
        injuryFlags = []
    }
    
    // MARK: - Remote Sync (Supabase)
    
    /// Load preferences from the `user_preferences` table and apply if found.
    private func loadPreferencesFromRemote(userId: UUID) async {
        do {
            let rows: [UserPreferencesRow] = try await CommunityService.shared.supabaseClient
                .from("user_preferences")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            
            guard let remote = rows.first else {
                // No remote prefs yet — save current local settings to DB
                print("🔄 No remote preferences found — uploading local settings")
                let params = toPreferencesParams(userId: userId)
                await savePreferencesToRemote(userId: userId, params: params)
                return
            }
            
            // Apply remote settings (overrides local)
            applyRemotePreferences(remote)
            print("🔄 Applied remote preferences for user")
        } catch {
            print("⚠️ Failed to load remote preferences: \(error). Using local settings.")
        }
    }
    
    /// Save current settings to the `user_preferences` table (upsert).
    private func savePreferencesToRemote(userId: UUID, params: [String: AnyJSON]) async {
        do {
            try await CommunityService.shared.supabaseClient
                .from("user_preferences")
                .upsert(params, onConflict: "user_id")
                .execute()
            
            print("🔄 Saved preferences to remote for user \(userId.uuidString.prefix(8))…")
        } catch {
            print("⚠️ Failed to save preferences to remote: \(error)")
        }
    }
    
    /// Build a params dictionary from current in-memory state for DB upsert.
    func toPreferencesParams(userId: UUID) -> [String: AnyJSON] {
        var params: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "body_weight": .double(bodyWeight),
            "preferred_weight_unit": .string(preferredWeightUnit.rawValue),
            "preferred_distance_unit": .string(preferredDistanceUnit.rawValue),
            "default_ruck_weight": .double(defaultRuckWeight),
            "rucking_goal": .string(ruckingGoal.rawValue),
            "experience_level": .string(experienceLevel.rawValue),
            "baseline_pace_minutes_per_mile": .double(baselinePaceMinutesPerMile),
            "baseline_longest_distance_miles": .double(baselineLongestDistanceMiles),
            "has_hill_access": .bool(hasHillAccess),
            "has_stairs_access": .bool(hasStairsAccess),
            "has_completed_onboarding": .bool(hasCompletedOnboarding),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        // Arrays need special handling
        // Supabase expects arrays as JSON arrays for integer[] columns
        let daysArray: [AnyJSON] = preferredTrainingDays.map { .double(Double($0)) }
        params["preferred_training_days"] = .array(daysArray)
        
        let flagsArray: [AnyJSON] = injuryFlags.map { .string($0) }
        params["injury_flags"] = .array(flagsArray)
        
        if let pid = activeProgramID {
            params["active_program_id"] = .string(pid)
        } else {
            params["active_program_id"] = .null
        }
        
        if let date = targetEventDate {
            params["target_event_date"] = .string(ISO8601DateFormatter().string(from: date))
        } else {
            params["target_event_date"] = .null
        }
        
        return params
    }
    
    /// Apply settings loaded from the remote `user_preferences` row.
    private func applyRemotePreferences(_ row: UserPreferencesRow) {
        bodyWeight = row.bodyWeight ?? 180.0
        if let unit = row.preferredWeightUnit, let wu = WeightUnit(rawValue: unit) {
            preferredWeightUnit = wu
        }
        if let unit = row.preferredDistanceUnit, let du = DistanceUnit(rawValue: unit) {
            preferredDistanceUnit = du
        }
        defaultRuckWeight = row.defaultRuckWeight ?? 20.0
        if let goal = row.ruckingGoal, let g = RuckingGoal(rawValue: goal) {
            ruckingGoal = g
        }
        if let exp = row.experienceLevel, let e = ExperienceLevel(rawValue: exp) {
            experienceLevel = e
        }
        if let days = row.preferredTrainingDays, !days.isEmpty {
            preferredTrainingDays = days
        }
        activeProgramID = row.activeProgramId
        targetEventDate = row.targetEventDate
        baselinePaceMinutesPerMile = row.baselinePaceMinutesPerMile ?? 16.0
        baselineLongestDistanceMiles = row.baselineLongestDistanceMiles ?? 4.0
        hasHillAccess = row.hasHillAccess ?? true
        hasStairsAccess = row.hasStairsAccess ?? false
        injuryFlags = row.injuryFlags ?? []
        hasCompletedOnboarding = row.hasCompletedOnboarding ?? false
    }
    
    // MARK: - Public: Save to Remote (called before sign-out or on demand)
    
    /// Explicitly sync current settings to the remote database.
    /// Call this before sign-out or when the app goes to the background.
    @MainActor
    func syncToRemoteIfNeeded() async {
        guard let userId = currentUserId else { return }
        let params = toPreferencesParams(userId: userId)
        await savePreferencesToRemote(userId: userId, params: params)
    }
    
    // MARK: - Combine Observers
    
    private func setupObservers() {
        $bodyWeight
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "bodyWeight")
            }
            .store(in: &cancellables)
        
        $preferredWeightUnit
            .sink { [weak self] value in
                self?.userDefaults.set(value.rawValue, forKey: "preferredWeightUnit")
            }
            .store(in: &cancellables)
        
        $preferredDistanceUnit
            .sink { [weak self] value in
                self?.userDefaults.set(value.rawValue, forKey: "preferredDistanceUnit")
            }
            .store(in: &cancellables)
        
        $defaultRuckWeight
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "defaultRuckWeight")
            }
            .store(in: &cancellables)
        
        $username
            .sink { [weak self] value in
                if let value = value {
                    self?.userDefaults.set(value, forKey: "username")
                } else {
                    self?.userDefaults.removeObject(forKey: "username")
                }
            }
            .store(in: &cancellables)
        
        $email
            .sink { [weak self] value in
                if let value = value {
                    self?.userDefaults.set(value, forKey: "email")
                } else {
                    self?.userDefaults.removeObject(forKey: "email")
                }
            }
            .store(in: &cancellables)
        
        $hasCompletedOnboarding
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "hasCompletedPhoneOnboarding")
            }
            .store(in: &cancellables)
        
        $ruckingGoal
            .sink { [weak self] value in
                self?.userDefaults.set(value.rawValue, forKey: "ruckingGoal")
            }
            .store(in: &cancellables)
        
        $experienceLevel
            .sink { [weak self] value in
                self?.userDefaults.set(value.rawValue, forKey: "experienceLevel")
            }
            .store(in: &cancellables)
        
        $preferredTrainingDays
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "preferredTrainingDays")
            }
            .store(in: &cancellables)
        
        $activeProgramID
            .sink { [weak self] value in
                if let value = value {
                    self?.userDefaults.set(value, forKey: "activeProgramID")
                } else {
                    self?.userDefaults.removeObject(forKey: "activeProgramID")
                }
            }
            .store(in: &cancellables)
        
        $targetEventDate
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "targetEventDate")
            }
            .store(in: &cancellables)
        
        $baselinePaceMinutesPerMile
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "baselinePaceMinutesPerMile")
            }
            .store(in: &cancellables)
        
        $baselineLongestDistanceMiles
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "baselineLongestDistanceMiles")
            }
            .store(in: &cancellables)
        
        $hasHillAccess
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "hasHillAccess")
            }
            .store(in: &cancellables)
        
        $hasStairsAccess
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "hasStairsAccess")
            }
            .store(in: &cancellables)
        
        $injuryFlags
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: "injuryFlags")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helpers
    var bodyWeightInKg: Double {
        bodyWeight * preferredWeightUnit.conversionToKg
    }
    
    var bodyWeightDisplayString: String {
        String(format: "%.1f %@", bodyWeight, preferredWeightUnit.rawValue)
    }
    
    func defaultRuckWeightInPounds() -> Double {
        preferredWeightUnit == .pounds ? defaultRuckWeight : defaultRuckWeight / 0.453592
    }
    
    func isValidBodyWeight(_ weight: Double) -> Bool {
        let minWeight: Double = preferredWeightUnit == .pounds ? 80 : 36
        let maxWeight: Double = preferredWeightUnit == .pounds ? 400 : 180
        return weight >= minWeight && weight <= maxWeight
    }
    
    func isValidRuckWeight(_ weight: Double) -> Bool {
        let maxWeight: Double = preferredWeightUnit == .pounds ? 100 : 45
        return weight >= 0 && weight <= maxWeight
    }
    
    func updateBodyWeight(_ weight: Double, unit: WeightUnit) {
        preferredWeightUnit = unit
        bodyWeight = weight
    }
    
    func resetToDefaults() {
        applyDefaults()
    }
}

// MARK: - Remote Preferences Model

/// Codable row for the `user_preferences` table.
struct UserPreferencesRow: Codable {
    let id: UUID?
    let userId: UUID?
    let bodyWeight: Double?
    let preferredWeightUnit: String?
    let preferredDistanceUnit: String?
    let defaultRuckWeight: Double?
    let ruckingGoal: String?
    let experienceLevel: String?
    let preferredTrainingDays: [Int]?
    let activeProgramId: String?
    let targetEventDate: Date?
    let baselinePaceMinutesPerMile: Double?
    let baselineLongestDistanceMiles: Double?
    let hasHillAccess: Bool?
    let hasStairsAccess: Bool?
    let injuryFlags: [String]?
    let hasCompletedOnboarding: Bool?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case bodyWeight = "body_weight"
        case preferredWeightUnit = "preferred_weight_unit"
        case preferredDistanceUnit = "preferred_distance_unit"
        case defaultRuckWeight = "default_ruck_weight"
        case ruckingGoal = "rucking_goal"
        case experienceLevel = "experience_level"
        case preferredTrainingDays = "preferred_training_days"
        case activeProgramId = "active_program_id"
        case targetEventDate = "target_event_date"
        case baselinePaceMinutesPerMile = "baseline_pace_minutes_per_mile"
        case baselineLongestDistanceMiles = "baseline_longest_distance_miles"
        case hasHillAccess = "has_hill_access"
        case hasStairsAccess = "has_stairs_access"
        case injuryFlags = "injury_flags"
        case hasCompletedOnboarding = "has_completed_onboarding"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Enums (The Psychology)

enum RuckingGoal: String, CaseIterable, Codable {
    case longevity = "Longevity & Health"
    case weightLoss = "Burn Calories"
    case hiking = "Hiking & Hunting"
    case goruckBasic = "GORUCK Basic"
    case goruckTough = "GORUCK Tough"
    case military = "Military Selection"
    
    var icon: String {
        switch self {
        case .longevity: return "heart.text.square.fill"
        case .weightLoss: return "flame.fill"
        case .hiking: return "mountain.2.fill"
        case .goruckBasic: return "figure.walk"
        case .goruckTough: return "trophy.fill"
        case .military: return "star.fill"
        }
    }
}

enum ExperienceLevel: String, CaseIterable, Codable {
    case beginner = "New to Rucking"
    case intermediate = "Hiker / Runner"
    case advanced = "Ruck Pro"
}
