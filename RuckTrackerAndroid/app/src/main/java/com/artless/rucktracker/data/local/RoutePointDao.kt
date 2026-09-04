package com.artless.rucktracker.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao
interface RoutePointDao {
    @Insert
    suspend fun insertAll(points: List<RoutePointEntity>)

    @Query("SELECT * FROM route_points WHERE workoutId = :workoutId ORDER BY timestamp ASC")
    suspend fun getPointsForWorkout(workoutId: String): List<RoutePointEntity>

    @Query("DELETE FROM route_points WHERE workoutId = :workoutId")
    suspend fun deleteForWorkout(workoutId: String)
}
