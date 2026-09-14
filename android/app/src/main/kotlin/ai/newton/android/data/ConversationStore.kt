package ai.newton.android.data

import ai.newton.shared.AIProvider
import ai.newton.shared.Conversation
import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

class ConversationStore(private val appContext: Context) {

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val dir: File = File(appContext.filesDir, "conversations").apply { mkdirs() }
    private val imagesDir: File = File(appContext.filesDir, "images").apply { mkdirs() }

    private val _conversations = MutableStateFlow<List<Conversation>>(loadAll())
    val conversations: StateFlow<List<Conversation>> = _conversations.asStateFlow()

    fun imageFile(name: String): File = File(imagesDir, name)

    fun createConversation(
        title: String = "New Conversation",
        modelId: String = "Singularity",
    ): Conversation {
        val newConvo = Conversation(
            title = title,
            provider = AIProvider.NEWTON,
            modelId = modelId,
            messages = emptyList(),
            isPinned = false,
            isGhost = false,
        )
        upsert(newConvo)
        return newConvo
    }

    fun createGhostConversation(title: String = "Ghost Session"): Conversation {
        val ghost = Conversation(
            title = title,
            provider = AIProvider.NEWTON,
            modelId = "Singularity",
            messages = emptyList(),
            isPinned = false,
            isGhost = true,
        )
        // Ephemeral: only in memory
        _conversations.value = listOf(ghost) + _conversations.value.filterNot { it.id == ghost.id }
        return ghost
    }

    fun togglePin(id: String) {
        val current = _conversations.value.firstOrNull { it.id == id } ?: return
        val updated = current.copy(isPinned = !current.isPinned)
        upsert(updated)
    }

    fun upsert(conversation: Conversation) {
        val updated = conversation.copy(updatedAt = System.currentTimeMillis())
        write(updated)
        val filtered = _conversations.value.filterNot { it.id == updated.id }
        _conversations.value = sort(filtered + updated)
    }

    fun updateConversationId(fromId: String, toId: String, updated: Conversation) {
        if (fromId != toId) {
            File(dir, "$fromId.json").delete()
        }
        upsert(updated.copy(id = toId))
    }

    fun remove(id: String) {
        File(dir, "$id.json").delete()
        _conversations.value = _conversations.value.filterNot { it.id == id }
    }

    fun purgeGhosts() {
        _conversations.value = _conversations.value.filterNot { it.isGhost }
    }

    fun clearAllConversations() {
        dir.listFiles()?.forEach { it.delete() }
        _conversations.value = emptyList()
    }

    suspend fun syncWithRemoteServer(cloudService: CloudChatService, auth: AuthManager) = withContext(Dispatchers.IO) {
        if (!auth.isLoggedIn.value) return@withContext
        try {
            val remoteChats = cloudService.fetchChats()
            val ghosts = _conversations.value.filter { it.isGhost }

            val merged = mutableListOf<Conversation>()
            for (rChat in remoteChats) {
                val existing = _conversations.value.firstOrNull { it.id == rChat.id }
                if (existing != null) {
                    var updated = rChat.copy(
                        isPinned = rChat.isPinned,
                        title = rChat.title,
                        modelId = rChat.modelId,
                    )
                    if (existing.messages.isNotEmpty()) {
                        updated = updated.copy(messages = existing.messages)
                    }
                    write(updated)
                    merged.add(updated)
                } else {
                    write(rChat)
                    merged.add(rChat)
                }
            }

            _conversations.value = sort(ghosts + merged)
        } catch (_: Exception) {}
    }

    fun handleRemoteSyncEvent(event: CloudSyncEvent) {
        val chatId = event.chatId ?: return
        when (event.event) {
            CloudSyncEventType.CHAT_CREATED -> {
                if (_conversations.value.none { it.id == chatId }) {
                    val newConvo = Conversation(
                        id = chatId,
                        title = event.title ?: "New Conversation",
                        provider = AIProvider.NEWTON,
                        modelId = event.model ?: "Singularity",
                        messages = emptyList(),
                        isPinned = event.isPinned ?: false,
                        isGhost = false,
                        createdAt = System.currentTimeMillis(),
                        updatedAt = event.updatedAt ?: System.currentTimeMillis(),
                    )
                    upsert(newConvo)
                }
            }
            CloudSyncEventType.CHAT_UPDATED -> {
                val existing = _conversations.value.firstOrNull { it.id == chatId }
                if (existing != null) {
                    val updated = existing.copy(
                        title = event.title ?: existing.title,
                        isPinned = event.isPinned ?: existing.isPinned,
                        modelId = event.model ?: existing.modelId,
                        updatedAt = event.updatedAt ?: System.currentTimeMillis(),
                    )
                    upsert(updated)
                }
            }
            CloudSyncEventType.CHAT_DELETED -> {
                remove(chatId)
            }
            CloudSyncEventType.UNKNOWN -> {}
        }
    }

    private fun sort(list: List<Conversation>): List<Conversation> =
        list.sortedWith(
            compareByDescending<Conversation> { it.isPinned }
                .thenByDescending { it.updatedAt },
        )

    private fun write(conversation: Conversation) {
        if (conversation.isGhost) return
        try {
            File(dir, "${conversation.id}.json").writeText(json.encodeToString(conversation))
        } catch (_: Exception) {}
    }

    private fun loadAll(): List<Conversation> {
        val files = dir.listFiles { f -> f.extension == "json" }.orEmpty()
        val loaded = files.mapNotNull { file ->
            try {
                json.decodeFromString<Conversation>(file.readText())
            } catch (_: Exception) {
                null
            }
        }
        return sort(loaded)
    }
}
