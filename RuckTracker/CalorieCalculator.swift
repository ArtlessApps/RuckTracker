//
//  CalorieCalculator.swift
//  RuckTracker
//
//  Created by Nick on 9/6/25.
//

import Foundation

struct CalorieCalculator {
    
    /// Calculate calories burned during rucking using MET (Metabolic Equivalent) values
    /// Based on research from Army studies and sports science literature
    static func calculateRuckingCalories(
        bodyWeightKg: Double,
        ruckWeightPounds: Double,
        timeMinutes: Double,
        distanceMiles: Double = 0
    ) -> Double {
        
        let timeHours = timeMinutes / 60.0
        
        // Base MET for walking without load
        let baseMET = calculateBaseMET(distanceMiles: distanceMiles, timeMinutes: timeMinutes)
        
        // Additional MET from carrying load
        let loadMET = calculateLoadMET(ruckWeightPounds: ruckWeightPounds, bodyWeightKg: bodyWeightKg)
        
        // Total MET calculation (using flat terrain multiplier of 1.0)
        let totalMET = baseMET + loadMET
        
        // Calories = MET × body weight (kg) × time (hours)
        let calories = totalMET * bodyWeightKg * timeHours
        
        return max(calories, 0) // Ensure non-negative
    }
    
    /// Calculate base MET based on walking pace
    private static func calculateBaseMET(distanceMiles: Double, timeMinutes: Double) -> Double {
        guard distanceMiles > 0 && timeMinutes > 0 else {
            return 3.5 // Resting MET for very slow movement
        }
        
        let paceMinutesPerMile = timeMinutes / distanceMiles
        let speedMPH = 60.0 / paceMinutesPerMile
        
        // MET values based on walking speed research
        switch speedMPH {
        case 0..<2.0: return 2.5    // Very slow
        case 2.0..<2.5: return 3.0  // Slow
        case 2.5..<3.0: return 3.5  // Moderate
        case 3.0..<3.5: return 4.0  // Brisk
        case 3.5..<4.0: return 4.5  // Fast
        case 4.0..<4.5: return 5.0  // Very fast
        default: return 5.5         // Running pace
        }
    }
    
    /// Calculate additional MET from carrying load
    /// Based on Army research: ~6% increase in energy cost per 10% of body weight carried
    private static func calculateLoadMET(ruckWeightPounds: Double, bodyWeightKg: Double) -> Double {
        let bodyWeightPounds = bodyWeightKg * 2.20462
        let loadPercentage = ruckWeightPounds / bodyWeightPounds
        
        // Research shows approximately 0.6 MET increase per 10% body weight carried
        let additionalMET = loadPercentage * 6.0
        
        return min(additionalMET, 4.0) // Cap at reasonable maximum
    }
    
    /// Calculate instantaneous calorie burn rate (calories per minute)
    static func calculateCurrentBurnRate(
        bodyWeightKg: Double,
        ruckWeightPounds: Double,
        currentPaceMinutesPerMile: Double?
    ) -> Double {
        
        let baseMET: Double
        if let pace = currentPaceMinutesPerMile {
            let speedMPH = 60.0 / pace
            baseMET = getBaseMETForSpeed(speedMPH)
        } else {
            baseMET = 3.5 // Default moderate pace
        }
        
        let loadMET = calculateLoadMET(ruckWeightPounds: ruckWeightPounds, bodyWeightKg: bodyWeightKg)
        let totalMET = baseMET + loadMET
        
        // Calories per minute = MET × body weight (kg) / 60
        return totalMET * bodyWeightKg / 60.0
    }
    
    private static func getBaseMETForSpeed(_ speedMPH: Double) -> Double {
        switch speedMPH {
        case 0..<2.0: return 2.5
        case 2.0..<2.5: return 3.0
        case 2.5..<3.0: return 3.5
        case 3.0..<3.5: return 4.0
        case 3.5..<4.0: return 4.5
        case 4.0..<4.5: return 5.0
        default: return 5.5
        }
    }
}

// MARK: - Supporting Types
// TerrainType enum removed for MVP - using flat terrain only

// MARK: - Validation and Comparison

extension CalorieCalculator {
    
    /// Compare our calculation with Apple Watch's standard walking calculation
    static func comparisonWithAppleWatch(
        bodyWeightKg: Double,
        ruckWeightPounds: Double,
        timeMinutes: Double,
        distanceMiles: Double
    ) -> (ours: Double, appleEstimate: Double, difference: Double) {
        
        let ourCalories = calculateRuckingCalories(
            bodyWeightKg: bodyWeightKg,
            ruckWeightPounds: ruckWeightPounds,
            timeMinutes: timeMinutes,
            distanceMiles: distanceMiles
        )
        
        // Apple's basic walking calculation (approximation)
        let timeHours = timeMinutes / 60.0
        let appleWalkingMET = 3.8 // Apple's typical walking MET
        let appleCalories = appleWalkingMET * bodyWeightKg * timeHours
        
        let difference = ourCalories - appleCalories
        
        return (ourCalories, appleCalories, difference)
    }
    
    /// Validate that our calculations are reasonable
    static func validateCalculation(
        bodyWeightKg: Double,
        ruckWeightPounds: Double,
        timeMinutes: Double,
        calculatedCalories: Double
    ) -> Bool {
        
        // Sanity checks
        guard bodyWeightKg > 30 && bodyWeightKg < 200 else { return false }
        guard ruckWeightPounds >= 0 && ruckWeightPounds <= 100 else { return false }
        guard timeMinutes > 0 else { return false }
        
        // Reasonable calorie range: 8-20 calories per minute for loaded walking
        let caloriesPerMinute = calculatedCalories / timeMinutes
        return caloriesPerMinute >= 5 && caloriesPerMinute <= 25
    }
}
