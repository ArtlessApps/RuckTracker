package com.artless.rucktracker.ui.premium

import android.app.Activity
import androidx.compose.animation.animateColorAsState
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.artless.rucktracker.ui.components.CircleIcon
import com.artless.rucktracker.ui.components.MarchBackground
import com.artless.rucktracker.ui.components.MarchGhostButton
import com.artless.rucktracker.ui.components.MarchIconButton
import com.artless.rucktracker.ui.components.MarchPrimaryButton
import com.artless.rucktracker.ui.components.marchPressable
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import com.artless.rucktracker.ui.theme.MarchType

private data class PremiumPerk(val icon: ImageVector, val title: String, val detail: String)

private val Perks = listOf(
    PremiumPerk(Icons.Filled.LocationOn, "Unlimited GPS tracking", "Every ruck mapped, no session caps"),
    PremiumPerk(Icons.Filled.FitnessCenter, "All training programs", "GORUCK, ACFT and marathon prep"),
    PremiumPerk(Icons.Filled.BarChart, "Advanced analytics", "Trends in pace, load and elevation"),
    PremiumPerk(Icons.Filled.EmojiEvents, "Global leaderboards", "Compete beyond your club")
)

@Composable
fun PaywallScreen(
    onDismiss: () -> Unit,
    onPurchased: () -> Unit,
    viewModel: PaywallViewModel = hiltViewModel()
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var yearlySelected by remember { mutableStateOf(true) }

    MarchBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = MarchDimens.ScreenPadding)
                .padding(top = 12.dp, bottom = 24.dp)
        ) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                MarchIconButton(
                    icon = Icons.Filled.Close,
                    onClick = onDismiss,
                    contentDescription = "Close"
                )
            }

            Spacer(Modifier.height(20.dp))

            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                CircleIcon(
                    icon = Icons.Filled.WorkspacePremium,
                    accent = MarchColors.RankGold,
                    size = 78.dp,
                    iconSize = 38.dp
                )
                Spacer(Modifier.height(20.dp))
                Text(
                    text = "MARCH PRO",
                    style = MarchType.Wordmark.copy(fontSize = 32.sp, letterSpacing = 4.sp),
                    color = MarchColors.TextPrimary
                )
                Spacer(Modifier.height(10.dp))
                Text(
                    text = "Train with the full arsenal.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MarchColors.TextSecondary,
                    textAlign = TextAlign.Center
                )
            }

            Spacer(Modifier.height(32.dp))

            Perks.forEach { perk ->
                PerkRow(perk)
                Spacer(Modifier.height(14.dp))
            }

            Spacer(Modifier.height(MarchDimens.SectionGap - 14.dp))

            PlanOption(
                title = "Yearly",
                price = "$39.99",
                cadence = "per year",
                caption = "Just $3.33/mo — save 33%",
                badge = "BEST VALUE",
                selected = yearlySelected,
                onClick = { yearlySelected = true }
            )
            Spacer(Modifier.height(12.dp))
            PlanOption(
                title = "Monthly",
                price = "$4.99",
                cadence = "per month",
                caption = "Cancel anytime",
                badge = null,
                selected = !yearlySelected,
                onClick = { yearlySelected = false }
            )

            Spacer(Modifier.height(MarchDimens.SectionGap))

            MarchPrimaryButton(
                text = if (yearlySelected) "Start Yearly — $39.99" else "Start Monthly — $4.99",
                onClick = {
                    (context as? Activity)?.let { activity ->
                        if (yearlySelected) viewModel.purchaseYearly(activity, onPurchased)
                        else viewModel.purchaseMonthly(activity, onPurchased)
                    }
                }
            )
            Spacer(Modifier.height(10.dp))
            MarchGhostButton(
                text = "Not now",
                accent = MarchColors.TextSecondary,
                onClick = onDismiss,
                modifier = Modifier.navigationBarsPadding()
            )
        }
    }
}

@Composable
private fun PerkRow(perk: PremiumPerk) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        CircleIcon(
            icon = perk.icon,
            accent = MarchColors.Primary,
            size = 38.dp,
            iconSize = 18.dp
        )
        Spacer(Modifier.width(14.dp))
        Column {
            Text(
                text = perk.title,
                style = MaterialTheme.typography.titleSmall,
                color = MarchColors.TextPrimary
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = perk.detail,
                style = MaterialTheme.typography.bodySmall,
                color = MarchColors.TextSecondary
            )
        }
    }
}

@Composable
private fun PlanOption(
    title: String,
    price: String,
    cadence: String,
    caption: String,
    badge: String?,
    selected: Boolean,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(18.dp)
    val border by animateColorAsState(
        targetValue = if (selected) MarchColors.Primary else MarchColors.HairlineStrong,
        label = "planBorder"
    )
    val fill by animateColorAsState(
        targetValue = if (selected) MarchColors.Primary.copy(alpha = 0.1f) else Color.Transparent,
        label = "planFill"
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .marchPressable(onClick = onClick, pressedScale = 0.985f)
            .clip(shape)
            .background(fill)
            .border(if (selected) 2.dp else 1.dp, border, shape)
            .padding(18.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        SelectionRing(selected = selected)
        Spacer(Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    color = MarchColors.TextPrimary
                )
                if (badge != null) {
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = badge,
                        style = MarchType.Eyebrow,
                        color = MarchColors.TextOnLight,
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(MarchColors.RankGold)
                            .padding(horizontal = 7.dp, vertical = 3.dp)
                    )
                }
            }
            Spacer(Modifier.height(3.dp))
            Text(
                text = caption,
                style = MaterialTheme.typography.bodySmall,
                color = MarchColors.TextSecondary
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = price,
                style = MaterialTheme.typography.headlineSmall,
                color = MarchColors.TextPrimary
            )
            Text(
                text = cadence,
                style = MaterialTheme.typography.bodySmall,
                color = MarchColors.TextSecondary
            )
        }
    }
}

@Composable
private fun SelectionRing(selected: Boolean) {
    Box(
        modifier = Modifier
            .size(22.dp)
            .clip(CircleShape)
            .background(if (selected) MarchColors.Primary else Color.Transparent)
            .border(
                width = if (selected) 0.dp else 1.5.dp,
                color = MarchColors.TextSecondary,
                shape = CircleShape
            ),
        contentAlignment = Alignment.Center
    ) {
        if (selected) {
            Icon(
                imageVector = Icons.Filled.Check,
                contentDescription = null,
                tint = MarchColors.TextOnLight,
                modifier = Modifier.size(14.dp)
            )
        }
    }
}
