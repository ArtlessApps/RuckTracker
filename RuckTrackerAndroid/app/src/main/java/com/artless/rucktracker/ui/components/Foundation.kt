package com.artless.rucktracker.ui.components

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import com.artless.rucktracker.ui.theme.MarchType

/**
 * Bottom inset so content clears the floating tab bar **and** the system
 * navigation gesture/button bar. Prefer this over [MarchDimens.TabBarClearance]
 * alone whenever laying out CTAs or list bottoms under [MainTabScaffold].
 */
@Composable
fun tabBarBottomInset(): Dp {
    val navBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    return MarchDimens.TabBarClearance + navBottom
}

/** PaddingValues with only the bottom set to [tabBarBottomInset]. */
@Composable
fun tabBarContentPadding(
    start: Dp = 0.dp,
    top: Dp = 0.dp,
    end: Dp = 0.dp
): PaddingValues = PaddingValues(
    start = start,
    top = top,
    end = end,
    bottom = tabBarBottomInset()
)

/**
 * Adds a spring-loaded press scale plus click handling, with no Material ripple.
 * This is the single source of tactile feedback across the app.
 */
@Composable
fun Modifier.marchPressable(
    onClick: () -> Unit,
    enabled: Boolean = true,
    pressedScale: Float = 0.97f
): Modifier {
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed && enabled) pressedScale else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMediumLow
        ),
        label = "pressScale"
    )
    return this
        .graphicsLayer {
            scaleX = scale
            scaleY = scale
        }
        .clickable(
            interactionSource = interactionSource,
            indication = null,
            enabled = enabled,
            onClick = onClick
        )
}

/**
 * App backdrop: the navy-to-black gradient with a soft brand-green aurora bled
 * in from the top-right. Every screen sits on this so navigation feels seamless.
 */
@Composable
fun MarchBackground(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MarchColors.BackgroundGradient)
            .drawWithCache {
                val aurora = Brush.radialGradient(
                    colors = listOf(
                        MarchColors.Primary.copy(alpha = 0.16f),
                        Color.Transparent
                    ),
                    center = Offset(size.width * 0.88f, size.height * -0.02f),
                    radius = size.width * 0.95f
                )
                val ember = Brush.radialGradient(
                    colors = listOf(
                        MarchColors.AccentTeal.copy(alpha = 0.22f),
                        Color.Transparent
                    ),
                    center = Offset(size.width * -0.1f, size.height * 0.32f),
                    radius = size.width * 0.8f
                )
                onDrawBehind {
                    drawRect(aurora)
                    drawRect(ember)
                }
            },
        content = content
    )
}

/** Backdrop plus a scrolling content column with standard gutters. */
@Composable
fun MarchScrollScreen(
    modifier: Modifier = Modifier,
    horizontalPadding: Dp = MarchDimens.ScreenPadding,
    bottomPadding: Dp? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val resolvedBottom = bottomPadding ?: tabBarBottomInset()
    MarchBackground(modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                // Inset for the status bar outside the scroll viewport, so the
                // header clips beneath the system bar instead of sliding over it.
                .statusBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = horizontalPadding)
                .padding(top = 12.dp, bottom = resolvedBottom),
            content = content
        )
    }
}

/** Backdrop plus a fixed content column, for screens that host their own list. */
@Composable
fun MarchScreen(
    modifier: Modifier = Modifier,
    horizontalPadding: Dp = MarchDimens.ScreenPadding,
    content: @Composable ColumnScope.() -> Unit
) {
    MarchBackground(modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(horizontal = horizontalPadding)
                .padding(top = 12.dp),
            content = content
        )
    }
}

/**
 * Screen title block: a large title with an optional all-caps accent [eyebrow]
 * or sentence-case [greeting] above it, plus an optional trailing accessory
 * (streak pill, settings button).
 */
@Composable
fun MarchScreenHeader(
    title: String,
    modifier: Modifier = Modifier,
    eyebrow: String? = null,
    greeting: String? = null,
    subtitle: String? = null,
    trailing: @Composable (() -> Unit)? = null
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            if (greeting != null) {
                Text(
                    text = greeting,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MarchColors.TextSecondary
                )
                Spacer(Modifier.height(2.dp))
            }
            if (eyebrow != null) {
                Text(
                    text = eyebrow.uppercase(),
                    style = MarchType.Eyebrow,
                    color = MarchColors.Primary
                )
                Spacer(Modifier.height(6.dp))
            }
            Text(
                text = title,
                style = MaterialTheme.typography.headlineMedium,
                color = MarchColors.TextPrimary
            )
            if (subtitle != null) {
                Spacer(Modifier.height(4.dp))
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MarchColors.TextSecondary
                )
            }
        }
        if (trailing != null) {
            Spacer(Modifier.width(12.dp))
            trailing()
        }
    }
}

/** All-caps divider label that introduces a group of cards. */
@Composable
fun SectionHeader(
    text: String,
    modifier: Modifier = Modifier,
    trailing: @Composable (() -> Unit)? = null
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = text.uppercase(),
            style = MarchType.Eyebrow,
            color = MarchColors.TextSecondary,
            modifier = Modifier.weight(1f)
        )
        trailing?.invoke()
    }
}

/**
 * The base surface for all content: a subtly graduated navy fill, hairline
 * border and lifted shadow. Pass [onClick] to make it tappable.
 */
@Composable
fun MarchCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    cornerRadius: Dp = 16.dp,
    borderColor: Color = MarchColors.HairlineLight,
    contentPadding: Dp = MarchDimens.CardPadding,
    content: @Composable ColumnScope.() -> Unit
) {
    val shape = RoundedCornerShape(cornerRadius)
    val base = modifier
        .fillMaxWidth()
        .shadow(
            elevation = 10.dp,
            shape = shape,
            ambientColor = Color.Black.copy(alpha = 0.5f),
            spotColor = Color.Black.copy(alpha = 0.5f)
        )
    Column(
        modifier = (if (onClick != null) base.marchPressable(onClick = onClick, pressedScale = 0.985f) else base)
            .clip(shape)
            .background(MarchColors.SurfaceGradient)
            .border(1.dp, borderColor, shape)
            .padding(contentPadding),
        content = content
    )
}

/**
 * Rounded square holding a tinted icon — the recurring visual anchor for tiles,
 * list rows and empty states.
 */
@Composable
fun IconBadge(
    icon: ImageVector,
    accent: Color,
    modifier: Modifier = Modifier,
    size: Dp = MarchDimens.IconBadge,
    cornerRadius: Dp = 12.dp,
    iconSize: Dp = 18.dp
) {
    Box(
        modifier = modifier
            .size(size)
            .clip(RoundedCornerShape(cornerRadius))
            .background(accent.copy(alpha = 0.16f))
            .border(1.dp, accent.copy(alpha = 0.28f), RoundedCornerShape(cornerRadius)),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = accent,
            modifier = Modifier.size(iconSize)
        )
    }
}

/** Circular tinted icon, used for avatars and larger empty-state glyphs. */
@Composable
fun CircleIcon(
    icon: ImageVector,
    accent: Color,
    modifier: Modifier = Modifier,
    size: Dp = 48.dp,
    iconSize: Dp = 22.dp
) {
    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(accent.copy(alpha = 0.16f))
            .border(1.dp, accent.copy(alpha = 0.3f), CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = accent,
            modifier = Modifier.size(iconSize)
        )
    }
}

/** Small capsule label, e.g. a streak count or a "TODAY" marker. */
@Composable
fun MarchPill(
    text: String,
    accent: Color,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null
) {
    Row(
        modifier = modifier
            .clip(CircleShape)
            .background(accent.copy(alpha = 0.14f))
            .border(1.dp, accent.copy(alpha = 0.3f), CircleShape)
            .padding(horizontal = 12.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = accent,
                modifier = Modifier.size(14.dp)
            )
            Spacer(Modifier.width(5.dp))
        }
        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge,
            color = MarchColors.TextPrimary
        )
    }
}

/** Tiny status chip for list rows: DONE / TODAY / LOCKED. */
@Composable
fun StatusBadge(
    text: String,
    accent: Color,
    modifier: Modifier = Modifier
) {
    Text(
        text = text.uppercase(),
        style = MarchType.Eyebrow,
        color = accent,
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(accent.copy(alpha = 0.16f))
            .padding(horizontal = 9.dp, vertical = 5.dp)
    )
}

/** The MARCH wordmark with brand tracking. */
@Composable
fun MarchWordmark(
    modifier: Modifier = Modifier,
    color: Color = MarchColors.TextPrimary
) {
    Text(
        text = "MARCH",
        style = MarchType.Wordmark,
        color = color,
        modifier = modifier
    )
}

/** Centered zero-state with a glyph, headline, supporting copy and optional CTA. */
@Composable
fun MarchEmptyState(
    icon: ImageVector,
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    accent: Color = MarchColors.Primary,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 40.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        CircleIcon(icon = icon, accent = accent, size = 76.dp, iconSize = 34.dp)
        Spacer(Modifier.height(20.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
            color = MarchColors.TextPrimary,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MarchColors.TextSecondary,
            textAlign = TextAlign.Center
        )
        if (actionLabel != null && onAction != null) {
            Spacer(Modifier.height(24.dp))
            MarchPrimaryButton(text = actionLabel, onClick = onAction)
        }
    }
}

/** One-line key/value row used in settings and detail panels. */
@Composable
fun MarchDetailRow(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    accent: Color = MarchColors.Primary
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) {
            IconBadge(icon = icon, accent = accent, size = 32.dp, cornerRadius = 10.dp, iconSize = 15.dp)
            Spacer(Modifier.width(12.dp))
        }
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MarchColors.TextSecondary,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Text(
            text = value,
            style = MaterialTheme.typography.titleSmall,
            color = MarchColors.TextPrimary
        )
    }
}

/** Bottom-anchored container that respects the system navigation bar. */
@Composable
fun MarchBottomActions(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = MarchDimens.ScreenPadding, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        content = content
    )
}
