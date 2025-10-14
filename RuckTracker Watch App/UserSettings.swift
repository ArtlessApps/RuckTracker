//
//  UserSettings.swift
//  RuckTracker Watch App
//
//  Created by Nick on 9/6/25.
//

import Foundation
import Combine

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    // User preferences
    @Published var bodyWeight: Double = 180.0 // lbs
    @Published var preferredWeightUnit: WeightUnit = .pounds
    @Published var preferredDistanceUnit: DistanceUnit = .miles
    @Published var defaultRuckWeight: Double = 20.0 // lbs
    @Published var username: String? = nil
    @Published var email: String? = nil
    
    // App settings
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
        if bodyWeight == 0 {
            bodyWeight = 180.0 // Default weight in lbs
        }
        
        if let weightUnitString = userDefaults.string(forKey: "preferredWeightUnit"),
           let weightUnit = WeightUnit(rawValue: weightUnitString) {
            preferredWeightUnit = weightUnit
        }
        
        if let distanceUnitString = userDefaults.string(forKey: "preferredDistanceUnit"),
           let distanceUnit = DistanceUnit(rawValue: distanceUnitString) {
            preferredDistanceUnit = distanceUnit
        }
        
        defaultRuckWeight = userDefaults.double(forKey: "defaultRuckWeight")
        if defaultRuckWeight == 0 {
            defaultRuckWeight = 20.0
        }
        
        username = userDefaults.string(forKey: "username")
        email = userDefaults.string(forKey: "email")
        
        hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
    }
    
    private func setupObservers() {
        // Auto-save when settings change
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
                self?.userDefaults.set(value, forKey: "hasCompletedOnboarding")
            }
            .store(in: &cancellables)
    }
    
    // Helper computed properties
    var bodyWeightInKg: Double {
        return bodyWeight * preferredWeightUnit.conversionToKg
    }
    
    var bodyWeightDisplayString: String {
        return String(format: "%.1f %@", bodyWeight, preferredWeightUnit.rawValue)
    }
    
    func defaultRuckWeightInPounds() -> Double {
        if preferredWeightUnit == .pounds {
            return defaultRuckWeight
        } else {
            return defaultRuckWeight / 0.453592 // Convert kg to lbs
        }
    }
    
    // Validation
    func isValidBodyWeight(_ weight: Double) -> Bool {
        let minWeight: Double = preferredWeightUnit == .pounds ? 80 : 36  // 80 lbs / 36 kg
        let maxWeight: Double = preferredWeightUnit == .pounds ? 400 : 180 // 400 lbs / 180 kg
        return weight >= minWeight && weight <= maxWeight
    }
    
    func isValidRuckWeight(_ weight: Double) -> Bool {
        let maxWeight: Double = preferredWeightUnit == .pounds ? 100 : 45 // 100 lbs / 45 kg
        return weight >= 0 && weight <= maxWeight
    }
    
    // For onboarding or settings changes
    func updateBodyWeight(_ weight: Double, unit: WeightUnit) {
        preferredWeightUnit = unit
        bodyWeight = weight
    }
    
    // Reset to defaults
    func resetToDefaults() {
        bodyWeight = 180.0
        preferredWeightUnit = .pounds
        preferredDistanceUnit = .miles
        defaultRuckWeight = 20.0
        username = nil
        hasCompletedOnboarding = false
    }
}

