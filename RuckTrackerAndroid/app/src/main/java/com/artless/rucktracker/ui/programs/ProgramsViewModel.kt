package com.artless.rucktracker.ui.programs

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.model.ChallengeJson
import com.artless.rucktracker.data.model.PaywallContext
import com.artless.rucktracker.data.model.PremiumFeature
import com.artless.rucktracker.data.model.ProgramJson
import com.artless.rucktracker.data.settings.UserSettingsRepository
import com.artless.rucktracker.domain.PremiumManager
import com.artless.rucktracker.domain.ProgramCatalogService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed class CatalogDetail {
    data class Program(val program: ProgramJson) : CatalogDetail()
    data class Challenge(val challenge: ChallengeJson) : CatalogDetail()
}

@HiltViewModel
class ProgramsViewModel @Inject constructor(
    catalogService: ProgramCatalogService,
    private val premiumManager: PremiumManager,
    private val settingsRepository: UserSettingsRepository
) : ViewModel() {
    private val _programs = MutableStateFlow(catalogService.loadPrograms())
    val programs: StateFlow<List<ProgramJson>> = _programs.asStateFlow()

    private val _challenges = MutableStateFlow(catalogService.loadChallenges())
    val challenges: StateFlow<List<ChallengeJson>> = _challenges.asStateFlow()

    val isPremium: StateFlow<Boolean> = premiumManager.isPremiumUser
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    private val _showPaywall = MutableStateFlow(false)
    val showPaywall: StateFlow<Boolean> = _showPaywall.asStateFlow()

    private val _selectedDetail = MutableStateFlow<CatalogDetail?>(null)
    val selectedDetail: StateFlow<CatalogDetail?> = _selectedDetail.asStateFlow()

    private val _enrolledProgramId = MutableStateFlow<String?>(null)
    val enrolledProgramId: StateFlow<String?> = _enrolledProgramId.asStateFlow()

    private val _enrolledChallengeId = MutableStateFlow<String?>(null)
    val enrolledChallengeId: StateFlow<String?> = _enrolledChallengeId.asStateFlow()

    init {
        viewModelScope.launch {
            settingsRepository.settings.collect { settings ->
                _enrolledProgramId.value = settings.activeProgramId
            }
        }
        viewModelScope.launch {
            premiumManager.refreshPremiumStatus()
        }
    }

    fun onProgramTap(program: ProgramJson) {
        if (premiumManager.canAccess(PremiumFeature.TRAINING_PROGRAMS)) {
            _selectedDetail.value = CatalogDetail.Program(program)
        } else {
            premiumManager.requestPaywall(PaywallContext.PROGRAM_ACCESS)
            _showPaywall.value = true
        }
    }

    fun onChallengeTap(challenge: ChallengeJson) {
        if (premiumManager.canAccess(PremiumFeature.WEEKLY_CHALLENGES)) {
            _selectedDetail.value = CatalogDetail.Challenge(challenge)
        } else {
            premiumManager.requestPaywall(PaywallContext.PROGRAM_ACCESS)
            _showPaywall.value = true
        }
    }

    fun dismissDetail() {
        _selectedDetail.value = null
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

    fun enrollInProgram(program: ProgramJson) {
        if (!premiumManager.canAccess(PremiumFeature.TRAINING_PROGRAMS)) {
            premiumManager.requestPaywall(PaywallContext.PROGRAM_ACCESS)
            _showPaywall.value = true
            return
        }
        viewModelScope.launch {
            settingsRepository.update { it.copy(activeProgramId = program.id) }
            _enrolledProgramId.value = program.id
            _selectedDetail.value = null
        }
    }

    fun enrollInChallenge(challenge: ChallengeJson) {
        if (!premiumManager.canAccess(PremiumFeature.WEEKLY_CHALLENGES)) {
            premiumManager.requestPaywall(PaywallContext.PROGRAM_ACCESS)
            _showPaywall.value = true
            return
        }
        _enrolledChallengeId.value = challenge.id
        _selectedDetail.value = null
    }
}
