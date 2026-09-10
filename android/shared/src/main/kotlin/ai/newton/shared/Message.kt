package ai.newton.shared

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
enum class MessageRole {
    @SerialName("system") SYSTEM,
    @SerialName("user") USER,
    @SerialName("assistant") ASSISTANT;

    /** Wire value matching Swift `MessageRole.rawValue`. */
    val wireValue: String
        get() = when (this) {
            SYSTEM -> "system"
            USER -> "user"
            ASSISTANT -> "assistant"
        }
}

/** Mirrors Swift `OrbitExecutionResult`. */
@Serializable
data class OrbitExecutionResult(
    val id: String = UUID.randomUUID().toString(),
    val orbitName: String = "orbit",
    val params: String = "",
    val result: String = "",
    val isSuccess: Boolean = true,
)

/**
 * Mirrors Swift `Message`.
 * Timestamps are epoch millis (Long). When syncing with iOS JSON (seconds Double),
 * convert: `millis = (seconds * 1000).toLong()`.
 */
@Serializable
data class Message(
    val id: String = UUID.randomUUID().toString(),
    val role: MessageRole = MessageRole.ASSISTANT,
    val content: String = "",
    val thinkingContent: String? = null,
    val imageUrl: String? = null,
    val orbitResults: List<OrbitExecutionResult> = emptyList(),
    val attachments: List<FileAttachment> = emptyList(),
    val createdAt: Long = System.currentTimeMillis(),
    val isStreaming: Boolean = false,
)
