package com.artless.rucktracker.ui.onboarding

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.model.ExperienceLevel
import com.artless.rucktracker.data.model.RuckingGoal
import com.artless.rucktracker.data.remote.AuthRepository
import com.artless.rucktracker.data.remote.PreferencesRepository
import com.artless.rucktracker.data.settings.UserSettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

data class OnboardingState(
    val bodyWeight: Double = 180.0,
    val defaultRuckWeight: Double = 20.0,
    val goal: RuckingGoal = RuckingGoal.LONGEVITY,
    val experience: ExperienceLevel = ExperienceLevel.BEGINNER,
    val pace: Double = 16.0,
    val longestDistance: Double = 4.0,
    val hasHills: Boolean = true,
    val hasStairs: Boolean = false,
    val trainingDays: List<Int> = listOf(2, 4, 7)
)

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val userSettingsRepository: UserSettingsRepository,
    private val preferencesRepository: PreferencesRepository,
    private val authRepository: AuthRepository
) : ViewModel() {
    var state by mutableStateOf(OnboardingState())
        private set

    fun updateWeights(body: Double, ruck: Double) {
        state = state.copy(bodyWeight = body, defaultRuckWeight = ruck)
    }

    fun updateGoal(goal: RuckingGoal) { state = state.copy(goal = goal) }
    fun updateExperience(level: ExperienceLevel) { state = state.copy(experience = level) }
    fun updateBaseline(pace: Double, distance: Double) { state = state.copy(pace = pace, longestDistance = distance) }
    fun updateTerrain(hills: Boolean, stairs: Boolean) { state = state.copy(hasHills = hills, hasStairs = stairs) }
    fun setEventDate() { /* optional */ }
    fun updateTrainingDays(days: List<Int>) { state = state.copy(trainingDays = days) }

    fun complete(onComplete: () -> Unit) {
        viewModelScope.launch {
            userSettingsRepository.update { current ->
                current.copy(
                    bodyWeight = state.bodyWeight,
                    defaultRuckWeight = state.defaultRuckWeight,
                    ruckingGoal = state.goal,
                    experienceLevel = state.experience,
                    baselinePaceMinutesPerMile = state.pace,
                    baselineLongestDistanceMiles = state.longestDistance,
                    hasHillAccess = state.hasHills,
                    hasStairsAccess = state.hasStairs,
                    preferredTrainingDays = state.trainingDays,
                    hasCompletedOnboarding = true
                )
            }
            userSettingsRepository.setOnboardingComplete(true)
            authRepository.currentUserId?.let { userId ->
                runCatching {
                    preferencesRepository.savePreferences(
                        userId,
                        userSettingsRepository.settings.first()
                    )
                }
            }
            onComplete()
        }
    }
}
