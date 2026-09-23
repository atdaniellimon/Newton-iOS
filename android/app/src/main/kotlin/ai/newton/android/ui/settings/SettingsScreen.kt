package ai.newton.android.ui.settings

import ai.newton.android.data.AuthManager
import ai.newton.android.data.SettingsRepository
import ai.newton.android.theme.NewtonColors
import ai.newton.android.ui.components.Hero3DCanvas
import ai.newton.shared.SingularityPrompt
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Logout
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Vibration
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

/**
 * Android Jetpack Compose counterpart of Swift `SettingsView`
 * (ios/Newton/Views/Settings/SettingsView.swift).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    authManager: AuthManager,
    settings: SettingsRepository,
    onBack: () -> Unit,
    onLogout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()

    val username by authManager.username.collectAsState()
    val email by authManager.email.collectAsState()
    val tier by authManager.tier.collectAsState()
    val creditsRemaining by authManager.creditsRemaining.collectAsState()
    val creditsTotal by authManager.creditsTotal.collectAsState()
    val quotaReq5h by authManager.quotaReq5h.collectAsState()
    val quotaMsgsWeek by authManager.quotaMsgsWeek.collectAsState()
    val quotaTokensWeek by authManager.quotaTokensWeek.collectAsState()
    val isRotatingKey by authManager.isRotatingKey.collectAsState()
    val lastRotationMessage by authManager.lastKeyRotationMessage.collectAsState()

    val currentModelId by settings.modelId.collectAsState(initial = "Singularity")

    var showLogoutDialog by remember { mutableStateOf(false) }
    var showRotateKeyDialog by remember { mutableStateOf(false) }
    var showModelSelectorDialog by remember { mutableStateOf(false) }
    var hapticsEnabled by remember { mutableStateOf(true) }
    var temperature by remember { mutableFloatStateOf(0.7f) }

    LaunchedEffect(Unit) {
        authManager.refreshUserInfo()
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = NewtonColors.BgDark,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Ajustes",
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Serif,
                        ),
                        color = NewtonColors.TextPrimaryDark,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = NewtonColors.Sand,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = NewtonColors.BgDark,
                ),
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            Hero3DCanvas(isDark = true, modifier = Modifier.fillMaxSize())

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                // MARK: - Account & Profile Card
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "CUENTA Y SUSCRIPCIÓN",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp,
                            letterSpacing = 1.sp,
                        ),
                        color = NewtonColors.TextMutedDark,
                    )

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(NewtonColors.CardDark)
                            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(16.dp))
                            .padding(16.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            // User Info Row
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween,
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(44.dp)
                                            .clip(CircleShape)
                                            .background(NewtonColors.SurfaceDark),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Person,
                                            contentDescription = null,
                                            tint = NewtonColors.Sand,
                                            modifier = Modifier.size(24.dp),
                                        )
                                    }
                                    Column {
                                        Text(
                                            text = username.ifEmpty { "Usuario" },
                                            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold),
                                            color = NewtonColors.TextPrimaryDark,
                                        )
                                        if (email.isNotEmpty()) {
                                            Text(
                                                text = email,
                                                style = MaterialTheme.typography.bodySmall,
                                                color = NewtonColors.TextSecondaryDark,
                                            )
                                        }
                                    }
                                }

                                // Tier Badge
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(NewtonColors.Sand.copy(alpha = 0.2f))
                                        .border(1.dp, NewtonColors.Sand.copy(alpha = 0.5f), RoundedCornerShape(8.dp))
                                        .padding(horizontal = 10.dp, vertical = 5.dp),
                                ) {
                                    Text(
                                        text = tier.name.uppercase(),
                                        style = MaterialTheme.typography.labelSmall.copy(
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 10.sp,
                                        ),
                                        color = NewtonColors.Sand,
                                    )
                                }
                            }

                            HorizontalDivider(color = NewtonColors.BorderDark.copy(alpha = 0.5f))

                            // Token Credits
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                ) {
                                    Text(
                                        text = "Créditos de tokens restantes",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = NewtonColors.TextSecondaryDark,
                                    )
                                    Text(
                                        text = "$creditsRemaining / $creditsTotal",
                                        style = MaterialTheme.typography.labelSmall.copy(
                                            fontFamily = FontFamily.Monospace,
                                            fontWeight = FontWeight.Bold,
                                        ),
                                        color = NewtonColors.TextPrimaryDark,
                                    )
                                }
                                val creditsProgress = if (creditsTotal > 0) (creditsRemaining.toFloat() / creditsTotal.toFloat()).coerceIn(0f, 1f) else 0f
                                LinearProgressIndicator(
                                    progress = { creditsProgress },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(6.dp)
                                        .clip(RoundedCornerShape(3.dp)),
                                    color = NewtonColors.Sand,
                                    trackColor = NewtonColors.SurfaceDark,
                                )
                            }
                        }
                    }
                }

                // MARK: - Quota Limits
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "VENTANAS DE CUOTAS Y LÍMITES",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp,
                            letterSpacing = 1.sp,
                        ),
                        color = NewtonColors.TextMutedDark,
                    )

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(NewtonColors.CardDark)
                            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(16.dp))
                            .padding(16.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            // 5-Hour Limit
                            QuotaBarItem(
                                title = "Solicitudes en ventana de 5 horas",
                                used = quotaReq5h.used,
                                limit = quotaReq5h.limit,
                                percent = quotaReq5h.percent,
                            )

                            // Weekly Messages
                            QuotaBarItem(
                                title = "Mensajes semanales",
                                used = quotaMsgsWeek.used,
                                limit = quotaMsgsWeek.limit,
                                percent = quotaMsgsWeek.percent,
                            )

                            // Weekly Tokens
                            QuotaBarItem(
                                title = "Tokens semanales",
                                used = quotaTokensWeek.used,
                                limit = quotaTokensWeek.limit,
                                percent = quotaTokensWeek.percent,
                            )
                        }
                    }
                }

                // MARK: - Security & API Key
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "SEGURIDAD Y CLAVE API",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp,
                            letterSpacing = 1.sp,
                        ),
                        color = NewtonColors.TextMutedDark,
                    )

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(NewtonColors.CardDark)
                            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(16.dp))
                            .padding(16.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Key,
                                        contentDescription = null,
                                        tint = NewtonColors.Sand,
                                        modifier = Modifier.size(20.dp),
                                    )
                                    Column {
                                        Text(
                                            text = "Clave API de Newton",
                                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                            color = NewtonColors.TextPrimaryDark,
                                        )
                                        val key = authManager.nwtnKey
                                        Text(
                                            text = if (key.length > 12) "${key.take(8)}••••••••${key.takeLast(4)}" else "••••••••",
                                            style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                                            color = NewtonColors.TextMutedDark,
                                        )
                                    }
                                }

                                Button(
                                    onClick = { showRotateKeyDialog = true },
                                    enabled = !isRotatingKey,
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = NewtonColors.SurfaceDark,
                                        contentColor = NewtonColors.Sand,
                                    ),
                                    shape = RoundedCornerShape(8.dp),
                                ) {
                                    if (isRotatingKey) {
                                        CircularProgressIndicator(
                                            color = NewtonColors.Sand,
                                            modifier = Modifier.size(16.dp),
                                            strokeWidth = 2.dp,
                                        )
                                    } else {
                                        Text("Rotar", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }

                            if (!lastRotationMessage.isNullOrEmpty()) {
                                Text(
                                    text = lastRotationMessage.orEmpty(),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = NewtonColors.ForestGreen,
                                )
                            }
                        }
                    }
                }

                // MARK: - Model & AI Configuration
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "MODELO DE INTELIGENCIA ARTIFICIAL",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp,
                            letterSpacing = 1.sp,
                        ),
                        color = NewtonColors.TextMutedDark,
                    )

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(NewtonColors.CardDark)
                            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(16.dp))
                            .padding(16.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            // Model selector row with modal dialog trigger
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { showModelSelectorDialog = true },
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Column {
                                    Text(
                                        text = "Modelo Principal",
                                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                        color = NewtonColors.TextPrimaryDark,
                                    )
                                    Text(
                                        text = if (currentModelId == "Singularity-Matrix") "Especialista en código y arquitectura" else "Razonamiento general y visión",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = NewtonColors.TextSecondaryDark,
                                    )
                                }
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                                ) {
                                    Text(
                                        text = currentModelId,
                                        style = MaterialTheme.typography.labelSmall.copy(
                                            fontFamily = FontFamily.Monospace,
                                            fontWeight = FontWeight.Bold,
                                        ),
                                        color = NewtonColors.Sand,
                                    )
                                    Icon(
                                        imageVector = Icons.Default.KeyboardArrowRight,
                                        contentDescription = null,
                                        tint = NewtonColors.TextMutedDark,
                                        modifier = Modifier.size(16.dp),
                                    )
                                }
                            }

                            HorizontalDivider(color = NewtonColors.BorderDark.copy(alpha = 0.5f))

                            // Temperature slider
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                ) {
                                    Text(
                                        text = "Temperatura de Razonamiento",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = NewtonColors.TextSecondaryDark,
                                    )
                                    Text(
                                        text = String.format("%.2f", temperature),
                                        style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                                        color = NewtonColors.Sand,
                                    )
                                }
                                Slider(
                                    value = temperature,
                                    onValueChange = { temperature = it },
                                    valueRange = 0.0f..1.0f,
                                    colors = SliderDefaults.colors(
                                        thumbColor = NewtonColors.Sand,
                                        activeTrackColor = NewtonColors.Sand,
                                        inactiveTrackColor = NewtonColors.SurfaceDark,
                                    ),
                                )
                            }
                        }
                    }
                }

                // MARK: - App Preferences & Haptics
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "PREFERENCIAS DE APLICACIÓN",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp,
                            letterSpacing = 1.sp,
                        ),
                        color = NewtonColors.TextMutedDark,
                    )

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(NewtonColors.CardDark)
                            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(16.dp))
                            .padding(16.dp),
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            // Haptic Feedback Switch
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Vibration,
                                        contentDescription = null,
                                        tint = NewtonColors.Sand,
                                        modifier = Modifier.size(20.dp),
                                    )
                                    Column {
                                        Text(
                                            text = "Vibración y Háptica",
                                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                            color = NewtonColors.TextPrimaryDark,
                                        )
                                        Text(
                                            text = "Respuesta táctil al pulsar y enviar",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = NewtonColors.TextSecondaryDark,
                                        )
                                    }
                                }
                                Switch(
                                    checked = hapticsEnabled,
                                    onCheckedChange = { hapticsEnabled = it },
                                    colors = SwitchDefaults.colors(
                                        checkedThumbColor = NewtonColors.BgDark,
                                        checkedTrackColor = NewtonColors.Sand,
                                        uncheckedThumbColor = NewtonColors.TextMutedDark,
                                        uncheckedTrackColor = NewtonColors.SurfaceDark,
                                    ),
                                )
                            }
                        }
                    }
                }

                // MARK: - Logout Button
                Button(
                    onClick = { showLogoutDialog = true },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = NewtonColors.CoralRed.copy(alpha = 0.15f),
                        contentColor = NewtonColors.CoralRed,
                    ),
                ) {
                    Icon(
                        imageVector = Icons.Default.Logout,
                        contentDescription = "Logout",
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Cerrar sesión",
                        fontWeight = FontWeight.Bold,
                    )
                }

                Spacer(modifier = Modifier.height(20.dp))
            }

            // Model Selection Dialog
            if (showModelSelectorDialog) {
                AlertDialog(
                    onDismissRequest = { showModelSelectorDialog = false },
                    title = {
                        Text(
                            text = "Seleccionar Modelo",
                            fontWeight = FontWeight.Bold,
                            color = NewtonColors.TextPrimaryDark,
                        )
                    },
                    text = {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            // Option 1: Singularity
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(if (currentModelId == "Singularity") NewtonColors.Sand.copy(alpha = 0.12f) else Color.Transparent)
                                    .clickable {
                                        scope.launch { settings.setModelId("Singularity") }
                                        showModelSelectorDialog = false
                                    }
                                    .padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                RadioButton(
                                    selected = currentModelId == "Singularity",
                                    onClick = {
                                        scope.launch { settings.setModelId("Singularity") }
                                        showModelSelectorDialog = false
                                    },
                                    colors = RadioButtonDefaults.colors(selectedColor = NewtonColors.Sand),
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text("Newton Singularity", fontWeight = FontWeight.Bold, color = NewtonColors.TextPrimaryDark)
                                    Text("Razonamiento general, multimodal y visión", style = MaterialTheme.typography.bodySmall, color = NewtonColors.TextSecondaryDark)
                                }
                            }

                            // Option 2: Singularity-Matrix
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(if (currentModelId == "Singularity-Matrix") NewtonColors.Aqua.copy(alpha = 0.12f) else Color.Transparent)
                                    .clickable {
                                        scope.launch { settings.setModelId("Singularity-Matrix") }
                                        showModelSelectorDialog = false
                                    }
                                    .padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                RadioButton(
                                    selected = currentModelId == "Singularity-Matrix",
                                    onClick = {
                                        scope.launch { settings.setModelId("Singularity-Matrix") }
                                        showModelSelectorDialog = false
                                    },
                                    colors = RadioButtonDefaults.colors(selectedColor = NewtonColors.Aqua),
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text("Singularity-Matrix", fontWeight = FontWeight.Bold, color = NewtonColors.TextPrimaryDark)
                                    Text("Especialista en código, terminal y workspaces", style = MaterialTheme.typography.bodySmall, color = NewtonColors.TextSecondaryDark)
                                }
                            }
                        }
                    },
                    confirmButton = {
                        Button(
                            onClick = { showModelSelectorDialog = false },
                            colors = ButtonDefaults.buttonColors(containerColor = NewtonColors.Sand, contentColor = Color.Black),
                        ) {
                            Text("Aceptar", fontWeight = FontWeight.Bold)
                        }
                    },
                    containerColor = NewtonColors.SurfaceDark,
                )
            }

            // Rotate Key Confirmation Dialog
            if (showRotateKeyDialog) {
                AlertDialog(
                    onDismissRequest = { showRotateKeyDialog = false },
                    title = {
                        Text(
                            text = "¿Rotar clave API?",
                            fontWeight = FontWeight.Bold,
                            color = NewtonColors.TextPrimaryDark,
                        )
                    },
                    text = {
                        Text(
                            text = "Se revocará la clave activa actual y se generará una nueva inmediatamente bajo tu cuenta y cuota.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = NewtonColors.TextSecondaryDark,
                        )
                    },
                    confirmButton = {
                        Button(
                            onClick = {
                                showRotateKeyDialog = false
                                scope.launch {
                                    authManager.rotateApiKey()
                                }
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = NewtonColors.Sand,
                                contentColor = Color.Black,
                            ),
                        ) {
                            Text("Rotar Clave", fontWeight = FontWeight.Bold)
                        }
                    },
                    dismissButton = {
                        OutlinedButton(onClick = { showRotateKeyDialog = false }) {
                            Text("Cancelar", color = NewtonColors.TextSecondaryDark)
                        }
                    },
                    containerColor = NewtonColors.SurfaceDark,
                )
            }

            // Logout Confirmation Dialog
            if (showLogoutDialog) {
                AlertDialog(
                    onDismissRequest = { showLogoutDialog = false },
                    title = {
                        Text(
                            text = "¿Cerrar Sesión?",
                            fontWeight = FontWeight.Bold,
                            color = NewtonColors.CoralRed,
                        )
                    },
                    text = {
                        Text(
                            text = "Se eliminarán tus credenciales locales y se cerrará la sesión de este dispositivo.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = NewtonColors.TextSecondaryDark,
                        )
                    },
                    confirmButton = {
                        Button(
                            onClick = {
                                showLogoutDialog = false
                                authManager.logout()
                                onLogout()
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = NewtonColors.CoralRed,
                                contentColor = Color.White,
                            ),
                        ) {
                            Text("Cerrar Sesión", fontWeight = FontWeight.Bold)
                        }
                    },
                    dismissButton = {
                        OutlinedButton(onClick = { showLogoutDialog = false }) {
                            Text("Cancelar", color = NewtonColors.TextSecondaryDark)
                        }
                    },
                    containerColor = NewtonColors.SurfaceDark,
                )
            }
        }
    }
}

@Composable
private fun QuotaBarItem(
    title: String,
    used: Int,
    limit: Int,
    percent: Float,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodySmall,
                color = NewtonColors.TextSecondaryDark,
            )
            Text(
                text = "$used / $limit (${(percent * 100).toInt()}%)",
                style = MaterialTheme.typography.labelSmall.copy(
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                ),
                color = NewtonColors.TextPrimaryDark,
            )
        }
        LinearProgressIndicator(
            progress = { percent },
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp)),
            color = if (percent > 0.85f) NewtonColors.CoralRed else NewtonColors.Sand,
            trackColor = NewtonColors.SurfaceDark,
        )
    }
}
