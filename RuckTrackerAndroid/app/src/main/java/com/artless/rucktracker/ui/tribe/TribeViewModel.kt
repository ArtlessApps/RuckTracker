package com.artless.rucktracker.ui.tribe

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.model.Club
import com.artless.rucktracker.data.model.ClubEvent
import com.artless.rucktracker.data.model.ClubMember
import com.artless.rucktracker.data.model.ClubPost
import com.artless.rucktracker.data.model.ClubRole
import com.artless.rucktracker.data.model.EmergencyContact
import com.artless.rucktracker.data.model.EventRsvp
import com.artless.rucktracker.data.model.LeaderboardEntry
import com.artless.rucktracker.data.remote.AuthRepository
import com.artless.rucktracker.data.remote.ClubRepository
import com.artless.rucktracker.data.remote.EventRepository
import com.artless.rucktracker.data.remote.FeedRepository
import com.artless.rucktracker.data.remote.LeaderboardRepository
import com.artless.rucktracker.service.EventNotificationService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

enum class ClubOverlay {
    None,
    Members,
    Settings,
    CreateEvent,
    EventDetail
}

data class TribeUiState(
    val isAuthenticated: Boolean = false,
    val clubs: List<Club> = emptyList(),
    val selectedClub: Club? = null,
    val userRole: ClubRole = ClubRole.MEMBER,
    val currentUserId: String? = null,
    val feedPosts: List<ClubPost> = emptyList(),
    val leaderboard: List<LeaderboardEntry> = emptyList(),
    val events: List<ClubEvent> = emptyList(),
    val members: List<ClubMember> = emptyList(),
    val overlay: ClubOverlay = ClubOverlay.None,
    val selectedEvent: ClubEvent? = null,
    val eventRsvps: List<EventRsvp> = emptyList(),
    val eventComments: List<ClubPost> = emptyList(),
    val isCreatingClub: Boolean = false,
    val isJoiningClub: Boolean = false,
    val isSigningWaiver: Boolean = false,
    /** Club joined but awaiting waiver signature (iOS JoinClubView pendingClub*). */
    val pendingWaiverClub: Club? = null,
    val isSaving: Boolean = false,
    val successMessage: String? = null,
    val error: String? = null
)

@HiltViewModel
class TribeViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val clubRepository: ClubRepository,
    private val feedRepository: FeedRepository,
    private val leaderboardRepository: LeaderboardRepository,
    private val eventRepository: EventRepository,
    private val notificationService: EventNotificationService
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
            val selectedId = _uiState.value.selectedClub?.id
            val selected = clubs.find { it.id == selectedId }
            _uiState.value = _uiState.value.copy(
                isAuthenticated = true,
                currentUserId = userId,
                clubs = clubs,
                selectedClub = selected,
                error = null
            )
            selected?.let { openClubData(it, userId) }
        }
    }

    fun selectClub(club: Club) {
        viewModelScope.launch {
            val userId = authRepository.currentUserId ?: return@launch
            _uiState.value = _uiState.value.copy(
                selectedClub = club,
                overlay = ClubOverlay.None,
                selectedEvent = null,
                error = null,
                successMessage = null
            )
            openClubData(club, userId)
        }
    }

    fun clearSelectedClub() {
        _uiState.value = _uiState.value.copy(
            selectedClub = null,
            overlay = ClubOverlay.None,
            selectedEvent = null,
            members = emptyList(),
            feedPosts = emptyList(),
            leaderboard = emptyList(),
            events = emptyList(),
            userRole = ClubRole.MEMBER
        )
    }

    fun showOverlay(overlay: ClubOverlay) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(overlay = overlay, error = null, successMessage = null)
            if (overlay == ClubOverlay.Members) loadMembers()
        }
    }

    fun dismissOverlay() {
        _uiState.value = _uiState.value.copy(
            overlay = ClubOverlay.None,
            selectedEvent = null,
            eventRsvps = emptyList(),
            eventComments = emptyList()
        )
    }

    fun joinClub(code: String) {
        if (_uiState.value.isJoiningClub) return
        viewModelScope.launch {
            val userId = authRepository.currentUserId ?: return@launch
            val trimmed = code.trim()
            if (trimmed.isEmpty()) return@launch
            _uiState.value = _uiState.value.copy(isJoiningClub = true, error = null)
            // iOS: join first (insert membership), then show waiver sheet
            runCatching { clubRepository.joinClubWithCode(trimmed, userId) }
                .onSuccess { club ->
                    val clubs = runCatching { clubRepository.loadMyClubs(userId) }.getOrDefault(emptyList())
                    _uiState.value = _uiState.value.copy(
                        isJoiningClub = false,
                        clubs = clubs,
                        pendingWaiverClub = club,
                        error = null
                    )
                }
                .onFailure {
                    _uiState.value = _uiState.value.copy(
                        isJoiningClub = false,
                        error = it.message
                    )
                }
        }
    }

    fun signPendingWaiver(contact: EmergencyContact) {
        if (_uiState.value.isSigningWaiver) return
        viewModelScope.launch {
            val userId = authRepository.currentUserId ?: return@launch
            val club = _uiState.value.pendingWaiverClub ?: return@launch
            _uiState.value = _uiState.value.copy(isSigningWaiver = true, error = null)
            runCatching { clubRepository.signWaiver(club.id, userId, contact) }
                .onSuccess {
                    val clubs = runCatching { clubRepository.loadMyClubs(userId) }.getOrDefault(emptyList())
                    val joined = clubs.find { it.id == club.id } ?: club
                    _uiState.value = _uiState.value.copy(
                        isSigningWaiver = false,
                        pendingWaiverClub = null,
                        clubs = clubs,
                        selectedClub = joined,
                        error = null
                    )
                    openClubData(joined, userId)
                }
                .onFailure {
                    _uiState.value = _uiState.value.copy(
                        isSigningWaiver = false,
                        error = it.message
                    )
                }
        }
    }

    /** iOS Cancel: dismiss waiver sheet; membership already exists, refresh club list. */
    fun dismissPendingWaiver() {
        viewModelScope.launch {
            val userId = authRepository.currentUserId
            val clubs = if (userId != null) {
                runCatching { clubRepository.loadMyClubs(userId) }.getOrDefault(_uiState.value.clubs)
            } else {
                _uiState.value.clubs
            }
            _uiState.value = _uiState.value.copy(
                pendingWaiverClub = null,
                isSigningWaiver = false,
                clubs = clubs,
                error = null
            )
        }
    }

    fun createClub(
        name: String,
        description: String,
        isPrivate: Boolean,
        zipcode: String?,
        customJoinCode: String? = null
    ) {
        if (_uiState.value.isCreatingClub) return
        viewModelScope.launch {
            val userId = authRepository.currentUserId ?: return@launch
            _uiState.value = _uiState.value.copy(isCreatingClub = true, error = null)
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
            }.onSuccess { club ->
                val clubs = runCatching { clubRepository.loadMyClubs(userId) }.getOrDefault(emptyList())
                val created = clubs.find { it.id == club.id } ?: club
                _uiState.value = _uiState.value.copy(
                    isAuthenticated = true,
                    currentUserId = userId,
                    clubs = clubs,
                    selectedClub = created,
                    isCreatingClub = false,
                    error = null
                )
                openClubData(created, userId)
            }.onFailure {
                _uiState.value = _uiState.value.copy(
                    isCreatingClub = false,
                    error = it.message
                )
            }
        }
    }

    fun toggleLike(postId: String) {
        viewModelScope.launch {
            val userId = authRepository.currentUserId ?: return@launch
            val posts = _uiState.value.feedPosts
            val index = posts.indexOfFirst { it.id == postId }
            if (index < 0) return@launch
            val post = posts[index]
            // get_club_feed does not return is_liked — keep optimistic local state like iOS
            val liked = post.isLiked
            val updated = post.copy(
                isLiked = !liked,
                likeCount = (post.likeCount + if (liked) -1 else 1).coerceAtLeast(0)
            )
            _uiState.value = _uiState.value.copy(
                feedPosts = posts.toMutableList().also { it[index] = updated }
            )
            runCatching {
                if (liked) feedRepository.unlikePost(postId, userId)
                else feedRepository.likePost(postId, userId)
            }.onFailure {
                // Roll back optimistic update; keep like_count from server on next refresh
                _uiState.value = _uiState.value.copy(
                    feedPosts = _uiState.value.feedPosts.toMutableList().also { list ->
                        val i = list.indexOfFirst { it.id == postId }
                        if (i >= 0) list[i] = post
                    }
                )
            }
        }
    }

    fun leaveClub() {
        viewModelScope.launch {
            val club = _uiState.value.selectedClub ?: return@launch
            val userId = authRepository.currentUserId ?: return@launch
            if (!_uiState.value.userRole.canLeaveClub) {
                _uiState.value = _uiState.value.copy(
                    error = "Transfer ownership before leaving as founder"
                )
                return@launch
            }
            runCatching { clubRepository.leaveClub(club.id, userId) }
                .onSuccess {
                    clearSelectedClub()
                    refresh()
                }
                .onFailure { _uiState.value = _uiState.value.copy(error = it.message) }
        }
    }

    fun loadMembers() {
        viewModelScope.launch {
            val clubId = _uiState.value.selectedClub?.id ?: return@launch
            val members = runCatching { clubRepository.loadClubMembers(clubId) }.getOrDefault(emptyList())
            _uiState.value = _uiState.value.copy(members = members)
        }
    }

    fun promoteMember(userId: String) {
        viewModelScope.launch {
            val clubId = _uiState.value.selectedClub?.id ?: return@launch
            runCatching { clubRepository.promoteToLeader(clubId, userId) }
                .onSuccess { loadMembers() }
                .onFailure { _uiState.value = _uiState.value.copy(error = it.message) }
        }
    }

    fun demoteMember(userId: String) {
        viewModelScope.launch {
            val clubId = _uiState.value.selectedClub?.id ?: return@launch
            runCatching { clubRepository.demoteToMember(clubId, userId) }
                .onSuccess { loadMembers() }
                .onFailure { _uiState.value = _uiState.value.copy(error = it.message) }
        }
    }

    fun removeMember(userId: String) {
        viewModelScope.launch {
            val clubId = _uiState.value.selectedClub?.id ?: return@launch
            runCatching { clubRepository.removeMember(clubId, userId) }
                .onSuccess {
                    loadMembers()
                    refreshSelectedClub()
                }
                .onFailure { _uiState.value = _uiState.value.copy(error = it.message) }
        }
    }

    fun saveClubSettings(
        name: String,
        description: String,
        isPrivate: Boolean,
        zipcode: String?
    ) {
        viewModelScope.launch {
            val club = _uiState.value.selectedClub ?: return@launch
            if (!_uiState.value.userRole.canEditClubDetails) return@launch
            _uiState.value = _uiState.value.copy(isSaving = true, error = null)
            runCatching {
                clubRepository.updateClub(
                    clubId = club.id,
                    name = name.trim(),
                    description = description.trim(),
                    isPrivate = isPrivate,
                    zipcode = zipcode?.trim()?.takeIf { it.isNotEmpty() }
                )
            }.onSuccess { updated ->
                _uiState.value = _uiState.value.copy(
                    selectedClub = updated,
                    isSaving = false,
                    successMessage = "Club updated",
                    overlay = ClubOverlay.None
                )
                refresh()
            }.onFailure {
                _uiState.value = _uiState.value.copy(isSaving = false, error = it.message)
            }
        }
    }

    fun regenerateJoinCode() {
        viewModelScope.launch {
            val club = _uiState.value.selectedClub ?: return@launch
            if (!_uiState.value.userRole.canRegenerateJoinCode) return@launch
            runCatching { clubRepository.regenerateJoinCode(club.id, club.name) }
                .onSuccess { code ->
                    val refreshed = clubRepository.getClub(club.id) ?: club.copy(joinCode = code)
                    _uiState.value = _uiState.value.copy(
                        selectedClub = refreshed,
                        successMessage = "New join code: $code"
                    )
                    refresh()
                }
                .onFailure { _uiState.value = _uiState.value.copy(error = it.message) }
        }
    }

    fun transferOwnership(newFounderId: String) {
        viewModelScope.launch {
            val club = _uiState.value.selectedClub ?: return@launch
            val userId = authRepository.currentUserId ?: return@launch
            if (!_uiState.value.userRole.canTransferOwnership) return@launch
            runCatching {
                clubRepository.transferFoundership(club.id, userId, newFounderId)
            }.onSuccess {
                _uiState.value = _uiState.value.copy(
                    overlay = ClubOverlay.None,
                    successMessage = "Ownership transferred"
                )
                openClubData(club, userId)
                refresh()
            }.onFailure { _uiState.value = _uiState.value.copy(error = it.message) }
        }
    }

    fun deleteClub() {
        viewModelScope.launch {
            val club = _uiState.value.selectedClub ?: return@launch
            if (!_uiState.value.userRole.canDeleteClub) return@launch
            _uiState.value = _uiState.value.copy(isSaving = true, error = null)
            runCatching { clubRepository.deleteClub(club.id) }
                .onSuccess {
                    clearSelectedClub()
                    _uiState.value = _uiState.value.copy(isSaving = false)
                    refresh()
                }
                .onFailure {
                    _uiState.value = _uiState.value.copy(isSaving = false, error = it.message)
                }
        }
    }

    fun createEvent(
        title: String,
        description: String?,
        startTimeIso: String,
        address: String?
    ) {
        viewModelScope.launch {
            val club = _uiState.value.selectedClub ?: return@launch
            val userId = authRepository.currentUserId ?: return@launch
            if (!_uiState.value.userRole.canCreateEvents) return@launch
            _uiState.value = _uiState.value.copy(isSaving = true, error = null)
            runCatching {
                eventRepository.createEvent(
                    clubId = club.id,
                    createdBy = userId,
                    title = title.trim(),
                    description = description?.trim()?.takeIf { it.isNotEmpty() },
                    startTime = startTimeIso,
                    lat = null,
                    lon = null,
                    address = address?.trim()?.takeIf { it.isNotEmpty() }
                )
            }.onSuccess { event ->
                loadEvents()
                _uiState.value = _uiState.value.copy(
                    isSaving = false,
                    overlay = ClubOverlay.EventDetail,
                    selectedEvent = event
                )
                loadEventDetail(event.id)
            }.onFailure {
                _uiState.value = _uiState.value.copy(isSaving = false, error = it.message)
            }
        }
    }

    fun openEvent(event: ClubEvent) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                overlay = ClubOverlay.EventDetail,
                selectedEvent = event,
                error = null
            )
            loadEventDetail(event.id)
        }
    }

    fun rsvpToEvent(status: String, declaredWeight: Int?) {
        viewModelScope.launch {
            val event = _uiState.value.selectedEvent ?: return@launch
            val userId = authRepository.currentUserId ?: return@launch
            runCatching {
                eventRepository.rsvpToEvent(event.id, userId, status, declaredWeight)
                if (status == "going") {
                    notificationService.scheduleEventReminder(
                        event.id,
                        event.title,
                        System.currentTimeMillis() + 3_600_000
                    )
                }
            }.onSuccess {
                loadEventDetail(event.id)
            }.onFailure { _uiState.value = _uiState.value.copy(error = it.message) }
        }
    }

    fun postEventComment(content: String) {
        viewModelScope.launch {
            val event = _uiState.value.selectedEvent ?: return@launch
            val club = _uiState.value.selectedClub ?: return@launch
            val userId = authRepository.currentUserId ?: return@launch
            val trimmed = content.trim()
            if (trimmed.isEmpty()) return@launch
            runCatching {
                feedRepository.postEventComment(event.id, club.id, userId, trimmed)
            }.onSuccess { loadEventDetail(event.id) }
                .onFailure { _uiState.value = _uiState.value.copy(error = it.message) }
        }
    }

    fun deleteEvent() {
        viewModelScope.launch {
            val event = _uiState.value.selectedEvent ?: return@launch
            if (!_uiState.value.userRole.canCreateEvents) return@launch
            runCatching { eventRepository.deleteEvent(event.id) }
                .onSuccess {
                    loadEvents()
                    dismissOverlay()
                }
                .onFailure { _uiState.value = _uiState.value.copy(error = it.message) }
        }
    }

    fun clearMessages() {
        _uiState.value = _uiState.value.copy(error = null, successMessage = null)
    }

    fun reportError(message: String) {
        _uiState.value = _uiState.value.copy(error = message)
    }

    fun promptSignIn() {}

    private suspend fun openClubData(club: Club, userId: String) {
        val role = ClubRole.from(
            runCatching { clubRepository.getUserRole(club.id, userId) }.getOrNull()
        )
        _uiState.value = _uiState.value.copy(userRole = role, currentUserId = userId)
        loadFeed(club.id)
        loadLeaderboard(club.id)
        loadEvents()
    }

    private suspend fun refreshSelectedClub() {
        val clubId = _uiState.value.selectedClub?.id ?: return
        val club = runCatching { clubRepository.getClub(clubId) }.getOrNull() ?: return
        _uiState.value = _uiState.value.copy(selectedClub = club)
    }

    private suspend fun loadFeed(clubId: String) {
        val posts = runCatching { feedRepository.loadClubFeed(clubId) }.getOrDefault(emptyList())
        _uiState.value = _uiState.value.copy(feedPosts = posts)
    }

    private suspend fun loadLeaderboard(clubId: String) {
        val board = runCatching { leaderboardRepository.loadWeeklyLeaderboard(clubId) }.getOrDefault(emptyList())
        _uiState.value = _uiState.value.copy(leaderboard = board)
    }

    private suspend fun loadEvents() {
        val clubId = _uiState.value.selectedClub?.id ?: return
        val events = runCatching { eventRepository.loadClubEvents(clubId) }.getOrDefault(emptyList())
        _uiState.value = _uiState.value.copy(events = events)
    }

    private suspend fun loadEventDetail(eventId: String) {
        val rsvps = runCatching { eventRepository.loadEventRsvps(eventId) }.getOrDefault(emptyList())
        val comments = runCatching { feedRepository.loadEventComments(eventId) }.getOrDefault(emptyList())
        _uiState.value = _uiState.value.copy(eventRsvps = rsvps, eventComments = comments)
    }
}
