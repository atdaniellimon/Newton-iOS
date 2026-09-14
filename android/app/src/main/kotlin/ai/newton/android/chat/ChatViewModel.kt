package ai.newton.android.chat

import ai.newton.android.data.AuthManager
import ai.newton.android.data.ChatPeerEvent
import ai.newton.android.data.ChatPeerEventType
import ai.newton.android.data.CloudChatService
import ai.newton.android.data.ConversationStore
import ai.newton.android.data.SettingsRepository
import ai.newton.android.data.WorkspaceManager
import ai.newton.shared.AIProvider
import ai.newton.shared.Conversation
import ai.newton.shared.LLMService
import ai.newton.shared.Message
import ai.newton.shared.MessageRole
import ai.newton.shared.OrbitEngine
import ai.newton.shared.SingularityPrompt
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

data class ChatUiState(
    val conversation: Conversation? = null,
    val isStreaming: Boolean = false,
    val error: String? = null,
)

/**
 * Android counterpart of Swift `ChatView.sendMessage` / `CloudChatService` streaming.
 */
class ChatViewModel(
    private val store: ConversationStore,
    private val settings: SettingsRepository,
    private val auth: AuthManager,
    private val cloudService: CloudChatService,
    private val workspaceManager: WorkspaceManager,
    private val llm: LLMService = LLMService(),
    orbitsInstance: OrbitEngine? = null,
) : ViewModel() {

    private val orbits: OrbitEngine by lazy { orbitsInstance ?: OrbitEngine() }

    private val _ui = MutableStateFlow(ChatUiState())
    val ui: StateFlow<ChatUiState> = _ui.asStateFlow()

    private var streamJob: Job? = null
    private var peerEventsJob: Job? = null

    private var cachedProvider: AIProvider = AIProvider.NEWTON
    private var cachedModelId: String = "Singularity"

    init {
        viewModelScope.launch {
            settings.provider.collect { cachedProvider = it }
        }
        viewModelScope.launch {
            settings.modelId.collect { cachedModelId = it }
        }
    }

    fun open(conversationId: String) {
        val convo = store.conversations.value.firstOrNull { it.id == conversationId }
        _ui.value = _ui.value.copy(
            conversation = convo,
            error = null,
        )

        // If messages are empty and logged in, pull from cloud
        if (convo != null && !convo.isGhost && auth.isLoggedIn.value && convo.messages.isEmpty()) {
            viewModelScope.launch {
                try {
                    val msgs = cloudService.fetchMessages(convo.id)
                    if (msgs.isNotEmpty()) {
                        val updated = convo.copy(messages = msgs)
                        _ui.value = _ui.value.copy(conversation = updated)
                        store.upsert(updated)
                    }
                } catch (_: Exception) {}
            }
        }

        // Listen to active chat peer events
        startPeerEventsListener(conversationId)
    }

    private fun startPeerEventsListener(conversationId: String) {
        peerEventsJob?.cancel()
        if (!auth.isLoggedIn.value) return

        peerEventsJob = viewModelScope.launch {
            cloudService.streamChatEvents(conversationId).collect { ev ->
                if (_ui.value.isStreaming) return@collect
                val current = _ui.value.conversation ?: return@collect
                if (current.id != conversationId) return@collect

                when (ev.event) {
                    ChatPeerEventType.MESSAGE_NEW -> {
                        val msgId = ev.messageId ?: return@collect
                        if (current.messages.none { it.id == msgId }) {
                            val role = if (ev.role?.lowercase() == "user") MessageRole.USER else MessageRole.ASSISTANT
                            val msg = Message(
                                id = msgId,
                                role = role,
                                content = ev.content.orEmpty(),
                                createdAt = System.currentTimeMillis(),
                                isStreaming = false,
                            )
                            val updated = current.copy(messages = current.messages + msg)
                            _ui.value = _ui.value.copy(conversation = updated)
                            store.upsert(updated)
                        }
                    }
                    ChatPeerEventType.AI_START -> {
                        val msgId = ev.messageId ?: return@collect
                        if (current.messages.none { it.id == msgId }) {
                            val placeholder = Message(
                                id = msgId,
                                role = MessageRole.ASSISTANT,
                                content = "",
                                isStreaming = true,
                            )
                            _ui.value = _ui.value.copy(conversation = current.copy(messages = current.messages + placeholder))
                        }
                    }
                    ChatPeerEventType.AI_DELTA -> {
                        val msgId = ev.messageId ?: return@collect
                        val delta = ev.delta ?: return@collect
                        val updated = current.copy(
                            messages = current.messages.map {
                                if (it.id == msgId) it.copy(content = it.content + delta) else it
                            },
                        )
                        _ui.value = _ui.value.copy(conversation = updated)
                    }
                    ChatPeerEventType.AI_DONE -> {
                        val msgId = ev.messageId ?: return@collect
                        val updated = current.copy(
                            messages = current.messages.map {
                                if (it.id == msgId) it.copy(isStreaming = false) else it
                            },
                        )
                        _ui.value = _ui.value.copy(conversation = updated)
                        store.upsert(updated)
                    }
                    else -> {}
                }
            }
        }
    }

    fun newConversation(title: String = "New Conversation"): String {
        val convo = Conversation(
            title = title,
            provider = AIProvider.NEWTON,
            modelId = cachedModelId,
        )
        store.upsert(convo)
        _ui.value = ChatUiState(conversation = convo)
        startPeerEventsListener(convo.id)
        return convo.id
    }

    fun setModel(modelId: String) {
        val current = _ui.value.conversation ?: return
        val updated = current.copy(modelId = modelId)
        _ui.value = _ui.value.copy(conversation = updated)
        store.upsert(updated)
        viewModelScope.launch {
            settings.setModelId(modelId)
            if (auth.isLoggedIn.value && !current.isGhost) {
                cloudService.updateChat(current.id, model = modelId)
            }
        }
    }

    fun toggleGhostMode() {
        val current = _ui.value.conversation ?: return
        val isNowGhost = !current.isGhost
        val updated = current.copy(isGhost = isNowGhost)
        _ui.value = _ui.value.copy(conversation = updated)
        if (!isNowGhost) {
            store.upsert(updated)
        }
    }

    fun vanishGhost() {
        val current = _ui.value.conversation ?: return
        store.remove(current.id)
        _ui.value = ChatUiState()
    }

    fun send(prompt: String, attachedImageBase64: String? = null, attachedFileName: String? = null) {
        val text = prompt.trim()
        if (text.isEmpty() && attachedImageBase64 == null) return
        var convo = _ui.value.conversation ?: run {
            newConversation()
            _ui.value.conversation!!
        }

        var displayPrompt = text
        var backendPrompt = text
        if (displayPrompt.isEmpty() && attachedImageBase64 != null) {
            displayPrompt = "Describe and analyze this image."
            backendPrompt = displayPrompt
        }
        if (!attachedFileName.isNullOrEmpty()) {
            backendPrompt += "\n\n[Attached File: $attachedFileName]"
        }

        val isFirstMessage = convo.messages.isEmpty()
        val userMsg = Message(
            role = MessageRole.USER,
            content = displayPrompt,
            imageUrl = attachedImageBase64,
        )
        val assistantId = UUID.randomUUID().toString()
        val assistantPlaceholder = Message(
            id = assistantId,
            role = MessageRole.ASSISTANT,
            content = "",
            isStreaming = true,
        )

        val updatedConvo = convo.copy(
            title = if (isFirstMessage) titleFrom(text.ifEmpty { attachedFileName ?: "New Conversation" }) else convo.title,
            messages = convo.messages + userMsg + assistantPlaceholder,
        )
        _ui.value = _ui.value.copy(conversation = updatedConvo, isStreaming = true, error = null)
        store.upsert(updatedConvo)

        streamJob?.cancel()
        streamJob = viewModelScope.launch {
            var rawStream = ""
            var visible = ""
            var thinking = ""
            var insideThinking = false

            try {
                // Determine whether to stream via CloudChatService or direct fallback
                val useCloud = !updatedConvo.isGhost && auth.isLoggedIn.value
                var targetChatId = updatedConvo.id

                if (useCloud && !targetChatId.startsWith("chat_")) {
                    try {
                        val remote = cloudService.createChat(title = updatedConvo.title, model = updatedConvo.modelId)
                        targetChatId = remote.id
                        val replaced = updatedConvo.copy(id = remote.id)
                        store.updateConversationId(updatedConvo.id, remote.id, replaced)
                        _ui.value = _ui.value.copy(conversation = replaced)
                        startPeerEventsListener(remote.id)
                    } catch (_: Exception) {}
                }

                val flow = if (useCloud) {
                    val atts = mutableListOf<Pair<String, String>>()
                    if (attachedImageBase64 != null) {
                        atts.add("image" to attachedImageBase64)
                    }
                    cloudService.streamChatMessage(
                        chatId = targetChatId,
                        prompt = backendPrompt,
                        model = updatedConvo.modelId,
                        attachments = atts,
                    )
                } else {
                    val activeWs = workspaceManager.activeWorkspace
                    val systemPrompt = buildString {
                        append(SingularityPrompt.base)
                        if (activeWs != null && activeWs.customSystemPrompt.isNotEmpty()) {
                            append("\n\n[ACTIVE PROJECT WORKSPACE: ").append(activeWs.name).append("]\n")
                            append(activeWs.customSystemPrompt)
                        }
                    }
                    llm.streamCompletion(
                        messages = updatedConvo.messages.dropLast(1),
                        provider = updatedConvo.provider,
                        modelId = updatedConvo.modelId,
                        baseUrl = settings.effectiveBaseUrl(updatedConvo.provider),
                        apiKey = auth.nwtnKey.ifEmpty { settings.getApiKey(updatedConvo.provider) },
                        systemPrompt = systemPrompt,
                    )
                }

                flow.collect { token ->
                    rawStream += token
                    if (!token.contains('<') && !token.contains('>')) {
                        if (insideThinking) thinking += token else visible += token
                    } else {
                        val parsed = LiveParse.parse(rawStream)
                        visible = parsed.visible
                        thinking = parsed.thinking
                        insideThinking = parsed.insideThinking
                    }
                    patchAssistant(assistantId, visible, thinking.ifEmpty { null }, streaming = true)
                }

                // Run Orbit post-processing (image generation, web citation, calculations)
                val processed = orbits.processOrbitsInText(
                    rawStream,
                    userPrompt = displayPrompt,
                    baseUrl = AuthManager.API_BASE_URL + "/nwtn",
                    apiKey = auth.nwtnKey,
                )
                val mergedThinking = mergeThinking(thinking, processed.thinkingContent.orEmpty())

                val finished = _ui.value.conversation!!.copy(
                    messages = _ui.value.conversation!!.messages.map { msg ->
                        if (msg.id != assistantId) msg else msg.copy(
                            content = processed.processedText,
                            imageUrl = processed.imageUrl,
                            orbitResults = processed.results,
                            thinkingContent = mergedThinking.ifEmpty { null },
                            isStreaming = false,
                        )
                    },
                )
                _ui.value = _ui.value.copy(conversation = finished, isStreaming = false)
                store.upsert(finished)

                if (isFirstMessage && displayPrompt.isNotEmpty()) {
                    launch { generateAiTitle(finished.id, displayPrompt) }
                }
            } catch (e: Exception) {
                val kept = _ui.value.conversation
                if (kept != null) {
                    val cleaned = kept.copy(
                        messages = kept.messages.map {
                            if (it.id == assistantId) it.copy(isStreaming = false) else it
                        },
                    )
                    _ui.value = _ui.value.copy(
                        conversation = cleaned,
                        isStreaming = false,
                        error = e.message ?: e.toString(),
                    )
                    store.upsert(cleaned)
                } else {
                    _ui.value = _ui.value.copy(isStreaming = false, error = e.message ?: e.toString())
                }
            }
        }
    }

    fun stop() {
        streamJob?.cancel()
        streamJob = null
        val convo = _ui.value.conversation ?: return
        val stopped = convo.copy(
            messages = convo.messages.map { it.copy(isStreaming = false) },
        )
        _ui.value = _ui.value.copy(conversation = stopped, isStreaming = false)
        store.upsert(stopped)
    }

    private fun patchAssistant(id: String, content: String, thinking: String?, streaming: Boolean) {
        val convo = _ui.value.conversation ?: return
        _ui.value = _ui.value.copy(
            conversation = convo.copy(
                messages = convo.messages.map {
                    if (it.id == id) it.copy(content = content, thinkingContent = thinking, isStreaming = streaming)
                    else it
                },
            ),
        )
    }

    private suspend fun generateAiTitle(conversationId: String, prompt: String) {
        try {
            val current = store.conversations.value.firstOrNull { it.id == conversationId } ?: return
            var title = ""
            llm.streamCompletion(
                messages = listOf(
                    Message(
                        role = MessageRole.USER,
                        content = "Create a concise, descriptive 2-4 word title in the language of this query: \"$prompt\". Output ONLY the title, no quotes or punctuation.",
                    ),
                ),
                provider = current.provider,
                modelId = current.modelId,
                baseUrl = AuthManager.API_BASE_URL + "/nwtn",
                apiKey = auth.nwtnKey,
                temperature = 0.3,
                maxTokens = 15,
                systemPrompt = "You are a concise title generator. Reply ONLY with a 2-4 word title.",
            ).collect { title += it }
            val clean = title.trim().replace("\"", "").replace("\n", " ")
            if (clean.isNotEmpty()) {
                val renamed = current.copy(title = clean)
                store.upsert(renamed)
                if (_ui.value.conversation?.id == conversationId) {
                    _ui.value = _ui.value.copy(conversation = renamed)
                }
                if (auth.isLoggedIn.value && !renamed.isGhost) {
                    cloudService.updateChat(renamed.id, title = clean)
                }
            }
        } catch (_: Exception) {}
    }

    override fun onCleared() {
        super.onCleared()
        streamJob?.cancel()
        peerEventsJob?.cancel()
    }

    companion object {
        fun titleFrom(prompt: String): String =
            prompt.split(" ").take(4).joinToString(" ").ifEmpty { "New Conversation" }

        fun mergeThinking(live: String, engine: String): String {
            val a = live.trim()
            val b = engine.trim()
            return when {
                a.isEmpty() -> b
                b.isEmpty() -> a
                b.contains(a) -> b
                a.contains(b) -> a
                else -> "$a\n\n---\n\n$b"
            }
        }
    }
}
