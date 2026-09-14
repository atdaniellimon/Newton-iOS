package ai.newton.android.ui.chat

import ai.newton.android.theme.NewtonColors
import ai.newton.android.ui.components.ThinkingOrb
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CallEnd
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Android Jetpack Compose counterpart of Swift `VoiceCallView`
 * (ios/Newton/Views/Chat/VoiceCallView.swift).
 *
 * Immersive full-screen Live Voice Call with pulsating reactive 3D Orb.
 */
@Composable
fun VoiceCallScreen(
    conversationTitle: String,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var isMuted by remember { mutableStateOf(false) }
    var isProcessing by remember { mutableStateOf(false) }
    var callStatus by remember { mutableStateOf("Escuchando...") }
    var transcriptText by remember { mutableStateOf("Hola Newton, ¿puedes resumirme los avances recientes?") }
    var responseText by remember { mutableStateOf("Con gusto. En 2025 y 2026, los reactores de fusión han logrado hitos históricos...") }

    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = 1.18f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1400, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "halo_pulse",
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFF0F1416)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Top Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column {
                    Text(
                        text = "NEWTON LLAMADA EN VIVO",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 1.5.sp,
                        ),
                        color = NewtonColors.Sand,
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = callStatus,
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.8f),
                    )
                }

                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.1f)),
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = Color.White,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // Central Glowing Orb
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier.size(260.dp),
            ) {
                // Pulsing radial glow halo
                Box(
                    modifier = Modifier
                        .size(260.dp)
                        .scale(if (!isMuted) pulseScale else 1f)
                        .clip(CircleShape)
                        .background(
                            Brush.radialGradient(
                                colors = listOf(
                                    NewtonColors.Sand.copy(alpha = 0.30f),
                                    NewtonColors.Sand.copy(alpha = 0.08f),
                                    Color.Transparent,
                                ),
                            ),
                        ),
                )

                // 3D Dotted Thought Orb
                ThinkingOrb(
                    size = 180.dp,
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Subtitle Card / Transcript
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.White.copy(alpha = 0.05f))
                    .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(16.dp))
                    .padding(18.dp),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (isProcessing) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            CircularProgressIndicator(
                                color = NewtonColors.Sand,
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp,
                            )
                            Text(
                                text = "Newton formulando razonamiento...",
                                style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Serif),
                                color = NewtonColors.Sand,
                            )
                        }
                    } else {
                        Text(
                            text = responseText,
                            style = MaterialTheme.typography.bodyMedium.copy(
                                lineHeight = 20.sp,
                            ),
                            color = Color.White.copy(alpha = 0.9f),
                            maxLines = 3,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(28.dp))

            // Controls Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 20.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Mute Button
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(if (isMuted) NewtonColors.CoralRed.copy(alpha = 0.2f) else Color.White.copy(alpha = 0.12f))
                        .clickable {
                            isMuted = !isMuted
                            callStatus = if (isMuted) "Micrófono silenciado" else "Escuchando..."
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = if (isMuted) Icons.Default.MicOff else Icons.Default.Mic,
                        contentDescription = "Mute",
                        tint = if (isMuted) NewtonColors.CoralRed else Color.White,
                        modifier = Modifier.size(24.dp),
                    )
                }

                // End Call Button
                Box(
                    modifier = Modifier
                        .size(68.dp)
                        .clip(CircleShape)
                        .background(NewtonColors.CoralRed)
                        .clickable(onClick = onDismiss),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.CallEnd,
                        contentDescription = "End Call",
                        tint = Color.White,
                        modifier = Modifier.size(30.dp),
                    )
                }
            }
        }
    }
}
