package ai.newton.android.chat

import ai.newton.android.data.ConversationStore
import ai.newton.android.data.SettingsRepository
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
 * Android counterpart of Swift `ChatView.sendMessage` /
 * `generateAITitle` (ios/Newton/Views/Chat/ChatView.swift).
 *
 * Same live-parse rules: thinking tags (open + closed, both spellings) and
 * orbit/download tags are hidden from [visibleResponse] while streaming; the
 * full [rawStream] is kept and passed to [OrbitEngine] at the end, so tags
 * split across SSE chunks still execute. Thinking accumulated live is merged
 * with the engine's parse the same way Swift does.
 */
class ChatViewModel(
    private val store: ConversationStore,
    private val settings: SettingsRepository,
    private val llm: LLMService = LLMService(),
    private val orbits: OrbitEngine = OrbitEngine(),
) : ViewModel() {

    private val _ui = MutableStateFlow(ChatUiState())
    val ui: StateFlow<ChatUiState> = _ui.asStateFlow()

    private var streamJob: Job? = null

    // Last-known settings, kept fresh by collectors below. Avoids runBlocking
    // on Main: DataStore reads are async, and blocking Main for them can jank.
    private var cachedProvider: AIProvider = AIProvider.OPENAI_COMPATIBLE
    private var cachedModelId: String = AIProvider.OPENAI_COMPATIBLE.defaultModelId

    init {
        viewModelScope.launch {
            settings.provider.collect { cachedProvider = it }
        }
        viewModelScope.launch {
            settings.modelId.collect { cachedModelId = it }
        }
    }

    fun open(conversationId: String) {
        _ui.value = _ui.value.copy(
            conversation = store.conversations.value.firstOrNull { it.id == conversationId },
            error = null,
        )
    }

    fun newConversation(title: String = "New Conversation"): String {
        val convo = Conversation(
            title = title,
            provider = cachedProvider,
            modelId = cachedModelId,
        )
        store.upsert(convo)
        _ui.value = ChatUiState(conversation = convo)
        return convo.id
    }

    fun send(prompt: String, imageFileUrl: String? = null) {
        val text = prompt.trim()
        if (text.isEmpty() && imageFileUrl == null) return
        val convo = _ui.value.conversation ?: run {
            newConversation()
            _ui.value.conversation!!
        }

        val displayPrompt = text.ifEmpty { "Describe and analyze this image." }
        val withUser = convo.copy(
            title = if (convo.messages.isEmpty()) titleFrom(text) else convo.title,
            messages = convo.messages + Message(
                role = MessageRole.USER,
                content = displayPrompt,
                imageUrl = imageFileUrl,
            ),
        )
        val assistantId = UUID.randomUUID().toString()
        val withPlaceholder = withUser.copy(
            messages = withUser.messages + Message(
                id = assistantId,
                role = MessageRole.ASSISTANT,
                content = "",
                isStreaming = true,
            ),
        )
        _ui.value = _ui.value.copy(conversation = withPlaceholder, isStreaming = true, error = null)

        streamJob?.cancel()
        streamJob = viewModelScope.launch {
            var rawStream = ""
            var visible = ""
            var thinking = ""
            var insideThinking = false
            try {
                val provider = withPlaceholder.provider
                val workspacePrompt = "" // wired to Workspace store in the workspaces milestone
                val systemPrompt = buildString {
                    append(SingularityPrompt.base)
                    if (workspacePrompt.isNotEmpty()) {
                        append("\n\n[ACTIVE PROJECT WORKSPACE]\n").append(workspacePrompt)
                    }
                }
                llm.streamCompletion(
                    messages = withPlaceholder.messages.dropLast(1),
                    provider = provider,
                    modelId = withPlaceholder.modelId,
                    baseUrl = settings.effectiveBaseUrl(provider),
                    apiKey = settings.getApiKey(provider),
                    systemPrompt = systemPrompt,
                ).collect { token ->
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

                val processed = orbits.processOrbitsInText(
                    rawStream,
                    userPrompt = displayPrompt,
                    baseUrl = settings.effectiveBaseUrl(withPlaceholder.provider),
                    apiKey = settings.getApiKey(withPlaceholder.provider),
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

                if (withUser.messages.size == 1 && displayPrompt.isNotEmpty()) {
                    launch { generateAiTitle(finished.id, displayPrompt) }
                }
            } catch (e: Exception) {
                val kept = _ui.value.conversation
                if (kept != null) {
                    val cleaned = if (visible.isEmpty()) {
                        kept.copy(messages = kept.messages.filterNot { it.id == assistantId })
                    } else {
                        kept.copy(
                            messages = kept.messages.map {
                                if (it.id == assistantId) it.copy(isStreaming = false) else it
                            },
                        )
                    }
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
                        content = "Create a concise, descriptive 2-4 word title in the language of this query: \"$prompt\". " +
                            "Output ONLY the title, no quotes or punctuation.",
                    ),
                ),
                provider = current.provider,
                modelId = current.modelId,
                baseUrl = settings.effectiveBaseUrl(current.provider),
                apiKey = settings.getApiKey(current.provider),
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
            }
        } catch (_: Exception) {
            // Title generation is best-effort (mirrors Swift fallback).
        }
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

/** Live streaming parse — same tag rules as Swift `ChatView.sendMessage`. */
object LiveParse {
    data class Result(val visible: String, val thinking: String, val insideThinking: Boolean)

    private val closed = Regex("""<think(?:ing)?>([\s\S]*?)</think(?:ing)?>""", RegexOption.IGNORE_CASE)
    private val strayClose = Regex("""</think(?:ing)?>""", RegexOption.IGNORE_CASE)
    private val orbitTag = Regex("""<orbit:[^>]*>[\s\S]*?(?:</orbit:[^>]*>|$)""", RegexOption.IGNORE_CASE)
    private val downloadTag = Regex("""<download>[\s\S]*?(?:</download>|$)""", RegexOption.IGNORE_CASE)

    fun parse(rawStream: String): Result {
        var display = rawStream
        var think = ""
        closed.findAll(display).toList().reversed().forEach { m ->
            val inner = m.groups[1]?.value.orEmpty()
            think = if (think.isEmpty()) inner else "$inner\n\n---\n\n$think"
            display = display.replace(m.value, "")
        }
        var inside = false
        val openIdx = display.indexOf("<think", ignoreCase = true)
        if (openIdx >= 0) {
            val tail = display.substring(openIdx)
            if (!tail.contains("</think", ignoreCase = true)) {
                val tagEnd = tail.indexOf('>')
                val thoughtTail = if (tagEnd >= 0) tail.substring(tagEnd + 1) else ""
                if (thoughtTail.trim().isNotEmpty()) {
                    think += (if (think.isEmpty()) "" else "\n\n---\n\n") + thoughtTail
                }
                display = display.substring(0, openIdx)
                inside = true
            }
        }
        display = strayClose.replace(display, "")
        display = orbitTag.replace(display, "")
        display = downloadTag.replace(display, "")
        return Result(display, think, inside)
    }
}
