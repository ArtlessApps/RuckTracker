package com.artless.rucktracker.ui.navigation

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artless.rucktracker.data.model.MainTab
import com.artless.rucktracker.ui.components.marchPressable
import com.artless.rucktracker.ui.plan.PlanScreen
import com.artless.rucktracker.ui.premium.PaywallScreen
import com.artless.rucktracker.ui.rankings.RankingsScreen
import com.artless.rucktracker.ui.ruck.RuckTabScreen
import com.artless.rucktracker.ui.ruck.RuckTabViewModel
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.tribe.TribeScreen
import com.artless.rucktracker.ui.you.YouScreen

@Composable
fun MainTabScaffold(
    onStartRuck: () -> Unit,
    viewModel: MainTabViewModel = hiltViewModel(),
    ruckViewModel: RuckTabViewModel = hiltViewModel()
) {
    val selectedTab by viewModel.selectedTab.collectAsStateWithLifecycle()
    val showPaywall by ruckViewModel.showPaywall.collectAsStateWithLifecycle()

    Box(modifier = Modifier.fillMaxSize()) {
        when (selectedTab) {
            MainTab.RUCK -> RuckTabScreen(
                onStartRuck = onStartRuck,
                onSelectTab = viewModel::selectTab,
                viewModel = ruckViewModel
            )
            MainTab.PLAN -> PlanScreen()
            MainTab.TRIBE -> TribeScreen()
            MainTab.RANKINGS -> RankingsScreen()
            MainTab.YOU -> YouScreen()
        }

        MarchTabBar(
            selectedTab = selectedTab,
            onSelect = viewModel::selectTab,
            modifier = Modifier.align(Alignment.BottomCenter)
        )

        // Full-screen takeover, drawn above the tab bar so the nav chrome
        // never floats over the purchase CTA.
        if (showPaywall) {
            PaywallScreen(
                onDismiss = ruckViewModel::dismissPaywall,
                onPurchased = ruckViewModel::onPurchased
            )
        }
    }
}

/**
 * Floating capsule tab bar. Content scrolls underneath it, and the selected tab
 * is marked by a brand-tinted disc plus an underline dot rather than a label,
 * matching the icon-only bar on iOS.
 */
@Composable
private fun MarchTabBar(
    selectedTab: MainTab,
    onSelect: (MainTab) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .navigationBarsPadding()
            .padding(horizontal = 18.dp, vertical = 14.dp)
            .fillMaxWidth()
            .height(66.dp)
            .shadow(
                elevation = 20.dp,
                shape = CircleShape,
                ambientColor = Color.Black.copy(alpha = 0.7f),
                spotColor = Color.Black.copy(alpha = 0.7f)
            )
            .clip(CircleShape)
            .background(MarchColors.Surface.copy(alpha = 0.97f))
            .border(1.dp, MarchColors.HairlineStrong, CircleShape)
            .padding(horizontal = 8.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        MainTab.entries.forEach { tab ->
            TabBarItem(
                tab = tab,
                selected = selectedTab == tab,
                onClick = { onSelect(tab) },
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun TabBarItem(
    tab: MainTab,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val tint by animateColorAsState(
        targetValue = if (selected) MarchColors.Primary else MarchColors.TextSecondary,
        label = "tabTint"
    )
    val disc by animateColorAsState(
        targetValue = if (selected) MarchColors.Primary.copy(alpha = 0.16f) else Color.Transparent,
        label = "tabDisc"
    )
    val dotSize by animateDpAsState(
        targetValue = if (selected) 5.dp else 0.dp,
        label = "tabDot"
    )

    Column(
        modifier = modifier
            .marchPressable(onClick = onClick, pressedScale = 0.9f)
            .padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(disc),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = tab.icon,
                contentDescription = tab.label,
                tint = tint,
                modifier = Modifier.size(21.dp)
            )
        }
        Spacer(Modifier.height(4.dp))
        Box(
            modifier = Modifier
                .size(dotSize)
                .clip(CircleShape)
                .background(MarchColors.Primary)
        )
    }
}

private val MainTab.label: String
    get() = when (this) {
        MainTab.RUCK -> "Ruck"
        MainTab.PLAN -> "Plan"
        MainTab.TRIBE -> "Tribe"
        MainTab.RANKINGS -> "Rankings"
        MainTab.YOU -> "You"
    }

private val MainTab.icon: ImageVector
    get() = when (this) {
        MainTab.RUCK -> Icons.AutoMirrored.Filled.DirectionsWalk
        MainTab.PLAN -> Icons.Filled.CalendarMonth
        MainTab.TRIBE -> Icons.Filled.Groups
        MainTab.RANKINGS -> Icons.Filled.EmojiEvents
        MainTab.YOU -> Icons.Filled.AccountCircle
    }
