package com.artless.rucktracker.ui.rankings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.artless.rucktracker.data.model.GlobalLeaderboardEntry
import com.artless.rucktracker.data.model.GlobalLeaderboardType
import com.artless.rucktracker.data.remote.LeaderboardRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class RankingsViewModel @Inject constructor(
    private val leaderboardRepository: LeaderboardRepository
) : ViewModel() {

    private val _selectedType = MutableStateFlow(GlobalLeaderboardType.DISTANCE)
    val selectedType: StateFlow<GlobalLeaderboardType> = _selectedType.asStateFlow()

    private val _entries = MutableStateFlow<List<GlobalLeaderboardEntry>>(emptyList())
    val entries: StateFlow<List<GlobalLeaderboardEntry>> = _entries.asStateFlow()

    init { refresh() }

    fun selectType(type: GlobalLeaderboardType) {
        _selectedType.value = type
        refresh()
    }

    /** Reload current board — call when Rankings tab becomes visible after a ruck. */
    fun refresh() {
        viewModelScope.launch {
            _entries.value = runCatching {
                leaderboardRepository.fetchGlobalLeaderboard(_selectedType.value)
            }.getOrDefault(emptyList())
        }
    }
}
