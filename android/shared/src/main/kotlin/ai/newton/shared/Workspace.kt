package ai.newton.shared

import kotlinx.serialization.Serializable
import java.util.UUID

/** Mirrors Swift `Workspace`. */
@Serializable
data class Workspace(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val iconName: String = "folder.fill",
    val colorHex: String = "#F5A623",
    val customSystemPrompt: String = "",
    val attachedFiles: List<FileAttachment> = emptyList(),
    val createdAt: Long = System.currentTimeMillis(),
)

@Serializable
data class MemoryItem(
    val id: String = UUID.randomUUID().toString(),
    val content: String,
    val category: String = "general",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
)
