package com.artless.rucktracker.ui.onboarding

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Stairs
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.artless.rucktracker.data.model.ExperienceLevel
import com.artless.rucktracker.data.model.RuckingGoal
import com.artless.rucktracker.ui.components.CircleIcon
import com.artless.rucktracker.ui.components.MarchBackground
import com.artless.rucktracker.ui.components.MarchCard
import com.artless.rucktracker.ui.components.MarchChevron
import com.artless.rucktracker.ui.components.MarchCompactButton
import com.artless.rucktracker.ui.components.MarchDayToggle
import com.artless.rucktracker.ui.components.MarchFieldLabel
import com.artless.rucktracker.ui.components.MarchGhostButton
import com.artless.rucktracker.ui.components.MarchPrimaryButton
import com.artless.rucktracker.ui.components.MarchProgressBar
import com.artless.rucktracker.ui.components.MarchSelectionRow
import com.artless.rucktracker.ui.components.MarchTextField
import com.artless.rucktracker.ui.components.MarchWordmark
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import com.artless.rucktracker.ui.theme.MarchType
import kotlinx.coroutines.launch

private const val PageCount = 12
private const val LastPage = PageCount - 1

/** Welcome, plan reveal and completion: brand moments rather than forms. */
private val HeroPages = setOf(0, 8, 11)

private val WeekDays = listOf(
    1 to "S", 2 to "M", 3 to "T", 4 to "W", 5 to "T", 6 to "F", 7 to "S"
)

@Composable
fun OnboardingScreen(
    onComplete: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel()
) {
    val pagerState = rememberPagerState(pageCount = { PageCount })
    val scope = rememberCoroutineScope()
    val state = viewModel.state

    fun goTo(page: Int) {
        scope.launch { pagerState.animateScrollToPage(page.coerceIn(0, LastPage)) }
    }

    MarchBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(horizontal = MarchDimens.ScreenPadding)
                .padding(top = 16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "STEP ${pagerState.currentPage + 1} OF $PageCount",
                    style = MarchType.Eyebrow,
                    color = MarchColors.TextSecondary,
                    modifier = Modifier.weight(1f)
                )
                if (pagerState.currentPage < LastPage) {
                    MarchCompactButton(text = "Skip", onClick = { viewModel.skip(onComplete) })
                }
            }

            Spacer(Modifier.height(14.dp))

            MarchProgressBar(progress = (pagerState.currentPage + 1) / PageCount.toFloat())

            HorizontalPager(
                state = pagerState,
                modifier = Modifier.weight(1f)
            ) { page ->
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(vertical = 28.dp),
                    // The hero pages carry little content, so they read as
                    // unbalanced when pinned to the top. In a scrollable column
                    // this centres short content and is a no-op once the content
                    // outgrows the viewport.
                    verticalArrangement = if (page in HeroPages) {
                        Arrangement.Center
                    } else {
                        Arrangement.Top
                    }
                ) {
                    when (page) {
                        0 -> WelcomeStep(onContinue = { goTo(1) })
                        1 -> ProfileSetupStep(state.bodyWeight, state.defaultRuckWeight, viewModel::updateWeights)
                        2 -> GoalStep(state.goal, viewModel::updateGoal)
                        3 -> ExperienceStep(state.experience, viewModel::updateExperience)
                        4 -> BaselineStep(state.pace, state.longestDistance, viewModel::updateBaseline)
                        5 -> TerrainStep(state.hasHills, state.hasStairs, viewModel::updateTerrain)
                        6 -> EventDateStep(viewModel::setEventDate)
                        7 -> TrainingDaysStep(state.trainingDays, viewModel::updateTrainingDays)
                        8 -> ProgramRevealStep(state.goal.displayName, state.trainingDays.size)
                        9 -> ProUpsellStep()
                        10 -> PermissionsStep()
                        11 -> CompleteStep(onComplete = { viewModel.complete(onComplete) })
                    }
                }
            }

            // The first and last pages carry their own full-width CTA, so the
            // shared nav row would only duplicate it.
            if (pagerState.currentPage in 1 until LastPage) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .navigationBarsPadding()
                        .padding(bottom = 20.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    MarchGhostButton(
                        text = "Back",
                        accent = MarchColors.TextSecondary,
                        onClick = { goTo(pagerState.currentPage - 1) },
                        modifier = Modifier.weight(1f)
                    )
                    MarchPrimaryButton(
                        text = "Continue",
                        onClick = { goTo(pagerState.currentPage + 1) },
                        modifier = Modifier.weight(1.4f)
                    )
                }
            }
        }
    }
}

/** Shared step layout: eyebrow, headline, supporting copy, then controls. */
@Composable
private fun StepScaffold(
    eyebrow: String,
    title: String,
    message: String? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Column {
        Text(
            text = eyebrow.uppercase(),
            style = MarchType.Eyebrow,
            color = MarchColors.Primary
        )
        Spacer(Modifier.height(10.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.headlineLarge,
            color = MarchColors.TextPrimary
        )
        if (message != null) {
            Spacer(Modifier.height(12.dp))
            Text(
                text = message,
                style = MaterialTheme.typography.bodyLarge,
                color = MarchColors.TextSecondary
            )
        }
        Spacer(Modifier.height(28.dp))
        content()
    }
}

@Composable
private fun WelcomeStep(onContinue: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        MarchChevron(size = 88.dp)
        Spacer(Modifier.height(24.dp))
        MarchWordmark()
        Spacer(Modifier.height(10.dp))
        Text(
            text = "WALK STRONGER",
            style = MarchType.Eyebrow.copy(letterSpacing = 4.sp),
            color = MarchColors.Primary
        )
        Spacer(Modifier.height(28.dp))
        Text(
            text = "Your rucking coach and your tribe. Answer a few questions and we'll build a plan around your goal.",
            style = MaterialTheme.typography.bodyLarge,
            color = MarchColors.TextSecondary,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(36.dp))
        MarchPrimaryButton(text = "Get Started", onClick = onContinue)
    }
}

@Composable
private fun ProfileSetupStep(body: Double, ruck: Double, onUpdate: (Double, Double) -> Unit) {
    var bodyText by remember { mutableStateOf(body.toInt().toString()) }
    var ruckText by remember { mutableStateOf(ruck.toInt().toString()) }

    StepScaffold(
        eyebrow = "Your profile",
        title = "The basics",
        message = "We use your body weight and load to calculate calories accurately."
    ) {
        MarchTextField(
            value = bodyText,
            onValueChange = {
                bodyText = it
                onUpdate(it.toDoubleOrNull() ?: 180.0, ruckText.toDoubleOrNull() ?: 20.0)
            },
            label = "Body weight",
            keyboardType = KeyboardType.Decimal,
            leadingIcon = Icons.AutoMirrored.Filled.DirectionsWalk,
            suffix = "lb"
        )
        Spacer(Modifier.height(14.dp))
        MarchTextField(
            value = ruckText,
            onValueChange = {
                ruckText = it
                onUpdate(bodyText.toDoubleOrNull() ?: 180.0, it.toDoubleOrNull() ?: 20.0)
            },
            label = "Default ruck weight",
            keyboardType = KeyboardType.Decimal,
            leadingIcon = Icons.Filled.Terrain,
            suffix = "lb"
        )
    }
}

@Composable
private fun GoalStep(selected: RuckingGoal, onSelect: (RuckingGoal) -> Unit) {
    StepScaffold(
        eyebrow = "Step 1",
        title = "What are you training for?",
        message = "This shapes your weekly mileage and load progression."
    ) {
        RuckingGoal.entries.forEach { goal ->
            MarchSelectionRow(
                title = goal.displayName,
                selected = selected == goal,
                onClick = { onSelect(goal) }
            )
            Spacer(Modifier.height(10.dp))
        }
    }
}

@Composable
private fun ExperienceStep(selected: ExperienceLevel, onSelect: (ExperienceLevel) -> Unit) {
    StepScaffold(
        eyebrow = "Step 2",
        title = "Where are you starting?",
        message = "Be honest — we'd rather build you up than burn you out."
    ) {
        ExperienceLevel.entries.forEach { level ->
            MarchSelectionRow(
                title = level.displayName,
                selected = selected == level,
                onClick = { onSelect(level) }
            )
            Spacer(Modifier.height(10.dp))
        }
    }
}

@Composable
private fun BaselineStep(pace: Double, distance: Double, onUpdate: (Double, Double) -> Unit) {
    var paceText by remember { mutableStateOf(pace.toString()) }
    var distanceText by remember { mutableStateOf(distance.toString()) }

    StepScaffold(
        eyebrow = "Step 3",
        title = "Your current baseline",
        message = "Roughly where you are today. We'll adjust as you log rucks."
    ) {
        MarchTextField(
            value = paceText,
            onValueChange = {
                paceText = it
                onUpdate(it.toDoubleOrNull() ?: 16.0, distanceText.toDoubleOrNull() ?: 4.0)
            },
            label = "Comfortable pace",
            keyboardType = KeyboardType.Decimal,
            suffix = "min/mi"
        )
        Spacer(Modifier.height(14.dp))
        MarchTextField(
            value = distanceText,
            onValueChange = {
                distanceText = it
                onUpdate(paceText.toDoubleOrNull() ?: 16.0, it.toDoubleOrNull() ?: 4.0)
            },
            label = "Longest ruck so far",
            keyboardType = KeyboardType.Decimal,
            suffix = "mi"
        )
    }
}

@Composable
private fun TerrainStep(hills: Boolean, stairs: Boolean, onUpdate: (Boolean, Boolean) -> Unit) {
    StepScaffold(
        eyebrow = "Step 4",
        title = "What can you train on?",
        message = "Pick everything you have regular access to."
    ) {
        MarchSelectionRow(
            title = "Hills",
            subtitle = "Sustained climbs near you",
            selected = hills,
            multiSelect = true,
            icon = Icons.Filled.Terrain,
            onClick = { onUpdate(!hills, stairs) }
        )
        Spacer(Modifier.height(10.dp))
        MarchSelectionRow(
            title = "Stairs",
            subtitle = "Stadium steps or a tall building",
            selected = stairs,
            multiSelect = true,
            icon = Icons.Filled.Stairs,
            onClick = { onUpdate(hills, !stairs) }
        )
    }
}

@Composable
private fun EventDateStep(onSet: () -> Unit) {
    StepScaffold(
        eyebrow = "Step 5",
        title = "Got a target event?",
        message = "Optional. If you're training toward a date, we'll work backwards from it."
    ) {
        MarchCard(contentPadding = 20.dp) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircleIcon(
                    icon = Icons.Filled.CalendarMonth,
                    accent = MarchColors.TileBlue,
                    size = 44.dp,
                    iconSize = 20.dp
                )
                Column(modifier = Modifier.padding(start = 14.dp)) {
                    Text(
                        text = "No date set",
                        style = MaterialTheme.typography.titleMedium,
                        color = MarchColors.TextPrimary
                    )
                    Text(
                        text = "You can add one later in settings",
                        style = MaterialTheme.typography.bodySmall,
                        color = MarchColors.TextSecondary
                    )
                }
            }
            Spacer(Modifier.height(18.dp))
            MarchGhostButton(text = "Set target date", onClick = onSet, height = 48.dp)
        }
    }
}

@Composable
private fun TrainingDaysStep(days: List<Int>, onUpdate: (List<Int>) -> Unit) {
    StepScaffold(
        eyebrow = "Step 6",
        title = "Which days can you ruck?",
        message = "Three days a week is plenty to make real progress."
    ) {
        MarchFieldLabel("Training days")
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            WeekDays.forEach { (day, label) ->
                MarchDayToggle(
                    label = label,
                    selected = days.contains(day),
                    onClick = {
                        val updated = if (days.contains(day)) days - day else days + day
                        onUpdate(updated.sorted())
                    }
                )
            }
        }
        Spacer(Modifier.height(16.dp))
        Text(
            text = "${days.size} day${if (days.size == 1) "" else "s"} selected",
            style = MaterialTheme.typography.bodySmall,
            color = MarchColors.TextSecondary
        )
    }
}

@Composable
private fun ProgramRevealStep(goal: String, dayCount: Int) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(24.dp))
        CircleIcon(
            icon = Icons.Filled.Check,
            accent = MarchColors.Primary,
            size = 78.dp,
            iconSize = 36.dp
        )
        Spacer(Modifier.height(24.dp))
        Text(
            text = "YOUR PLAN IS READY",
            style = MarchType.Eyebrow,
            color = MarchColors.Primary
        )
        Spacer(Modifier.height(12.dp))
        Text(
            text = goal,
            style = MaterialTheme.typography.headlineMedium,
            color = MarchColors.TextPrimary,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(24.dp))
        MarchCard(contentPadding = 20.dp) {
            Text(
                text = "Built around $dayCount session${if (dayCount == 1) "" else "s"} a week, scaling distance and load as you go. You can swap or skip any session.",
                style = MaterialTheme.typography.bodyMedium,
                color = MarchColors.TextSecondary
            )
        }
    }
}

@Composable
private fun ProUpsellStep() {
    StepScaffold(
        eyebrow = "Optional",
        title = "Unlock MARCH Pro",
        message = "Unlimited GPS tracking, every training program, advanced analytics and global rankings."
    ) {
        MarchCard(contentPadding = 20.dp) {
            listOf(
                "Unlimited GPS-tracked rucks",
                "All training programs",
                "Advanced analytics",
                "Global leaderboards"
            ).forEach { perk ->
                Row(
                    modifier = Modifier.padding(vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircleIcon(
                        icon = Icons.Filled.Check,
                        accent = MarchColors.Primary,
                        size = 24.dp,
                        iconSize = 13.dp
                    )
                    Text(
                        text = perk,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MarchColors.TextPrimary,
                        modifier = Modifier.padding(start = 12.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun PermissionsStep() {
    StepScaffold(
        eyebrow = "Almost there",
        title = "Two quick permissions",
        message = "You'll be asked for these when you start your first ruck."
    ) {
        MarchCard(contentPadding = 20.dp) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircleIcon(
                    icon = Icons.Filled.LocationOn,
                    accent = MarchColors.TileBlue,
                    size = 42.dp,
                    iconSize = 19.dp
                )
                Column(modifier = Modifier.padding(start = 14.dp)) {
                    Text(
                        text = "Location",
                        style = MaterialTheme.typography.titleMedium,
                        color = MarchColors.TextPrimary
                    )
                    Text(
                        text = "Required for distance and elevation",
                        style = MaterialTheme.typography.bodySmall,
                        color = MarchColors.TextSecondary
                    )
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        MarchCard(contentPadding = 20.dp) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircleIcon(
                    icon = Icons.Filled.Favorite,
                    accent = MarchColors.DestructiveRed,
                    size = 42.dp,
                    iconSize = 19.dp
                )
                Column(modifier = Modifier.padding(start = 14.dp)) {
                    Text(
                        text = "Health Connect",
                        style = MaterialTheme.typography.titleMedium,
                        color = MarchColors.TextPrimary
                    )
                    Text(
                        text = "Optional, for heart rate",
                        style = MaterialTheme.typography.bodySmall,
                        color = MarchColors.TextSecondary
                    )
                }
            }
        }
    }
}

@Composable
private fun CompleteStep(onComplete: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(40.dp))
        MarchChevron(size = 76.dp)
        Spacer(Modifier.height(28.dp))
        Text(
            text = "You're all set",
            style = MaterialTheme.typography.headlineLarge,
            color = MarchColors.TextPrimary,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(12.dp))
        Text(
            text = "Load up, step out, and let's put some miles behind you.",
            style = MaterialTheme.typography.bodyLarge,
            color = MarchColors.TextSecondary,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(36.dp))
        MarchPrimaryButton(text = "Enter MARCH", onClick = onComplete)
    }
}
