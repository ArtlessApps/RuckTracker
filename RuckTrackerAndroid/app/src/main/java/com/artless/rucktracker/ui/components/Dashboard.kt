package com.artless.rucktracker.ui.components

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import com.artless.rucktracker.ui.theme.MarchType

/**
 * The single most important control in the app: a centred gradient slab with an
 * oversized label, so starting a ruck is never more than one deliberate tap away.
 */
@Composable
fun HeroRuckButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    title: String = "START RUCK",
    subtitle: String = "No plan. Just walk with weight."
) {
    val shape = RoundedCornerShape(20.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .height(MarchDimens.HeroHeight)
            .shadow(
                elevation = 16.dp,
                shape = shape,
                ambientColor = MarchColors.Primary.copy(alpha = 0.35f),
                spotColor = MarchColors.Primary.copy(alpha = 0.35f)
            )
            .marchPressable(onClick = onClick, pressedScale = 0.965f)
            .clip(shape)
            .background(MarchColors.HeroGradient)
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = title,
            color = Color.White,
            textAlign = TextAlign.Center,
            style = MarchType.HeroTitle.copy(
                shadow = Shadow(
                    color = Color.Black.copy(alpha = 0.35f),
                    offset = Offset(0f, 2f),
                    blurRadius = 4f
                )
            )
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White.copy(alpha = 0.85f),
            textAlign = TextAlign.Center
        )
    }
}

/**
 * Full-width bento tile: heavy all-caps destination name, a live status line,
 * and a tinted icon badge that colour-codes each destination.
 */
@Composable
fun DashboardTile(
    title: String,
    subtitle: String,
    icon: ImageVector,
    accent: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val shape = RoundedCornerShape(16.dp)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(MarchDimens.TileHeight)
            .shadow(
                elevation = 10.dp,
                shape = shape,
                ambientColor = Color.Black.copy(alpha = 0.55f),
                spotColor = Color.Black.copy(alpha = 0.55f)
            )
            .marchPressable(onClick = onClick, pressedScale = 0.98f)
            .clip(shape)
            .background(MarchColors.SurfaceGradient)
            .drawWithCache {
                // Accent bloom anchored under the icon badge.
                val bloom = Brush.radialGradient(
                    colors = listOf(accent.copy(alpha = 0.20f), Color.Transparent),
                    center = Offset(size.width * 0.92f, size.height * 0.18f),
                    radius = size.width * 0.5f
                )
                onDrawBehind { drawRect(bloom) }
            }
            .border(1.dp, MarchColors.HairlineLight, shape)
            .padding(18.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(end = 56.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = title.uppercase(),
                style = MarchType.TileTitle,
                color = MarchColors.TextPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.labelLarge,
                color = MarchColors.TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        IconBadge(
            icon = icon,
            accent = accent,
            modifier = Modifier.align(Alignment.TopEnd)
        )
    }
}

/**
 * Compact metric tile for stat grids: an all-caps label, a large value and an
 * optional unit suffix.
 */
@Composable
fun StatTile(
    label: String,
    value: String,
    icon: ImageVector,
    accent: Color,
    modifier: Modifier = Modifier,
    unit: String? = null
) {
    val shape = RoundedCornerShape(18.dp)
    Column(
        modifier = modifier
            .clip(shape)
            .background(MarchColors.SurfaceGradient)
            .border(1.dp, MarchColors.HairlineLight, shape)
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconBadge(
                icon = icon,
                accent = accent,
                size = 30.dp,
                cornerRadius = 9.dp,
                iconSize = 14.dp
            )
            Spacer(Modifier.width(9.dp))
            Text(
                text = label.uppercase(),
                style = MarchType.Eyebrow,
                color = MarchColors.TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = value,
                style = MarchType.MetricMedium,
                color = MarchColors.TextPrimary,
                maxLines = 1
            )
            if (unit != null) {
                Spacer(Modifier.width(4.dp))
                Text(
                    text = unit,
                    style = MaterialTheme.typography.labelLarge,
                    color = MarchColors.TextSecondary,
                    modifier = Modifier.padding(bottom = 3.dp)
                )
            }
        }
    }
}

/**
 * Large hero metric used on live and summary workout screens: value dominates,
 * label and unit stay quiet.
 */
@Composable
fun MetricBlock(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
    unit: String? = null,
    accent: Color = MarchColors.TextPrimary,
    horizontalAlignment: Alignment.Horizontal = Alignment.CenterHorizontally
) {
    Column(
        modifier = modifier,
        horizontalAlignment = horizontalAlignment
    ) {
        Text(
            text = label.uppercase(),
            style = MarchType.StatLabel,
            color = MarchColors.TextSecondary
        )
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = value,
                style = MarchType.MetricLarge,
                color = accent,
                maxLines = 1
            )
            if (unit != null) {
                Spacer(Modifier.width(5.dp))
                Text(
                    text = unit,
                    style = MaterialTheme.typography.titleMedium,
                    color = MarchColors.TextSecondary,
                    modifier = Modifier.padding(bottom = 6.dp)
                )
            }
        }
    }
}

/** Rank medallion: gold/silver/bronze for the podium, muted navy beyond it. */
@Composable
fun RankMedallion(
    rank: Int,
    modifier: Modifier = Modifier,
    size: Dp = 40.dp
) {
    val accent = when (rank) {
        1 -> MarchColors.RankGold
        2 -> MarchColors.RankSilver
        3 -> MarchColors.RankBronze
        else -> MarchColors.TextSecondary
    }
    val onPodium = rank in 1..3
    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(accent.copy(alpha = if (onPodium) 0.2f else 0.1f))
            .border(1.dp, accent.copy(alpha = if (onPodium) 0.55f else 0.2f), CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = rank.toString(),
            style = MaterialTheme.typography.labelLarge,
            color = accent
        )
    }
}
