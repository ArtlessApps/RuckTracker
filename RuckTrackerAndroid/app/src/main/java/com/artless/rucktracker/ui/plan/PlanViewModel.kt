package com.artless.rucktracker.ui.plan

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.settings.UserSettingsRepository
import com.artless.rucktracker.domain.MarchPlanGenerator
import com.artless.rucktracker.domain.PlanSession
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PlanViewModel @Inject constructor(
    private val userSettingsRepository: UserSettingsRepository
) : ViewModel() {

    private val _sessions = MutableStateFlow<List<PlanSession>>(emptyList())
    val sessions: StateFlow<List<PlanSession>> = _sessions.asStateFlow()

    private val _goal = MutableStateFlow("")
    val goal: StateFlow<String> = _goal.asStateFlow()

    init {
        viewModelScope.launch {
            val settings = userSettingsRepository.settings.first()
            val plan = MarchPlanGenerator.generatePlan(settings)
            _goal.value = settings.ruckingGoal.displayName
            _sessions.value = MarchPlanGenerator.currentWeekSessions(plan)
        }
    }
}
