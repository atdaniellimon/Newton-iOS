package ai.newton.shared

import kotlinx.serialization.Serializable
import java.util.UUID

/** Mirrors Swift `FileAttachment`. */
@Serializable
data class FileAttachment(
    val id: String = UUID.randomUUID().toString(),
    val fileName: String,
    val fileExtension: String,
    val fileSizeFormatted: String,
    val lineCount: Int? = null,
    val previewSnippet: String? = null,
    val mimeType: String = "text/plain",
    val isImage: Boolean = false,
    val base64Data: String? = null,
    val localPath: String? = null,
) {
    /**
     * Platform-agnostic icon key. The Android app maps these to drawables;
     * the key set mirrors the Swift `iconName` switch intent (SF Symbols -> keys).
     */
    val iconKey: String
        get() = when (fileExtension.lowercase()) {
            "swift", "kt", "kts", "c", "cpp", "h", "py", "js", "ts",
            "html", "css", "rs", "go", "java" -> "code"
            "pdf" -> "pdf"
            "json", "xml", "yaml", "yml", "plist", "toml" -> "data"
            "png", "jpg", "jpeg", "gif", "webp", "heic", "svg" -> "image"
            "mp3", "wav", "m4a", "aac", "ogg" -> "audio"
            "zip", "tar", "gz", "apk", "aab" -> "archive"
            "md", "markdown", "txt" -> "doc"
            else -> "file"
        }
}
