package com.artless.rucktracker.ui.workout

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.artless.rucktracker.ui.components.CircleIcon
import com.artless.rucktracker.ui.components.MarchBackground
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchDivider
import com.artless.rucktracker.ui.components.MarchDetailRow
import com.artless.rucktracker.ui.components.MarchPrimaryButton
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import com.artless.rucktracker.ui.theme.MarchType
import java.util.Locale

@Composable
fun PostWorkoutSummaryScreen(viewModel: WorkoutViewModel, onDone: () -> Unit) {
    val completed by viewModel.completedWorkout.collectAsState()
    val workout = completed?.entity ?: return

    MarchBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MarchDimens.ScreenPadding)
                .padding(top = 40.dp, bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            CircleIcon(
                icon = Icons.Filled.Check,
                accent = MarchColors.Primary,
                size = 76.dp,
                iconSize = 36.dp
            )

            Spacer(Modifier.height(20.dp))

            Text(
                text = "RUCK COMPLETE",
                style = MarchType.Eyebrow,
                color = MarchColors.Primary
            )
            Spacer(Modifier.height(10.dp))
            Text(
                text = "Weight carried, ground covered.",
                style = MaterialTheme.typography.bodyLarge,
                color = MarchColors.TextSecondary,
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(36.dp))

            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = String.format(Locale.US, "%.2f", workout.distance),
                    style = MarchType.MetricHero,
                    color = MarchColors.TextPrimary
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = "mi",
                    style = MaterialTheme.typography.headlineSmall,
                    color = MarchColors.TextSecondary,
                    modifier = Modifier.padding(bottom = 14.dp)
                )
            }

            Spacer(Modifier.height(32.dp))

            MarchCard(contentPadding = 20.dp) {
                MarchDetailRow(
                    label = "Duration",
                    value = formatDuration(workout.duration),
                    icon = Icons.Filled.Timer
                )
                MarchDivider()
                MarchDetailRow(
                    label = "Average pace",
                    value = averagePace(workout.duration, workout.distance),
                    icon = Icons.Filled.Speed,
                    accent = MarchColors.TileBlue
                )
                MarchDivider()
                MarchDetailRow(
                    label = "Calories",
                    value = "${workout.calories.toInt()} cal",
                    icon = Icons.Filled.LocalFireDepartment,
                    accent = MarchColors.AccentWarm
                )
                MarchDivider()
                MarchDetailRow(
                    label = "Ruck load",
                    value = "${workout.ruckWeight.toInt()} lb",
                    icon = Icons.Filled.Terrain,
                    accent = MarchColors.TileGold
                )
                if (workout.elevationGain > 0) {
                    MarchDivider()
                    MarchDetailRow(
                        label = "Elevation gain",
                        value = "${workout.elevationGain.toInt()} ft",
                        icon = Icons.Filled.Terrain,
                        accent = MarchColors.TilePurple
                    )
                }
                if (workout.heartRate > 0) {
                    MarchDivider()
                    MarchDetailRow(
                        label = "Average heart rate",
                        value = "${workout.heartRate.toInt()} bpm",
                        icon = Icons.Filled.Favorite,
                        accent = MarchColors.DestructiveRed
                    )
                }
            }

            Spacer(Modifier.height(MarchDimens.SectionGap))

            MarchPrimaryButton(
                text = "Done",
                onClick = onDone,
                modifier = Modifier.navigationBarsPadding()
            )
        }
    }
}

private fun formatDuration(totalSeconds: Double): String {
    val seconds = totalSeconds.toInt()
    val hours = seconds / 3600
    val minutes = (seconds % 3600) / 60
    val remaining = seconds % 60
    return if (hours > 0) String.format(Locale.US, "%dh %02dm", hours, minutes)
    else String.format(Locale.US, "%dm %02ds", minutes, remaining)
}

private fun averagePace(totalSeconds: Double, distanceMiles: Double): String {
    if (distanceMiles <= 0.01) return "--:--"
    val paceMinutes = (totalSeconds / 60.0) / distanceMiles
    val minutes = paceMinutes.toInt()
    val seconds = ((paceMinutes - minutes) * 60).toInt()
    return String.format(Locale.US, "%d:%02d /mi", minutes, seconds)
}
