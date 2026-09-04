package com.artless.rucktracker.ui.plan

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.remote.AuthRepository
import com.artless.rucktracker.data.remote.PreferencesRepository
import com.artless.rucktracker.data.settings.UserSettingsRepository
import com.artless.rucktracker.domain.MarchPlanGenerator
import com.artless.rucktracker.domain.PlanSession
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PlanViewModel @Inject constructor(
    private val userSettingsRepository: UserSettingsRepository,
    private val preferencesRepository: PreferencesRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _sessions = MutableStateFlow<List<PlanSession>>(emptyList())
    val sessions: StateFlow<List<PlanSession>> = _sessions.asStateFlow()

    private val _goal = MutableStateFlow("")
    val goal: StateFlow<String> = _goal.asStateFlow()

    private val _hasPlan = MutableStateFlow(false)
    val hasPlan: StateFlow<Boolean> = _hasPlan.asStateFlow()

    private val _requestOnboarding = MutableSharedFlow<Unit>()
    val requestOnboarding: SharedFlow<Unit> = _requestOnboarding.asSharedFlow()

    init {
        viewModelScope.launch {
            userSettingsRepository.settings.collect { settings ->
                if (settings.activeProgramId != null) {
                    val plan = MarchPlanGenerator.generatePlan(settings)
                    _goal.value = settings.ruckingGoal.displayName
                    _sessions.value = MarchPlanGenerator.currentWeekSessions(plan)
                    _hasPlan.value = true
                } else {
                    _goal.value = ""
                    _sessions.value = emptyList()
                    _hasPlan.value = false
                }
            }
        }
    }

    /** Matches iOS Plan empty-state "Build My Plan" — reopens onboarding. */
    fun buildMyPlan() {
        viewModelScope.launch {
            userSettingsRepository.update {
                it.copy(hasCompletedOnboarding = false, activeProgramId = null)
            }
            authRepository.currentUserId?.let { userId ->
                runCatching {
                    preferencesRepository.savePreferences(
                        userId,
                        userSettingsRepository.settings.first()
                    )
                }
            }
            _requestOnboarding.emit(Unit)
        }
    }
}
