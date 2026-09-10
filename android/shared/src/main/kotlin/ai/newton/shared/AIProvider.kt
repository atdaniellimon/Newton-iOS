package ai.newton.shared

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Mirrors Swift `AIProvider` (ios/Newton/Models/AIProvider.swift).
 * `wireValue` matches the Swift rawValue so JSON stays cross-platform compatible.
 */
@Serializable
enum class AIProvider(val wireValue: String) {
    @SerialName("openrouter") OPENROUTER("openrouter"),
    @SerialName("openai") OPENAI("openai"),
    @SerialName("anthropic") ANTHROPIC("anthropic"),
    @SerialName("openai_compatible") OPENAI_COMPATIBLE("openai_compatible"),
    @SerialName("anthropic_compatible") ANTHROPIC_COMPATIBLE("anthropic_compatible"),
    @SerialName("gemini") GEMINI("gemini"),
    @SerialName("groq") GROQ("groq"),
    @SerialName("deepseek") DEEPSEEK("deepseek"),
    @SerialName("ollama") OLLAMA("ollama");

    val displayName: String
        get() = when (this) {
            OPENROUTER -> "OpenRouter"
            OPENAI -> "OpenAI"
            ANTHROPIC -> "Anthropic"
            OPENAI_COMPATIBLE -> "OpenAI Compatible (Custom / Local)"
            ANTHROPIC_COMPATIBLE -> "Anthropic Compatible (Custom / Proxy)"
            GEMINI -> "Google Gemini"
            GROQ -> "Groq"
            DEEPSEEK -> "DeepSeek"
            OLLAMA -> "Ollama (Local API)"
        }

    val defaultBaseUrl: String
        get() = when (this) {
            OPENROUTER -> "https://openrouter.ai/api/v1"
            OPENAI -> "https://api.openai.com/v1"
            ANTHROPIC -> "https://api.anthropic.com/v1"
            OPENAI_COMPATIBLE -> "http://localhost:1234/v1"
            ANTHROPIC_COMPATIBLE -> "https://api.anthropic.com/v1"
            GEMINI -> "https://generativelanguage.googleapis.com/v1beta/openai"
            GROQ -> "https://api.groq.com/openai/v1"
            DEEPSEEK -> "https://api.deepseek.com/v1"
            OLLAMA -> "http://localhost:11434/v1"
        }

    val isCustomOrLocal: Boolean
        get() = this == OLLAMA || this == OPENAI_COMPATIBLE || this == ANTHROPIC_COMPATIBLE

    val isAnthropicProtocol: Boolean
        get() = this == ANTHROPIC || this == ANTHROPIC_COMPATIBLE

    val defaultModelId: String
        get() = when (this) {
            OPENROUTER -> "anthropic/claude-3.5-sonnet"
            OPENAI -> "gpt-4o-mini"
            ANTHROPIC -> "claude-3-7-sonnet-20250219"
            OPENAI_COMPATIBLE -> "default"
            ANTHROPIC_COMPATIBLE -> "claude-3-7-sonnet-20250219"
            GEMINI -> "gemini-1.5-flash"
            GROQ -> "llama-3.3-70b-versatile"
            DEEPSEEK -> "deepseek-chat"
            OLLAMA -> "llama3"
        }

    companion object {
        /** Matches Swift `AIProvider(rawValue:) ?? .openaiCompatible` fallback. */
        fun fromWire(value: String?): AIProvider =
            entries.firstOrNull { it.wireValue == value } ?: OPENAI_COMPATIBLE
    }
}
