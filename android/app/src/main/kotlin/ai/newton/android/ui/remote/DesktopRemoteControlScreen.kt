package ai.newton.android.ui.remote

import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import ai.newton.android.data.SettingsRepository
import ai.newton.android.theme.NewtonColors
import ai.newton.shared.AIProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.BufferedReader
import java.util.concurrent.TimeUnit

@Serializable
data class RemoteWorkspaceChat(
    val id: String,
    val title: String,
    val created_at: Long? = null,
)

@Serializable
data class RemoteWorkspaceItem(
    val name: String,
    val path: String,
    val hasGit: Boolean? = null,
    val branch: String? = null,
    val chats: List<RemoteWorkspaceChat> = emptyList(),
)

@Serializable
data class RemoteDesktopStatus(
    val online: Boolean = false,
    val last_seen: Long? = null,
    val current_task: String? = null,
)

@Serializable
data class RemoteStepEvent(
    val stepType: String = "step",
    val toolName: String? = null,
    val message: String? = null,
    val stdout: String? = null,
    val stderr: String? = null,
    val timestamp: Long = System.currentTimeMillis(),
)

data class RemoteUiState(
    val status: RemoteDesktopStatus? = null,
    val workspaces: List<RemoteWorkspaceItem> = emptyList(),
    val selectedWorkspace: RemoteWorkspaceItem? = null,
    val selectedChat: RemoteWorkspaceChat? = null,
    val isExecuting: Boolean = false,
    val steps: List<RemoteStepEvent> = emptyList(),
    val finalAnswer: String? = null,
    val errorMessage: String? = null,
)

class RemoteControlViewModel(
    private val settings: SettingsRepository,
) : ViewModel() {

    private val _ui = MutableStateFlow(RemoteUiState())
    val ui: StateFlow<RemoteUiState> = _ui.asStateFlow()

    private val json = Json { ignoreUnknownKeys = true }
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.SECONDS) // For streaming
        .build()

    private var streamJob: Job? = null
    private var activeSessionId: String? = null

    init {
        refresh()
    }

    fun selectWorkspace(ws: RemoteWorkspaceItem) {
        _ui.value = _ui.value.copy(
            selectedWorkspace = ws,
            selectedChat = ws.chats.firstOrNull(),
        )
    }

    fun selectChat(chat: RemoteWorkspaceChat?) {
        _ui.value = _ui.value.copy(selectedChat = chat)
    }

    fun refresh() {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val baseUrl = settings.effectiveBaseUrl(AIProvider.OPENAI_COMPATIBLE)
                val statusReq = Request.Builder()
                    .url("$baseUrl/nwtn/desktop/status")
                    .get()
                    .build()
                val statusRes = client.newCall(statusReq).execute()
                val status = if (statusRes.isSuccessful) {
                    json.decodeFromString<RemoteDesktopStatus>(statusRes.body?.string().orEmpty())
                } else null

                val wsReq = Request.Builder()
                    .url("$baseUrl/nwtn/desktop/workspaces")
                    .get()
                    .build()
                val wsRes = client.newCall(wsReq).execute()
                val wsList = if (wsRes.isSuccessful) {
                    val raw = wsRes.body?.string().orEmpty()
                    // Extract workspaces array
                    if (raw.contains("\"workspaces\":")) {
                        val body = json.decodeFromString<Map<String, List<RemoteWorkspaceItem>>>(raw)
                        body["workspaces"].orEmpty()
                    } else emptyList()
                } else emptyList()

                _ui.value = _ui.value.copy(
                    status = status,
                    workspaces = wsList,
                    selectedWorkspace = _ui.value.selectedWorkspace ?: wsList.firstOrNull(),
                    errorMessage = null,
                )
            } catch (e: Exception) {
                _ui.value = _ui.value.copy(
                    errorMessage = "No se pudo conectar con la Mac: ${e.message}",
                )
            }
        }
    }

    fun dispatchTask(task: String) {
        val ws = _ui.value.selectedWorkspace ?: return
        if (task.isBlank() || _ui.value.isExecuting) return

        _ui.value = _ui.value.copy(
            isExecuting = true,
            steps = emptyList(),
            finalAnswer = null,
            errorMessage = null,
        )

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val baseUrl = settings.effectiveBaseUrl(AIProvider.OPENAI_COMPATIBLE)
                val selectedChatId = _ui.value.selectedChat?.id
                val payloadMap = mutableMapOf<String, String>(
                    "workspacePath" to ws.path,
                    "task" to task,
                    "model" to "Singularity-Matrix",
                )
                if (selectedChatId != null) {
                    payloadMap["chatId"] = selectedChatId
                }
                val payload = json.encodeToString(payloadMap)
                val body = payload.toRequestBody("application/json".toMediaType())
                val req = Request.Builder()
                    .url("$baseUrl/nwtn/desktop/dispatch")
                    .post(body)
                    .build()

                val res = client.newCall(req).execute()
                if (res.isSuccessful) {
                    startStream(baseUrl)
                } else {
                    _ui.value = _ui.value.copy(
                        isExecuting = false,
                        errorMessage = "Error al despachar comando: ${res.code}",
                    )
                }
            } catch (e: Exception) {
                _ui.value = _ui.value.copy(
                    isExecuting = false,
                    errorMessage = "Error de red: ${e.message}",
                )
            }
        }
    }

    private fun startStream(baseUrl: String) {
        streamJob?.cancel()
        streamJob = viewModelScope.launch(Dispatchers.IO) {
            try {
                val req = Request.Builder()
                    .url("$baseUrl/nwtn/desktop/session/stream")
                    .get()
                    .build()
                val response = client.newCall(req).execute()
                val source = response.body?.byteStream()?.bufferedReader() ?: return@launch

                var currentEventType = "step"
                var line: String? = source.readLine()
                while (line != null) {
                    val trimmed = line.trim()
                    if (trimmed.startsWith("event: ")) {
                        currentEventType = trimmed.removePrefix("event: ").trim()
                    } else if (trimmed.startsWith("data: ")) {
                        val dataStr = trimmed.removePrefix("data: ").trim()
                        try {
                            val event = json.decodeFromString<RemoteStepEvent>(dataStr)
                            val step = event.copy(stepType = if (event.stepType.isNotBlank()) event.stepType else currentEventType)
                            
                            val updatedSteps = _ui.value.steps + step
                            var finalAns = _ui.value.finalAnswer
                            var executing = _ui.value.isExecuting
                            var errMsg = _ui.value.errorMessage

                            if (step.stepType == "task_done") {
                                executing = false
                                finalAns = step.message
                            } else if (step.stepType == "error") {
                                executing = false
                                errMsg = step.message
                            }

                            _ui.value = _ui.value.copy(
                                steps = updatedSteps,
                                finalAnswer = finalAns,
                                isExecuting = executing,
                                errorMessage = errMsg,
                            )
                        } catch (_: Exception) {}
                    }
                    line = source.readLine()
                }
            } catch (e: Exception) {
                _ui.value = _ui.value.copy(
                    isExecuting = false,
                    errorMessage = "Stream finalizado: ${e.message}",
                )
            }
        }
    }

    fun cancelTask() {
        streamJob?.cancel()
        _ui.value = _ui.value.copy(isExecuting = false)
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val baseUrl = settings.effectiveBaseUrl(AIProvider.OPENAI_COMPATIBLE)
                val req = Request.Builder()
                    .url("$baseUrl/nwtn/desktop/cancel")
                    .post("{}".toRequestBody("application/json".toMediaType()))
                    .build()
                client.newCall(req).execute()
            } catch (_: Exception) {}
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DesktopRemoteControlScreen(
    viewModel: RemoteControlViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val uiState by viewModel.ui.collectAsState()
    var promptInput by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    val quickPrompts = listOf(
        "Revisa los archivos con git status",
        "Ejecuta los tests del proyecto",
        "Busca cuellos de botella y optimiza",
        "Lista los archivos del proyecto",
    )

    LaunchedEffect(uiState.steps.size) {
        if (uiState.steps.isNotEmpty()) {
            listState.animateScrollToItem(uiState.steps.size)
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = NewtonColors.BgDark,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Mac Remote Studio",
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
                actions = {
                    IconButton(onClick = { viewModel.refresh() }) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh",
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
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(NewtonColors.BgDark)
                    .padding(12.dp),
            ) {
                uiState.errorMessage?.let { err ->
                    Text(
                        text = err,
                        color = NewtonColors.CoralRed,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(bottom = 6.dp),
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextField(
                        value = promptInput,
                        onValueChange = { promptInput = it },
                        placeholder = {
                            Text(
                                text = "Instrucción para la Mac (e.g. arregla los tests)...",
                                style = MaterialTheme.typography.bodySmall,
                                color = NewtonColors.TextMutedDark,
                            )
                        },
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(20.dp))
                            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(20.dp)),
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = NewtonColors.CardDark,
                            unfocusedContainerColor = NewtonColors.CardDark,
                            focusedTextColor = NewtonColors.TextPrimaryDark,
                            unfocusedTextColor = NewtonColors.TextPrimaryDark,
                            focusedIndicatorColor = Color.Transparent,
                            unfocusedIndicatorColor = Color.Transparent,
                        ),
                        maxLines = 3,
                    )

                    Spacer(modifier = Modifier.width(8.dp))

                    val canDispatch = promptInput.isNotBlank() && uiState.selectedWorkspace != null && !uiState.isExecuting
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(if (canDispatch) NewtonColors.Sand else NewtonColors.CardDark)
                            .border(1.dp, NewtonColors.BorderDark, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        IconButton(
                            onClick = {
                                if (canDispatch) {
                                    viewModel.dispatchTask(promptInput)
                                    promptInput = ""
                                }
                            },
                            enabled = canDispatch,
                        ) {
                            Icon(
                                imageVector = Icons.Default.ArrowUpward,
                                contentDescription = "Dispatch",
                                tint = if (canDispatch) NewtonColors.BgDark else NewtonColors.TextMutedDark,
                            )
                        }
                    }
                }
            }
        },
    ) { padding ->
        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            // Header status card
            item {
                MacStatusCard(
                    status = uiState.status,
                    workspacesCount = uiState.workspaces.size,
                    isExecuting = uiState.isExecuting,
                    onCancel = { viewModel.cancelTask() },
                )
            }

            // Workspaces section
            item {
                Text(
                    text = "WORKSPACE EN LA MAC",
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                    ),
                    color = NewtonColors.TextMutedDark,
                )
                Spacer(modifier = Modifier.height(6.dp))

                if (uiState.workspaces.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(NewtonColors.CardDark)
                            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(10.dp))
                            .padding(14.dp),
                    ) {
                        Text(
                            text = "No hay carpetas registradas. Inicia Newton en tu Mac.",
                            style = MaterialTheme.typography.bodySmall,
                            color = NewtonColors.TextMutedDark,
                        )
                    }
                } else {
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(uiState.workspaces) { ws ->
                            val isSelected = uiState.selectedWorkspace?.path == ws.path
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(if (isSelected) NewtonColors.Sand.copy(alpha = 0.12f) else NewtonColors.CardDark)
                                    .border(
                                        1.dp,
                                        if (isSelected) NewtonColors.Sand.copy(alpha = 0.5f) else NewtonColors.BorderDark,
                                        RoundedCornerShape(10.dp),
                                    )
                                    .clickable { viewModel.selectWorkspace(ws) }
                                    .padding(horizontal = 14.dp, vertical = 10.dp),
                            ) {
                                Column {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(
                                            imageVector = Icons.Default.Folder,
                                            contentDescription = null,
                                            tint = if (isSelected) NewtonColors.Sand else NewtonColors.TextMutedDark,
                                            modifier = Modifier.size(16.dp),
                                        )
                                        Spacer(modifier = Modifier.width(6.dp))
                                        Text(
                                            text = ws.name,
                                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                            color = if (isSelected) NewtonColors.TextPrimaryDark else NewtonColors.TextMutedDark,
                                        )
                                    }
                                    if (!ws.branch.isNullOrEmpty()) {
                                        Spacer(modifier = Modifier.height(2.dp))
                                        Text(
                                            text = ws.branch,
                                            style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                                            color = if (isSelected) NewtonColors.Sand.copy(alpha = 0.8f) else NewtonColors.TextMutedDark,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Workspace Chats section
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "SESIONES DE CÓDIGO (CHATS)",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp,
                        ),
                        color = NewtonColors.TextMutedDark,
                    )
                    Row(
                        modifier = Modifier
                            .clickable { viewModel.selectChat(null) }
                            .padding(4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = null,
                            tint = if (uiState.selectedChat == null) NewtonColors.Sand else NewtonColors.TextMutedDark,
                            modifier = Modifier.size(14.dp),
                        )
                        Spacer(modifier = Modifier.width(2.dp))
                        Text(
                            text = "Nueva tarea",
                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                            color = if (uiState.selectedChat == null) NewtonColors.Sand else NewtonColors.TextMutedDark,
                        )
                    }
                }
                Spacer(modifier = Modifier.height(6.dp))

                val currentChats = uiState.selectedWorkspace?.chats.orEmpty()
                if (currentChats.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(NewtonColors.CardDark)
                            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(10.dp))
                            .padding(12.dp),
                    ) {
                        Text(
                            text = "No hay tareas previas. Escribe tu primera orden abajo.",
                            style = MaterialTheme.typography.bodySmall,
                            color = NewtonColors.TextMutedDark,
                        )
                    }
                } else {
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        item {
                            val isNewSelected = uiState.selectedChat == null
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(if (isNewSelected) NewtonColors.Sand.copy(alpha = 0.18f) else NewtonColors.CardDark)
                                    .border(
                                        1.dp,
                                        if (isNewSelected) NewtonColors.Sand.copy(alpha = 0.6f) else NewtonColors.BorderDark,
                                        RoundedCornerShape(8.dp),
                                    )
                                    .clickable { viewModel.selectChat(null) }
                                    .padding(horizontal = 10.dp, vertical = 8.dp),
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        imageVector = Icons.Default.Add,
                                        contentDescription = null,
                                        tint = if (isNewSelected) NewtonColors.Sand else NewtonColors.TextMutedDark,
                                        modifier = Modifier.size(12.dp),
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = "Nueva sesión",
                                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                                        color = if (isNewSelected) NewtonColors.Sand else NewtonColors.TextMutedDark,
                                    )
                                }
                            }
                        }

                        items(currentChats) { chat ->
                            val isChatSelected = uiState.selectedChat?.id == chat.id
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(if (isChatSelected) NewtonColors.Sand.copy(alpha = 0.15f) else NewtonColors.CardDark)
                                    .border(
                                        1.dp,
                                        if (isChatSelected) NewtonColors.Sand.copy(alpha = 0.5f) else NewtonColors.BorderDark,
                                        RoundedCornerShape(8.dp),
                                    )
                                    .clickable { viewModel.selectChat(chat) }
                                    .padding(horizontal = 10.dp, vertical = 8.dp),
                            ) {
                                Text(
                                    text = chat.title,
                                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
                                    color = if (isChatSelected) NewtonColors.TextPrimaryDark else NewtonColors.TextMutedDark,
                                    maxLines = 1,
                                )
                            }
                        }
                    }
                }
            }

            // Quick actions
            if (!uiState.isExecuting && uiState.steps.isEmpty()) {
                item {
                    Text(
                        text = "ÓRDENES RÁPIDAS",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp,
                        ),
                        color = NewtonColors.TextMutedDark,
                    )
                    Spacer(modifier = Modifier.height(6.dp))

                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        quickPrompts.forEach { prompt ->
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(NewtonColors.CardDark)
                                    .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(8.dp))
                                    .clickable { promptInput = prompt }
                                    .padding(horizontal = 12.dp, vertical = 10.dp),
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        imageVector = Icons.Default.Bolt,
                                        contentDescription = null,
                                        tint = NewtonColors.Sand,
                                        modifier = Modifier.size(16.dp),
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = prompt,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = NewtonColors.TextPrimaryDark,
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Timeline of execution
            if (uiState.steps.isNotEmpty() || uiState.isExecuting) {
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(
                            text = "PASOS DEL AGENTE EN LA MAC",
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontWeight = FontWeight.Bold,
                                fontSize = 11.sp,
                            ),
                            color = NewtonColors.TextMutedDark,
                        )

                        if (uiState.isExecuting) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(14.dp),
                                    strokeWidth = 2.dp,
                                    color = NewtonColors.Sand,
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "Ejecutando...",
                                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
                                    color = NewtonColors.Sand,
                                )
                            }
                        }
                    }
                }

                items(uiState.steps) { step ->
                    RemoteStepCard(step = step)
                }
            }

            // Final answer section
            uiState.finalAnswer?.let { answer ->
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(NewtonColors.CardDark)
                            .border(1.dp, NewtonColors.Sand.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                            .padding(14.dp),
                    ) {
                        Column {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    tint = NewtonColors.Sand,
                                    modifier = Modifier.size(16.dp),
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "SOLUCIÓN FINAL DE MATRIX",
                                    style = MaterialTheme.typography.labelSmall.copy(
                                        fontWeight = FontWeight.Bold,
                                        color = NewtonColors.Sand,
                                    ),
                                )
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = answer,
                                style = MaterialTheme.typography.bodyMedium,
                                color = NewtonColors.TextPrimaryDark,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun MacStatusCard(
    status: RemoteDesktopStatus?,
    workspacesCount: Int,
    isExecuting: Boolean,
    onCancel: () -> Unit,
) {
    val isOnline = status?.online == true

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(NewtonColors.CardDark)
            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .background(
                    if (isOnline) NewtonColors.ForestGreen.copy(alpha = 0.2f)
                    else NewtonColors.CoralRed.copy(alpha = 0.2f),
                    CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .background(
                        if (isOnline) NewtonColors.ForestGreen else NewtonColors.CoralRed,
                        CircleShape,
                    ),
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = if (isOnline) "Mac Desktop Conectada" else "Mac Desktop Desconectada",
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                    color = NewtonColors.TextPrimaryDark,
                )
                if (isOnline) {
                    Spacer(modifier = Modifier.width(6.dp))
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(4.dp))
                            .background(NewtonColors.Sand.copy(alpha = 0.15f))
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    ) {
                        Text(
                            text = "Matrix Agente",
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontSize = 10.sp,
                                color = NewtonColors.Sand,
                                fontWeight = FontWeight.SemiBold,
                            ),
                        )
                    }
                }
            }

            Text(
                text = if (isOnline) "$workspacesCount workspaces sincronizados · Bucle autónomo activo"
                else "Abre la aplicación Newton en tu Mac para sincronizar",
                style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.sp),
                color = NewtonColors.TextSecondaryDark,
            )
        }

        if (isExecuting) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(NewtonColors.CoralRed.copy(alpha = 0.15f))
                    .clickable(onClick = onCancel)
                    .padding(horizontal = 10.dp, vertical = 6.dp),
            ) {
                Text(
                    text = "Detener",
                    style = MaterialTheme.typography.labelSmall.copy(
                        color = NewtonColors.CoralRed,
                        fontWeight = FontWeight.Bold,
                    ),
                )
            }
        }
    }
}

@Composable
fun RemoteStepCard(step: RemoteStepEvent) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(NewtonColors.CardDark)
            .border(1.dp, NewtonColors.BorderDark, RoundedCornerShape(10.dp))
            .padding(12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Default.Terminal,
                    contentDescription = null,
                    tint = NewtonColors.Sand,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = if (step.toolName != null) "Herramienta: ${step.toolName}" else step.stepType.replaceFirstChar { it.uppercase() },
                    style = MaterialTheme.typography.bodyMedium.copy(
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 13.sp,
                    ),
                    color = NewtonColors.TextPrimaryDark,
                )
            }

            val (badgeText, badgeColor) = when (step.stepType) {
                "tool_start" -> "RUNNING" to NewtonColors.Sand
                "tool_done", "task_done" -> "SUCCESS" to NewtonColors.ForestGreen
                "error" -> "ERROR" to NewtonColors.CoralRed
                else -> "INFO" to NewtonColors.TextMutedDark
            }

            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(badgeColor.copy(alpha = 0.15f))
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            ) {
                Text(
                    text = badgeText,
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        color = badgeColor,
                    ),
                )
            }
        }

        step.message?.takeIf { it.isNotBlank() }?.let { msg ->
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = msg,
                style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.sp),
                color = NewtonColors.TextSecondaryDark,
            )
        }

        step.stdout?.takeIf { it.isNotBlank() }?.let { stdout ->
            Spacer(modifier = Modifier.height(6.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(6.dp))
                    .background(Color.Black.copy(alpha = 0.45f))
                    .padding(8.dp),
            ) {
                val scroll = rememberScrollState()
                Text(
                    text = stdout,
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontSize = 11.sp,
                        fontFamily = FontFamily.Monospace,
                        color = NewtonColors.ForestGreen,
                    ),
                    modifier = Modifier.horizontalScroll(scroll),
                )
            }
        }

        step.stderr?.takeIf { it.isNotBlank() }?.let { stderr ->
            Spacer(modifier = Modifier.height(6.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(6.dp))
                    .background(Color.Black.copy(alpha = 0.45f))
                    .padding(8.dp),
            ) {
                val scroll = rememberScrollState()
                Text(
                    text = stderr,
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontSize = 11.sp,
                        fontFamily = FontFamily.Monospace,
                        color = NewtonColors.CoralRed,
                    ),
                    modifier = Modifier.horizontalScroll(scroll),
                )
            }
        }
    }
}
