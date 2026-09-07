package com.artless.rucktracker.data.remote

import com.artless.rucktracker.data.local.RoutePointDao
import com.artless.rucktracker.data.local.RoutePointEntity
import com.artless.rucktracker.data.local.WorkoutDao
import com.artless.rucktracker.data.local.WorkoutEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

data class WorkoutStats(
    val totalWorkouts: Int,
    val totalDistance: Double,
    val totalCalories: Double,
    val totalElevation: Double
)

@Singleton
class WorkoutRepository @Inject constructor(
    private val workoutDao: WorkoutDao,
    private val routePointDao: RoutePointDao
) {
    fun getAllWorkouts(): Flow<List<WorkoutEntity>> = workoutDao.getAllWorkouts()

    suspend fun saveWorkout(workout: WorkoutEntity, routePoints: List<RoutePointEntity> = emptyList()) {
        workoutDao.insert(workout)
        if (routePoints.isNotEmpty()) {
            routePointDao.insertAll(routePoints)
        }
    }

    suspend fun deleteWorkout(id: String) {
        routePointDao.deleteForWorkout(id)
        workoutDao.deleteById(id)
    }

    suspend fun getWorkoutById(id: String): WorkoutEntity? = workoutDao.getWorkoutById(id)

    suspend fun getStats(): WorkoutStats = WorkoutStats(
        totalWorkouts = workoutDao.getWorkoutCount(),
        totalDistance = workoutDao.getTotalDistance(),
        totalCalories = workoutDao.getTotalCalories(),
        totalElevation = workoutDao.getTotalElevation()
    )

    /**
     * Builds a CSV of all workouts. Uses [Flow.first] — Room Flows never complete,
     * so [Flow.collect] would hang forever and the Export CSV button would appear dead.
     */
    suspend fun exportCsv(): String {
        val header = "Date,Time,Duration (min),Distance (mi),Calories,Ruck Weight (lb),Heart Rate (bpm),Elevation (ft)\n"
        val rows = StringBuilder(header)
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val timeFormat = SimpleDateFormat("HH:mm", Locale.US)
        // One-shot read; do not collect() — Room Flow stays open indefinitely.
        val workouts = getAllWorkouts().first()
        workouts.forEach { w ->
            val date = Date(w.date)
            rows.append(
                "${dateFormat.format(date)},${timeFormat.format(date)}," +
                    String.format(Locale.US, "%.2f", w.duration / 60.0) + "," +
                    String.format(Locale.US, "%.2f", w.distance) + "," +
                    "${w.calories.toInt()},${w.ruckWeight.toInt()},${w.heartRate.toInt()},${w.elevationGain.toInt()}\n"
            )
        }
        return rows.toString()
    }
}

@Singleton
class WorkoutShareService @Inject constructor(
    private val feedRepository: FeedRepository,
    private val leaderboardRepository: LeaderboardRepository,
    private val clubRepository: ClubRepository,
    private val authRepository: AuthRepository
) {
    /**
     * Always updates the global leaderboard (even with no clubs).
     * Posts the workout to each club in [clubIds] when non-empty.
     * Club failures are isolated so one club cannot block the others / global update.
     */
    suspend fun shareWorkoutToCommunity(
        workout: WorkoutEntity,
        clubIds: List<String>
    ) {
        val userId = authRepository.currentUserId ?: return
        val tonnage = workout.distance * workout.ruckWeight
        runCatching {
            leaderboardRepository.updateGlobalLeaderboard(
                userId = userId,
                distance = workout.distance,
                elevation = workout.elevationGain,
                tonnage = tonnage
            )
        }.onFailure {
            android.util.Log.e("WorkoutShare", "Global leaderboard update failed", it)
        }
        clubIds.forEach { clubId ->
            runCatching {
                feedRepository.postWorkout(
                    clubId = clubId,
                    userId = userId,
                    workoutId = workout.id,
                    distanceMiles = workout.distance,
                    durationMinutes = workout.duration / 60.0,
                    weightLbs = workout.ruckWeight,
                    calories = workout.calories,
                    elevationGain = workout.elevationGain
                )
            }.onFailure {
                android.util.Log.e("WorkoutShare", "Failed to post workout to club $clubId", it)
            }
        }
    }

    suspend fun getUserClubIds(): List<String> {
        val userId = authRepository.currentUserId ?: return emptyList()
        return clubRepository.loadMyClubs(userId).map { it.id }
    }
}
