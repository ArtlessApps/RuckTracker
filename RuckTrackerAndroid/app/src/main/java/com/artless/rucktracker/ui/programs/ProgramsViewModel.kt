package com.artless.rucktracker.ui.programs

import androidx.lifecycle.ViewModel
import com.artless.rucktracker.data.model.ChallengeJson
import com.artless.rucktracker.data.model.ProgramJson
import com.artless.rucktracker.domain.ProgramCatalogService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

@HiltViewModel
class ProgramsViewModel @Inject constructor(
    catalogService: ProgramCatalogService
) : ViewModel() {
    private val _programs = MutableStateFlow(catalogService.loadPrograms())
    val programs: StateFlow<List<ProgramJson>> = _programs.asStateFlow()

    private val _challenges = MutableStateFlow(catalogService.loadChallenges())
    val challenges: StateFlow<List<ChallengeJson>> = _challenges.asStateFlow()
}
