package ai.newton.android.ui.settings

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ai.newton.android.data.SettingsRepository
import ai.newton.android.theme.NewtonColors
import ai.newton.shared.AIProvider
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    settings: SettingsRepository,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    val currentProvider by settings.provider.collectAsState(initial = AIProvider.OPENAI_COMPATIBLE)
    val currentModelId by settings.modelId.collectAsState(initial = AIProvider.OPENAI_COMPATIBLE.defaultModelId)
    val currentBaseUrl by settings.baseUrl.collectAsState(initial = "")

    var apiKeyInput by remember(currentProvider) {
        mutableStateOf(settings.getApiKey(currentProvider))
    }
    var modelIdInput by remember(currentModelId) {
        mutableStateOf(currentModelId)
    }
    var baseUrlInput by remember(currentBaseUrl) {
        mutableStateOf(currentBaseUrl)
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = NewtonColors.BgDark,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Configuración",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            // Provider Section
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "PROVEEDOR DE IA",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                    ),
                    color = NewtonColors.TextMutedDark,
                )

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(NewtonColors.CardDark)
                        .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(12.dp)),
                ) {
                    val supported = listOf(
                        AIProvider.OPENAI_COMPATIBLE,
                        AIProvider.OPENROUTER,
                        AIProvider.ANTHROPIC,
                        AIProvider.OLLAMA,
                    )

                    supported.forEachIndexed { index, provider ->
                        val isSelected = currentProvider == provider
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    scope.launch {
                                        settings.setProvider(provider)
                                        settings.setModelId(provider.defaultModelId)
                                    }
                                }
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Column {
                                Text(
                                    text = provider.displayName,
                                    style = MaterialTheme.typography.bodyMedium.copy(
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                    ),
                                    color = if (isSelected) NewtonColors.Sand else NewtonColors.TextPrimaryDark,
                                )
                                Text(
                                    text = "Default: ${provider.defaultModelId}",
                                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
                                    color = NewtonColors.TextSecondaryDark,
                                )
                            }

                            if (isSelected) {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = "Selected",
                                    tint = NewtonColors.Sand,
                                    modifier = Modifier.size(20.dp),
                                )
                            }
                        }

                        if (index < supported.size - 1) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(1.dp)
                                    .background(NewtonColors.BorderDark.copy(alpha = 0.5f)),
                            )
                        }
                    }
                }
            }

            // Model ID section
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "MODELO",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                    ),
                    color = NewtonColors.TextMutedDark,
                )

                TextField(
                    value = modelIdInput,
                    onValueChange = {
                        modelIdInput = it
                        scope.launch { settings.setModelId(it.trim()) }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(10.dp)),
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.Psychology,
                            contentDescription = null,
                            tint = NewtonColors.Sand,
                            modifier = Modifier.size(18.dp),
                        )
                    },
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = NewtonColors.CardDark,
                        unfocusedContainerColor = NewtonColors.CardDark,
                        focusedTextColor = NewtonColors.TextPrimaryDark,
                        unfocusedTextColor = NewtonColors.TextPrimaryDark,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                    ),
                    singleLine = true,
                )
            }

            // Base URL section
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "GATEWAY BASE URL (OPCIONAL)",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                    ),
                    color = NewtonColors.TextMutedDark,
                )

                TextField(
                    value = baseUrlInput,
                    onValueChange = {
                        baseUrlInput = it
                        scope.launch { settings.setBaseUrl(it.trim()) }
                    },
                    placeholder = {
                        Text(
                            text = currentProvider.defaultBaseUrl.ifEmpty { "https://api.openai.com/v1" },
                            style = MaterialTheme.typography.bodySmall,
                            color = NewtonColors.TextMutedDark,
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(10.dp)),
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.Language,
                            contentDescription = null,
                            tint = NewtonColors.Sand,
                            modifier = Modifier.size(18.dp),
                        )
                    },
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = NewtonColors.CardDark,
                        unfocusedContainerColor = NewtonColors.CardDark,
                        focusedTextColor = NewtonColors.TextPrimaryDark,
                        unfocusedTextColor = NewtonColors.TextPrimaryDark,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                    ),
                    singleLine = true,
                )
            }

            // API Key section
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "API KEY (ENCRIPTADA EN KEYSTORE)",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                    ),
                    color = NewtonColors.TextMutedDark,
                )

                TextField(
                    value = apiKeyInput,
                    onValueChange = {
                        apiKeyInput = it
                        settings.setApiKey(currentProvider, it.trim())
                    },
                    placeholder = {
                        Text(
                            text = "sk-...",
                            style = MaterialTheme.typography.bodySmall,
                            color = NewtonColors.TextMutedDark,
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(10.dp)),
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.Key,
                            contentDescription = null,
                            tint = NewtonColors.Sand,
                            modifier = Modifier.size(18.dp),
                        )
                    },
                    visualTransformation = PasswordVisualTransformation(),
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = NewtonColors.CardDark,
                        unfocusedContainerColor = NewtonColors.CardDark,
                        focusedTextColor = NewtonColors.TextPrimaryDark,
                        unfocusedTextColor = NewtonColors.TextPrimaryDark,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                    ),
                    singleLine = true,
                )
            }
        }
    }
}
