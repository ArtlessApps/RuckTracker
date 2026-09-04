package com.artless.rucktracker.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

val MarchShapes = Shapes(
    extraSmall = RoundedCornerShape(6.dp),
    small = RoundedCornerShape(10.dp),
    medium = RoundedCornerShape(14.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(20.dp)
)

/** Shared layout constants so screens stay on the same rhythm. */
object MarchDimens {
    /** Standard screen gutter. */
    val ScreenPadding = 20.dp

    /** Padding inside a card. */
    val CardPadding = 16.dp

    /** Vertical gap between stacked cards. */
    val CardGap = 12.dp

    /** Gap between major sections. */
    val SectionGap = 24.dp

    /** Height of the hero CTA. */
    val HeroHeight = 160.dp

    /** Height of a dashboard bento tile. */
    val TileHeight = 110.dp

    /** Vertical gap between dashboard bento tiles. */
    val TileGap = 16.dp

    /** Standard full-width button height. */
    val ButtonHeight = 56.dp

    /** Bottom scroll clearance so content clears the tab bar. */
    val TabBarClearance = 104.dp

    val IconBadge = 40.dp
}
