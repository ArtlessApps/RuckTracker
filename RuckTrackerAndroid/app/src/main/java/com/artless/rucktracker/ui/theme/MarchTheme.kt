package com.artless.rucktracker.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val MarchDarkColorScheme = darkColorScheme(
    primary = MarchColors.Primary,
    onPrimary = MarchColors.TextOnLight,
    primaryContainer = MarchColors.PrimaryDeep,
    onPrimaryContainer = MarchColors.TextPrimary,
    secondary = MarchColors.AccentGreen,
    onSecondary = MarchColors.TextOnLight,
    tertiary = MarchColors.AccentTeal,
    onTertiary = MarchColors.TextPrimary,
    background = MarchColors.Background,
    onBackground = MarchColors.TextPrimary,
    surface = MarchColors.Surface,
    onSurface = MarchColors.TextPrimary,
    surfaceVariant = MarchColors.SurfaceAlt,
    onSurfaceVariant = MarchColors.TextSecondary,
    outline = MarchColors.TextSecondary,
    outlineVariant = MarchColors.HairlineStrong,
    error = MarchColors.DestructiveRed,
    onError = Color.White,
    scrim = Color.Black
)

@Composable
fun MarchTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = MarchDarkColorScheme,
        typography = MarchTypography,
        shapes = MarchShapes,
        content = content
    )
}
