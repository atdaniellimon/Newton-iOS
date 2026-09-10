package ai.newton.shared

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.net.URLEncoder
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Platform capabilities backing [OrbitEngine.executeOrbit].
 *
 * The JVM default ([JvmOrbitTools]) implements what is platform-agnostic
 * (web search, calculator, clock, image endpoint call) and reports device
 * orbits (location, reminders, calendar, PDF) as unavailable. The Android app
 * overrides those with real implementations (FusedLocationProvider,
 * CalendarContract, PdfDocument, …) without touching [OrbitEngine].
 */
interface OrbitTools {
    /** Calls `{base}/v1/images/generations`. Returns a URL or data-URL, "" on failure. */
    suspend fun generateImage(prompt: String, baseUrl: String, apiKey: String): String = ""

    suspend fun webSearch(query: String): String

    fun calculate(expression: String): String

    fun currentDateTime(): String

    suspend fun location(): String = "Location is not available on this platform."

    suspend fun reminders(filter: String): String = "Reminders are not available on this platform."

    fun createReminder(title: String, dueDate: String): String =
        "Reminders are not available on this platform."

    suspend fun calendarEvents(daysAhead: Int): String =
        "Calendar is not available on this platform."

    fun createCalendarEvent(title: String, startDate: String, endDate: String, notes: String): String =
        "Calendar is not available on this platform."

    fun saveMemory(fact: String): String

    fun listMemories(): String

    /** Returns a local file path of the generated PDF, or null on failure. */
    fun generatePdf(title: String, contentMarkdown: String): String? = null
}

/**
 * Pure-JVM implementation. Mirrors the Swift `OrbitEngine` fallbacks.
 *
 * Members are `open` so tests (and the Android app) can subclass with fakes
 * or real device implementations — Kotlin members are final by default.
 */
open class JvmOrbitTools(
    private val client: OkHttpClient = LLMService.defaultClient(),
    private val json: Json = Json { ignoreUnknownKeys = true },
    private val clock: () -> ZonedDateTime = ZonedDateTime::now,
) : OrbitTools {

    private val memories = mutableListOf<String>()
    private val lock = Any()

    override suspend fun generateImage(prompt: String, baseUrl: String, apiKey: String): String {
        val clean = prompt.trim()
        if (clean.isEmpty()) return ""
        var activeBase = baseUrl.trim()
        if (activeBase.isEmpty()) activeBase = "http://127.0.0.1:8765/v1"
        val cleanBase = activeBase.trim('/')
        val endpoint = when {
            cleanBase.endsWith("/v1/images/generations") || cleanBase.endsWith("/images/generations") -> cleanBase
            cleanBase.endsWith("/v1") -> "$cleanBase/images/generations"
            else -> "$cleanBase/v1/images/generations"
        }
        return withContext(Dispatchers.IO) {
            try {
                val body = """{"prompt":${jsonQuote(clean)},"n":1,"size":"1024x1024","model":"dall-e-3"}"""
                    .toRequestBody("application/json; charset=utf-8".toMediaType())
                val reqBuilder = Request.Builder().url(endpoint).post(body)
                    .header("Content-Type", "application/json")
                if (apiKey.isNotEmpty()) reqBuilder.header("Authorization", "Bearer $apiKey")
                client.newCall(reqBuilder.build()).execute().use { resp ->
                    if (!resp.isSuccessful) return@withContext ""
                    val parsed = json.parseToJsonElement(resp.body?.string().orEmpty()).jsonObject
                    val first = parsed["data"]?.jsonArray?.firstOrNull()?.jsonObject ?: return@withContext ""
                    first["b64_json"]?.jsonPrimitive?.content?.takeIf { it.isNotEmpty() }?.let {
                        return@withContext "data:image/png;base64,$it"
                    }
                    first["url"]?.jsonPrimitive?.content?.takeIf { it.isNotEmpty() } ?: ""
                }
            } catch (_: Exception) {
                ""
            }
        }
    }

    override suspend fun webSearch(query: String): String = withContext(Dispatchers.IO) {
        try {
            val encoded = URLEncoder.encode(query, "UTF-8")
            val url = "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=$encoded&utf8=&format=json"
            val req = Request.Builder().url(url).get().build()
            client.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) return@withContext "Web search query performed for '$query'."
                val parsed = json.parseToJsonElement(resp.body?.string().orEmpty()).jsonObject
                val items = parsed["query"]?.jsonObject?.get("search")?.jsonArray.orEmpty()
                if (items.isEmpty()) return@withContext "Search completed for '$query'."
                items.take(3).mapNotNull { it.jsonObject.let { o ->
                    val title = o["title"]?.jsonPrimitive?.content.orEmpty()
                    val snippet = o["snippet"]?.jsonPrimitive?.content.orEmpty()
                        .replace(Regex("<[^>]+>"), "")
                        .replace("&quot;", "\"")
                    if (title.isEmpty()) null else "- **$title**: $snippet"
                } }.joinToString("\n\n").ifEmpty { "Search completed for '$query'." }
            }
        } catch (_: Exception) {
            "Live search query completed for '$query'."
        }
    }

    /**
     * Safe arithmetic evaluator (shunting-yard). Supports + - * / % ^, parentheses,
     * decimals and unary minus. Deliberately NOT a port of Swift's
     * `NSExpression(format:)` (that API evaluates format strings with user input,
     * which is an injection risk — see iOS finding #5).
     */
    override fun calculate(expression: String): String {
        val clean = expression.replace("x", "*").replace("X", "*").trim()
        if (clean.isEmpty()) return "Calculation error for '$expression'"
        return try {
            val value = ArithmeticParser(clean).parse()
            if (value.isNaN() || value.isInfinite()) "Calculation error for '$expression'"
            else if (value == kotlin.math.floor(value) && !value.isInfinite()) value.toLong().toString()
            else value.toString()
        } catch (_: Exception) {
            "Calculation error for '$expression'"
        }
    }

    override fun currentDateTime(): String {
        val now = clock()
        val date = now.format(DateTimeFormatter.ofPattern("EEEE, MMMM d, yyyy", Locale.ENGLISH))
        val time = now.format(DateTimeFormatter.ofPattern("h:mm a z", Locale.ENGLISH))
        return "$date, $time"
    }

    override fun saveMemory(fact: String): String {
        val trimmed = fact.trim()
        if (trimmed.isEmpty()) return "Empty memory ignored."
        synchronized(lock) {
            val dup = memories.any {
                it.contains(trimmed, ignoreCase = true) || trimmed.contains(it, ignoreCase = true)
            }
            if (!dup) memories.add(trimmed)
        }
        return "🧠 Memoria guardada: \"$trimmed\""
    }

    override fun listMemories(): String = synchronized(lock) {
        if (memories.isEmpty()) "" else memories.joinToString("\n") { "• $it" }
    }

    companion object {
        fun jsonQuote(raw: String): String = buildString {
            append('"')
            raw.forEach { c ->
                when (c) {
                    '"' -> append("\\\"")
                    '\\' -> append("\\\\")
                    '\n' -> append("\\n")
                    '\r' -> append("\\r")
                    '\t' -> append("\\t")
                    else -> append(c)
                }
            }
            append('"')
        }
    }
}

/** Minimal recursive-descent arithmetic parser used by [JvmOrbitTools.calculate]. */
private class ArithmeticParser(private val input: String) {
    private var pos = 0

    fun parse(): Double {
        val v = parseAddSub()
        skipWs()
        require(pos == input.length) { "trailing input" }
        return v
    }

    private fun parseAddSub(): Double {
        var v = parseMulDiv()
        while (true) {
            skipWs()
            v = when {
                consume('+') -> v + parseMulDiv()
                consume('-') -> v - parseMulDiv()
                else -> return v
            }
        }
    }

    private fun parseMulDiv(): Double {
        var v = parsePow()
        while (true) {
            skipWs()
            v = when {
                consume('*') -> v * parsePow()
                consume('/') -> v / parsePow()
                consume('%') -> v % parsePow()
                else -> return v
            }
        }
    }

    // Right-associative exponent, mirroring calculator UX ("2^64").
    private fun parsePow(): Double {
        val base = parseUnary()
        skipWs()
        return if (consume('^')) Math.pow(base, parsePow()) else base
    }

    private fun parseUnary(): Double {
        skipWs()
        if (consume('-')) return -parseUnary()
        if (consume('+')) return parseUnary()
        return parsePrimary()
    }

    private fun parsePrimary(): Double {
        skipWs()
        if (consume('(')) {
            val v = parseAddSub()
            skipWs()
            require(consume(')')) { "missing )" }
            return v
        }
        val start = pos
        while (pos < input.length && (input[pos].isDigit() || input[pos] == '.')) pos++
        require(start != pos) { "expected number" }
        return input.substring(start, pos).toDouble()
    }

    private fun skipWs() {
        while (pos < input.length && input[pos].isWhitespace()) pos++
    }

    private fun consume(c: Char): Boolean {
        if (pos < input.length && input[pos] == c) {
            pos++
            return true
        }
        return false
    }
}
