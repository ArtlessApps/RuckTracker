package com.artless.rucktracker.ui.tribe

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.model.Club
import com.artless.rucktracker.data.model.ClubEvent
import com.artless.rucktracker.data.model.ClubPost
import com.artless.rucktracker.data.model.LeaderboardEntry
import com.artless.rucktracker.data.remote.AuthRepository
import com.artless.rucktracker.data.remote.ClubRepository
import com.artless.rucktracker.data.remote.EventRepository
import com.artless.rucktracker.data.remote.FeedRepository
import com.artless.rucktracker.data.remote.LeaderboardRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

data class TribeUiState(
    val isAuthenticated: Boolean = false,
    val clubs: List<Club> = emptyList(),
    val selectedClub: Club? = null,
    val feedPosts: List<ClubPost> = emptyList(),
    val leaderboard: List<LeaderboardEntry> = emptyList(),
    val events: List<ClubEvent> = emptyList(),
    val error: String? = null
)

@HiltViewModel
class TribeViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val clubRepository: ClubRepository,
    private val feedRepository: FeedRepository,
    private val leaderboardRepository: LeaderboardRepository,
    private val eventRepository: EventRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(TribeUiState())
    val uiState: StateFlow<TribeUiState> = _uiState.asStateFlow()

    init { refresh() }

    fun refresh() {
        viewModelScope.launch {
            val userId = authRepository.currentUserId
            if (userId == null) {
                _uiState.value = TribeUiState(isAuthenticated = false)
                return@launch
            }
            val clubs = runCatching { clubRepository.loadMyClubs(userId) }.getOrDefault(emptyList())
            _uiState.value = _uiState.value.copy(isAuthenticated = true, clubs = clubs, error = null)
        }
    }

    fun selectClub(club: Club) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(selectedClub = club)
            loadFeed(club.id)
            loadLeaderboard(club.id)
            loadEvents()
        }
    }

    fun clearSelectedClub() {
        _uiState.value = _uiState.value.copy(selectedClub = null)
    }

    fun joinClub(code: String) {
        viewModelScope.launch {
            val userId = authRepository.currentUserId ?: return@launch
            runCatching { clubRepository.joinClubWithCode(code.trim(), userId) }
                .onSuccess { refresh() }
                .onFailure { _uiState.value = _uiState.value.copy(error = it.message) }
        }
    }

    fun createClub(
        name: String,
        description: String,
        isPrivate: Boolean,
        zipcode: String?,
        customJoinCode: String? = null
    ) {
        viewModelScope.launch {
            val userId = authRepository.currentUserId ?: return@launch
            val trimmedCustom = customJoinCode?.trim()?.uppercase().orEmpty()
            val code = trimmedCustom.ifEmpty { UUID.randomUUID().toString().take(6).uppercase() }
            runCatching {
                clubRepository.createClub(
                    name = name.trim(),
                    description = description.trim(),
                    isPrivate = isPrivate,
                    zipcode = zipcode?.trim()?.takeIf { it.isNotEmpty() },
                    createdBy = userId,
                    joinCode = code
                )
            }.onSuccess { refresh() }
                .onFailure { _uiState.value = _uiState.value.copy(error = it.message) }
        }
    }

    fun toggleLike(postId: String) {
        viewModelScope.launch {
            val userId = authRepository.currentUserId ?: return@launch
            runCatching { feedRepository.likePost(postId, userId) }
            _uiState.value.selectedClub?.let { loadFeed(it.id) }
        }
    }

    fun loadEvents() {
        viewModelScope.launch {
            val clubId = _uiState.value.selectedClub?.id ?: return@launch
            val events = runCatching { eventRepository.loadClubEvents(clubId) }.getOrDefault(emptyList())
            _uiState.value = _uiState.value.copy(events = events)
        }
    }

    private suspend fun loadFeed(clubId: String) {
        val posts = runCatching { feedRepository.loadClubFeed(clubId) }.getOrDefault(emptyList())
        _uiState.value = _uiState.value.copy(feedPosts = posts)
    }

    private suspend fun loadLeaderboard(clubId: String) {
        val board = runCatching { leaderboardRepository.loadWeeklyLeaderboard(clubId) }.getOrDefault(emptyList())
        _uiState.value = _uiState.value.copy(leaderboard = board)
    }

    fun promptSignIn() {}
}
