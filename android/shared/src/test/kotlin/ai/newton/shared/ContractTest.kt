package ai.newton.shared

import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ContractTest {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    @Test
    fun `wire values match Swift rawValues`() {
        assertEquals("openrouter", AIProvider.OPENROUTER.wireValue)
        assertEquals("openai_compatible", AIProvider.OPENAI_COMPATIBLE.wireValue)
        assertEquals("anthropic_compatible", AIProvider.ANTHROPIC_COMPATIBLE.wireValue)
        assertEquals("ollama", AIProvider.OLLAMA.wireValue)
    }

    @Test
    fun `unknown provider falls back like Swift`() {
        assertEquals(AIProvider.OPENAI_COMPATIBLE, AIProvider.fromWire("nope"))
        assertEquals(AIProvider.OPENAI_COMPATIBLE, AIProvider.fromWire(null))
        assertEquals(AIProvider.GROQ, AIProvider.fromWire("groq"))
    }

    @Test
    fun `conversation json round-trips with stable field names`() {
        val convo = Conversation(
            title = "Test",
            provider = AIProvider.OPENAI,
            modelId = "gpt-4o-mini",
            messages = listOf(
                Message(role = MessageRole.USER, content = "hola"),
                Message(
                    role = MessageRole.ASSISTANT,
                    content = "respuesta",
                    thinkingContent = "pensando",
                    orbitResults = listOf(
                        OrbitExecutionResult(orbitName = "calculator", params = "{}", result = "4", isSuccess = true),
                    ),
                ),
            ),
            isPinned = true,
        )
        val raw = json.encodeToString(convo)
        // Cross-platform field names (must match Swift CodingKeys).
        listOf(
            "\"title\"", "\"provider\"", "\"modelId\"", "\"messages\"",
            "\"isPinned\"", "\"isGhost\"", "\"createdAt\"", "\"updatedAt\"",
            "\"thinkingContent\"", "\"orbitResults\"", "\"isStreaming\"",
        ).forEach { assertTrue("missing $it in $raw", raw.contains(it)) }

        val decoded = json.decodeFromString<Conversation>(raw)
        assertEquals(convo.title, decoded.title)
        assertEquals(2, decoded.messages.size)
        assertEquals("pensando", decoded.messages[1].thinkingContent)
        assertEquals("calculator", decoded.messages[1].orbitResults.single().orbitName)
    }

    @Test
    fun `singularity prompt loads and composes with memory`() {
        assertTrue(SingularityPrompt.base.length > 10_000)
        assertTrue(SingularityPrompt.base.contains("Newton Singularity"))
        assertTrue(SingularityPrompt.base.contains("ORBIT CATALOG"))

        val withMemory = SingularityPrompt.effective(memoryFacts = "• Prefiere Kotlin")
        assertTrue(withMemory.contains("Prefiere Kotlin"))
        assertTrue(withMemory.contains("PERSISTENT USER LONG-TERM MEMORY SYSTEM"))

        val empty = SingularityPrompt.effective(memoryFacts = "")
        assertTrue(empty.contains("No specific facts stored yet"))
    }

    @Test
    fun `catalog covers every provider`() {
        AIProvider.entries.forEach { provider ->
            assertTrue(
                "empty catalog for $provider",
                DefaultModelCatalog.models(provider).isNotEmpty(),
            )
        }
        // Newton default model exists for the local-compatible provider.
        assertTrue(
            DefaultModelCatalog.models(AIProvider.OPENAI_COMPATIBLE)
                .any { it.id == "newton-singularity" },
        )
    }
}
