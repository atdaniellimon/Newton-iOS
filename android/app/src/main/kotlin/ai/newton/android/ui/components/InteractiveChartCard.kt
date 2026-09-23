package ai.newton.android.ui.components

import ai.newton.android.theme.NewtonColors
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class ChartDataPoint(
    val label: String,
    val value: Double,
)

@Serializable
data class InteractiveChartPayload(
    val title: String,
    val chartType: String = "bar",
    val data: List<ChartDataPoint>,
)

/**
 * Android Jetpack Compose counterpart of Swift `InteractiveChartView`
 * (ios/Newton/Views/Components/InteractiveChartView.swift).
 */
@Composable
fun InteractiveChartCard(
    payload: InteractiveChartPayload,
    modifier: Modifier = Modifier,
) {
    val maxValue = remember(payload.data) {
        val maxVal = payload.data.maxOfOrNull { it.value } ?: 1.0
        if (maxVal <= 0.0) 1.0 else maxVal
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(NewtonColors.CardDark)
            .border(0.8.dp, NewtonColors.BorderDark.copy(alpha = 0.6f), RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.BarChart,
                    contentDescription = null,
                    tint = NewtonColors.Sand,
                    modifier = Modifier.size(16.dp),
                )
                Text(
                    text = payload.title,
                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                    color = NewtonColors.Sand,
                )
            }

            Text(
                text = payload.chartType.uppercase(),
                style = MaterialTheme.typography.labelSmall.copy(
                    fontFamily = FontFamily.Monospace,
                    fontSize = 10.sp,
                ),
                color = NewtonColors.TextSecondaryDark,
            )
        }

        // Bar Columns
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(130.dp)
                .padding(top = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            for (dp in payload.data) {
                val heightPercent = ((dp.value / maxValue).coerceIn(0.05, 1.0)).toFloat()
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Bottom,
                ) {
                    Text(
                        text = if (dp.value % 1.0 == 0.0) dp.value.toInt().toString() else String.format("%.1f", dp.value),
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold,
                            fontSize = 9.sp,
                        ),
                        color = NewtonColors.Sand,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(0.7f)
                            .height((heightPercent * 85).dp)
                            .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                            .background(
                                Brush.verticalGradient(
                                    colors = listOf(NewtonColors.Sand, NewtonColors.ForestGreen)
                                )
                            ),
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = dp.label,
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                        color = NewtonColors.TextSecondaryDark,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

object InteractiveChartParser {
    private val json = Json { ignoreUnknownKeys = true }
    private val chartRegex = Regex("```chart\\s*([\\s\\S]*?)\\s*```")

    fun extractChartData(text: String): InteractiveChartPayload? {
        val match = chartRegex.find(text) ?: return null
        val jsonStr = match.groups[1]?.value?.trim() ?: return null
        return try {
            json.decodeFromString<InteractiveChartPayload>(jsonStr)
        } catch (_: Exception) {
            null
        }
    }
}
