package ai.newton.shared

import kotlinx.serialization.Serializable

/** Mirrors Swift `AIModel` + `DefaultModelCatalog`. */
@Serializable
data class AIModel(
    val id: String,
    val name: String,
    val provider: AIProvider,
    val description: String = "",
    val iconKey: String = "sparkles",
)

object DefaultModelCatalog {
    fun models(provider: AIProvider): List<AIModel> = when (provider) {
        AIProvider.OPENROUTER -> listOf(
            AIModel("anthropic/claude-3.5-sonnet", "Claude 3.5 Sonnet", provider, "Top tier reasoning & code"),
            AIModel("deepseek/deepseek-r1", "DeepSeek R1", provider, "SOTA reasoning model"),
            AIModel("openai/gpt-4o", "GPT-4o", provider, "Flagship multimodal"),
            AIModel("openai/gpt-4o-mini", "GPT-4o Mini", provider, "Fast & lightweight"),
            AIModel("meta-llama/llama-3.3-70b-instruct", "Llama 3.3 70B", provider, "Open source leader"),
            AIModel("google/gemini-2.0-flash-exp:free", "Gemini 2.0 Flash (Free)", provider, "Fast experimental model"),
        )
        AIProvider.OPENAI -> listOf(
            AIModel("gpt-4o", "GPT-4o", provider, "Flagship intelligence"),
            AIModel("gpt-4o-mini", "GPT-4o Mini", provider, "Fast & affordable"),
            AIModel("o3-mini", "o3-mini", provider, "Reasoning for STEM & code"),
            AIModel("gpt-4-turbo", "GPT-4 Turbo", provider, "Previous generation flagship"),
        )
        AIProvider.ANTHROPIC -> listOf(
            AIModel("claude-3-7-sonnet-20250219", "Claude 3.7 Sonnet", provider, "Hybrid reasoning & speed"),
            AIModel("claude-3-5-sonnet-20241022", "Claude 3.5 Sonnet", provider, "High-intelligence code & analysis"),
            AIModel("claude-3-5-haiku-20241022", "Claude 3.5 Haiku", provider, "Fastest compact Claude model"),
            AIModel("claude-3-opus-20240229", "Claude 3 Opus", provider, "Deep analysis & writing"),
        )
        AIProvider.OPENAI_COMPATIBLE -> listOf(
            AIModel("newton-singularity", "Newton Singularity", provider, "Active loaded model"),
            AIModel("default", "Default Server Model", provider, "Active loaded model"),
            AIModel("llama-3.3-70b-instruct", "Llama 3.3 70B", provider, "Hosted or local Llama"),
            AIModel("deepseek-r1", "DeepSeek R1", provider, "Local reasoning model"),
            AIModel("qwen2.5-coder-32b-instruct", "Qwen 2.5 Coder 32B", provider, "Code specialist"),
        )
        AIProvider.ANTHROPIC_COMPATIBLE -> listOf(
            AIModel("claude-3-7-sonnet-20250219", "Claude 3.7 Sonnet", provider, "Proxy / Gateway Anthropic 3.7"),
            AIModel("claude-3-5-sonnet-20241022", "Claude 3.5 Sonnet", provider, "Proxy / Gateway Anthropic 3.5"),
            AIModel("claude-3-5-haiku-20241022", "Claude 3.5 Haiku", provider, "Proxy / Gateway Anthropic Haiku"),
        )
        AIProvider.GEMINI -> listOf(
            AIModel("gemini-1.5-flash", "Gemini 1.5 Flash", provider, "Fast performance"),
            AIModel("gemini-1.5-pro", "Gemini 1.5 Pro", provider, "Complex reasoning"),
            AIModel("gemini-2.0-flash-exp", "Gemini 2.0 Flash Exp", provider, "Next-gen experimental"),
        )
        AIProvider.GROQ -> listOf(
            AIModel("llama-3.3-70b-versatile", "Llama 3.3 70B", provider, "Ultra-fast inference"),
            AIModel("deepseek-r1-distill-llama-70b", "DeepSeek R1 Distill 70B", provider, "Fast reasoning on Groq"),
            AIModel("mixtral-8x7b-32768", "Mixtral 8x7B", provider, "Mixture of experts"),
        )
        AIProvider.DEEPSEEK -> listOf(
            AIModel("deepseek-chat", "DeepSeek-V3", provider, "General intelligence"),
            AIModel("deepseek-reasoner", "DeepSeek-R1", provider, "Chain-of-thought reasoning"),
        )
        AIProvider.OLLAMA -> listOf(
            AIModel("llama3", "Llama 3", provider, "Local Ollama model"),
            AIModel("mistral", "Mistral 7B", provider, "Local Ollama model"),
            AIModel("deepseek-r1", "DeepSeek R1", provider, "Local Ollama reasoning"),
            AIModel("qwen2.5", "Qwen 2.5", provider, "Local Ollama Qwen"),
        )
    }
}
