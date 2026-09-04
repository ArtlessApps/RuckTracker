package com.artless.rucktracker.ui.ruck

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.automirrored.filled.ListAlt
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artless.rucktracker.data.model.MainTab
import com.artless.rucktracker.ui.components.DashboardTile
import com.artless.rucktracker.ui.components.HeroRuckButton
import com.artless.rucktracker.ui.components.MarchGhostButton
import com.artless.rucktracker.ui.components.MarchPill
import com.artless.rucktracker.ui.components.MarchScreenHeader
import com.artless.rucktracker.ui.components.MarchScrollScreen
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens

@Composable
fun RuckTabScreen(
    modifier: Modifier = Modifier,
    onStartRuck: () -> Unit,
    onSelectTab: (MainTab) -> Unit = {},
    viewModel: RuckTabViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    MarchScrollScreen(modifier = modifier) {
        MarchScreenHeader(
            greeting = "Good ${state.timeOfDay}",
            title = state.displayName,
            trailing = {
                val streak = state.streak
                if (streak != null && streak > 0) {
                    MarchPill(
                        text = streak.toString(),
                        accent = MarchColors.AccentWarm,
                        icon = Icons.Filled.LocalFireDepartment
                    )
                }
            }
        )

        Spacer(Modifier.height(MarchDimens.SectionGap))

        HeroRuckButton(onClick = { viewModel.onStartRuck(onStartRuck) })

        Spacer(Modifier.height(MarchDimens.SectionGap))

        DashboardTile(
            title = "My Plan",
            subtitle = "View your schedule",
            icon = Icons.Filled.CalendarMonth,
            accent = MarchColors.TileBlue,
            onClick = { onSelectTab(MainTab.PLAN) }
        )
        Spacer(Modifier.height(MarchDimens.TileGap))
        DashboardTile(
            title = "My Tribe",
            subtitle = state.nextEvent ?: "Join a club",
            icon = Icons.Filled.Groups,
            accent = MarchColors.TileGold,
            onClick = { onSelectTab(MainTab.TRIBE) }
        )
        Spacer(Modifier.height(MarchDimens.TileGap))
        DashboardTile(
            title = "Programs",
            subtitle = "${state.programCount} available",
            icon = Icons.AutoMirrored.Filled.ListAlt,
            accent = MarchColors.AccentWarm,
            onClick = { onSelectTab(MainTab.PLAN) }
        )
        Spacer(Modifier.height(MarchDimens.TileGap))
        DashboardTile(
            title = "Leaderboard",
            subtitle = state.rankSummary ?: "View rankings",
            icon = Icons.Filled.BarChart,
            accent = MarchColors.TilePurple,
            onClick = { onSelectTab(MainTab.RANKINGS) }
        )

        Spacer(Modifier.height(MarchDimens.SectionGap))

        MarchGhostButton(
            text = "Workout History",
            icon = Icons.Filled.History,
            accent = MarchColors.TextSecondary,
            onClick = { onSelectTab(MainTab.YOU) }
        )

        Spacer(Modifier.height(8.dp))
    }
}
