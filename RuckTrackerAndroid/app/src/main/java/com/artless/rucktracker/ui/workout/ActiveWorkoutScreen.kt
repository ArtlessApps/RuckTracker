package com.artless.rucktracker.ui.workout

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import com.artless.rucktracker.ui.components.MarchBackground
import com.artless.rucktracker.ui.components.StatTile
import com.artless.rucktracker.ui.components.marchPressable
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import com.artless.rucktracker.ui.theme.MarchType
import java.util.Locale

@Composable
fun ActiveWorkoutScreen(viewModel: WorkoutViewModel, onEnded: () -> Unit) {
    val state by viewModel.state.collectAsState()
    val paused = state.isPaused
    val accent by animateColorAsState(
        targetValue = if (paused) MarchColors.PauseOrange else MarchColors.Primary,
        label = "sessionAccent"
    )

    MarchBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(horizontal = MarchDimens.ScreenPadding)
                .padding(top = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            SessionStatus(paused = paused, accent = accent)

            Spacer(Modifier.weight(1f))

            Text(
                text = formatElapsed(state.elapsedSeconds),
                style = MarchType.MetricHero,
                color = MarchColors.TextPrimary
            )
            Text(
                text = if (paused) "PAUSED" else "ELAPSED",
                style = MarchType.Eyebrow,
                color = MarchColors.TextSecondary
            )

            Spacer(Modifier.height(28.dp))

            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = String.format(Locale.US, "%.2f", state.distanceMiles),
                    style = MarchType.MetricLarge,
                    color = accent
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    text = "mi",
                    style = MaterialTheme.typography.titleLarge,
                    color = MarchColors.TextSecondary,
                    modifier = Modifier.padding(bottom = 6.dp)
                )
            }

            Spacer(Modifier.weight(1f))

            Row(horizontalArrangement = Arrangement.spacedBy(MarchDimens.CardGap)) {
                StatTile(
                    label = "Pace",
                    value = pace(state),
                    unit = "/mi",
                    icon = Icons.Filled.Speed,
                    accent = MarchColors.TileBlue,
                    modifier = Modifier.weight(1f)
                )
                StatTile(
                    label = "Calories",
                    value = state.calories.toInt().toString(),
                    icon = Icons.Filled.LocalFireDepartment,
                    accent = MarchColors.AccentWarm,
                    modifier = Modifier.weight(1f)
                )
            }
            Spacer(Modifier.height(MarchDimens.CardGap))
            Row(horizontalArrangement = Arrangement.spacedBy(MarchDimens.CardGap)) {
                StatTile(
                    label = "Load",
                    value = state.ruckWeightLbs.toInt().toString(),
                    unit = "lb",
                    icon = Icons.Filled.Terrain,
                    accent = MarchColors.TileGold,
                    modifier = Modifier.weight(1f)
                )
                StatTile(
                    label = "Elevation",
                    value = state.elevationGain.toInt().toString(),
                    unit = "ft",
                    icon = Icons.Filled.Terrain,
                    accent = MarchColors.TilePurple,
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(Modifier.height(36.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(bottom = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(20.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                ControlButton(
                    icon = Icons.Filled.Stop,
                    label = "End",
                    accent = MarchColors.DestructiveRed,
                    onClick = {
                        viewModel.end()
                        onEnded()
                    },
                    modifier = Modifier.weight(1f)
                )
                ControlButton(
                    icon = if (paused) Icons.Filled.PlayArrow else Icons.Filled.Pause,
                    label = if (paused) "Resume" else "Pause",
                    accent = if (paused) MarchColors.SuccessGreen else MarchColors.PauseOrange,
                    onClick = { if (paused) viewModel.resume() else viewModel.pause() },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

/** Live status chip with a breathing dot, so the screen reads as "recording". */
@Composable
private fun SessionStatus(paused: Boolean, accent: Color) {
    val transition = rememberInfiniteTransition(label = "livePulse")
    val pulse by transition.animateFloat(
        initialValue = 0.35f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1100, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "livePulseAlpha"
    )

    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(accent.copy(alpha = 0.12f))
            .border(1.dp, accent.copy(alpha = 0.3f), CircleShape)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .graphicsLayer { alpha = if (paused) 1f else pulse }
                .clip(CircleShape)
                .background(accent)
        )
        Spacer(Modifier.width(9.dp))
        Text(
            text = if (paused) "SESSION PAUSED" else "RUCK IN PROGRESS",
            style = MarchType.Eyebrow,
            color = accent
        )
    }
}

@Composable
private fun ControlButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    accent: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .marchPressable(onClick = onClick, pressedScale = 0.92f)
                .clip(CircleShape)
                .background(accent.copy(alpha = 0.16f))
                .border(1.5.dp, accent.copy(alpha = 0.5f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = accent,
                modifier = Modifier.size(30.dp)
            )
        }
        Spacer(Modifier.height(10.dp))
        Text(
            text = label.uppercase(),
            style = MarchType.Eyebrow,
            color = MarchColors.TextSecondary
        )
    }
}

private fun formatElapsed(totalSeconds: Int): String {
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return if (hours > 0) String.format(Locale.US, "%d:%02d:%02d", hours, minutes, seconds)
    else String.format(Locale.US, "%d:%02d", minutes, seconds)
}

private fun pace(state: ActiveWorkoutState): String {
    if (state.distanceMiles <= 0.01) return "--:--"
    val paceMinutesPerMile = (state.elapsedSeconds / 60.0) / state.distanceMiles
    val minutes = paceMinutesPerMile.toInt()
    val seconds = ((paceMinutesPerMile - minutes) * 60).toInt()
    return String.format(Locale.US, "%d:%02d", minutes, seconds)
}
