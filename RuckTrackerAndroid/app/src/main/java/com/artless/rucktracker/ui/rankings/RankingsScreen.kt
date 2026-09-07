package com.artless.rucktracker.ui.rankings

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artless.rucktracker.data.model.GlobalLeaderboardEntry
import com.artless.rucktracker.data.model.GlobalLeaderboardType
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchChip
import com.artless.rucktracker.ui.components.MarchEmptyState
import com.artless.rucktracker.ui.components.MarchScreen
import com.artless.rucktracker.ui.components.MarchScreenHeader
import com.artless.rucktracker.ui.components.RankMedallion
import com.artless.rucktracker.ui.components.tabBarContentPadding
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import java.util.Locale

@Composable
fun RankingsScreen(modifier: Modifier = Modifier, viewModel: RankingsViewModel = hiltViewModel()) {
    val entries by viewModel.entries.collectAsStateWithLifecycle()
    val selectedType by viewModel.selectedType.collectAsStateWithLifecycle()

    MarchScreen(modifier = modifier) {
        MarchScreenHeader(
            eyebrow = "Global",
            title = selectedType.displayName,
            subtitle = selectedType.blurb
        )

        Spacer(Modifier.height(18.dp))

        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            GlobalLeaderboardType.entries.forEach { type ->
                MarchChip(
                    label = type.displayName,
                    selected = selectedType == type,
                    icon = type.icon,
                    onClick = { viewModel.selectType(type) }
                )
            }
        }

        Spacer(Modifier.height(18.dp))

        if (entries.isEmpty()) {
            MarchEmptyState(
                icon = Icons.Filled.EmojiEvents,
                title = "No rankings yet",
                message = "Log a ruck to claim your place on the board.",
                accent = MarchColors.RankGold,
                modifier = Modifier.weight(1f)
            )
            return@MarchScreen
        }

        LazyColumn(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = tabBarContentPadding()
        ) {
            itemsIndexed(entries) { index, entry ->
                LeaderRow(
                    entry = entry,
                    rank = if (entry.rank > 0) entry.rank else index + 1,
                    unit = selectedType.unit
                )
            }
        }
    }
}

@Composable
private fun LeaderRow(
    entry: GlobalLeaderboardEntry,
    rank: Int,
    unit: String
) {
    val podiumAccent = when (rank) {
        1 -> MarchColors.RankGold
        2 -> MarchColors.RankSilver
        3 -> MarchColors.RankBronze
        else -> null
    }
    MarchCard(
        contentPadding = 14.dp,
        borderColor = podiumAccent?.copy(alpha = 0.35f) ?: MarchColors.HairlineLight
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            RankMedallion(rank = rank, size = 42.dp)
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = entry.username ?: "Rucker",
                        style = MaterialTheme.typography.titleMedium,
                        color = MarchColors.TextPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    if (entry.isPremium) {
                        Spacer(Modifier.width(6.dp))
                        Icon(
                            imageVector = Icons.Filled.WorkspacePremium,
                            contentDescription = "Premium member",
                            tint = MarchColors.RankGold,
                            modifier = Modifier.size(15.dp)
                        )
                    }
                }
                if (podiumAccent != null) {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = when (rank) {
                            1 -> "Leading the pack"
                            2 -> "Runner-up"
                            else -> "Third place"
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = podiumAccent
                    )
                }
            }
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = String.format(Locale.US, "%.1f", entry.score),
                    style = MaterialTheme.typography.headlineSmall,
                    color = MarchColors.Primary
                )
                Spacer(Modifier.width(3.dp))
                Text(
                    text = unit,
                    style = MaterialTheme.typography.labelMedium,
                    color = MarchColors.TextSecondary,
                    modifier = Modifier.padding(bottom = 3.dp)
                )
            }
        }
    }
}

private val GlobalLeaderboardType.icon: ImageVector
    get() = when (this) {
        GlobalLeaderboardType.DISTANCE -> Icons.Filled.LocationOn
        GlobalLeaderboardType.TONNAGE -> Icons.Filled.Terrain
        GlobalLeaderboardType.ELEVATION -> Icons.Filled.Terrain
        GlobalLeaderboardType.CONSISTENCY -> Icons.Filled.LocalFireDepartment
    }

private val GlobalLeaderboardType.unit: String
    get() = when (this) {
        GlobalLeaderboardType.DISTANCE -> "mi"
        GlobalLeaderboardType.TONNAGE -> "t·mi"
        GlobalLeaderboardType.ELEVATION -> "ft"
        GlobalLeaderboardType.CONSISTENCY -> "days"
    }

private val GlobalLeaderboardType.blurb: String
    get() = when (this) {
        GlobalLeaderboardType.DISTANCE -> "Most miles under load this week"
        GlobalLeaderboardType.TONNAGE -> "Most weight moved, all time"
        GlobalLeaderboardType.ELEVATION -> "Most vertical gain this month"
        GlobalLeaderboardType.CONSISTENCY -> "Longest unbroken streaks"
    }
