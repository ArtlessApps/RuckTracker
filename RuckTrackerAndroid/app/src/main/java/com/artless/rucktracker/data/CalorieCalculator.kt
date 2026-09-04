package com.artless.rucktracker.data

/**
 * Direct Kotlin port of RuckTracker/CalorieCalculator.swift — MET-based calorie
 * estimate from Army rucking research. Keep in sync with the Swift original if
 * that formula changes.
 */
object CalorieCalculator {

    fun calculateRuckingCalories(
        bodyWeightKg: Double,
        ruckWeightPounds: Double,
        timeMinutes: Double,
        distanceMiles: Double = 0.0
    ): Double {
        val timeHours = timeMinutes / 60.0
        val baseMET = calculateBaseMET(distanceMiles, timeMinutes)
        val loadMET = calculateLoadMET(ruckWeightPounds, bodyWeightKg)
        val totalMET = baseMET + loadMET
        val calories = totalMET * bodyWeightKg * timeHours
        return maxOf(calories, 0.0)
    }

    private fun calculateBaseMET(distanceMiles: Double, timeMinutes: Double): Double {
        if (distanceMiles <= 0 || timeMinutes <= 0) return 3.5

        val paceMinutesPerMile = timeMinutes / distanceMiles
        val speedMph = 60.0 / paceMinutesPerMile

        return when {
            speedMph < 2.0 -> 2.5
            speedMph < 2.5 -> 3.0
            speedMph < 3.0 -> 3.5
            speedMph < 3.5 -> 4.0
            speedMph < 4.0 -> 4.5
            speedMph < 4.5 -> 5.0
            else -> 5.5
        }
    }

    private fun calculateLoadMET(ruckWeightPounds: Double, bodyWeightKg: Double): Double {
        val bodyWeightPounds = bodyWeightKg * 2.20462
        val loadPercentage = ruckWeightPounds / bodyWeightPounds
        val additionalMET = loadPercentage * 6.0
        return minOf(additionalMET, 4.0)
    }
}
