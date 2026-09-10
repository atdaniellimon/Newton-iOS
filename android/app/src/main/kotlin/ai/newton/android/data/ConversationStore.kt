package ai.newton.android.data

import ai.newton.shared.Conversation
import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Android counterpart of Swift `StorageManager`.
 *
 * Difference from iOS (fix, not port): conversations persist as one JSON file
 * PER conversation instead of a single `newton_conversations_v1.json`, so the
 * 1MB-bag limit class of bug behind iOS finding #2 cannot recur. Images are
 * stored as separate files under `images/`; messages MUST reference them via
 * `FileAttachment.localPath` or `Message.imageUrl = file://…`, never inline
 * base64 in the JSON.
 */
class ConversationStore(appContext: Context) {

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val dir: File = File(appContext.filesDir, "conversations").apply { mkdirs() }
    private val imagesDir: File = File(appContext.filesDir, "images").apply { mkdirs() }

    private val _conversations = MutableStateFlow<List<Conversation>>(loadAll())
    val conversations: StateFlow<List<Conversation>> = _conversations.asStateFlow()

    fun imageFile(name: String): File = File(imagesDir, name)

    fun upsert(conversation: Conversation) {
        val updated = conversation.copy(updatedAt = System.currentTimeMillis())
        write(updated)
        _conversations.value = sort((_conversations.value.filterNot { it.id == updated.id } + updated))
    }

    fun remove(id: String) {
        File(dir, "$id.json").delete()
        _conversations.value = _conversations.value.filterNot { it.id == id }
    }

    fun purgeGhosts() {
        _conversations.value.filter { it.isGhost }.forEach { remove(it.id) }
    }

    private fun sort(list: List<Conversation>): List<Conversation> =
        list.sortedWith(
            compareByDescending<Conversation> { it.isPinned }
                .thenByDescending { it.updatedAt },
        )

    private fun write(conversation: Conversation) {
        // Ghost sessions are ephemeral: never touch disk (mirrors Swift).
        if (conversation.isGhost) return
        File(dir, "${conversation.id}.json").writeText(json.encodeToString(conversation))
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
