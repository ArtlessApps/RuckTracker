package com.artless.rucktracker.ui.programs

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.WorkspacePremium
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artless.rucktracker.data.model.ChallengeJson
import com.artless.rucktracker.data.model.ProgramJson
import com.artless.rucktracker.ui.components.MarchBackground
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchIconButton
import com.artless.rucktracker.ui.components.MarchPill
import com.artless.rucktracker.ui.components.MarchPrimaryButton
import com.artless.rucktracker.ui.components.MarchScreenHeader
import com.artless.rucktracker.ui.components.StatusBadge
import com.artless.rucktracker.ui.premium.PaywallScreen
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import java.util.Locale

@Composable
fun ProgramsCatalogScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: ProgramsViewModel = hiltViewModel()
) {
    val programs by viewModel.programs.collectAsStateWithLifecycle()
    val challenges by viewModel.challenges.collectAsStateWithLifecycle()
    val isPremium by viewModel.isPremium.collectAsStateWithLifecycle()
    val showPaywall by viewModel.showPaywall.collectAsStateWithLifecycle()
    val selectedDetail by viewModel.selectedDetail.collectAsStateWithLifecycle()
    val enrolledProgramId by viewModel.enrolledProgramId.collectAsStateWithLifecycle()
    val enrolledChallengeId by viewModel.enrolledChallengeId.collectAsStateWithLifecycle()
    var tab by remember { mutableIntStateOf(0) }

    Box(modifier = modifier.fillMaxSize()) {
        MarchBackground {
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
                    subtitle = "Programs and challenges to structure your rucks.",
                    trailing = {
                        if (!isPremium) {
                            MarchPill(
                                text = "PRO",
                                accent = MarchColors.AccentWarm,
                                icon = Icons.Filled.WorkspacePremium
                            )
                        }
                    }
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
                    0 -> ProgramList(
                        programs = programs,
                        showProBadge = !isPremium,
                        enrolledProgramId = enrolledProgramId,
                        onProgramClick = viewModel::onProgramTap
                    )
                    1 -> ChallengeList(
                        challenges = challenges,
                        showProBadge = !isPremium,
                        enrolledChallengeId = enrolledChallengeId,
                        onChallengeClick = viewModel::onChallengeTap
                    )
                }
            }
        }

        when (val detail = selectedDetail) {
            is CatalogDetail.Program -> ProgramDetailScreen(
                program = detail.program,
                isEnrolled = detail.program.id == enrolledProgramId,
                onEnroll = { viewModel.enrollInProgram(detail.program) },
                onDismiss = viewModel::dismissDetail
            )
            is CatalogDetail.Challenge -> ChallengeDetailScreen(
                challenge = detail.challenge,
                isEnrolled = detail.challenge.id == enrolledChallengeId,
                onEnroll = { viewModel.enrollInChallenge(detail.challenge) },
                onDismiss = viewModel::dismissDetail
            )
            null -> Unit
        }

        if (showPaywall) {
            PaywallScreen(
                onDismiss = viewModel::dismissPaywall,
                onPurchased = viewModel::onPurchased
            )
        }
    }
}

@Composable
private fun ProgramList(
    programs: List<ProgramJson>,
    showProBadge: Boolean,
    enrolledProgramId: String?,
    onProgramClick: (ProgramJson) -> Unit
) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(MarchDimens.CardGap)) {
        items(programs, key = { it.id }) { program ->
            CatalogItemCard(
                title = program.name,
                description = program.description,
                meta = "${program.durationWeeks} weeks · ${program.difficulty.replaceFirstChar {
                    if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString()
                }}",
                showProBadge = showProBadge,
                isEnrolled = program.id == enrolledProgramId,
                onClick = { onProgramClick(program) }
            )
        }
    }
}

@Composable
private fun ChallengeList(
    challenges: List<ChallengeJson>,
    showProBadge: Boolean,
    enrolledChallengeId: String?,
    onChallengeClick: (ChallengeJson) -> Unit
) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(MarchDimens.CardGap)) {
        items(challenges, key = { it.id }) { challenge ->
            CatalogItemCard(
                title = challenge.name,
                description = challenge.description,
                meta = "${challenge.durationDays} days · ${challenge.focusArea.replaceFirstChar {
                    if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString()
                }}",
                showProBadge = showProBadge,
                isEnrolled = challenge.id == enrolledChallengeId,
                onClick = { onChallengeClick(challenge) }
            )
        }
    }
}

@Composable
private fun CatalogItemCard(
    title: String,
    description: String,
    meta: String,
    showProBadge: Boolean,
    isEnrolled: Boolean,
    onClick: () -> Unit
) {
    MarchCard(onClick = onClick) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top
        ) {
            Text(
                text = title,
                color = MarchColors.Primary,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.weight(1f)
            )
            when {
                isEnrolled -> StatusBadge(text = "Active", accent = MarchColors.Primary)
                showProBadge -> MarchPill(
                    text = "PRO",
                    accent = MarchColors.AccentWarm,
                    icon = Icons.Filled.WorkspacePremium
                )
            }
        }
        Spacer(Modifier.height(4.dp))
        Text(description, color = MarchColors.TextSecondary, style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(8.dp))
        Text(meta, color = MarchColors.TextSecondary, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun ProgramDetailScreen(
    program: ProgramJson,
    isEnrolled: Boolean,
    onEnroll: () -> Unit,
    onDismiss: () -> Unit
) {
    CatalogDetailScaffold(
        title = program.name,
        description = program.description,
        overviewRows = listOf(
            "Duration" to if (program.durationWeeks > 0) "${program.durationWeeks} weeks" else "Ongoing",
            "Difficulty" to program.difficulty.replaceFirstChar {
                if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString()
            },
            "Category" to (program.category ?: "Fitness").replaceFirstChar {
                if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString()
            }
        ),
        ctaLabel = if (isEnrolled) "Enrolled" else "Enroll in Program",
        ctaEnabled = !isEnrolled,
        onCta = onEnroll,
        onDismiss = onDismiss
    )
}

@Composable
private fun ChallengeDetailScreen(
    challenge: ChallengeJson,
    isEnrolled: Boolean,
    onEnroll: () -> Unit,
    onDismiss: () -> Unit
) {
    CatalogDetailScaffold(
        title = challenge.name,
        description = challenge.description,
        overviewRows = listOf(
            "Duration" to "${challenge.durationDays} days",
            "Focus" to challenge.focusArea.replaceFirstChar {
                if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString()
            }
        ),
        ctaLabel = if (isEnrolled) "Enrolled" else "Enroll in Challenge",
        ctaEnabled = !isEnrolled,
        onCta = onEnroll,
        onDismiss = onDismiss
    )
}

@Composable
private fun CatalogDetailScaffold(
    title: String,
    description: String,
    overviewRows: List<Pair<String, String>>,
    ctaLabel: String,
    ctaEnabled: Boolean,
    onCta: () -> Unit,
    onDismiss: () -> Unit
) {
    MarchBackground {
        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(horizontal = MarchDimens.ScreenPadding)
                .padding(top = 12.dp, bottom = 24.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                MarchIconButton(
                    icon = Icons.Filled.Close,
                    onClick = onDismiss,
                    contentDescription = "Close"
                )
            }

            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
            ) {
                Spacer(Modifier.height(8.dp))

                Text(
                    text = title,
                    color = MarchColors.TextPrimary,
                    style = MaterialTheme.typography.headlineLarge
                )
                Spacer(Modifier.height(12.dp))
                Text(
                    text = description,
                    color = MarchColors.TextSecondary,
                    style = MaterialTheme.typography.bodyLarge
                )

                Spacer(Modifier.height(28.dp))

                Text(
                    text = "Overview",
                    color = MarchColors.TextPrimary,
                    style = MaterialTheme.typography.titleLarge
                )
                Spacer(Modifier.height(12.dp))

                MarchCard(contentPadding = 0.dp) {
                    overviewRows.forEachIndexed { index, (label, value) ->
                        OverviewRow(label = label, value = value)
                        if (index < overviewRows.lastIndex) {
                            Box(
                                Modifier
                                    .fillMaxWidth()
                                    .height(1.dp)
                                    .background(MarchColors.HairlineLight)
                            )
                        }
                    }
                }

                Spacer(Modifier.height(24.dp))
            }

            MarchPrimaryButton(
                text = ctaLabel,
                onClick = onCta,
                enabled = ctaEnabled,
                icon = if (ctaEnabled) Icons.Filled.CheckCircle else null
            )
        }
    }
}

@Composable
private fun OverviewRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, color = MarchColors.TextSecondary, style = MaterialTheme.typography.bodyMedium)
        Text(value, color = MarchColors.TextPrimary, style = MaterialTheme.typography.titleSmall)
    }
}
