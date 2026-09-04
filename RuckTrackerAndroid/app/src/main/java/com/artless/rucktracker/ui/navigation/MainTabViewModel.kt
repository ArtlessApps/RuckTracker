package com.artless.rucktracker.ui.navigation

import androidx.lifecycle.ViewModel
import com.artless.rucktracker.data.model.MainTab
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

@HiltViewModel
class MainTabViewModel @Inject constructor() : ViewModel() {
    private val _selectedTab = MutableStateFlow(MainTab.RUCK)
    val selectedTab: StateFlow<MainTab> = _selectedTab.asStateFlow()

    fun selectTab(tab: MainTab) {
        _selectedTab.value = tab
    }
}
