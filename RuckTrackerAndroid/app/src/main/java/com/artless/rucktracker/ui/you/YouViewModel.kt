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
import com.artless.rucktracker.domain.FeedbackSupport
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
    private val shareCardRenderer: ShareCardRenderer,
    private val feedbackSupport: FeedbackSupport
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

    fun shareWorkout(context: android.content.Context, workout: WorkoutEntity) {
        viewModelScope.launch {
            val userId = authRepository.currentUserId
            val username = userId?.let { runCatching { authRepository.fetchProfile(it).username }.getOrNull() }
            shareCardRenderer.shareWorkout(workout, username, launchContext = context)
        }
    }

    fun exportAndShare(context: android.content.Context) {
        viewModelScope.launch {
            val csv = workoutRepository.exportCsv()
            try {
                val cacheDir = java.io.File(context.cacheDir, "share").apply { mkdirs() }
                val file = java.io.File(cacheDir, "MARCH_Workouts.csv")
                file.writeText(csv)
                val uri = androidx.core.content.FileProvider.getUriForFile(
                    context,
                    "${context.packageName}.fileprovider",
                    file
                )
                val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                    type = "text/csv"
                    putExtra(android.content.Intent.EXTRA_STREAM, uri)
                    clipData = android.content.ClipData.newUri(
                        context.contentResolver,
                        "MARCH workouts",
                        uri
                    )
                    addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                val chooser = android.content.Intent.createChooser(intent, "Export CSV").apply {
                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(chooser)
            } catch (e: Exception) {
                android.util.Log.e("YouViewModel", "Failed to export CSV", e)
            }
        }
    }

    fun sendFeedback(context: android.content.Context) {
        feedbackSupport.sendFeedback(launchContext = context)
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
