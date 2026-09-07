package com.artless.rucktracker.ui.you

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artless.rucktracker.data.local.WorkoutEntity
import com.artless.rucktracker.data.settings.UserSettingsState
import com.artless.rucktracker.ui.components.CircleIcon
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchDetailRow
import com.artless.rucktracker.ui.components.MarchDivider
import com.artless.rucktracker.ui.components.MarchEmptyState
import com.artless.rucktracker.ui.components.MarchGhostButton
import com.artless.rucktracker.ui.components.MarchIconButton
import com.artless.rucktracker.ui.components.MarchScreen
import com.artless.rucktracker.ui.components.MarchScreenHeader
import com.artless.rucktracker.ui.components.MarchSecondaryButton
import com.artless.rucktracker.ui.components.MarchSegmentedControl
import com.artless.rucktracker.ui.components.StatTile
import com.artless.rucktracker.ui.components.tabBarBottomInset
import com.artless.rucktracker.ui.components.tabBarContentPadding
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun YouScreen(modifier: Modifier = Modifier, viewModel: YouViewModel = hiltViewModel()) {
    val stats by viewModel.stats.collectAsStateWithLifecycle()
    val workouts by viewModel.workouts.collectAsStateWithLifecycle()
    val settings by viewModel.settings.collectAsStateWithLifecycle()
    var selectedSection by remember { mutableIntStateOf(0) }
    val context = LocalContext.current

    MarchScreen(modifier = modifier) {
        MarchScreenHeader(
            eyebrow = "Profile",
            title = settings.username ?: "You",
            subtitle = settings.email
        )

        Spacer(Modifier.height(20.dp))

        Row(horizontalArrangement = Arrangement.spacedBy(MarchDimens.CardGap)) {
            StatTile(
                label = "Rucks",
                value = stats.totalWorkouts.toString(),
                icon = Icons.AutoMirrored.Filled.DirectionsWalk,
                accent = MarchColors.Primary,
                modifier = Modifier.weight(1f)
            )
            StatTile(
                label = "Distance",
                value = String.format(Locale.US, "%.1f", stats.totalDistance),
                unit = "mi",
                icon = Icons.Filled.LocationOn,
                accent = MarchColors.TileBlue,
                modifier = Modifier.weight(1f)
            )
        }
        Spacer(Modifier.height(MarchDimens.CardGap))
        Row(horizontalArrangement = Arrangement.spacedBy(MarchDimens.CardGap)) {
            StatTile(
                label = "Calories",
                value = stats.totalCalories.toInt().toString(),
                icon = Icons.Filled.LocalFireDepartment,
                accent = MarchColors.AccentWarm,
                modifier = Modifier.weight(1f)
            )
            StatTile(
                label = "Elevation",
                value = stats.totalElevation.toInt().toString(),
                unit = "ft",
                icon = Icons.Filled.Terrain,
                accent = MarchColors.TilePurple,
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(Modifier.height(MarchDimens.SectionGap))

        MarchSegmentedControl(
            options = listOf("History", "Settings"),
            selectedIndex = selectedSection,
            onSelect = { selectedSection = it }
        )

        Spacer(Modifier.height(16.dp))

        if (selectedSection == 0) {
            HistorySection(
                workouts = workouts,
                onShare = { viewModel.shareWorkout(context, it) },
                onDelete = viewModel::deleteWorkout,
                modifier = Modifier.weight(1f)
            )
        } else {
            SettingsSection(
                settings = settings,
                onExport = { viewModel.exportAndShare(context) },
                onSendFeedback = { viewModel.sendFeedback(context) },
                onSignOut = viewModel::signOut,
                onDeleteAccount = viewModel::deleteAccount,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun HistorySection(
    workouts: List<WorkoutEntity>,
    onShare: (WorkoutEntity) -> Unit,
    onDelete: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (workouts.isEmpty()) {
        MarchEmptyState(
            icon = Icons.AutoMirrored.Filled.DirectionsWalk,
            title = "No rucks logged",
            message = "Your completed rucks will show up here with distance, load and elevation.",
            modifier = modifier
        )
        return
    }

    LazyColumn(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = tabBarContentPadding()
    ) {
        items(workouts, key = { it.id }) { workout ->
            WorkoutRow(
                workout = workout,
                onShare = { onShare(workout) },
                onDelete = { onDelete(workout.id) }
            )
        }
    }
}

@Composable
private fun WorkoutRow(
    workout: WorkoutEntity,
    onShare: () -> Unit,
    onDelete: () -> Unit
) {
    val dateFormat = remember { SimpleDateFormat("MMM d, yyyy", Locale.US) }
    MarchCard(contentPadding = 14.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            CircleIcon(
                icon = Icons.AutoMirrored.Filled.DirectionsWalk,
                accent = MarchColors.Primary,
                size = 42.dp,
                iconSize = 20.dp
            )
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = String.format(Locale.US, "%.2f mi", workout.distance),
                    style = MaterialTheme.typography.titleMedium,
                    color = MarchColors.TextPrimary
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = buildString {
                        append(dateFormat.format(Date(workout.date)))
                        append(" · ")
                        append("${workout.calories.toInt()} cal")
                        if (workout.ruckWeight > 0) append(" · ${workout.ruckWeight.toInt()} lb")
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MarchColors.TextSecondary
                )
            }
            MarchIconButton(
                icon = Icons.Filled.Share,
                onClick = onShare,
                size = 36.dp,
                contentDescription = "Share ruck"
            )
            Spacer(Modifier.width(8.dp))
            MarchIconButton(
                icon = Icons.Filled.Delete,
                onClick = onDelete,
                accent = MarchColors.DestructiveRed,
                size = 36.dp,
                contentDescription = "Delete ruck"
            )
        }
    }
}

@Composable
private fun SettingsSection(
    settings: UserSettingsState,
    onExport: () -> Unit,
    onSendFeedback: () -> Unit,
    onSignOut: () -> Unit,
    onDeleteAccount: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier.verticalScroll(rememberScrollState())) {
        MarchCard(contentPadding = 18.dp) {
            MarchDetailRow(
                label = "Body weight",
                value = "${settings.bodyWeight.toInt()} lb",
                icon = Icons.AutoMirrored.Filled.DirectionsWalk
            )
            MarchDivider()
            MarchDetailRow(
                label = "Default ruck load",
                value = "${settings.defaultRuckWeight.toInt()} lb",
                icon = Icons.Filled.Terrain,
                accent = MarchColors.AccentWarm
            )
            MarchDivider()
            MarchDetailRow(
                label = "Goal",
                value = settings.ruckingGoal.displayName,
                icon = Icons.Filled.LocalFireDepartment,
                accent = MarchColors.TileGold
            )
        }

        Spacer(Modifier.height(MarchDimens.SectionGap))

        MarchSecondaryButton(
            text = "Export CSV",
            icon = Icons.Filled.Download,
            onClick = onExport
        )
        Spacer(Modifier.height(10.dp))
        MarchSecondaryButton(
            text = "Send Feedback",
            icon = Icons.Filled.Email,
            onClick = onSendFeedback
        )
        Spacer(Modifier.height(10.dp))
        MarchGhostButton(
            text = "Sign Out",
            icon = Icons.AutoMirrored.Filled.Logout,
            accent = MarchColors.TextSecondary,
            onClick = onSignOut
        )
        Spacer(Modifier.height(10.dp))
        MarchGhostButton(
            text = "Delete Account",
            accent = MarchColors.DestructiveRed,
            onClick = onDeleteAccount
        )
        Spacer(Modifier.height(tabBarBottomInset()))
    }
}
