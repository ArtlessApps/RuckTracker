import Foundation
import Combine

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
    
    private let userDefaults = UserDefaults.standard
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
