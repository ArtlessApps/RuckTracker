package com.artless.rucktracker.ui.programs

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artless.rucktracker.data.model.ChallengeJson
import com.artless.rucktracker.data.model.ProgramJson
import com.artless.rucktracker.ui.theme.MarchColors

@Composable
fun ProgramsCatalogScreen(modifier: Modifier = Modifier, viewModel: ProgramsViewModel = hiltViewModel()) {
    val programs by viewModel.programs.collectAsStateWithLifecycle()
    val challenges by viewModel.challenges.collectAsStateWithLifecycle()
    var tab by remember { mutableIntStateOf(0) }

    Column(modifier.fillMaxSize().background(MarchColors.BackgroundGradient).padding(16.dp)) {
        Text("Training", style = MaterialTheme.typography.headlineMedium, color = MarchColors.TextPrimary)
        TabRow(selectedTabIndex = tab) {
            Tab(tab == 0, { tab = 0 }, text = { Text("Programs") })
            Tab(tab == 1, { tab = 1 }, text = { Text("Challenges") })
        }
        Spacer(Modifier.height(8.dp))
        when (tab) {
            0 -> ProgramList(programs)
            1 -> ChallengeList(challenges)
        }
    }
}

@Composable
private fun ProgramList(programs: List<ProgramJson>) {
    LazyColumn {
        items(programs) { program ->
            Card(Modifier.fillMaxWidth().padding(vertical = 4.dp), colors = CardDefaults.cardColors(containerColor = MarchColors.Surface)) {
                Column(Modifier.padding(16.dp)) {
                    Text(program.name, color = MarchColors.Primary, style = MaterialTheme.typography.titleMedium)
                    Text(program.description, color = MarchColors.TextSecondary, modifier = Modifier.padding(top = 4.dp))
                    Text("${program.durationWeeks} weeks · ${program.difficulty}", color = MarchColors.TextSecondary, style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

@Composable
private fun ChallengeList(challenges: List<ChallengeJson>) {
    LazyColumn {
        items(challenges) { challenge ->
            Card(Modifier.fillMaxWidth().padding(vertical = 4.dp), colors = CardDefaults.cardColors(containerColor = MarchColors.Surface)) {
                Column(Modifier.padding(16.dp)) {
                    Text(challenge.name, color = MarchColors.Primary, style = MaterialTheme.typography.titleMedium)
                    Text(challenge.description, color = MarchColors.TextSecondary, modifier = Modifier.padding(top = 4.dp))
                    Text("${challenge.durationDays} days · ${challenge.focusArea}", color = MarchColors.TextSecondary, style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}
