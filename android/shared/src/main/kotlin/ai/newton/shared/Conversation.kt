package ai.newton.shared

import kotlinx.serialization.Serializable
import java.util.UUID

/** Mirrors Swift `Conversation`. See [Message] for timestamp convention. */
@Serializable
data class Conversation(
    val id: String = UUID.randomUUID().toString(),
    val title: String = "New Conversation",
    val provider: AIProvider = AIProvider.OPENROUTER,
    val modelId: String = "anthropic/claude-3.5-sonnet",
    val messages: List<Message> = emptyList(),
    val isPinned: Boolean = false,
    val isGhost: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
)
