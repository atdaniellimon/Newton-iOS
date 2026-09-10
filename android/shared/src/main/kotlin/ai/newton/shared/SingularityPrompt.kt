package ai.newton.shared

/**
 * Loads the Newton Singularity Core system prompt.
 *
 * Source of truth: `shared/src/main/resources/singularity_prompt.md`,
 * extracted verbatim from Swift `SettingsManager.singularitySystemPrompt`
 * (ios/Newton/Services/SettingsManager.swift). Keep both in sync;
 * the iOS string is the canonical copy until a codegen step exists.
 *
 * [memorySection] mirrors the "PERSISTENT USER LONG-TERM MEMORY SYSTEM"
 * block that Swift `LLMService` appends at request time.
 */
object SingularityPrompt {
    const val RESOURCE_PATH = "singularity_prompt.md"

    val base: String by lazy {
        SingularityPrompt::class.java.classLoader
            ?.getResourceAsStream(RESOURCE_PATH)
            ?.bufferedReader(Charsets.UTF_8)
            ?.readText()
            ?.trim()
            .orEmpty()
    }

    fun memorySection(memoryFacts: String): String {
        val facts = memoryFacts.ifBlank {
            "(No specific facts stored yet. When the user tells you about themselves, " +
                "their stack, or says 'remember that...', invoke " +
                "<orbit:save_memory>{\"fact\": \"...\"}</orbit:save_memory> organically to save it permanently.)"
        }
        return """

        ==================================================
        PERSISTENT USER LONG-TERM MEMORY SYSTEM
        ==================================================
        - You POSSESS an active persistent memory system across all sessions and conversations.
        - You DO remember past facts stored in your memory system. NEVER claim you cannot remember things across sessions or that you have no memory.
        - When the user asks who they are, what you remember, or what you know about them, recite their stored facts clearly.
        - Current stored user memories:
        $facts

        MEMORY USAGE DIRECTIVES (STRICT):
        - Naturally ground your technical depth, recommendations, architectural solutions, and tone using this knowledge.
        - DO NOT nag the user or force awkward conversational small talk (NEVER spontaneously ask 'How is project X going?' or 'How is your company doing?'). Only reference past projects or facts when directly relevant to answering the user's current request.
        - If the user shares new persistent facts about themselves or says 'remember that...', invoke `<orbit:save_memory>{"fact": "..."}</orbit:save_memory>` organically.
        """.trimIndent()
    }

    /** Full effective system prompt, mirroring Swift `LLMService.constructPayload`. */
    fun effective(basePrompt: String = base, memoryFacts: String = ""): String {
        val root = basePrompt.ifBlank { base }
        return root + "\n\n" + memorySection(memoryFacts)
    }
}
