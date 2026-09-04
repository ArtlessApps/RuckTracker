package com.artless.rucktracker.ui.ruck

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.model.MainTab
import com.artless.rucktracker.data.model.PaywallContext
import com.artless.rucktracker.data.remote.AuthRepository
import com.artless.rucktracker.domain.PremiumManager
import com.artless.rucktracker.domain.ProgramCatalogService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.Calendar
import javax.inject.Inject

data class RuckTabUiState(
    val displayName: String = "Rucker",
    val timeOfDay: String = "morning",
    val streak: Int? = null,
    val nextEvent: String? = null,
    val programCount: Int = 0,
    val rankSummary: String? = null
)

@HiltViewModel
class RuckTabViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val premiumManager: PremiumManager,
    private val programCatalogService: ProgramCatalogService
) : ViewModel() {

    private val _uiState = MutableStateFlow(RuckTabUiState())
    val uiState: StateFlow<RuckTabUiState> = _uiState.asStateFlow()

    private val _showPaywall = MutableStateFlow(false)
    val showPaywall: StateFlow<Boolean> = _showPaywall.asStateFlow()

    private val _navigateToStartRuck = MutableSharedFlow<Unit>()
    val navigateToStartRuck: SharedFlow<Unit> = _navigateToStartRuck.asSharedFlow()

    init {
        viewModelScope.launch {
            val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
            val timeOfDay = when {
                hour < 12 -> "morning"
                hour < 17 -> "afternoon"
                else -> "evening"
            }
            val userId = authRepository.currentUserId
            val profile = userId?.let { runCatching { authRepository.fetchProfile(it) }.getOrNull() }
            _uiState.value = RuckTabUiState(
                displayName = profile?.username ?: "Rucker",
                timeOfDay = timeOfDay,
                streak = profile?.currentStreak,
                programCount = programCatalogService.loadPrograms().size
            )
        }
    }

    fun onStartRuck(onNavigate: () -> Unit) {
        if (premiumManager.canStartWorkout()) {
            onNavigate()
        } else {
            premiumManager.requestPaywall(PaywallContext.WORKOUT_START)
            _showPaywall.value = true
        }
    }

    fun dismissPaywall() {
        _showPaywall.value = false
        premiumManager.dismissPaywall()
    }

    fun onPurchased() {
        viewModelScope.launch {
            premiumManager.onPurchaseComplete()
            _showPaywall.value = false
        }
    }
}
