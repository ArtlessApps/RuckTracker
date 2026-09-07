package com.artless.rucktracker.service

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.os.Build
import android.util.Log
import com.artless.rucktracker.data.CalorieCalculator
import com.artless.rucktracker.data.local.RoutePointEntity
import com.artless.rucktracker.data.local.WorkoutEntity
import com.artless.rucktracker.data.remote.WorkoutRepository
import com.artless.rucktracker.data.remote.WorkoutShareService
import com.artless.rucktracker.data.settings.UserSettingsRepository
import com.artless.rucktracker.domain.ReviewManager
import com.artless.rucktracker.health.HealthConnectManager
import com.artless.rucktracker.ui.workout.ActiveWorkoutState
import com.artless.rucktracker.ui.workout.CompletedWorkout
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Owns the live ruck session independently of Activity/ViewModel lifecycle so
 * tracking survives screen lock, brief backgrounding, and Activity recreation.
 */
@Singleton
class WorkoutSessionManager @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val workoutRepository: WorkoutRepository,
    private val workoutShareService: WorkoutShareService,
    private val userSettingsRepository: UserSettingsRepository,
    private val healthConnectManager: HealthConnectManager,
    private val reviewManager: ReviewManager
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val fusedLocationClient = LocationServices.getFusedLocationProviderClient(appContext)
    private val sensorManager = appContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val pressureSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_PRESSURE)

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

    private var usingBarometer = false
    private var elevationGainMeters = 0.0
    private var altitudeBaselineMeters: Double? = null
    private var lastAltitudeTimestampMs: Long = 0L
    private var lastGpsAltitudeMeters: Double? = null

    companion object {
        private const val TAG = "WorkoutSession"
        private const val BARO_FILTER_THRESHOLD_M = 0.3
        private const val GPS_FILTER_THRESHOLD_M = 1.5
        private const val MAX_CLIMB_RATE_M_PER_S = 5.0
        private const val MAX_GPS_VERTICAL_ACCURACY_M = 25.0
        private const val METERS_TO_FEET = 3.28084
    }

    @SuppressLint("MissingPermission")
    fun start(bodyWeightLbs: Double, ruckWeightLbs: Double) {
        if (_state.value.isActive) return

        this.bodyWeightLbs = bodyWeightLbs
        lastLocation = null
        routePoints.clear()
        resetElevationTracking()
        val workoutId = UUID.randomUUID().toString()
        _state.value = ActiveWorkoutState(
            isActive = true,
            ruckWeightLbs = ruckWeightLbs,
            workoutId = workoutId
        )
        _completedWorkout.value = null

        appContext.startForegroundService(
            Intent(appContext, WorkoutTrackingService::class.java).apply {
                action = WorkoutTrackingService.ACTION_START
            }
        )

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 2000L)
            .setMinUpdateDistanceMeters(5f)
            .build()
        fusedLocationClient.requestLocationUpdates(request, locationCallback, appContext.mainLooper)
        startBarometerTracking()
        startTimer()
        Log.d(TAG, "Session started id=$workoutId")
    }

    fun pause() {
        if (!_state.value.isActive || _state.value.isPaused) return
        _state.value = _state.value.copy(isPaused = true)
        altitudeBaselineMeters = null
        lastAltitudeTimestampMs = 0L
        lastGpsAltitudeMeters = null
        notifyService()
    }

    fun resume() {
        if (!_state.value.isActive || !_state.value.isPaused) return
        _state.value = _state.value.copy(isPaused = false)
        notifyService()
    }

    fun end() {
        if (!_state.value.isActive) return

        timerJob?.cancel()
        timerJob = null
        stopBarometerTracking()
        fusedLocationClient.removeLocationUpdates(locationCallback)

        appContext.startService(
            Intent(appContext, WorkoutTrackingService::class.java).apply {
                action = WorkoutTrackingService.ACTION_STOP
            }
        )

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
        val pointsSnapshot = routePoints.toList()
        _state.value = ActiveWorkoutState()
        resetElevationTracking()
        routePoints.clear()

        scope.launch {
            workoutRepository.saveWorkout(entity, pointsSnapshot)
            _completedWorkout.value = CompletedWorkout(entity)
            try {
                val clubIds = workoutShareService.getUserClubIds()
                workoutShareService.shareWorkoutToCommunity(entity, clubIds)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to share workout to community", e)
            }
            userSettingsRepository.incrementWorkoutCountForReview()
            val count = userSettingsRepository.getWorkoutCountForReview()
            _showReviewPrompt.value = reviewManager.shouldShowReviewPrompt(count)
        }
        Log.d(TAG, "Session ended id=${entity.id}")
    }

    fun clearCompletedWorkout() {
        _completedWorkout.value = null
    }

    private fun notifyService() {
        if (!_state.value.isActive) return
        appContext.startService(
            Intent(appContext, WorkoutTrackingService::class.java).apply {
                action = WorkoutTrackingService.ACTION_UPDATE
            }
        )
    }

    private fun resetElevationTracking() {
        usingBarometer = false
        elevationGainMeters = 0.0
        altitudeBaselineMeters = null
        lastAltitudeTimestampMs = 0L
        lastGpsAltitudeMeters = null
    }

    private fun startBarometerTracking() {
        val sensor = pressureSensor ?: return
        sensorManager.registerListener(
            pressureListener,
            sensor,
            SensorManager.SENSOR_DELAY_UI
        )
    }

    private fun stopBarometerTracking() {
        sensorManager.unregisterListener(pressureListener)
    }

    private val pressureListener = object : SensorEventListener {
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

        override fun onSensorChanged(event: SensorEvent?) {
            val pressureHpa = event?.values?.firstOrNull() ?: return
            val current = _state.value
            if (!current.isActive || current.isPaused) return

            if (!usingBarometer) {
                usingBarometer = true
                altitudeBaselineMeters = null
                lastAltitudeTimestampMs = 0L
                lastGpsAltitudeMeters = null
            }

            val altitudeMeters = SensorManager.getAltitude(
                SensorManager.PRESSURE_STANDARD_ATMOSPHERE,
                pressureHpa
            ).toDouble()
            applyAltitudeSample(altitudeMeters, BARO_FILTER_THRESHOLD_M)
        }
    }

    private fun applyAltitudeSample(currentAltitudeMeters: Double, filterThresholdMeters: Double) {
        val now = System.currentTimeMillis()
        val baseline = altitudeBaselineMeters
        if (baseline == null) {
            altitudeBaselineMeters = currentAltitudeMeters
            lastAltitudeTimestampMs = now
            return
        }

        val elapsedSec = (now - lastAltitudeTimestampMs) / 1000.0
        if (elapsedSec > 0) {
            val climbRate = kotlin.math.abs(currentAltitudeMeters - baseline) / elapsedSec
            if (climbRate > MAX_CLIMB_RATE_M_PER_S) {
                altitudeBaselineMeters = currentAltitudeMeters
                lastAltitudeTimestampMs = now
                return
            }
        }
        lastAltitudeTimestampMs = now

        val delta = currentAltitudeMeters - baseline
        when {
            delta > filterThresholdMeters -> {
                elevationGainMeters += delta
                altitudeBaselineMeters = currentAltitudeMeters
                _state.value = _state.value.copy(
                    elevationGain = elevationGainMeters * METERS_TO_FEET
                )
            }
            delta < -filterThresholdMeters -> {
                altitudeBaselineMeters = currentAltitudeMeters
            }
        }
    }

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val newLocation = result.lastLocation ?: return
            if (_state.value.isPaused) {
                lastLocation = newLocation
                lastGpsAltitudeMeters = null
                return
            }
            val previous = lastLocation
            if (previous != null) {
                val meters = previous.distanceTo(newLocation)
                val additionalMiles = meters * 0.000621371
                _state.value = _state.value.copy(
                    distanceMiles = _state.value.distanceMiles + additionalMiles
                )
            }

            if (!usingBarometer) {
                accumulateGpsElevation(newLocation)
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

    private fun accumulateGpsElevation(location: Location) {
        if (!location.hasAltitude()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val verticalAccuracy = location.verticalAccuracyMeters
            if (verticalAccuracy > 0 && verticalAccuracy > MAX_GPS_VERTICAL_ACCURACY_M) return
        }

        val previousAlt = lastGpsAltitudeMeters
        lastGpsAltitudeMeters = location.altitude
        if (previousAlt == null) {
            altitudeBaselineMeters = location.altitude
            lastAltitudeTimestampMs = System.currentTimeMillis()
            return
        }
        applyAltitudeSample(location.altitude, GPS_FILTER_THRESHOLD_M)
    }

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = scope.launch {
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
                _state.value = current.copy(
                    elapsedSeconds = newElapsed,
                    calories = calories,
                    heartRate = hr
                )
            }
        }
    }
}
