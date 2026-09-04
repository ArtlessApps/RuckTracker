package com.artless.rucktracker.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.KeyboardOptions
import com.artless.rucktracker.ui.theme.MarchColors
import com.artless.rucktracker.ui.theme.MarchDimens
import com.artless.rucktracker.ui.theme.MarchType

/**
 * The app's headline action: gradient fill, dark-on-green label and a green
 * glow so it reads as the obvious next step on any screen.
 */
@Composable
fun MarchPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
    icon: ImageVector? = null,
    height: Dp = MarchDimens.ButtonHeight
) {
    val shape = RoundedCornerShape(16.dp)
    val active = enabled && !loading
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .alpha(if (active) 1f else 0.5f)
            .shadow(
                elevation = if (active) 14.dp else 0.dp,
                shape = shape,
                ambientColor = MarchColors.Primary.copy(alpha = 0.6f),
                spotColor = MarchColors.Primary.copy(alpha = 0.6f)
            )
            .marchPressable(onClick = onClick, enabled = active)
            .clip(shape)
            .background(MarchColors.PrimaryGradient),
        contentAlignment = Alignment.Center
    ) {
        if (loading) {
            CircularProgressIndicator(
                color = MarchColors.TextOnLight,
                strokeWidth = 2.dp,
                modifier = Modifier.size(22.dp)
            )
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (icon != null) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = MarchColors.TextOnLight,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(8.dp))
                }
                Text(
                    text = text,
                    style = MaterialTheme.typography.titleMedium,
                    color = MarchColors.TextOnLight
                )
            }
        }
    }
}

/** Muted companion action — a translucent white fill with secondary text. */
@Composable
fun MarchSecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
    height: Dp = MarchDimens.ButtonHeight
) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .alpha(if (enabled) 1f else 0.5f)
            .marchPressable(onClick = onClick, enabled = enabled)
            .clip(shape)
            .background(MarchColors.FillMuted)
            .border(1.dp, MarchColors.HairlineStrong, shape),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MarchColors.TextPrimary,
                modifier = Modifier.size(18.dp)
            )
            Spacer(Modifier.width(8.dp))
        }
        Text(
            text = text,
            style = MaterialTheme.typography.titleMedium,
            color = MarchColors.TextPrimary
        )
    }
}

/** Outlined action for tertiary paths (destructive, "not now", back). */
@Composable
fun MarchGhostButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    accent: Color = MarchColors.Primary,
    icon: ImageVector? = null,
    height: Dp = MarchDimens.ButtonHeight
) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .alpha(if (enabled) 1f else 0.5f)
            .marchPressable(onClick = onClick, enabled = enabled)
            .clip(shape)
            .border(1.5.dp, accent.copy(alpha = 0.55f), shape),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = accent,
                modifier = Modifier.size(18.dp)
            )
            Spacer(Modifier.width(8.dp))
        }
        Text(
            text = text,
            style = MaterialTheme.typography.titleMedium,
            color = accent
        )
    }
}

/** Compact pill action for inline placement inside headers and rows. */
@Composable
fun MarchCompactButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    accent: Color = MarchColors.TextSecondary,
    filled: Boolean = false
) {
    Row(
        modifier = modifier
            .marchPressable(onClick = onClick, pressedScale = 0.94f)
            .clip(CircleShape)
            .background(if (filled) accent.copy(alpha = 0.18f) else MarchColors.FillSubtle)
            .border(1.dp, accent.copy(alpha = 0.28f), CircleShape)
            .padding(horizontal = 14.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = accent,
                modifier = Modifier.size(15.dp)
            )
            if (text.isNotEmpty()) Spacer(Modifier.width(6.dp))
        }
        if (text.isNotEmpty()) {
            Text(
                text = text,
                style = MaterialTheme.typography.labelLarge,
                color = accent
            )
        }
    }
}

/** Circular icon-only button, used for back arrows and row affordances. */
@Composable
fun MarchIconButton(
    icon: ImageVector,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    accent: Color = MarchColors.TextSecondary,
    size: Dp = 40.dp,
    contentDescription: String? = null
) {
    Box(
        modifier = modifier
            .size(size)
            .marchPressable(onClick = onClick, pressedScale = 0.9f)
            .clip(CircleShape)
            .background(MarchColors.FillSubtle)
            .border(1.dp, MarchColors.HairlineLight, CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = accent,
            modifier = Modifier.size(size * 0.45f)
        )
    }
}

/** Selectable filter pill; animates between muted and solid-brand states. */
@Composable
fun MarchChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null
) {
    val container by animateColorAsState(
        targetValue = if (selected) MarchColors.Primary else MarchColors.Primary.copy(alpha = 0.1f),
        label = "chipContainer"
    )
    val content by animateColorAsState(
        targetValue = if (selected) MarchColors.TextOnLight else MarchColors.Primary,
        label = "chipContent"
    )
    Row(
        modifier = modifier
            .marchPressable(onClick = onClick, pressedScale = 0.95f)
            .clip(CircleShape)
            .background(container)
            .padding(horizontal = 14.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = content,
                modifier = Modifier.size(14.dp)
            )
            Spacer(Modifier.width(6.dp))
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            color = content
        )
    }
}

/**
 * Equal-width segmented control that replaces Material's underlined `TabRow`
 * with a recessed track and a solid selected segment.
 */
@Composable
fun MarchSegmentedControl(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .background(MarchColors.Background.copy(alpha = 0.5f))
            .border(1.dp, MarchColors.HairlineLight, CircleShape)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        options.forEachIndexed { index, option ->
            val selected = index == selectedIndex
            val container by animateColorAsState(
                targetValue = if (selected) MarchColors.Primary else Color.Transparent,
                label = "segmentContainer"
            )
            val content by animateColorAsState(
                targetValue = if (selected) MarchColors.TextOnLight else MarchColors.TextSecondary,
                label = "segmentContent"
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(36.dp)
                    .marchPressable(onClick = { onSelect(index) }, pressedScale = 0.96f)
                    .clip(CircleShape)
                    .background(container),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = option,
                    style = MaterialTheme.typography.labelLarge,
                    color = content,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

/**
 * Full-width selectable row — the preferred way to present a small set of
 * mutually exclusive choices. Reads far better than a wrap of tiny chips.
 */
@Composable
fun MarchSelectionRow(
    title: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    icon: ImageVector? = null,
    multiSelect: Boolean = false
) {
    val shape = RoundedCornerShape(16.dp)
    val border by animateColorAsState(
        targetValue = if (selected) MarchColors.Primary else MarchColors.HairlineStrong,
        label = "selectionBorder"
    )
    val fill by animateColorAsState(
        targetValue = if (selected) MarchColors.Primary.copy(alpha = 0.1f) else MarchColors.FillSubtle,
        label = "selectionFill"
    )

    Row(
        modifier = modifier
            .fillMaxWidth()
            .marchPressable(onClick = onClick, pressedScale = 0.985f)
            .clip(shape)
            .background(fill)
            .border(if (selected) 1.5.dp else 1.dp, border, shape)
            .padding(horizontal = 16.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (selected) MarchColors.Primary else MarchColors.TextSecondary,
                modifier = Modifier.size(20.dp)
            )
            Spacer(Modifier.width(14.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = MarchColors.TextPrimary
            )
            if (subtitle != null) {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MarchColors.TextSecondary
                )
            }
        }
        Spacer(Modifier.width(12.dp))
        SelectionIndicator(selected = selected, rounded = multiSelect)
    }
}

@Composable
private fun SelectionIndicator(selected: Boolean, rounded: Boolean) {
    val shape = if (rounded) RoundedCornerShape(7.dp) else CircleShape
    Box(
        modifier = Modifier
            .size(23.dp)
            .clip(shape)
            .background(if (selected) MarchColors.Primary else Color.Transparent)
            .border(
                width = if (selected) 0.dp else 1.5.dp,
                color = MarchColors.TextSecondary.copy(alpha = 0.6f),
                shape = shape
            ),
        contentAlignment = Alignment.Center
    ) {
        if (selected) {
            Icon(
                imageVector = Icons.Filled.Check,
                contentDescription = null,
                tint = MarchColors.TextOnLight,
                modifier = Modifier.size(15.dp)
            )
        }
    }
}

/** Segmented progress rail used by multi-step flows. */
@Composable
fun MarchProgressBar(
    progress: Float,
    modifier: Modifier = Modifier
) {
    val animated by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        label = "progress"
    )
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(5.dp)
            .clip(CircleShape)
            .background(MarchColors.FillMuted)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(animated)
                .height(5.dp)
                .clip(CircleShape)
                .background(MarchColors.PrimaryGradient)
        )
    }
}

/** Circular single-letter toggle, used for picking training days. */
@Composable
fun MarchDayToggle(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val fill by animateColorAsState(
        targetValue = if (selected) MarchColors.Primary else MarchColors.FillSubtle,
        label = "dayFill"
    )
    val content by animateColorAsState(
        targetValue = if (selected) MarchColors.TextOnLight else MarchColors.TextSecondary,
        label = "dayContent"
    )
    Box(
        modifier = modifier
            .size(44.dp)
            .marchPressable(onClick = onClick, pressedScale = 0.9f)
            .clip(CircleShape)
            .background(fill)
            .border(1.dp, if (selected) Color.Transparent else MarchColors.HairlineStrong, CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            color = content
        )
    }
}

/** Brand-styled text input with a floating label and green focus state. */
@Composable
fun MarchTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    keyboardType: KeyboardType = KeyboardType.Text,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    singleLine: Boolean = true,
    leadingIcon: ImageVector? = null,
    suffix: String? = null
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        modifier = modifier.fillMaxWidth(),
        singleLine = singleLine,
        shape = RoundedCornerShape(14.dp),
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        visualTransformation = visualTransformation,
        textStyle = MaterialTheme.typography.titleMedium,
        leadingIcon = leadingIcon?.let {
            {
                Icon(
                    imageVector = it,
                    contentDescription = null,
                    tint = MarchColors.TextSecondary,
                    modifier = Modifier.size(18.dp)
                )
            }
        },
        suffix = suffix?.let {
            {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MarchColors.TextSecondary
                )
            }
        },
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = MarchColors.TextPrimary,
            unfocusedTextColor = MarchColors.TextPrimary,
            focusedContainerColor = MarchColors.Surface.copy(alpha = 0.55f),
            unfocusedContainerColor = MarchColors.Surface.copy(alpha = 0.35f),
            focusedBorderColor = MarchColors.Primary,
            unfocusedBorderColor = MarchColors.HairlineStrong,
            focusedLabelColor = MarchColors.Primary,
            unfocusedLabelColor = MarchColors.TextSecondary,
            cursorColor = MarchColors.Primary
        )
    )
}

/** Inline error message with a left accent rule. */
@Composable
fun MarchInlineMessage(
    text: String,
    modifier: Modifier = Modifier,
    accent: Color = MarchColors.DestructiveRed
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(accent.copy(alpha = 0.12f))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .width(3.dp)
                .height(18.dp)
                .clip(CircleShape)
                .background(SolidColor(accent))
        )
        Spacer(Modifier.width(10.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            color = MarchColors.TextPrimary
        )
    }
}

/** Divider tuned for dark navy surfaces. */
@Composable
fun MarchDivider(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(
                Brush.horizontalGradient(
                    listOf(Color.Transparent, MarchColors.HairlineStrong, Color.Transparent)
                )
            )
    )
}

/** All-caps micro label, for grouping controls. */
@Composable
fun MarchFieldLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text.uppercase(),
        style = MarchType.Eyebrow,
        color = MarchColors.TextSecondary,
        modifier = modifier
    )
}
