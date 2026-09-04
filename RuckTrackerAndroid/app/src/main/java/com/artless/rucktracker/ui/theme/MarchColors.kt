package com.artless.rucktracker.ui.theme

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

/**
 * Canonical MARCH palette, mirroring `AppColors.swift` on iOS so both platforms
 * render the same brand. Prefer these tokens over ad-hoc [Color] literals.
 */
object MarchColors {
    // Base surfaces
    val Background = Color(0xFF000000)
    val BackgroundNavy = Color(0xFF052035)
    val Surface = Color(0xFF0F2942)
    val SurfaceAlt = Color(0xFF1A3A5A)

    // Text
    val TextPrimary = Color.White
    val TextSecondary = Color(0xFF8CA6C1)
    val TextOnLight = Color(0xFF021223)

    // Brand
    val Primary = Color(0xFF00C896)
    val PrimaryLight = Color(0xFF00E08F)
    val PrimaryMid = Color(0xFF007A6E)
    val PrimaryDeep = Color(0xFF005F56)
    val AccentGreen = Color(0xFF00C4B4)
    val AccentGreenLight = Color(0xFF33E6A3)
    val AccentTeal = Color(0xFF005F73)
    val AccentWarm = Color(0xFFE06C00)

    // Status
    val PauseOrange = Color(0xFFFF9500)
    val SuccessGreen = Color(0xFF34C759)
    val DestructiveRed = Color(0xFFFF3B30)

    // Per-destination tile accents
    val TileBlue = Color(0xFF4A9FD9)
    val TileGold = Color(0xFFD4A844)
    val TilePurple = Color(0xFF9B6BD4)

    // Podium
    val RankGold = Color(0xFFFFC93C)
    val RankSilver = Color(0xFFB8C4D0)
    val RankBronze = Color(0xFFCD7F32)

    // Hairlines and scrims, expressed as overlays so they compose over any surface
    val HairlineLight = Color(0x14FFFFFF)
    val HairlineStrong = Color(0x1FFFFFFF)
    val FillSubtle = Color(0x0DFFFFFF)
    val FillMuted = Color(0x1AFFFFFF)

    /** Base app backdrop: navy at the top fading to pure black at the bottom. */
    val BackgroundGradient = Brush.verticalGradient(
        colors = listOf(BackgroundNavy, Background)
    )

    /** Primary CTA fill. */
    val PrimaryGradient = Brush.horizontalGradient(
        colors = listOf(PrimaryLight, AccentGreen)
    )

    /** Three-stop diagonal fill used by the hero "START RUCK" button. */
    val HeroGradient = Brush.linearGradient(
        colors = listOf(Primary, PrimaryMid, PrimaryDeep)
    )

    /** Slightly lifted card fill, giving cards depth against the black backdrop. */
    val SurfaceGradient = Brush.verticalGradient(
        colors = listOf(Color(0xFF12314D), Surface)
    )

    fun tint(color: Color, alpha: Float): Color = color.copy(alpha = alpha)
}
