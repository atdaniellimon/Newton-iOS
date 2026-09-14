package ai.newton.android.ui.components

import ai.newton.android.theme.NewtonColors
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

private data class ProjectedDot(
    val x: Float,
    val y: Float,
    val z: Float,
    val radius: Float,
    val alpha: Float,
    val isHighlight: Boolean,
)

/**
 * Android Jetpack Compose counterpart of Swift `ThinkingOrbView`
 * (ios/Newton/Views/Components/ThinkingOrbView.swift).
 *
 * Dotted 3D Thought-Orb with latitude/longitude rotation and scan beam.
 */
@Composable
fun ThinkingOrb(
    modifier: Modifier = Modifier,
    size: Dp = 32.dp,
) {
    val infiniteTransition = rememberInfiniteTransition(label = "orb_rotation")
    val time by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 6.2831853f * 4f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 12000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "orb_time",
    )

    Canvas(modifier = modifier.size(size)) {
        val cx = this.size.width / 2f
        val cy = this.size.height / 2f
        val sphereRadius = min(cx, cy) * 0.82f

        val rotY = (time * 0.95f).toDouble()
        val rotX = 0.35 + 0.08 * sin((time * 0.4f).toDouble())
        val scanPos = (time * 1.4f).toDouble()

        val sinY = sin(rotY); val cosY = cos(rotY)
        val sinX = sin(rotX); val cosX = cos(rotX)

        val latRings = 10
        val lonDensity = 20

        val dots = mutableListOf<ProjectedDot>()

        for (p in 0..latRings) {
            val lat = -Math.PI / 2.0 + (p.toDouble() / latRings.toDouble()) * Math.PI
            val cosLat = cos(lat); val sinLat = sin(lat)
            val count = max(1, (kotlin.math.abs(cosLat) * lonDensity).toInt())

            for (v in 0 until count) {
                val lon = (v.toDouble() / count.toDouble()) * 2.0 * Math.PI
                val x0 = cosLat * cos(lon)
                val y0 = sinLat
                val z0 = cosLat * sin(lon)

                val rx = x0 * cosX + z0 * sinX
                val rz = -x0 * sinX + z0 * cosX
                val ry = y0 * cosY - rz * sinY
                val rz2 = y0 * sinY + rz * cosY

                val depthFactor = ((rz2 + 1.0) / 2.0).toFloat()
                if (depthFactor <= 0.05f) continue

                val diff = atan2(sin(lon + rotY - scanPos), cos(lon + rotY - scanPos))
                val scanHighlight = (exp(-(diff * diff) / 0.22) * max(0.0, rz2)).toFloat()

                val px = cx + (rx * sphereRadius).toFloat()
                val py = cy - (ry * sphereRadius).toFloat()
                val rDot = (0.7f + 1.6f * depthFactor + scanHighlight * 1.5f) * (this.size.width / 64f)
                val alpha = (0.25f + 0.75f * depthFactor + scanHighlight * 0.6f).coerceIn(0.15f, 1f)

                dots.add(
                    ProjectedDot(
                        x = px,
                        y = py,
                        z = rz2.toFloat(),
                        radius = rDot,
                        alpha = alpha,
                        isHighlight = scanHighlight > 0.35f,
                    )
                )
            }
        }

        // Sort by depth
        dots.sortBy { it.z }

        for (dot in dots) {
            val color = if (dot.isHighlight) NewtonColors.SandLight else NewtonColors.Sand
            drawCircle(
                color = color.copy(alpha = dot.alpha),
                radius = dot.radius,
                center = Offset(dot.x, dot.y),
            )
        }
    }
}
