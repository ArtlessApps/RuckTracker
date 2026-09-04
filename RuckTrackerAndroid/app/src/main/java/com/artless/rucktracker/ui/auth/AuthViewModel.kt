package com.artless.rucktracker.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.model.UserProfile
import com.artless.rucktracker.data.remote.AuthRepository
import com.artless.rucktracker.data.remote.PreferencesRepository
import com.artless.rucktracker.data.settings.UserSettingsRepository
import com.artless.rucktracker.domain.PremiumManager
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.auth.status.SessionStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed interface AppGateState {
    data object Loading : AppGateState
    data object SignedOut : AppGateState
    data object NeedsOnboarding : AppGateState
    data class Ready(val profile: UserProfile?) : AppGateState
}

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val repository: AuthRepository,
    private val userSettingsRepository: UserSettingsRepository,
    private val preferencesRepository: PreferencesRepository,
    private val premiumManager: PremiumManager
) : ViewModel() {

    private val _gateState = MutableStateFlow<AppGateState>(AppGateState.Loading)
    val gateState: StateFlow<AppGateState> = _gateState.asStateFlow()

    private val _isSubmitting = MutableStateFlow(false)
    val isSubmitting: StateFlow<Boolean> = _isSubmitting.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _infoMessage = MutableStateFlow<String?>(null)
    val infoMessage: StateFlow<String?> = _infoMessage.asStateFlow()

    init {
        viewModelScope.launch {
            repository.sessionStatus.collect { status ->
                when (status) {
                    is SessionStatus.Authenticated -> loadAuthenticatedState(status.session.user?.id)
                    is SessionStatus.NotAuthenticated -> _gateState.value = AppGateState.SignedOut
                    is SessionStatus.RefreshFailure -> _gateState.value = AppGateState.SignedOut
                    SessionStatus.Initializing -> _gateState.value = AppGateState.Loading
                }
            }
        }
    }

    private suspend fun loadAuthenticatedState(userId: String?) {
        if (userId == null) {
            _gateState.value = AppGateState.Ready(null)
            return
        }
        val profile = runCatching { repository.fetchProfile(userId) }.getOrNull()
        // Always replace device-local settings for this account so a previous
        // login's plan/onboarding flag cannot leak across users.
        val remoteSettings = preferencesRepository.loadPreferences(userId)
        if (remoteSettings != null) {
            userSettingsRepository.replaceAll(remoteSettings)
        } else {
            userSettingsRepository.resetToDefaults()
        }
        premiumManager.refreshPremiumStatus()
        val needsOnboarding = !userSettingsRepository.settings.first().hasCompletedOnboarding
        _gateState.value = if (needsOnboarding) AppGateState.NeedsOnboarding else AppGateState.Ready(profile)
    }

    fun signUp(email: String, username: String, password: String) {
        clearMessages()
        _isSubmitting.value = true
        viewModelScope.launch {
            runCatching {
                if (!repository.isUsernameAvailable(username)) error("That username is already taken.")
                repository.signUp(email, username, password)
            }.onSuccess {
                if (repository.sessionStatus.value !is SessionStatus.Authenticated) {
                    _infoMessage.value = "Check your email to confirm your account, then sign in."
                }
            }.onFailure { _errorMessage.value = it.message ?: "Sign up failed." }
            _isSubmitting.value = false
        }
    }

    fun signIn(email: String, password: String) {
        clearMessages()
        _isSubmitting.value = true
        viewModelScope.launch {
            runCatching { repository.signIn(email, password) }
                .onFailure { _errorMessage.value = it.message ?: "Sign in failed." }
            _isSubmitting.value = false
        }
    }

    fun signOut() {
        viewModelScope.launch { performSignOut() }
    }

    fun deleteAccount() {
        viewModelScope.launch {
            runCatching { repository.deleteAccount() }
            userSettingsRepository.resetToDefaults()
        }
    }

    private suspend fun performSignOut() {
        val userId = repository.currentUserId
        if (userId != null) {
            runCatching {
                preferencesRepository.savePreferences(
                    userId,
                    userSettingsRepository.settings.first()
                )
            }
        }
        repository.signOut()
        userSettingsRepository.resetToDefaults()
    }

    private fun clearMessages() {
        _errorMessage.value = null
        _infoMessage.value = null
    }
}
