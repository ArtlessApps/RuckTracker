package com.artless.rucktracker.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val Sans = FontFamily.SansSerif

/**
 * Material slots mapped onto the iOS type scale so stock Material components
 * inherit the brand voice without per-call-site overrides.
 */
val MarchTypography = Typography(
    displayLarge = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Black,
        fontSize = 72.sp, lineHeight = 76.sp, letterSpacing = (-1.5).sp
    ),
    displayMedium = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Black,
        fontSize = 56.sp, lineHeight = 60.sp, letterSpacing = (-1).sp
    ),
    displaySmall = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Bold,
        fontSize = 44.sp, lineHeight = 48.sp, letterSpacing = (-0.5).sp
    ),
    headlineLarge = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Bold,
        fontSize = 34.sp, lineHeight = 40.sp, letterSpacing = (-0.5).sp
    ),
    headlineMedium = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Bold,
        fontSize = 26.sp, lineHeight = 32.sp, letterSpacing = (-0.4).sp
    ),
    headlineSmall = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Bold,
        fontSize = 22.sp, lineHeight = 28.sp, letterSpacing = (-0.2).sp
    ),
    titleLarge = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.SemiBold,
        fontSize = 20.sp, lineHeight = 26.sp
    ),
    titleMedium = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp, lineHeight = 22.sp
    ),
    titleSmall = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.SemiBold,
        fontSize = 15.sp, lineHeight = 20.sp
    ),
    bodyLarge = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Normal,
        fontSize = 16.sp, lineHeight = 24.sp
    ),
    bodyMedium = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Normal,
        fontSize = 15.sp, lineHeight = 21.sp
    ),
    bodySmall = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Normal,
        fontSize = 13.sp, lineHeight = 18.sp
    ),
    labelLarge = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.SemiBold,
        fontSize = 14.sp, lineHeight = 18.sp
    ),
    labelMedium = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.SemiBold,
        fontSize = 12.sp, lineHeight = 16.sp, letterSpacing = 0.6.sp
    ),
    labelSmall = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Bold,
        fontSize = 11.sp, lineHeight = 14.sp, letterSpacing = 1.sp
    )
)

/**
 * Brand-specific styles that have no natural Material slot: hero numerals,
 * all-caps eyebrows, tile titles and the wordmark.
 */
object MarchType {
    /** 36sp black — the "START RUCK" hero label. */
    val HeroTitle = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Black,
        fontSize = 36.sp, lineHeight = 40.sp, letterSpacing = (-0.5).sp
    )

    /** 24sp heavy all-caps — dashboard tile titles. */
    val TileTitle = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Black,
        fontSize = 24.sp, lineHeight = 28.sp, letterSpacing = (-0.3).sp
    )

    /** Oversized live metric, e.g. the active-workout timer. */
    val MetricHero = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Medium,
        fontSize = 76.sp, lineHeight = 80.sp, letterSpacing = (-2).sp
    )

    /** Large stat value on summary screens. */
    val MetricLarge = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Bold,
        fontSize = 44.sp, lineHeight = 48.sp, letterSpacing = (-1).sp
    )

    /** Compact stat value inside tiles. */
    val MetricMedium = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Bold,
        fontSize = 26.sp, lineHeight = 30.sp, letterSpacing = (-0.5).sp
    )

    /** 11sp heavy all-caps section label with wide tracking. */
    val Eyebrow = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Black,
        fontSize = 11.sp, lineHeight = 14.sp, letterSpacing = 1.4.sp
    )

    /** 13sp all-caps label used above metric values. */
    val StatLabel = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.SemiBold,
        fontSize = 12.sp, lineHeight = 16.sp, letterSpacing = 1.sp
    )

    /** The MARCH wordmark. */
    val Wordmark = TextStyle(
        fontFamily = Sans, fontWeight = FontWeight.Black,
        fontSize = 44.sp, lineHeight = 48.sp, letterSpacing = 6.sp
    )
}
