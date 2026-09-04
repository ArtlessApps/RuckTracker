package com.artless.rucktracker.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface WorkoutDao {
    @Insert
    suspend fun insert(workout: WorkoutEntity)

    @Query("SELECT * FROM workouts ORDER BY date DESC")
    fun getAllWorkouts(): Flow<List<WorkoutEntity>>

    @Query("SELECT * FROM workouts WHERE id = :id LIMIT 1")
    suspend fun getWorkoutById(id: String): WorkoutEntity?

    @Query("DELETE FROM workouts WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("SELECT COUNT(*) FROM workouts")
    suspend fun getWorkoutCount(): Int

    @Query("SELECT COALESCE(SUM(distance), 0) FROM workouts")
    suspend fun getTotalDistance(): Double

    @Query("SELECT COALESCE(SUM(calories), 0) FROM workouts")
    suspend fun getTotalCalories(): Double

    @Query("SELECT COALESCE(SUM(elevationGain), 0) FROM workouts")
    suspend fun getTotalElevation(): Double
}
