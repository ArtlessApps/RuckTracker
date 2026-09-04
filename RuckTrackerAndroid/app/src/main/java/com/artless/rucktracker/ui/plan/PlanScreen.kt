package com.artless.rucktracker.ui.plan

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artless.rucktracker.domain.MarchPlanGenerator
import com.artless.rucktracker.domain.PlanSession
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchDivider
import com.artless.rucktracker.ui.components.MarchEmptyState
import com.artless.rucktracker.ui.components.MarchScreen
import com.artless.rucktracker.ui.components.MarchScreenHeader
import com.artless.rucktracker.ui.components.MetricBlock
import com.artless.rucktracker.ui.components.SectionHeader
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import com.artless.rucktracker.ui.theme.MarchType
import java.util.Locale

@Composable
fun PlanScreen(modifier: Modifier = Modifier, viewModel: PlanViewModel = hiltViewModel()) {
    val sessions by viewModel.sessions.collectAsStateWithLifecycle()
    val goal by viewModel.goal.collectAsStateWithLifecycle()

    MarchScreen(modifier = modifier) {
        MarchScreenHeader(
            eyebrow = "This week",
            title = "My Plan",
            subtitle = goal.ifBlank { "Build your base" }
        )

        Spacer(Modifier.height(20.dp))

        if (sessions.isEmpty()) {
            MarchEmptyState(
                icon = Icons.Filled.CalendarMonth,
                title = "No plan yet",
                message = "Finish onboarding and MARCH will build a week-by-week schedule around your goal.",
                accent = MarchColors.TileBlue
            )
            return@MarchScreen
        }

        WeekSummaryCard(sessions)

        Spacer(Modifier.height(MarchDimens.SectionGap))

        SectionHeader("Sessions")
        Spacer(Modifier.height(12.dp))

        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(MarchDimens.CardGap),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                bottom = MarchDimens.TabBarClearance
            )
        ) {
            items(sessions) { session ->
                PlanSessionCard(session)
            }
        }
    }
}

@Composable
private fun WeekSummaryCard(sessions: List<PlanSession>) {
    val totalDistance = sessions.sumOf { it.distanceMiles }
    val averageLoad = sessions.map { it.ruckWeightLbs }.average()

    MarchCard(contentPadding = 20.dp) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            MetricBlock(
                label = "Sessions",
                value = sessions.size.toString(),
                accent = MarchColors.Primary,
                horizontalAlignment = Alignment.Start
            )
            MetricBlock(
                label = "Distance",
                value = String.format(Locale.US, "%.1f", totalDistance),
                unit = "mi",
                horizontalAlignment = Alignment.Start
            )
            MetricBlock(
                label = "Avg load",
                value = averageLoad.toInt().toString(),
                unit = "lb",
                horizontalAlignment = Alignment.Start
            )
        }
        Spacer(Modifier.height(16.dp))
        MarchDivider()
        Spacer(Modifier.height(14.dp))
        Text(
            text = "Stay consistent. Every session compounds.",
            style = MaterialTheme.typography.bodySmall,
            color = MarchColors.TextSecondary
        )
    }
}

@Composable
private fun PlanSessionCard(session: PlanSession) {
    MarchCard {
        Row(verticalAlignment = Alignment.Top) {
            DayBadge(session.dayOfWeek)
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = session.title,
                    style = MaterialTheme.typography.titleMedium,
                    color = MarchColors.TextPrimary
                )
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StatChip(String.format(Locale.US, "%.1f mi", session.distanceMiles))
                    StatChip("${session.ruckWeightLbs.toInt()} lb")
                }
                if (session.description.isNotBlank()) {
                    Spacer(Modifier.height(10.dp))
                    Text(
                        text = session.description,
                        style = MaterialTheme.typography.bodySmall,
                        color = MarchColors.TextSecondary
                    )
                }
            }
        }
    }
}

@Composable
private fun DayBadge(dayOfWeek: Int) {
    val shape = RoundedCornerShape(12.dp)
    Box(
        modifier = Modifier
            .size(48.dp)
            .clip(shape)
            .background(MarchColors.Primary.copy(alpha = 0.14f)),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = MarchPlanGenerator.dayName(dayOfWeek).take(3).uppercase(),
            style = MarchType.Eyebrow,
            color = MarchColors.Primary,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun StatChip(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelMedium,
        color = MarchColors.TextSecondary,
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(MarchColors.Background.copy(alpha = 0.45f))
            .padding(horizontal = 9.dp, vertical = 5.dp)
    )
}
