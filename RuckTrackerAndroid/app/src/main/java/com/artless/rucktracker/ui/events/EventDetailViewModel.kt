package com.artless.rucktracker.ui.events

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.model.EventRsvp
import com.artless.rucktracker.data.remote.AuthRepository
import com.artless.rucktracker.data.remote.EventRepository
import com.artless.rucktracker.service.EventNotificationService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class EventDetailViewModel @Inject constructor(
    private val eventRepository: EventRepository,
    private val authRepository: AuthRepository,
    private val notificationService: EventNotificationService,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val eventId: String = savedStateHandle.get<String>("eventId") ?: ""

    private val _rsvps = MutableStateFlow<List<EventRsvp>>(emptyList())
    val rsvps: StateFlow<List<EventRsvp>> = _rsvps.asStateFlow()

    init {
        if (eventId.isNotEmpty()) loadRsvps()
    }

    fun loadRsvps() {
        viewModelScope.launch {
            _rsvps.value = runCatching { eventRepository.loadEventRsvps(eventId) }.getOrDefault(emptyList())
        }
    }

    fun rsvp(eventId: String, status: String, declaredWeight: Int?) {
        viewModelScope.launch {
            val userId = authRepository.currentUserId ?: return@launch
            eventRepository.rsvpToEvent(eventId, userId, status, declaredWeight)
            if (status == "going") {
                notificationService.scheduleEventReminder(eventId, "Upcoming ruck event", System.currentTimeMillis() + 3600000)
            }
            loadRsvps()
        }
    }
}
