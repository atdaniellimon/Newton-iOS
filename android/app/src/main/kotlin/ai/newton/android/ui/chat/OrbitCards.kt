package ai.newton.android.ui.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Calculate
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material.icons.filled.Widgets
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ai.newton.android.theme.NewtonColors
import ai.newton.shared.OrbitExecutionResult

@Composable
fun OrbitCard(
    orbit: OrbitExecutionResult,
    modifier: Modifier = Modifier,
) {
    val (icon, titleColor) = when (orbit.orbitName.lowercase()) {
        "calculator", "calculate" -> Icons.Default.Calculate to NewtonColors.Sand
        "web_search", "search" -> Icons.Default.Public to NewtonColors.Aqua
        "current_time", "time" -> Icons.Default.Schedule to NewtonColors.SandLight
        "generate_image", "image" -> Icons.Default.Image to NewtonColors.Sand
        "exec_bash", "bash", "terminal" -> Icons.Default.Terminal to NewtonColors.ForestGreen
        else -> Icons.Default.Widgets to NewtonColors.Sand
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(NewtonColors.CardDark)
            .border(
                1.dp,
                if (orbit.isSuccess) NewtonColors.BorderDark else NewtonColors.CoralRed.copy(alpha = 0.6f),
                RoundedCornerShape(10.dp),
            )
            .padding(12.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = icon,
                    contentDescription = orbit.orbitName,
                    tint = titleColor,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "Orbit: ${orbit.orbitName}",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = FontFamily.Monospace,
                    ),
                    color = NewtonColors.TextPrimaryDark,
                )
            }

            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(
                        if (orbit.isSuccess) NewtonColors.ForestGreen.copy(alpha = 0.15f)
                        else NewtonColors.CoralRed.copy(alpha = 0.15f),
                    )
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            ) {
                Text(
                    text = if (orbit.isSuccess) "SUCCESS" else "FAILED",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    color = if (orbit.isSuccess) NewtonColors.ForestGreen else NewtonColors.CoralRed,
                )
            }
        }

        if (orbit.params.isNotBlank()) {
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = orbit.params,
                style = MaterialTheme.typography.bodySmall.copy(
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace,
                ),
                color = NewtonColors.TextSecondaryDark,
                maxLines = 3,
            )
        }

        if (orbit.result.isNotBlank()) {
            Spacer(modifier = Modifier.height(8.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(6.dp))
                    .background(Color.Black.copy(alpha = 0.45f))
                    .padding(8.dp),
            ) {
                val scrollState = rememberScrollState()
                Text(
                    text = orbit.result,
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontSize = 11.sp,
                        fontFamily = FontFamily.Monospace,
                    ),
                    color = if (orbit.isSuccess) NewtonColors.ForestGreen else NewtonColors.CoralRed,
                    modifier = Modifier.horizontalScroll(scrollState),
                )
            }
        }
    }
}
