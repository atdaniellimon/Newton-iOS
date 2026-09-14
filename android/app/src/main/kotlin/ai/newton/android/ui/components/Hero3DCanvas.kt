package ai.newton.android.ui.components

import ai.newton.android.theme.NewtonColors
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import kotlin.math.cos
import kotlin.math.sin

/**
 * Android Jetpack Compose counterpart of Swift `Hero3DCanvasView`
 * (ios/Newton/Views/Components/Hero3DCanvasView.swift).
 *
 * 3D undulating kinetic wave grid matching Newton's signature background.
 */
@Composable
fun Hero3DCanvas(
    modifier: Modifier = Modifier,
    isDark: Boolean = true,
) {
    val infiniteTransition = rememberInfiniteTransition(label = "wave_motion")
    val time by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 6.2831853f * 4f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 18000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "time",
    )

    Canvas(modifier = modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height
        val cx = w / 2f
        val cy = h * 0.58f

        val rows = 28
        val cols = 26
        val gridSpacing = 34f
        val cameraHeight = 220f
        val fov = 380f

        val grid = Array(rows) { Array(cols) { Offset.Zero } }

        for (r in 0 until rows) {
            for (c in 0 until cols) {
                val xWorld = (c.toFloat() - cols.toFloat() / 2f) * gridSpacing
                val zWorld = r.toFloat() * gridSpacing + 30f

                val u = xWorld.toDouble() * 0.034
                val v = zWorld.toDouble() * 0.034
                val wave = sin(u + time.toDouble() * 0.8) * cos(v + time.toDouble() * 0.8) * 38.0
                val yWorld = wave.toFloat() - 12f

                val depth = zWorld
                if (depth <= 10f) continue
                val scale = fov / (fov + depth)

                val xProj = cx + xWorld * scale
                val yProj = cy + (cameraHeight - yWorld) * scale

                grid[r][c] = Offset(xProj, yProj)
            }
        }

        // Horizontal wave lines
        for (r in 0 until rows) {
            val path = Path()
            var started = false
            for (c in 0 until cols) {
                val pt = grid[r][c]
                if (pt != Offset.Zero) {
                    if (!started) {
                        path.moveTo(pt.x, pt.y)
                        started = true
                    } else {
                        path.lineTo(pt.x, pt.y)
                    }
                }
            }
            val depthRatio = 1f - r.toFloat() / rows.toFloat()
            val alpha = (depthRatio * (if (isDark) 0.35f else 0.28f)).coerceAtLeast(0.05f)
            val color = (if (isDark) NewtonColors.Sand else NewtonColors.TextSecondaryDark).copy(alpha = alpha)
            drawPath(path = path, color = color, style = Stroke(width = 1f))
        }

        // Vertical perspective lines
        for (c in 0 until cols) {
            val path = Path()
            var started = false
            for (r in 0 until rows) {
                val pt = grid[r][c]
                if (pt != Offset.Zero) {
                    if (!started) {
                        path.moveTo(pt.x, pt.y)
                        started = true
                    } else {
                        path.lineTo(pt.x, pt.y)
                    }
                }
            }
            val alpha = if (isDark) 0.12f else 0.09f
            val color = (if (isDark) NewtonColors.Aqua else NewtonColors.TextMutedDark).copy(alpha = alpha)
            drawPath(path = path, color = color, style = Stroke(width = 0.8f))
        }
    }
}
