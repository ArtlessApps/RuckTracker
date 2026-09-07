package com.artless.rucktracker.data.remote

import com.artless.rucktracker.data.local.RoutePointDao
import com.artless.rucktracker.data.local.RoutePointEntity
import com.artless.rucktracker.data.local.WorkoutDao
import com.artless.rucktracker.data.local.WorkoutEntity
import kotlinx.coroutines.flow.Flow
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

    suspend fun exportCsv(): String {
        val header = "Date,Duration (min),Distance (mi),Calories,Ruck Weight (lb),Elevation (ft)\n"
        val rows = StringBuilder(header)
        var workouts: List<WorkoutEntity> = emptyList()
        getAllWorkouts().collect { workouts = it; return@collect }
        workouts.forEach { w ->
            rows.append("${w.date},${w.duration / 60},${w.distance},${w.calories},${w.ruckWeight},${w.elevationGain}\n")
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
     */
    suspend fun shareWorkoutToCommunity(
        workout: WorkoutEntity,
        clubIds: List<String>
    ) {
        val userId = authRepository.currentUserId ?: return
        val tonnage = workout.distance * workout.ruckWeight
        leaderboardRepository.updateGlobalLeaderboard(
            userId = userId,
            distance = workout.distance,
            elevation = workout.elevationGain,
            tonnage = tonnage
        )
        clubIds.forEach { clubId ->
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
        }
    }

    suspend fun getUserClubIds(): List<String> {
        val userId = authRepository.currentUserId ?: return emptyList()
        return clubRepository.loadMyClubs(userId).map { it.id }
    }
}
