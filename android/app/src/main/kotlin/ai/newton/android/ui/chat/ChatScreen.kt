package ai.newton.android.ui.chat

import ai.newton.android.chat.ChatViewModel
import ai.newton.android.data.WorkspaceManager
import ai.newton.android.theme.NewtonColors
import ai.newton.android.ui.components.Hero3DCanvas
import ai.newton.android.ui.components.ThinkingOrb
import ai.newton.shared.Message
import ai.newton.shared.MessageRole
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PhoneInTalk
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import java.io.InputStream
import android.util.Base64

/**
 * Android Jetpack Compose counterpart of Swift `ChatView`
 * (ios/Newton/Views/Chat/ChatView.swift).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    viewModel: ChatViewModel,
    workspaceManager: WorkspaceManager,
    onBack: () -> Unit,
    onOpenRemoteStudio: () -> Unit,
    onOpenVoiceCall: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val uiState by viewModel.ui.collectAsState()
    val activeWorkspace = workspaceManager.activeWorkspace

    var inputText by remember { mutableStateOf("") }
    var attachedImageUri by remember { mutableStateOf<Uri?>(null) }
    var attachedImageBase64 by remember { mutableStateOf<String?>(null) }

    var showModelMenu by remember { mutableStateOf(false) }
    var showExportMenu by remember { mutableStateOf(false) }
    var showAttachmentMenu by remember { mutableStateOf(false) }

    val listState = rememberLazyListState()
    val messages = uiState.conversation?.messages.orEmpty()
    val isGhost = uiState.conversation?.isGhost == true
    val currentModelId = uiState.conversation?.modelId ?: "Singularity"

    val isTerminated = remember(messages) {
        messages.any { msg ->
            msg.orbitResults.any {
                val name = it.orbitName.lowercase()
                name == "kick" || name == "terminate"
            }
        }
    }

    val showScrollToBottom by remember {
        derivedStateOf {
            listState.firstVisibleItemIndex < messages.size - 2 && messages.isNotEmpty()
        }
    }

    // Photo picker launcher
    val photoPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent(),
    ) { uri: Uri? ->
        uri?.let {
            attachedImageUri = it
            try {
                val inputStream: InputStream? = context.contentResolver.openInputStream(it)
                val bytes = inputStream?.readBytes()
                if (bytes != null) {
                    attachedImageBase64 = "data:image/jpeg;base64," + Base64.encodeToString(bytes, Base64.NO_WRAP)
                }
            } catch (_: Exception) {}
        }
    }

    LaunchedEffect(messages.size, messages.lastOrNull()?.content?.length) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size - 1)
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = NewtonColors.BgDark,
        topBar = {
            TopAppBar(
                navigationIcon = {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(start = 4.dp),
                    ) {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = Icons.Default.ArrowBack,
                                contentDescription = "Back",
                                tint = NewtonColors.Sand,
                            )
                        }

                        // Remote Studio Button
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(NewtonColors.Sand.copy(alpha = 0.12f))
                                .clickable(onClick = onOpenRemoteStudio)
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Default.Laptop,
                                contentDescription = null,
                                tint = NewtonColors.Sand,
                                modifier = Modifier.size(12.dp),
                            )
                            Text(
                                text = "Remote",
                                style = MaterialTheme.typography.labelSmall.copy(
                                    fontWeight = FontWeight.SemiBold,
                                    fontSize = 11.sp,
                                ),
                                color = NewtonColors.Sand,
                                maxLines = 1,
                            )
                        }
                    }
                },
                title = {
                    Box(
                        modifier = Modifier.fillMaxWidth(),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.clickable { showModelMenu = true },
                        ) {
                            Text(
                                text = uiState.conversation?.title ?: "Newton",
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                color = NewtonColors.TextPrimaryDark,
                                maxLines = 1,
                            )
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(2.dp),
                            ) {
                                Text(
                                    text = if (currentModelId == "Singularity-Matrix") "Singularity-Matrix" else "Singularity",
                                    style = MaterialTheme.typography.labelSmall.copy(
                                        fontFamily = FontFamily.Monospace,
                                        fontSize = 10.sp,
                                    ),
                                    color = NewtonColors.Sand,
                                )
                                Icon(
                                    imageVector = Icons.Default.KeyboardArrowDown,
                                    contentDescription = null,
                                    tint = NewtonColors.Sand,
                                    modifier = Modifier.size(12.dp),
                                )
                            }
                        }

                        // Model selection dropdown
                        DropdownMenu(
                            expanded = showModelMenu,
                            onDismissRequest = { showModelMenu = false },
                            modifier = Modifier.background(NewtonColors.SurfaceDark),
                        ) {
                            DropdownMenuItem(
                                text = {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        modifier = Modifier.fillMaxWidth(),
                                    ) {
                                        Column {
                                            Text("Newton Singularity", fontWeight = FontWeight.Bold, color = NewtonColors.TextPrimaryDark)
                                            Text("Chat general, visión e imágenes", style = MaterialTheme.typography.labelSmall, color = NewtonColors.TextSecondaryDark)
                                        }
                                        if (currentModelId == "Singularity") {
                                            Icon(Icons.Default.Check, null, tint = NewtonColors.Sand)
                                        }
                                    }
                                },
                                onClick = {
                                    viewModel.setModel("Singularity")
                                    showModelMenu = false
                                },
                            )
                            DropdownMenuItem(
                                text = {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        modifier = Modifier.fillMaxWidth(),
                                    ) {
                                        Column {
                                            Text("Singularity-Matrix", fontWeight = FontWeight.Bold, color = NewtonColors.TextPrimaryDark)
                                            Text("Especialista en código y arquitectura", style = MaterialTheme.typography.labelSmall, color = NewtonColors.TextSecondaryDark)
                                        }
                                        if (currentModelId == "Singularity-Matrix") {
                                            Icon(Icons.Default.Check, null, tint = NewtonColors.Sand)
                                        }
                                    }
                                },
                                onClick = {
                                    viewModel.setModel("Singularity-Matrix")
                                    showModelMenu = false
                                },
                            )
                        }
                    }
                },
                actions = {
                    // Ghost Mode Toggle
                    IconButton(onClick = { viewModel.toggleGhostMode() }) {
                        Icon(
                            imageVector = Icons.Default.AutoAwesome,
                            contentDescription = "Ghost Mode",
                            tint = if (isGhost) NewtonColors.GhostPurple else NewtonColors.TextSecondaryDark,
                            modifier = Modifier.size(20.dp),
                        )
                    }

                    // Voice Call Button
                    IconButton(onClick = onOpenVoiceCall) {
                        Icon(
                            imageVector = Icons.Default.PhoneInTalk,
                            contentDescription = "Voice Call",
                            tint = NewtonColors.Sand,
                            modifier = Modifier.size(20.dp),
                        )
                    }

                    // Export Menu (PDF / Markdown)
                    Box {
                        IconButton(onClick = { showExportMenu = true }) {
                            Icon(
                                imageVector = Icons.Default.MoreVert,
                                contentDescription = "Export",
                                tint = NewtonColors.TextSecondaryDark,
                            )
                        }
                        DropdownMenu(
                            expanded = showExportMenu,
                            onDismissRequest = { showExportMenu = false },
                            modifier = Modifier.background(NewtonColors.SurfaceDark),
                        ) {
                            DropdownMenuItem(
                                text = { Text("Exportar como Markdown", color = NewtonColors.TextPrimaryDark) },
                                onClick = {
                                    showExportMenu = false
                                    val convo = uiState.conversation ?: return@DropdownMenuItem
                                    val md = buildString {
                                        append("# ${convo.title}\n\n")
                                        for (m in convo.messages) {
                                            append("### ${m.role.wireValue.uppercase()}\n")
                                            append("${m.content}\n\n")
                                        }
                                    }
                                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                        type = "text/plain"
                                        putExtra(Intent.EXTRA_SUBJECT, convo.title)
                                        putExtra(Intent.EXTRA_TEXT, md)
                                    }
                                    context.startActivity(Intent.createChooser(shareIntent, "Exportar conversación"))
                                },
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = NewtonColors.BgDark,
                ),
            )
        },
        bottomBar = {
            if (isTerminated) {
                // Terminated Banner
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                        .clip(RoundedCornerShape(24.dp))
                        .background(NewtonColors.CardDark)
                        .border(1.dp, NewtonColors.CoralRed.copy(alpha = 0.5f), RoundedCornerShape(24.dp))
                        .padding(horizontal = 20.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.Lock,
                        contentDescription = null,
                        tint = NewtonColors.CoralRed,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Sesión finalizada por Newton.",
                        style = MaterialTheme.typography.bodyMedium.copy(
                            fontWeight = FontWeight.SemiBold,
                            fontFamily = FontFamily.Serif,
                        ),
                        color = NewtonColors.TextSecondaryDark,
                    )
                }
            } else {
                ChatInputBar(
                    text = inputText,
                    onTextChange = { inputText = it },
                    attachedImageUri = attachedImageUri,
                    onRemoveAttachment = {
                        attachedImageUri = null
                        attachedImageBase64 = null
                    },
                    onTriggerAttachmentMenu = { showAttachmentMenu = true },
                    onSend = {
                        if (inputText.isNotBlank() || attachedImageBase64 != null) {
                            viewModel.send(inputText, attachedImageBase64 = attachedImageBase64)
                            inputText = ""
                            attachedImageUri = null
                            attachedImageBase64 = null
                        }
                    },
                    onStop = { viewModel.stop() },
                    isStreaming = uiState.isStreaming,
                )
            }
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            // Background Canvas
            Hero3DCanvas(isDark = true, modifier = Modifier.fillMaxSize())

            Column(modifier = Modifier.fillMaxSize()) {
                // Ghost Mode Banner
                AnimatedVisibility(
                    visible = isGhost,
                    enter = fadeIn(),
                    exit = fadeOut(),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 6.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(NewtonColors.GhostPurple.copy(alpha = 0.12f))
                            .padding(horizontal = 14.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(
                            text = "Sesión Fantasma · Efímera",
                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                            color = NewtonColors.GhostPurple,
                        )
                        Text(
                            text = "Desvanecer",
                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                            color = NewtonColors.CoralRed,
                            modifier = Modifier.clickable { viewModel.vanishGhost() },
                        )
                    }
                }

                // Error Notification Bubble
                uiState.error?.let { err ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 6.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(NewtonColors.CoralRed.copy(alpha = 0.15f))
                            .padding(12.dp),
                    ) {
                        Text(
                            text = "Error: $err",
                            color = NewtonColors.CoralRed,
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                }

                // Message List or Welcome Hero
                if (messages.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .weight(1f),
                        contentAlignment = Alignment.Center,
                    ) {
                        NewtonHeroWelcomeView(
                            onPromptSelected = { prompt ->
                                inputText = prompt
                                viewModel.send(prompt)
                            },
                        )
                    }
                } else {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier
                            .fillMaxSize()
                            .weight(1f),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        items(messages, key = { it.id }) { message ->
                            MessageBubble(message = message)
                        }

                        // Thinking indicator while streaming without content yet
                        if (uiState.isStreaming && (messages.lastOrNull()?.content?.isEmpty() == true)) {
                            item {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                    modifier = Modifier.padding(vertical = 8.dp),
                                ) {
                                    ThinkingOrb(size = 30.dp)
                                    Text(
                                        text = "Newton está razonando...",
                                        style = MaterialTheme.typography.bodyMedium.copy(
                                            fontFamily = FontFamily.Serif,
                                            fontWeight = FontWeight.Medium,
                                        ),
                                        color = NewtonColors.Sand,
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Scroll to bottom floating button
            if (showScrollToBottom) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(16.dp)
                        .size(38.dp)
                        .clip(CircleShape)
                        .background(NewtonColors.CardDark.copy(alpha = 0.95f))
                        .border(1.dp, NewtonColors.BorderDark, CircleShape)
                        .clickable {
                            scope.launch {
                                if (messages.isNotEmpty()) {
                                    listState.animateScrollToItem(messages.size - 1)
                                }
                            }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.ArrowDownward,
                        contentDescription = "Scroll down",
                        tint = NewtonColors.Sand,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }

            // Attachment Options Dialog / Menu
            DropdownMenu(
                expanded = showAttachmentMenu,
                onDismissRequest = { showAttachmentMenu = false },
                modifier = Modifier.background(NewtonColors.SurfaceDark),
            ) {
                DropdownMenuItem(
                    leadingIcon = { Icon(Icons.Default.Image, null, tint = NewtonColors.Sand) },
                    text = { Text("Galería / Fotos", color = NewtonColors.TextPrimaryDark) },
                    onClick = {
                        showAttachmentMenu = false
                        photoPickerLauncher.launch("image/*")
                    },
                )
                DropdownMenuItem(
                    leadingIcon = { Icon(Icons.Default.Public, null, tint = NewtonColors.Aqua) },
                    text = { Text("Búsqueda web", color = NewtonColors.TextPrimaryDark) },
                    onClick = {
                        showAttachmentMenu = false
                        inputText = "Por favor investiga en la web: "
                    },
                )
            }
        }
    }
}

@Composable
private fun MessageBubble(message: Message) {
    val isUser = message.role == MessageRole.USER

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = if (isUser) Alignment.End else Alignment.Start,
    ) {
        if (isUser) {
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                if (!message.imageUrl.isNullOrEmpty()) {
                    AsyncImage(
                        model = message.imageUrl,
                        contentDescription = "Attached Image",
                        modifier = Modifier
                            .size(180.dp)
                            .clip(RoundedCornerShape(14.dp)),
                        contentScale = ContentScale.Crop,
                    )
                }
                Box(
                    modifier = Modifier
                        .clip(
                            RoundedCornerShape(
                                topStart = 16.dp,
                                topEnd = 16.dp,
                                bottomStart = 16.dp,
                                bottomEnd = 4.dp,
                            ),
                        )
                        .background(NewtonColors.UserBubbleDark)
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                ) {
                    Text(
                        text = message.content,
                        style = MaterialTheme.typography.bodyMedium.copy(
                            color = NewtonColors.BgDark,
                            fontWeight = FontWeight.Medium,
                        ),
                    )
                }
            }
        } else {
            Column(
                modifier = Modifier.fillMaxWidth(0.96f),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                // Thinking trace
                if (message.thinkingContent != null || (message.isStreaming && message.content.isEmpty())) {
                    ThinkingCard(
                        thinkingText = message.thinkingContent.orEmpty(),
                        isStreaming = message.isStreaming && message.content.isEmpty(),
                    )
                }

                // Orbit tool cards
                for (orbit in message.orbitResults) {
                    OrbitCard(orbit = orbit)
                }

                // Generated image (if any)
                if (!message.imageUrl.isNullOrEmpty()) {
                    AsyncImage(
                        model = message.imageUrl,
                        contentDescription = "Generated Image",
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(12.dp)),
                        contentScale = ContentScale.Fit,
                    )
                }

                // Main message content
                if (message.content.isNotBlank()) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(14.dp))
                            .background(NewtonColors.CardDark)
                            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(14.dp))
                            .padding(14.dp),
                    ) {
                        RenderFormattedText(text = message.content)
                    }
                }
            }
        }
    }
}

@Composable
private fun RenderFormattedText(text: String) {
    val clipboardManager = LocalClipboardManager.current
    val segments = remember(text) { text.split("```") }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        segments.forEachIndexed { index, segment ->
            if (index % 2 == 1) {
                // Code block
                val lines = segment.trim().lines()
                val lang = if (lines.isNotEmpty() && !lines.first().contains(" ")) lines.first() else ""
                val code = if (lang.isNotEmpty()) lines.drop(1).joinToString("\n") else segment.trim()

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color.Black.copy(alpha = 0.55f))
                        .border(1.dp, NewtonColors.BorderDark.copy(alpha = 0.6f), RoundedCornerShape(10.dp))
                        .padding(12.dp),
                ) {
                    val scrollState = rememberScrollState()
                    Column {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = (if (lang.isNotEmpty()) lang else "CODE").uppercase(),
                                style = MaterialTheme.typography.labelSmall.copy(
                                    fontSize = 10.sp,
                                    fontFamily = FontFamily.Monospace,
                                    fontWeight = FontWeight.Bold,
                                    color = NewtonColors.Sand,
                                ),
                            )
                            IconButton(
                                onClick = { clipboardManager.setText(AnnotatedString(code)) },
                                modifier = Modifier.size(24.dp),
                            ) {
                                Icon(
                                    imageVector = Icons.Default.ContentCopy,
                                    contentDescription = "Copy",
                                    tint = NewtonColors.TextMutedDark,
                                    modifier = Modifier.size(14.dp),
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = code,
                            style = MaterialTheme.typography.bodySmall.copy(
                                fontFamily = FontFamily.Monospace,
                                fontSize = 12.sp,
                                lineHeight = 17.sp,
                                color = NewtonColors.TextPrimaryDark,
                            ),
                            modifier = Modifier.horizontalScroll(scrollState),
                        )
                    }
                }
            } else {
                if (segment.isNotBlank()) {
                    Text(
                        text = segment.trim(),
                        style = MaterialTheme.typography.bodyMedium.copy(
                            lineHeight = 22.sp,
                            color = NewtonColors.TextPrimaryDark,
                        ),
                    )
                }
            }
        }
    }
}

@Composable
private fun NewtonHeroWelcomeView(
    onPromptSelected: (String) -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier.padding(24.dp),
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(CircleShape)
                .background(NewtonColors.Sand.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Default.AutoAwesome,
                contentDescription = null,
                tint = NewtonColors.Sand,
                modifier = Modifier.size(36.dp),
            )
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "Newton Singularity",
                style = MaterialTheme.typography.headlineSmall.copy(
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Serif,
                ),
                color = NewtonColors.TextPrimaryDark,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Razonamiento puro, código y herramientas Orbit.",
                style = MaterialTheme.typography.bodyMedium,
                color = NewtonColors.TextSecondaryDark,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Suggested Prompt Chips
        val suggestions = listOf(
            "Explica cómo funciona la fusión nuclear en 2026",
            "Crea un algoritmo de optimización de rutas en Python",
            "Genera una imagen de un puesto de trabajo cyberpunk",
            "Diferencia técnica entre mutex y semáforo con ejemplos",
        )

        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            for (sug in suggestions) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(NewtonColors.CardDark)
                        .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(12.dp))
                        .clickable { onPromptSelected(sug) }
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                ) {
                    Text(
                        text = sug,
                        style = MaterialTheme.typography.bodySmall,
                        color = NewtonColors.TextPrimaryDark,
                    )
                }
            }
        }
    }
}

@Composable
private fun ChatInputBar(
    text: String,
    onTextChange: (String) -> Unit,
    attachedImageUri: Uri?,
    onRemoveAttachment: () -> Unit,
    onTriggerAttachmentMenu: () -> Unit,
    onSend: () -> Unit,
    onStop: () -> Unit,
    isStreaming: Boolean,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(NewtonColors.BgDark)
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        // Attachment thumbnail chip
        if (attachedImageUri != null) {
            Row(
                modifier = Modifier
                    .padding(bottom = 6.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(NewtonColors.CardDark)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                AsyncImage(
                    model = attachedImageUri,
                    contentDescription = null,
                    modifier = Modifier
                        .size(28.dp)
                        .clip(RoundedCornerShape(4.dp)),
                    contentScale = ContentScale.Crop,
                )
                Text(
                    text = "Foto adjunta",
                    style = MaterialTheme.typography.labelSmall,
                    color = NewtonColors.TextPrimaryDark,
                )
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Remove",
                    tint = NewtonColors.CoralRed,
                    modifier = Modifier
                        .size(16.dp)
                        .clickable(onClick = onRemoveAttachment),
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Attachment Plus button
            IconButton(
                onClick = onTriggerAttachmentMenu,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(NewtonColors.SurfaceDark),
            ) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "Attachments",
                    tint = NewtonColors.Sand,
                    modifier = Modifier.size(20.dp),
                )
            }

            Spacer(modifier = Modifier.width(8.dp))

            TextField(
                value = text,
                onValueChange = onTextChange,
                placeholder = {
                    Text(
                        text = "Mensaje a Newton...",
                        color = NewtonColors.TextMutedDark,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                },
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(24.dp))
                    .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(24.dp)),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = NewtonColors.CardDark,
                    unfocusedContainerColor = NewtonColors.CardDark,
                    focusedTextColor = NewtonColors.TextPrimaryDark,
                    unfocusedTextColor = NewtonColors.TextPrimaryDark,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                ),
                maxLines = 4,
            )

            Spacer(modifier = Modifier.width(8.dp))

            // Send / Stop button
            Box(
                modifier = Modifier
                    .size(42.dp)
                    .clip(CircleShape)
                    .background(if (isStreaming) NewtonColors.CoralRed else NewtonColors.Sand)
                    .border(1.dp, NewtonColors.BorderDark, CircleShape)
                    .clickable(onClick = if (isStreaming) onStop else onSend),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = if (isStreaming) Icons.Default.Stop else Icons.Default.ArrowUpward,
                    contentDescription = if (isStreaming) "Stop" else "Send",
                    tint = NewtonColors.BgDark,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}
