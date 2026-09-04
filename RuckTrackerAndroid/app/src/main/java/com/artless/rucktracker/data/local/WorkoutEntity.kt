package com.artless.rucktracker.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * Mirrors the Core Data WorkoutEntity in RuckTracker/WorkoutDataManager.swift:24-36.
 * programId/challengeId/programWorkoutDay/challengeDay are kept for schema parity with
 * iOS but unused until program/challenge features are ported.
 */
@Entity(tableName = "workouts")
data class WorkoutEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val date: Long,
    val duration: Double,
    val distance: Double,
    val calories: Double,
    val ruckWeight: Double,
    val heartRate: Double = 0.0,
    val elevationGain: Double = 0.0,
    val programId: String? = null,
    val programWorkoutDay: Int = 0,
    val challengeId: String? = null,
    val challengeDay: Int = 0
)
