package com.artless.rucktracker.ui.you

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.local.WorkoutEntity
import com.artless.rucktracker.data.remote.AuthRepository
import com.artless.rucktracker.data.remote.PreferencesRepository
import com.artless.rucktracker.data.remote.WorkoutRepository
import com.artless.rucktracker.data.remote.WorkoutStats
import com.artless.rucktracker.data.settings.UserSettingsRepository
import com.artless.rucktracker.data.settings.UserSettingsState
import com.artless.rucktracker.share.ShareCardRenderer
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class YouViewModel @Inject constructor(
    private val workoutRepository: WorkoutRepository,
    private val authRepository: AuthRepository,
    private val preferencesRepository: PreferencesRepository,
    private val userSettingsRepository: UserSettingsRepository,
    private val shareCardRenderer: ShareCardRenderer
) : ViewModel() {

    val workouts: StateFlow<List<WorkoutEntity>> = workoutRepository.getAllWorkouts()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val settings: StateFlow<UserSettingsState> = userSettingsRepository.settings
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), UserSettingsState())

    private val _stats = kotlinx.coroutines.flow.MutableStateFlow(WorkoutStats(0, 0.0, 0.0, 0.0))
    val stats: StateFlow<WorkoutStats> = _stats

    init {
        refreshStats()
    }

    fun refreshStats() {
        viewModelScope.launch {
            _stats.value = workoutRepository.getStats()
        }
    }

    fun deleteWorkout(id: String) {
        viewModelScope.launch {
            workoutRepository.deleteWorkout(id)
            refreshStats()
        }
    }

    fun shareWorkout(workout: WorkoutEntity) {
        viewModelScope.launch {
            val userId = authRepository.currentUserId
            val username = userId?.let { runCatching { authRepository.fetchProfile(it).username }.getOrNull() }
            shareCardRenderer.shareWorkout(workout, username)
        }
    }

    fun exportAndShare(context: android.content.Context) {
        viewModelScope.launch {
            val csv = workoutRepository.exportCsv()
            val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(android.content.Intent.EXTRA_TEXT, csv)
            }
            context.startActivity(android.content.Intent.createChooser(intent, "Export CSV"))
        }
    }

    fun signOut() {
        viewModelScope.launch {
            val userId = authRepository.currentUserId
            if (userId != null) {
                runCatching {
                    preferencesRepository.savePreferences(
                        userId,
                        userSettingsRepository.settings.first()
                    )
                }
            }
            authRepository.signOut()
            userSettingsRepository.resetToDefaults()
        }
    }

    fun deleteAccount() {
        viewModelScope.launch {
            runCatching { authRepository.deleteAccount() }
            userSettingsRepository.resetToDefaults()
        }
    }
}
