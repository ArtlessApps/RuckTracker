package com.artless.rucktracker.ui.workout

import android.annotation.SuppressLint
import android.app.Application
import android.content.Intent
import android.location.Location
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.CalorieCalculator
import com.artless.rucktracker.data.local.RoutePointEntity
import com.artless.rucktracker.data.local.WorkoutEntity
import com.artless.rucktracker.data.remote.WorkoutRepository
import com.artless.rucktracker.data.remote.WorkoutShareService
import com.artless.rucktracker.data.settings.UserSettingsRepository
import com.artless.rucktracker.domain.PremiumManager
import com.artless.rucktracker.domain.ReviewManager
import com.artless.rucktracker.health.HealthConnectManager
import com.artless.rucktracker.service.WorkoutTrackingService
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

data class ActiveWorkoutState(
    val isActive: Boolean = false,
    val isPaused: Boolean = false,
    val elapsedSeconds: Int = 0,
    val distanceMiles: Double = 0.0,
    val calories: Double = 0.0,
    val ruckWeightLbs: Double = 20.0,
    val elevationGain: Double = 0.0,
    val heartRate: Double = 0.0,
    val workoutId: String = UUID.randomUUID().toString()
)

data class CompletedWorkout(val entity: WorkoutEntity)

@HiltViewModel
class WorkoutViewModel @Inject constructor(
    application: Application,
    private val workoutRepository: WorkoutRepository,
    private val workoutShareService: WorkoutShareService,
    private val userSettingsRepository: UserSettingsRepository,
    private val premiumManager: PremiumManager,
    private val healthConnectManager: HealthConnectManager,
    private val reviewManager: ReviewManager
) : AndroidViewModel(application) {

    private val app = application
    private val fusedLocationClient = LocationServices.getFusedLocationProviderClient(application)

    private val _state = MutableStateFlow(ActiveWorkoutState())
    val state: StateFlow<ActiveWorkoutState> = _state.asStateFlow()

    private val _completedWorkout = MutableStateFlow<CompletedWorkout?>(null)
    val completedWorkout: StateFlow<CompletedWorkout?> = _completedWorkout.asStateFlow()

    private val _showReviewPrompt = MutableStateFlow(false)
    val showReviewPrompt: StateFlow<Boolean> = _showReviewPrompt.asStateFlow()

    private var bodyWeightLbs = 180.0
    private var lastLocation: Location? = null
    private var timerJob: Job? = null
    private val routePoints = mutableListOf<RoutePointEntity>()

    suspend fun loadDefaults(): Pair<Double, Double> {
        val settings = userSettingsRepository.settings.first()
        return settings.bodyWeight to settings.defaultRuckWeight
    }

    fun canStartWorkout(): Boolean = premiumManager.canStartWorkout()

    @SuppressLint("MissingPermission")
    fun start(bodyWeightLbs: Double, ruckWeightLbs: Double) {
        this.bodyWeightLbs = bodyWeightLbs
        lastLocation = null
        routePoints.clear()
        val workoutId = UUID.randomUUID().toString()
        _state.value = ActiveWorkoutState(isActive = true, ruckWeightLbs = ruckWeightLbs, workoutId = workoutId)

        app.startForegroundService(Intent(app, WorkoutTrackingService::class.java).apply {
            action = WorkoutTrackingService.ACTION_START
        })

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 2000L)
            .setMinUpdateDistanceMeters(5f)
            .build()
        fusedLocationClient.requestLocationUpdates(request, locationCallback, app.mainLooper)
        startTimer()
    }

    fun pause() { _state.value = _state.value.copy(isPaused = true) }
    fun resume() { _state.value = _state.value.copy(isPaused = false) }

    fun end() {
        timerJob?.cancel()
        fusedLocationClient.removeLocationUpdates(locationCallback)
        app.startService(Intent(app, WorkoutTrackingService::class.java).apply {
            action = WorkoutTrackingService.ACTION_STOP
        })

        val finalState = _state.value
        val entity = WorkoutEntity(
            id = finalState.workoutId,
            date = System.currentTimeMillis(),
            duration = finalState.elapsedSeconds.toDouble(),
            distance = finalState.distanceMiles,
            calories = finalState.calories,
            ruckWeight = finalState.ruckWeightLbs,
            heartRate = finalState.heartRate,
            elevationGain = finalState.elevationGain
        )
        viewModelScope.launch {
            workoutRepository.saveWorkout(entity, routePoints.toList())
            val clubIds = workoutShareService.getUserClubIds()
            if (clubIds.isNotEmpty()) {
                workoutShareService.shareWorkoutToCommunity(entity, clubIds)
            }
            userSettingsRepository.incrementWorkoutCountForReview()
            val count = userSettingsRepository.getWorkoutCountForReview()
            _showReviewPrompt.value = reviewManager.shouldShowReviewPrompt(count)
            _completedWorkout.value = CompletedWorkout(entity)
        }
        _state.value = ActiveWorkoutState()
    }

    fun clearCompletedWorkout() { _completedWorkout.value = null }

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val newLocation = result.lastLocation ?: return
            if (_state.value.isPaused) { lastLocation = newLocation; return }
            val previous = lastLocation
            var elevationDelta = 0.0
            if (previous != null) {
                val meters = previous.distanceTo(newLocation)
                val additionalMiles = meters * 0.000621371
                if (newLocation.hasAltitude() && previous.hasAltitude()) {
                    val elevMeters = newLocation.altitude - previous.altitude
                    if (elevMeters > 0) elevationDelta = elevMeters * 3.28084
                }
                _state.value = _state.value.copy(
                    distanceMiles = _state.value.distanceMiles + additionalMiles,
                    elevationGain = _state.value.elevationGain + elevationDelta
                )
            }
            routePoints.add(
                RoutePointEntity(
                    workoutId = _state.value.workoutId,
                    latitude = newLocation.latitude,
                    longitude = newLocation.longitude,
                    altitude = if (newLocation.hasAltitude()) newLocation.altitude else 0.0
                )
            )
            lastLocation = newLocation
        }
    }

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            while (true) {
                delay(1000)
                val current = _state.value
                if (!current.isActive) break
                if (current.isPaused) continue
                val newElapsed = current.elapsedSeconds + 1
                val calories = CalorieCalculator.calculateRuckingCalories(
                    bodyWeightKg = bodyWeightLbs / 2.20462,
                    ruckWeightPounds = current.ruckWeightLbs,
                    timeMinutes = newElapsed / 60.0,
                    distanceMiles = current.distanceMiles
                )
                val hr = healthConnectManager.getLatestHeartRate() ?: current.heartRate
                _state.value = current.copy(elapsedSeconds = newElapsed, calories = calories, heartRate = hr)
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        timerJob?.cancel()
        fusedLocationClient.removeLocationUpdates(locationCallback)
    }
}
