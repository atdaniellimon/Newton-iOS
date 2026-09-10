package ai.newton.shared

import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LLMServiceTest {

    private val service = LLMService()

    @Test
    fun `endpoint selection mirrors Swift`() {
        assertEquals(
            "https://api.anthropic.com/v1/messages",
            service.constructEndpointURL(AIProvider.ANTHROPIC, "ignored"),
        )
        assertEquals(
            "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
            service.constructEndpointURL(AIProvider.GEMINI, "ignored"),
        )
        assertEquals(
            "http://localhost:11434/v1/api/chat",
            service.constructEndpointURL(AIProvider.OLLAMA, "http://localhost:11434/v1"),
        )
        assertEquals(
            "https://x.trycloudflare.com/v1/chat/completions",
            service.constructEndpointURL(AIProvider.OPENAI_COMPATIBLE, "https://x.trycloudflare.com/v1"),
        )
        assertEquals(
            "https://x.trycloudflare.com/v1/chat/completions",
            service.constructEndpointURL(AIProvider.OPENAI_COMPATIBLE, "https://x.trycloudflare.com/v1/"),
        )
        // Bare host gets /v1/chat/completions, like Swift.
        assertEquals(
            "https://myhost.com/v1/chat/completions",
            service.constructEndpointURL(AIProvider.OPENAI, "https://myhost.com"),
        )
    }

    @Test
    fun `openai payload puts system first and streams`() {
        val payload = service.buildPayload(
            provider = AIProvider.OPENAI,
            modelId = "gpt-4o-mini",
            messages = listOf(Message(role = MessageRole.USER, content = "hola")),
            temperature = 0.7,
            maxTokens = 100,
            systemPrompt = "SYS",
            memoryFacts = "",
        )
        assertEquals("gpt-4o-mini", payload["model"]!!.jsonPrimitive.content)
        assertEquals(true, payload["stream"]!!.jsonPrimitive.content.toBoolean())
        val msgs = payload["messages"]!!.jsonArray
        assertEquals("system", msgs[0].jsonObject["role"]!!.jsonPrimitive.content)
        assertTrue(msgs[0].jsonObject["content"]!!.jsonPrimitive.content.contains("SYS"))
        assertTrue(msgs[0].jsonObject["content"]!!.jsonPrimitive.content.contains("PERSISTENT USER LONG-TERM MEMORY"))
        assertEquals("user", msgs[1].jsonObject["role"]!!.jsonPrimitive.content)
    }

    @Test
    fun `anthropic payload uses system field, no system message`() {
        val payload = service.buildPayload(
            provider = AIProvider.ANTHROPIC,
            modelId = "claude-3-7-sonnet-20250219",
            messages = listOf(
                Message(role = MessageRole.SYSTEM, content = "skip me"),
                Message(role = MessageRole.USER, content = "hi"),
            ),
            temperature = 0.7,
            maxTokens = 100,
            systemPrompt = "SYS",
        )
        // System message filtered out; system lives in its own field.
        val msgs = payload["messages"]!!.jsonArray
        assertEquals(1, msgs.size)
        assertEquals("user", msgs[0].jsonObject["role"]!!.jsonPrimitive.content)
        assertTrue(payload["system"]!!.jsonPrimitive.content.contains("SYS"))
    }

    @Test
    fun `vision message becomes image_url block`() {
        val payload = service.buildPayload(
            provider = AIProvider.OPENAI,
            modelId = "gpt-4o-mini",
            messages = listOf(
                Message(role = MessageRole.USER, content = "", imageUrl = "data:image/jpeg;base64,AAA"),
            ),
            temperature = 0.7,
            maxTokens = 100,
            systemPrompt = "SYS",
        )
        val content = payload["messages"]!!.jsonArray[1].jsonObject["content"]!!.jsonArray
        assertEquals(2, content.size)
        assertEquals("image_url", content[1].jsonObject["type"]!!.jsonPrimitive.content)
    }

    @Test
    fun `parseToken openai delta`() {
        val token = service.parseToken(
            """{"choices":[{"delta":{"content":"Hello"}}]}""",
            AIProvider.OPENAI,
        )
        assertEquals("Hello", token)
    }

    @Test
    fun `parseToken reasoning becomes thinking tag`() {
        val token = service.parseToken(
            """{"choices":[{"delta":{"reasoning_content":"step one"}}]}""",
            AIProvider.OPENAI,
        )
        assertEquals("<thinking>step one</thinking>", token)
    }

    @Test
    fun `parseToken anthropic delta`() {
        val token = service.parseToken(
            """{"type":"content_block_delta","delta":{"text":"world"}}""",
            AIProvider.ANTHROPIC,
        )
        assertEquals("world", token)
        assertNull(
            service.parseToken("""{"type":"message_start"}""", AIProvider.ANTHROPIC),
        )
    }

    @Test
    fun `streamCompletion yields SSE tokens and stops at DONE`() = runTest {
        val server = MockWebServer()
        try {
            server.enqueue(
                MockResponse()
                    .setResponseCode(200)
                    .setBody(
                        "data: {\"choices\":[{\"delta\":{\"content\":\"Hola\"}}]}\n\n" +
                            "data: {\"choices\":[{\"delta\":{\"content\":\" mundo\"}}]}\n\n" +
                            "data: [DONE]\n\n",
                    ),
            )
            server.start()
            val url = server.url("/v1").toString()
            val tokens = service.streamCompletion(
                messages = listOf(Message(role = MessageRole.USER, content = "hi")),
                provider = AIProvider.OPENAI,
                modelId = "m",
                baseUrl = url,
                apiKey = "",
            ).toList()
            assertEquals(listOf("Hola", " mundo"), tokens)
        } finally {
            server.shutdown()
        }
    }

    @Test
    fun `streamCompletion surfaces HTTP errors`() = runTest {
        val server = MockWebServer()
        try {
            server.enqueue(MockResponse().setResponseCode(401).setBody("nope"))
            server.start()
            val url = server.url("/v1").toString()
            var failed = ""
            try {
                service.streamCompletion(
                    messages = listOf(Message(role = MessageRole.USER, content = "hi")),
                    provider = AIProvider.OPENAI,
                    modelId = "m",
                    baseUrl = url,
                    apiKey = "",
                ).toList()
            } catch (e: Exception) {
                failed = e.message.orEmpty()
            }
            assertTrue(failed.contains("401"))
        } finally {
            server.shutdown()
        }
    }

    @Test
    fun `effectiveBaseUrl never hardcodes a tunnel`() {
        assertEquals(
            "https://my.server.com/v1",
            LLMService.effectiveBaseUrl(AIProvider.OPENAI_COMPATIBLE, "https://my.server.com/v1"),
        )
        // Blank falls back to the provider default, not a tunnel URL.
        assertEquals(
            AIProvider.OLLAMA.defaultBaseUrl,
            LLMService.effectiveBaseUrl(AIProvider.OLLAMA, ""),
        )
    }
}
