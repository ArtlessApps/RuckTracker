package com.artless.rucktracker.domain

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DeepLinkManager @Inject constructor() {
    private val _pendingWorkoutId = MutableStateFlow<String?>(null)
    val pendingWorkoutId: StateFlow<String?> = _pendingWorkoutId.asStateFlow()

    fun handleDeepLink(uri: String) {
        when {
            uri.contains("workout/") -> {
                _pendingWorkoutId.value = uri.substringAfter("workout/")
            }
            uri.contains("share/") -> {
                _pendingWorkoutId.value = uri.substringAfter("share/")
            }
        }
    }

    fun clearPending() {
        _pendingWorkoutId.value = null
    }
}

@Singleton
class ReviewManager @Inject constructor() {
    private val reviewMilestones = setOf(1, 5, 20)

    fun shouldShowReviewPrompt(workoutCount: Int): Boolean =
        workoutCount in reviewMilestones
}
