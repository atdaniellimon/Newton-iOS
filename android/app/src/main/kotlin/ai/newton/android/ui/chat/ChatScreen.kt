package ai.newton.android.ui.chat

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Stop
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ai.newton.android.theme.NewtonColors
import ai.newton.android.chat.ChatViewModel
import ai.newton.shared.Message
import ai.newton.shared.MessageRole

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    viewModel: ChatViewModel,
    onOpenDrawer: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val uiState by viewModel.ui.collectAsState()
    var inputText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    val messages = uiState.conversation?.messages.orEmpty()

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
                title = {
                    Column {
                        Text(
                            text = uiState.conversation?.title ?: "Newton",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                            color = NewtonColors.TextPrimaryDark,
                            maxLines = 1,
                        )
                        uiState.conversation?.let { convo ->
                            Text(
                                text = "${convo.provider.wireValue} · ${convo.modelId}",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
                                color = NewtonColors.TextSecondaryDark,
                            )
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onOpenDrawer) {
                        Icon(
                            imageVector = Icons.Default.Menu,
                            contentDescription = "Menu",
                            tint = NewtonColors.Sand,
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.newConversation() }) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = "New Conversation",
                            tint = NewtonColors.Sand,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = NewtonColors.BgDark,
                ),
            )
        },
        bottomBar = {
            ChatInputBar(
                text = inputText,
                onTextChange = { inputText = it },
                onSend = {
                    if (inputText.isNotBlank()) {
                        viewModel.send(inputText)
                        inputText = ""
                    }
                },
                onStop = { viewModel.stop() },
                isStreaming = uiState.isStreaming,
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            uiState.error?.let { err ->
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(NewtonColors.CoralRed.copy(alpha = 0.15f))
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                ) {
                    Text(
                        text = "Error: $err",
                        color = NewtonColors.CoralRed,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }

            if (messages.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .weight(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(32.dp),
                    ) {
                        Text(
                            text = "Newton",
                            style = MaterialTheme.typography.headlineLarge.copy(
                                fontWeight = FontWeight.Bold,
                                color = NewtonColors.Sand,
                            ),
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Inteligencia pura con herramientas Orbit y razonamiento profundo.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = NewtonColors.TextSecondaryDark,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        )
                    }
                }
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .fillMaxSize()
                        .weight(1f),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    items(messages, key = { it.id }) { message ->
                        ChatMessageItem(message = message)
                    }
                }
            }
        }
    }
}

@Composable
fun ChatMessageItem(message: Message) {
    val isUser = message.role == MessageRole.USER

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = if (isUser) Alignment.End else Alignment.Start,
    ) {
        if (isUser) {
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
        } else {
            Column(
                modifier = Modifier.fillMaxWidth(0.95f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // Thinking trace
                if (message.thinkingContent != null || (message.isStreaming && message.content.isEmpty())) {
                    ThinkingCard(
                        thinkingText = message.thinkingContent.orEmpty(),
                        isStreaming = message.isStreaming && message.content.isEmpty(),
                    )
                }

                // Orbit execution cards
                for (orbit in message.orbitResults) {
                    OrbitCard(orbit = orbit)
                }

                // Main message content
                if (message.content.isNotBlank()) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(NewtonColors.CardDark)
                            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(12.dp))
                            .padding(14.dp),
                    ) {
                        Column {
                            RenderFormattedText(text = message.content)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun RenderFormattedText(text: String) {
    // Simple code block / markdown parser
    val segments = remember(text) { text.split("```") }

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        segments.forEachIndexed { index, segment ->
            if (index % 2 == 1) {
                // Code block
                val lines = segment.trim().lines()
                val lang = if (lines.isNotEmpty() && !lines.first().contains(" ")) lines.first() else ""
                val code = if (lang.isNotEmpty()) lines.drop(1).joinToString("\n") else segment.trim()

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color.Black.copy(alpha = 0.5f))
                        .border(1.dp, NewtonColors.BorderDark.copy(alpha = 0.5f), RoundedCornerShape(8.dp))
                        .padding(10.dp),
                ) {
                    val scrollState = rememberScrollState()
                    Column {
                        if (lang.isNotEmpty()) {
                            Text(
                                text = lang.uppercase(),
                                style = MaterialTheme.typography.labelSmall.copy(
                                    fontSize = 10.sp,
                                    fontFamily = FontFamily.Monospace,
                                    color = NewtonColors.Sand,
                                ),
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                        }
                        Text(
                            text = code,
                            style = MaterialTheme.typography.bodySmall.copy(
                                fontFamily = FontFamily.Monospace,
                                fontSize = 12.sp,
                                lineHeight = 16.sp,
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
fun ChatInputBar(
    text: String,
    onTextChange: (String) -> Unit,
    onSend: () -> Unit,
    onStop: () -> Unit,
    isStreaming: Boolean,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(NewtonColors.BgDark)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TextField(
            value = text,
            onValueChange = onTextChange,
            placeholder = {
                Text(
                    text = "Message Newton...",
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

        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(if (isStreaming) NewtonColors.CoralRed else NewtonColors.Sand)
                .border(1.dp, NewtonColors.BorderDark, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            IconButton(onClick = if (isStreaming) onStop else onSend) {
                Icon(
                    imageVector = if (isStreaming) Icons.Default.Stop else Icons.Default.ArrowUpward,
                    contentDescription = if (isStreaming) "Stop" else "Send",
                    tint = NewtonColors.BgDark,
                    modifier = Modifier.size(22.dp),
                )
            }
        }
    }
}
