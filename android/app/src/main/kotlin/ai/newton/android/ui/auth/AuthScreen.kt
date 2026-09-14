package ai.newton.android.ui.auth

import ai.newton.android.data.AuthManager
import ai.newton.android.theme.NewtonColors
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

private enum class AuthMode { LOGIN, REGISTER }

@Composable
fun AuthScreen(
    authManager: AuthManager,
    onAuthSuccess: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    val isLoading by authManager.isLoading.collectAsState()
    val lastError by authManager.lastError.collectAsState()

    var mode by remember { mutableStateOf(AuthMode.LOGIN) }
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var passwordConfirm by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }

    val shakeOffset = remember { Animatable(0f) }

    fun triggerShake() {
        scope.launch {
            for (i in 0..3) {
                shakeOffset.animateTo(-16f, tween(40))
                shakeOffset.animateTo(16f, tween(40))
            }
            shakeOffset.animateTo(0f, tween(40))
        }
    }

    fun submit() {
        val trimUser = username.trim()
        if (trimUser.isEmpty() || password.isEmpty()) return

        scope.launch {
            if (mode == AuthMode.REGISTER) {
                if (password != passwordConfirm) {
                    triggerShake()
                    return@launch
                }
                if (password.length < 8) {
                    triggerShake()
                    return@launch
                }
                val ok = authManager.register(username = trimUser, password = password)
                if (ok) onAuthSuccess() else triggerShake()
            } else {
                val ok = authManager.login(username = trimUser, password = password)
                if (ok) onAuthSuccess() else triggerShake()
            }
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black),
    ) {
        // Subtle gradient overlay matching iOS
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF0D141F).copy(alpha = 0.85f),
                            Color.Black.copy(alpha = 0.3f),
                        ),
                    ),
                ),
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Spacer(modifier = Modifier.height(40.dp))

            // Logo + Branding (Animated Glowing Orb)
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier.padding(bottom = 36.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(100.dp)
                        .background(
                            Brush.radialGradient(
                                colors = listOf(
                                    NewtonColors.Sand.copy(alpha = 0.35f),
                                    NewtonColors.Sand.copy(alpha = 0.10f),
                                    Color.Transparent,
                                ),
                            ),
                            shape = CircleShape,
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.AutoAwesome,
                        contentDescription = "Newton",
                        tint = NewtonColors.Sand,
                        modifier = Modifier.size(46.dp),
                    )
                }

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "Newton",
                        style = MaterialTheme.typography.headlineMedium.copy(
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Serif,
                        ),
                        color = Color.White,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "SINGULARITY",
                        style = MaterialTheme.typography.labelSmall.copy(
                            letterSpacing = 4.sp,
                            fontWeight = FontWeight.SemiBold,
                        ),
                        color = NewtonColors.Sand.copy(alpha = 0.85f),
                    )
                }
            }

            // Auth Card
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .offset { IntOffset(shakeOffset.value.roundToInt(), 0) }
                    .clip(RoundedCornerShape(24.dp))
                    .background(Color.White.copy(alpha = 0.04f))
                    .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(24.dp))
                    .padding(24.dp),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                    // Mode Toggle: Sign In / Create Account
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color.White.copy(alpha = 0.06f))
                            .padding(4.dp),
                    ) {
                        // Sign In
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(10.dp))
                                .background(
                                    if (mode == AuthMode.LOGIN) {
                                        Brush.horizontalGradient(
                                            listOf(NewtonColors.Sand, NewtonColors.SandLight),
                                        )
                                    } else {
                                        Brush.horizontalGradient(listOf(Color.Transparent, Color.Transparent))
                                    },
                                )
                                .clickable { mode = AuthMode.LOGIN }
                                .padding(vertical = 12.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = "Iniciar sesión",
                                style = MaterialTheme.typography.bodyMedium.copy(
                                    fontWeight = if (mode == AuthMode.LOGIN) FontWeight.Bold else FontWeight.Medium,
                                ),
                                color = if (mode == AuthMode.LOGIN) Color.Black else Color.White.copy(alpha = 0.65f),
                            )
                        }

                        // Create Account
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(10.dp))
                                .background(
                                    if (mode == AuthMode.REGISTER) {
                                        Brush.horizontalGradient(
                                            listOf(NewtonColors.Sand, NewtonColors.SandLight),
                                        )
                                    } else {
                                        Brush.horizontalGradient(listOf(Color.Transparent, Color.Transparent))
                                    },
                                )
                                .clickable { mode = AuthMode.REGISTER }
                                .padding(vertical = 12.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = "Crear cuenta",
                                style = MaterialTheme.typography.bodyMedium.copy(
                                    fontWeight = if (mode == AuthMode.REGISTER) FontWeight.Bold else FontWeight.Medium,
                                ),
                                color = if (mode == AuthMode.REGISTER) Color.Black else Color.White.copy(alpha = 0.65f),
                            )
                        }
                    }

                    // Fields
                    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        // Username
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                text = "Usuario o correo",
                                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
                                color = Color.White.copy(alpha = 0.65f),
                            )
                            TextField(
                                value = username,
                                onValueChange = { username = it },
                                placeholder = { Text("developer_dan", color = Color.White.copy(alpha = 0.3f)) },
                                singleLine = true,
                                leadingIcon = {
                                    Icon(
                                        imageVector = Icons.Default.Person,
                                        contentDescription = null,
                                        tint = NewtonColors.Sand.copy(alpha = 0.7f),
                                        modifier = Modifier.size(18.dp),
                                    )
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(12.dp)),
                                colors = TextFieldDefaults.colors(
                                    focusedContainerColor = Color.White.copy(alpha = 0.07f),
                                    unfocusedContainerColor = Color.White.copy(alpha = 0.07f),
                                    focusedTextColor = Color.White,
                                    unfocusedTextColor = Color.White,
                                    focusedIndicatorColor = Color.Transparent,
                                    unfocusedIndicatorColor = Color.Transparent,
                                ),
                            )
                        }

                        // Password
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                text = "Contraseña",
                                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
                                color = Color.White.copy(alpha = 0.65f),
                            )
                            TextField(
                                value = password,
                                onValueChange = { password = it },
                                placeholder = { Text("••••••••", color = Color.White.copy(alpha = 0.3f)) },
                                singleLine = true,
                                visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                                leadingIcon = {
                                    Icon(
                                        imageVector = Icons.Default.Lock,
                                        contentDescription = null,
                                        tint = NewtonColors.Sand.copy(alpha = 0.7f),
                                        modifier = Modifier.size(18.dp),
                                    )
                                },
                                trailingIcon = {
                                    IconButton(onClick = { showPassword = !showPassword }) {
                                        Icon(
                                            imageVector = if (showPassword) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                            contentDescription = null,
                                            tint = Color.White.copy(alpha = 0.45f),
                                            modifier = Modifier.size(18.dp),
                                        )
                                    }
                                },
                                keyboardOptions = KeyboardOptions(imeAction = if (mode == AuthMode.LOGIN) ImeAction.Done else ImeAction.Next),
                                keyboardActions = KeyboardActions(onDone = { submit() }),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(12.dp)),
                                colors = TextFieldDefaults.colors(
                                    focusedContainerColor = Color.White.copy(alpha = 0.07f),
                                    unfocusedContainerColor = Color.White.copy(alpha = 0.07f),
                                    focusedTextColor = Color.White,
                                    unfocusedTextColor = Color.White,
                                    focusedIndicatorColor = Color.Transparent,
                                    unfocusedIndicatorColor = Color.Transparent,
                                ),
                            )
                        }

                        // Password confirm (Register mode only)
                        AnimatedVisibility(
                            visible = mode == AuthMode.REGISTER,
                            enter = fadeIn(),
                            exit = fadeOut(),
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(
                                    text = "Confirmar contraseña",
                                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
                                    color = Color.White.copy(alpha = 0.65f),
                                )
                                TextField(
                                    value = passwordConfirm,
                                    onValueChange = { passwordConfirm = it },
                                    placeholder = { Text("••••••••", color = Color.White.copy(alpha = 0.3f)) },
                                    singleLine = true,
                                    visualTransformation = PasswordVisualTransformation(),
                                    leadingIcon = {
                                        Icon(
                                            imageVector = Icons.Default.Lock,
                                            contentDescription = null,
                                            tint = NewtonColors.Sand.copy(alpha = 0.7f),
                                            modifier = Modifier.size(18.dp),
                                        )
                                    },
                                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                                    keyboardActions = KeyboardActions(onDone = { submit() }),
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(12.dp)),
                                    colors = TextFieldDefaults.colors(
                                        focusedContainerColor = Color.White.copy(alpha = 0.07f),
                                        unfocusedContainerColor = Color.White.copy(alpha = 0.07f),
                                        focusedTextColor = Color.White,
                                        unfocusedTextColor = Color.White,
                                        focusedIndicatorColor = Color.Transparent,
                                        unfocusedIndicatorColor = Color.Transparent,
                                    ),
                                )
                            }
                        }
                    }

                    // Error banner
                    lastError?.let { err ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(Color.Red.copy(alpha = 0.12f))
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Default.Warning,
                                contentDescription = null,
                                tint = Color(0xFFFF6B6B),
                                modifier = Modifier.size(16.dp),
                            )
                            Text(
                                text = err,
                                color = Color(0xFFFF6B6B),
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                    }

                    // Action Button
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(
                                Brush.horizontalGradient(
                                    listOf(NewtonColors.Sand, NewtonColors.SandLight),
                                ),
                            )
                            .clickable(enabled = !isLoading && username.isNotBlank() && password.isNotBlank()) {
                                submit()
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (isLoading) {
                            CircularProgressIndicator(
                                color = Color.Black,
                                modifier = Modifier.size(24.dp),
                                strokeWidth = 2.5.dp,
                            )
                        } else {
                            Text(
                                text = if (mode == AuthMode.LOGIN) "Iniciar sesión" else "Crear cuenta",
                                style = MaterialTheme.typography.bodyLarge.copy(
                                    fontWeight = FontWeight.SemiBold,
                                ),
                                color = Color.Black,
                            )
                        }
                    }

                    // Trial info (register mode only)
                    if (mode == AuthMode.REGISTER) {
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(2.dp),
                        ) {
                            Text(
                                text = "30 días de prueba gratis",
                                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
                                color = NewtonColors.Sand,
                            )
                            Text(
                                text = "$100 MXN/mes después",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color.White.copy(alpha = 0.4f),
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(40.dp))

            // Footer
            Text(
                text = "Newton Labs © 2026",
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
                color = Color.White.copy(alpha = 0.25f),
            )

            Spacer(modifier = Modifier.height(20.dp))
        }
    }
}
