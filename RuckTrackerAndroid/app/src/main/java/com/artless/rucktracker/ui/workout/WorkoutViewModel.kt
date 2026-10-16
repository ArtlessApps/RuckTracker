package com.artless.rucktracker.ui.workout

import androidx.lifecycle.ViewModel
import com.artless.rucktracker.data.local.WorkoutEntity
import com.artless.rucktracker.data.settings.UserSettingsRepository
import com.artless.rucktracker.domain.PremiumManager
import com.artless.rucktracker.health.HealthConnectManager
import com.artless.rucktracker.service.WorkoutSessionManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
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
    val heartRateConnected: Boolean = false,
    val workoutId: String = UUID.randomUUID().toString()
)

data class CompletedWorkout(val entity: WorkoutEntity)

@HiltViewModel
class WorkoutViewModel @Inject constructor(
    private val sessionManager: WorkoutSessionManager,
    private val userSettingsRepository: UserSettingsRepository,
    private val premiumManager: PremiumManager,
    private val healthConnectManager: HealthConnectManager
) : ViewModel() {

    val state: StateFlow<ActiveWorkoutState> = sessionManager.state
    val completedWorkout: StateFlow<CompletedWorkout?> = sessionManager.completedWorkout
    val showReviewPrompt: StateFlow<Boolean> = sessionManager.showReviewPrompt

    suspend fun loadDefaults(): Pair<Double, Double> {
        val settings = userSettingsRepository.settings.first()
        return settings.bodyWeight to settings.defaultRuckWeight
    }

    fun canStartWorkout(): Boolean = premiumManager.canStartWorkout()

    val heartRatePermissions: Set<String> = healthConnectManager.permissions

    fun heartRatePermissionContract() = healthConnectManager.requestPermissionsContract()

    suspend fun shouldPromptForHeartRate(): Boolean = healthConnectManager.shouldPromptForPermissions()

    fun markHeartRatePrompted() = healthConnectManager.markPrompted()

    fun isHealthConnectAvailable(): Boolean = healthConnectManager.isAvailable()

    fun healthConnectSettingsIntent() = healthConnectManager.settingsIntent()

    fun start(bodyWeightLbs: Double, ruckWeightLbs: Double) {
        sessionManager.start(bodyWeightLbs, ruckWeightLbs)
    }

    fun pause() = sessionManager.pause()

    fun resume() = sessionManager.resume()

    fun end() = sessionManager.end()

    fun clearCompletedWorkout() = sessionManager.clearCompletedWorkout()
}
