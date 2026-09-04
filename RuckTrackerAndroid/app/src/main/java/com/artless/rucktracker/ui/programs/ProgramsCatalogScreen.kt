package com.artless.rucktracker.ui.programs

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.TabRowDefaults
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
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
import com.artless.rucktracker.ui.components.MarchBackground
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchIconButton
import com.artless.rucktracker.ui.components.MarchScreenHeader
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens

@Composable
fun ProgramsCatalogScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: ProgramsViewModel = hiltViewModel()
) {
    val programs by viewModel.programs.collectAsStateWithLifecycle()
    val challenges by viewModel.challenges.collectAsStateWithLifecycle()
    var tab by remember { mutableIntStateOf(0) }

    MarchBackground(modifier = modifier) {
        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(horizontal = MarchDimens.ScreenPadding)
                .padding(top = 12.dp, bottom = 24.dp)
        ) {
            MarchIconButton(
                icon = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                onClick = onBack,
                contentDescription = "Back"
            )

            Spacer(Modifier.height(20.dp))

            MarchScreenHeader(
                eyebrow = "Catalog",
                title = "Training",
                subtitle = "Programs and challenges to structure your rucks."
            )

            Spacer(Modifier.height(20.dp))

            TabRow(
                selectedTabIndex = tab,
                containerColor = MarchColors.Surface,
                contentColor = MarchColors.Primary,
                indicator = { tabPositions ->
                    TabRowDefaults.SecondaryIndicator(
                        modifier = Modifier.tabIndicatorOffset(tabPositions[tab]),
                        color = MarchColors.Primary
                    )
                }
            ) {
                Tab(
                    selected = tab == 0,
                    onClick = { tab = 0 },
                    text = { Text("Programs") },
                    selectedContentColor = MarchColors.Primary,
                    unselectedContentColor = MarchColors.TextSecondary
                )
                Tab(
                    selected = tab == 1,
                    onClick = { tab = 1 },
                    text = { Text("Challenges") },
                    selectedContentColor = MarchColors.Primary,
                    unselectedContentColor = MarchColors.TextSecondary
                )
            }

            Spacer(Modifier.height(16.dp))

            when (tab) {
                0 -> ProgramList(programs)
                1 -> ChallengeList(challenges)
            }
        }
    }
}

@Composable
private fun ProgramList(programs: List<ProgramJson>) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(MarchDimens.CardGap)) {
        items(programs, key = { it.id }) { program ->
            MarchCard {
                Text(program.name, color = MarchColors.Primary, style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(4.dp))
                Text(program.description, color = MarchColors.TextSecondary, style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.height(8.dp))
                Text(
                    "${program.durationWeeks} weeks · ${program.difficulty}",
                    color = MarchColors.TextSecondary,
                    style = MaterialTheme.typography.labelSmall
                )
            }
        }
    }
}

@Composable
private fun ChallengeList(challenges: List<ChallengeJson>) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(MarchDimens.CardGap)) {
        items(challenges, key = { it.id }) { challenge ->
            MarchCard {
                Text(challenge.name, color = MarchColors.Primary, style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(4.dp))
                Text(challenge.description, color = MarchColors.TextSecondary, style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.height(8.dp))
                Text(
                    "${challenge.durationDays} days · ${challenge.focusArea}",
                    color = MarchColors.TextSecondary,
                    style = MaterialTheme.typography.labelSmall
                )
            }
        }
    }
}
