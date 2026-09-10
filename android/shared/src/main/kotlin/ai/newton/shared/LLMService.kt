package ai.newton.shared

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * Multi-provider streaming client. JVM port of Swift `LLMService`
 * (ios/Newton/Services/LLMService.swift).
 *
 * SSE parsing, endpoint selection, auth headers and payload shapes mirror Swift
 * exactly so both clients speak the same contract to the backend.
 *
 * [memoryFacts] is the pre-formatted persistent-memory block; when blank the
 * same "(No specific facts stored yet…)" fallback as Swift is used.
 */
class LLMService(
    private val client: OkHttpClient = defaultClient(),
    private val json: Json = Json { ignoreUnknownKeys = true },
) {
    fun streamCompletion(
        messages: List<Message>,
        provider: AIProvider,
        modelId: String,
        baseUrl: String,
        apiKey: String,
        temperature: Double = 0.7,
        maxTokens: Int = 4096,
        systemPrompt: String = SingularityPrompt.base,
        memoryFacts: String = "",
    ): Flow<String> {
        // flowOn(IO): the blocking OkHttp execute() must never run on the
        // collector's dispatcher (viewModelScope == Main on Android).
        val flow = callbackFlow {
            val url = constructEndpointURL(provider, baseUrl)
            if (url == null) {
                close(IllegalArgumentException("Invalid API Base URL: $baseUrl"))
                return@callbackFlow
            }

            val payload = buildPayload(
                provider = provider,
                modelId = modelId,
                messages = messages,
                temperature = temperature,
                maxTokens = maxTokens,
                systemPrompt = systemPrompt,
                memoryFacts = memoryFacts,
            )

            val builder = Request.Builder()
                .url(url)
                .post(json.encodeToString(JsonObject.serializer(), payload).toRequestBody(JSON))
            applyAuthHeaders(builder, provider, apiKey)
            builder.header("Accept", "application/json")

            val call = client.newCall(builder.build())
            val response = try {
                call.execute()
            } catch (e: Exception) {
                close(e)
                return@callbackFlow
            }

            if (!response.isSuccessful) {
                val body = try {
                    response.body?.string().orEmpty()
                } catch (_: Exception) {
                    ""
                }
                response.close()
                close(IllegalStateException("API Error (${response.code}): $body"))
                return@callbackFlow
            }

            try {
                val source = response.body?.source()
                if (source == null) {
                    close(IllegalStateException("Invalid response from server"))
                    return@callbackFlow
                }
                while (!source.exhausted()) {
                    val line = source.readUtf8Line() ?: break
                    val trimmed = line.trim()
                    if (trimmed.isEmpty()) continue
                    if (trimmed == "data: [DONE]" || trimmed == "[DONE]") break
                    if (trimmed.startsWith("data: ") || trimmed.startsWith("data:")) {
                        val jsonStr = if (trimmed.startsWith("data: ")) trimmed.drop(6) else trimmed.drop(5)
                        parseToken(jsonStr, provider)?.let { trySend(it) }
                    }
                }
                close()
            } catch (e: Exception) {
                close(e)
            } finally {
                response.close()
            }

            awaitClose { call.cancel() }
        }
        return flow.flowOn(Dispatchers.IO)
    }

    //region Contract (public for tests)

    fun constructEndpointURL(provider: AIProvider, baseUrl: String): String? {
        val cleanBase = baseUrl.trim().trim('/')
        if (provider != AIProvider.OLLAMA && cleanBase.isEmpty()) return null
        return when (provider) {
            AIProvider.ANTHROPIC -> "https://api.anthropic.com/v1/messages"
            AIProvider.GEMINI -> "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
            AIProvider.OLLAMA -> "$cleanBase/api/chat"
            else -> when {
                cleanBase.endsWith("/chat/completions") -> cleanBase
                cleanBase.endsWith("/v1") -> "$cleanBase/chat/completions"
                else -> "$cleanBase/v1/chat/completions"
            }
        }
    }

    fun buildPayload(
        provider: AIProvider,
        modelId: String,
        messages: List<Message>,
        temperature: Double,
        maxTokens: Int,
        systemPrompt: String,
        memoryFacts: String = "",
    ): JsonObject {
        val effectiveSystem = SingularityPrompt.effective(systemPrompt, memoryFacts)

        if (provider.isAnthropicProtocol) {
            val formatted = messages
                .filter { it.role != MessageRole.SYSTEM }
                .map { msg ->
                    val role = if (msg.role == MessageRole.USER) "user" else "assistant"
                    val img = msg.imageUrl
                    if (img != null && img.startsWith("data:image/")) {
                        var mediaType = "image/jpeg"
                        var base64Data = img
                        val commaIdx = img.indexOf(',')
                        if (commaIdx >= 0) {
                            val header = img.substring(0, commaIdx)
                            base64Data = img.substring(commaIdx + 1)
                            if (header.contains("image/png")) mediaType = "image/png"
                            else if (header.contains("image/webp")) mediaType = "image/webp"
                        }
                        buildJsonObject {
                            put("role", role)
                            put(
                                "content",
                                JsonArray(
                                    listOf(
                                        buildJsonObject {
                                            put("type", "image")
                                            put(
                                                "source",
                                                buildJsonObject {
                                                    put("type", "base64")
                                                    put("media_type", mediaType)
                                                    put("data", base64Data)
                                                },
                                            )
                                        },
                                        buildJsonObject {
                                            put("type", "text")
                                            put("text", msg.content.ifEmpty { "Analyze this content." })
                                        },
                                    ),
                                ),
                            )
                        }
                    } else {
                        buildJsonObject {
                            put("role", role)
                            put("content", msg.content)
                        }
                    }
                }
            return buildJsonObject {
                put("model", modelId)
                put("messages", JsonArray(formatted))
                put("max_tokens", maxTokens)
                put("temperature", temperature)
                put("stream", true)
                put("system", effectiveSystem)
            }
        }

        val formatted = buildList {
            add(
                buildJsonObject {
                    put("role", "system")
                    put("content", effectiveSystem)
                },
            )
            messages.forEach { msg ->
                val img = msg.imageUrl
                if (!img.isNullOrEmpty()) {
                    add(
                        buildJsonObject {
                            put("role", msg.role.wireValue)
                            put(
                                "content",
                                JsonArray(
                                    listOf(
                                        buildJsonObject {
                                            put("type", "text")
                                            put(
                                                "text",
                                                msg.content.ifEmpty { "Describe and analyze this content." },
                                            )
                                        },
                                        buildJsonObject {
                                            put("type", "image_url")
                                            put(
                                                "image_url",
                                                buildJsonObject { put("url", img) },
                                            )
                                        },
                                    ),
                                ),
                            )
                        },
                    )
                } else {
                    add(
                        buildJsonObject {
                            put("role", msg.role.wireValue)
                            put("content", msg.content)
                        },
                    )
                }
            }
        }
        return buildJsonObject {
            put("model", modelId)
            put("messages", JsonArray(formatted))
            put("temperature", temperature)
            put("max_tokens", maxTokens)
            put("stream", true)
        }
    }

    fun parseToken(jsonString: String, provider: AIProvider): String? =
        try {
            parseTokenUnsafe(jsonString, provider)
        } catch (_: Exception) {
            null
        }

    private fun parseTokenUnsafe(jsonString: String, provider: AIProvider): String? {
        val parsed = try {
            json.parseToJsonElement(jsonString).jsonObject
        } catch (_: Exception) {
            return null
        }

        if (provider.isAnthropicProtocol) {
            val type = parsed["type"]?.jsonPrimitive?.contentOrNull.orEmpty()
            if (type == "content_block_delta") {
                return parsed["delta"]?.jsonObject
                    ?.get("text")?.jsonPrimitive?.contentOrNull
            }
            return null
        }

        val choices = parsed["choices"]?.jsonArray
        val first = choices?.firstOrNull()?.jsonObject
        if (first != null) {
            val delta = first["delta"]?.jsonObject
            if (delta != null) {
                val reasoning = delta["reasoning_content"]?.takeUnless { it is JsonNull }
                    ?.jsonPrimitive?.contentOrNull
                if (!reasoning.isNullOrEmpty()) return "<thinking>$reasoning</thinking>"
                val content = delta["content"]?.takeUnless { it is JsonNull }
                    ?.jsonPrimitive?.contentOrNull
                if (content != null) return content
            }
            first["text"]?.takeUnless { it is JsonNull }?.jsonPrimitive?.contentOrNull?.let { return it }
        }

        parsed["message"]?.jsonObject
            ?.get("content")?.takeUnless { it is JsonNull }
            ?.jsonPrimitive?.contentOrNull?.let { return it }

        parsed["response"]?.takeUnless { it is JsonNull }
            ?.jsonPrimitive?.contentOrNull?.let { return it }

        return null
    }

    //endregion

    private fun applyAuthHeaders(builder: Request.Builder, provider: AIProvider, apiKey: String) {
        builder.header("Content-Type", "application/json")
        val key = apiKey.trim()
        if (key.isEmpty()) return
        when (provider) {
            AIProvider.ANTHROPIC, AIProvider.ANTHROPIC_COMPATIBLE -> {
                // Swift only sets anthropic headers for .anthropic; compatible proxies go Bearer.
                if (provider == AIProvider.ANTHROPIC) {
                    builder.header("x-api-key", key)
                    builder.header("anthropic-version", "2023-06-01")
                } else {
                    builder.header("Authorization", "Bearer $key")
                }
            }
            AIProvider.OPENROUTER -> {
                builder.header("Authorization", "Bearer $key")
                builder.header("HTTP-Referer", "https://newton.ai")
                builder.header("X-Title", "Newton Android")
            }
            else -> builder.header("Authorization", "Bearer $key")
        }
    }

    companion object {
        private val JSON = "application/json; charset=utf-8".toMediaType()

        fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(120, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .retryOnConnectionFailure(true)
            .build()

        /**
         * No hardcoded tunnel. The endpoint always comes from user settings
         * (SettingsManager equivalent); blank falls back to the provider default.
         * Mirrors the intent of Swift `effectiveBaseUrl`, minus the hardcoded URL.
         */
        fun effectiveBaseUrl(provider: AIProvider, customBaseUrl: String): String {
            val trimmed = customBaseUrl.trim().trim('/')
            return trimmed.ifEmpty { provider.defaultBaseUrl.trimEnd('/') }
        }
    }
}

private val JsonPrimitive.contentOrNull: String?
    get() = try {
        if (this is JsonNull) null else content
    } catch (_: Exception) {
        null
    }
