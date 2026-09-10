package ai.newton.android.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * Newton Everforest & Sand palette. Direct port of Swift `NewtonTheme`
 * (ios/Newton/Utilities/Theme.swift) — same hex intent, no reinterpretation.
 */
object NewtonColors {
    // Canvas
    val BgDark = Color(0xFF1F2528)
    val BgLight = Color(0xFFFAF8F2)

    // Cards / surfaces
    val CardDark = Color(0xFF283136)
    val CardLight = Color(0xFFF0EBE3)
    val SurfaceDark = Color(0xFF333D42)
    val SurfaceLight = Color(0xFFE6E0D6)

    // Borders
    val BorderDark = Color(0xCC424E54)
    val BorderLight = Color(0xE6D1C9BC)

    // Accents
    val Sand = Color(0xFFE0BD80)
    val SandLight = Color(0xFFF2DBB3)
    val ForestGreen = Color(0xFFA7C080)
    val Aqua = Color(0xFF7FBBB3)
    val CoralRed = Color(0xFFE67E80)

    // Typography
    val TextPrimaryDark = Color(0xFFD9CFB8)
    val TextPrimaryLight = Color(0xFF262E33)
    val TextSecondaryDark = Color(0xFF94A197)
    val TextSecondaryLight = Color(0xFF7A857D)
    val TextMutedDark = Color(0xFF6B7570)
    val TextMutedLight = Color(0xFF9EA69E)

    val UserBubbleDark = Color(0xFFE0BD80)
    val UserBubbleLight = Color(0xFFE6CC9E)

    val GhostPurple = Color(0xFFBF8CF2)
}

private val NewtonDarkScheme: ColorScheme = darkColorScheme(
    background = NewtonColors.BgDark,
    onBackground = NewtonColors.TextPrimaryDark,
    surface = NewtonColors.CardDark,
    onSurface = NewtonColors.TextPrimaryDark,
    surfaceVariant = NewtonColors.SurfaceDark,
    onSurfaceVariant = NewtonColors.TextSecondaryDark,
    primary = NewtonColors.Sand,
    onPrimary = NewtonColors.BgDark,
    secondary = NewtonColors.Aqua,
    tertiary = NewtonColors.ForestGreen,
    error = NewtonColors.CoralRed,
    outline = NewtonColors.BorderDark,
)

private val NewtonLightScheme: ColorScheme = lightColorScheme(
    background = NewtonColors.BgLight,
    onBackground = NewtonColors.TextPrimaryLight,
    surface = NewtonColors.CardLight,
    onSurface = NewtonColors.TextPrimaryLight,
    surfaceVariant = NewtonColors.SurfaceLight,
    onSurfaceVariant = NewtonColors.TextSecondaryLight,
    primary = NewtonColors.Sand,
    onPrimary = NewtonColors.TextPrimaryLight,
    secondary = NewtonColors.Aqua,
    tertiary = NewtonColors.ForestGreen,
    error = NewtonColors.CoralRed,
    outline = NewtonColors.BorderLight,
)

@Composable
fun NewtonTheme(darkTheme: Boolean = true, content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (darkTheme) NewtonDarkScheme else NewtonLightScheme,
        content = content,
    )
}
