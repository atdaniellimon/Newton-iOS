package ai.newton.shared

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

data class ProcessedOrbitText(
    val processedText: String,
    val results: List<OrbitExecutionResult>,
    val imageUrl: String?,
    val thinkingContent: String?,
)

/**
 * Local tool engine. JVM port of Swift `OrbitEngine`
 * (ios/Newton/Services/OrbitEngine.swift).
 *
 * Tag grammars are identical to Swift so the same model output parses the same:
 * `<thinking>`, `<orbit:name>{json}</orbit:name>`, `<orbit:generate>`,
 * `<download>`, legacy `[ORBIT:name]`, ```json {"name","parameters"}``` blocks,
 * plus the image-intent fallback.
 *
 * Device orbits (location, reminders, calendar, PDF) delegate to [OrbitTools],
 * which the Android app overrides with real implementations.
 */
class OrbitEngine(
    private val tools: OrbitTools = JvmOrbitTools(),
    private val json: Json = Json { ignoreUnknownKeys = true },
) {
    suspend fun processOrbitsInText(
        text: String,
        userPrompt: String = "",
        baseUrl: String = "",
        apiKey: String = "",
    ): ProcessedOrbitText {
        var output = text
        val results = mutableListOf<OrbitExecutionResult>()
        var detectedImageUrl: String? = null
        var accumulatedThinking = ""

        // 0. Model already embedded a markdown image or direct fbcdn URL.
        detectedImageUrl = firstGroup(MARKDOWN_IMAGE, output, 1)
            ?: firstGroup(FBCDN_URL, output, 1)

        // 1. <thinking>/<think> blocks (chain of thought).
        THINKING_BLOCK.findAll(output).toList().reversed().forEach { m ->
            val inner = m.groups[1]?.value.orEmpty().trim()
            if (inner.isNotEmpty()) {
                accumulatedThinking = if (accumulatedThinking.isEmpty()) inner
                else "$inner\n\n---\n\n$accumulatedThinking"
            }
            output = output.replace(m.value, "")
        }

        // 1b. Unclosed trailing <thinking> (truncated stream).
        val openIdx = output.indexOf("<think", ignoreCase = true)
        if (openIdx >= 0) {
            val tail = output.substring(openIdx)
            if (!tail.contains("</think", ignoreCase = true)) {
                var thoughtTail = tail
                val tagEnd = thoughtTail.indexOf('>')
                thoughtTail = if (tagEnd >= 0) thoughtTail.substring(tagEnd + 1).trim() else ""
                if (thoughtTail.isNotEmpty()) {
                    accumulatedThinking = if (accumulatedThinking.isEmpty()) thoughtTail
                    else "$accumulatedThinking\n\n---\n\n$thoughtTail"
                }
                output = output.substring(0, openIdx)
            }
        }
        output = STRAY_THINK_CLOSE.replace(output, "")

        // 2. Natural <orbit:name>{json}</orbit:name>.
        NATURAL_ORBIT.findAll(output).toList().reversed().forEach { m ->
            val name = m.groups[1]?.value.orEmpty().lowercase()
            val paramsJson = m.groups[2]?.value.orEmpty().trim()
            val result = executeOrbit(name, paramsJson, baseUrl, apiKey)
            results.add(result)
            if ((name == "generate_image" || name == "image_gen") && result.result.isNotEmpty()) {
                detectedImageUrl = result.result
            }
            output = output.replace(m.value, "")
        }

        // 2b. Simple <orbit:generate>prompt</orbit:generate>.
        SIMPLE_GENERATE.findAll(output).toList().reversed().forEach { m ->
            val prompt = m.groups[1]?.value.orEmpty().trim().replace("\"", "\\\"")
            val result = executeOrbit("generate_image", "{\"prompt\": \"$prompt\"}", baseUrl, apiKey)
            results.add(result)
            if (result.result.isNotEmpty()) detectedImageUrl = result.result
            output = output.replace(m.value, "")
        }

        // 3. <download> blocks.
        DOWNLOAD_BLOCK.findAll(output).toList().reversed().forEach { m ->
            val content = m.groups[1]?.value.orEmpty().trim()
            if (content.isNotEmpty()) {
                results.add(
                    OrbitExecutionResult(
                        orbitName = "download",
                        params = "",
                        result = content,
                        isSuccess = true,
                    ),
                )
            }
            output = output.replace(m.value, "")
        }

        // 4. Legacy [ORBIT:name]...[/ORBIT].
        LEGACY_ORBIT.findAll(text).forEach { m ->
            val name = m.groups[1]?.value.orEmpty()
            val paramsJson = m.groups[2]?.value.orEmpty().trim()
            val result = executeOrbit(name, paramsJson, baseUrl, apiKey)
            results.add(result)
            if (name.lowercase() in setOf("image_gen", "imagine", "generate_image") &&
                result.result.isNotEmpty()
            ) {
                detectedImageUrl = result.result
            }
            output = output.replace(m.value, "")
        }

        // JSON tool calls ```json {"name","parameters"}```.
        JSON_TOOL.findAll(output).toList().forEach { m ->
            val toolName = m.groups[1]?.value.orEmpty()
            val paramsJson = m.groups[2]?.value.orEmpty()
            val result = executeOrbit(toolName, paramsJson, baseUrl, apiKey)
            results.add(result)
            if (toolName.lowercase() in setOf("generate_image", "image_gen") &&
                result.result.isNotEmpty()
            ) {
                detectedImageUrl = result.result
            }
            output = output.replace(m.value, "")
        }

        // Raw search dumps -> cards.
        if (output.contains("URL: http") || output.contains("Citation ID:") ||
            (output.contains("Found ") && output.contains("results"))
        ) {
            SEARCH_DUMP.findAll(output).toList().forEach { m ->
                var dump = m.value
                if (dump.length > 2000) dump = dump.take(2000) + "\n\n... (resultado recortado)"
                results.add(OrbitExecutionResult(orbitName = "web_search", params = "", result = dump, isSuccess = true))
                output = output.replace(dump, "")
            }
        }

        // Scraping / boilerplate cleanup (same patterns as Swift).
        output = SCRAPE_LINES.replace(output, "")
        output = CITATION_ID.replace(output, "")
        output = CONFIDENCE_TAG.replace(output, "")
        output = LOGIC_CHAIN.replace(output, "")
        output = output
            .replace(", de la familia de modelos Newton", "")
            .replace(", from the Newton model family", "")
        output = META_TOOL_CHATTER.replace(output, "")
        output = MARKDOWN_IMAGE.replace(output, "")
        output = GENERATED_IMAGE_LABEL.replace(output, "")

        if (detectedImageUrl == null) {
            detectedImageUrl = firstGroup(MARKDOWN_IMAGE, output, 1)
        }

        // 5. Image-intent fallback: user asked for an image but the model replied in prose.
        val alreadyImage = results.any {
            it.orbitName.lowercase() in setOf("image_gen", "generate_image", "imagine", "draw")
        }
        if (detectedImageUrl == null && !alreadyImage) {
            val lowerPrompt = userPrompt.lowercase()
            val keywords = listOf(
                "genera una imagen", "generame una imagen", "crea una imagen",
                "haz una imagen", "dibuja", "draw", "generate an image",
                "create an image", "make an image", "generate a picture", "/imagine",
            )
            if (keywords.any { lowerPrompt.contains(it) } || lowerPrompt.startsWith("imagine")) {
                val cleanPrompt = userPrompt.replace("\"", " ").replace("\n", " ")
                val fallback = executeOrbit(
                    "generate_image",
                    "{\"prompt\": \"${cleanPrompt.replace("\"", "\\\"")}\"}",
                    baseUrl,
                    apiKey,
                )
                results.add(fallback)
                if (fallback.result.isNotEmpty()) {
                    detectedImageUrl = fallback.result
                    output = REFUSAL_PROSE.replace(output, "")
                }
            }
        }

        val finalImage = detectedImageUrl?.takeIf { it.isNotEmpty() }
        return ProcessedOrbitText(
            processedText = output.trim(),
            results = results,
            imageUrl = finalImage,
            thinkingContent = accumulatedThinking.ifEmpty { null },
        )
    }

    suspend fun executeOrbit(
        name: String,
        paramsJson: String,
        baseUrl: String = "",
        apiKey: String = "",
    ): OrbitExecutionResult {
        val trimmed = name.lowercase()
        val params: Map<String, String?> = try {
            val obj = json.parseToJsonElement(paramsJson).jsonObject
            obj.entries.associate { (k, v) ->
                k to try {
                    v.jsonPrimitive.content
                } catch (_: Exception) {
                    v.toString()
                }
            }
        } catch (_: Exception) {
            emptyMap()
        }
        fun str(vararg keys: String): String =
            keys.firstNotNullOfOrNull { params[it] }.orEmpty().ifEmpty { paramsJson }

        return when (trimmed) {
            "image_gen", "imagine", "generate_image", "draw" -> {
                val url = tools.generateImage(str("prompt"), baseUrl, apiKey)
                OrbitExecutionResult(orbitName = "image_gen", params = paramsJson, result = url, isSuccess = true)
            }
            "web_search", "search" -> {
                val out = tools.webSearch(str("query").ifEmpty { paramsJson })
                OrbitExecutionResult("web_search", paramsJson, out, true)
            }
            "calculator", "math" -> {
                val out = tools.calculate(str("expression").ifEmpty { paramsJson })
                OrbitExecutionResult("calculator", paramsJson, out, true)
            }
            "sequential_thinking", "think", "reason" -> {
                val thought = str("thought")
                val num = params["thoughtNumber"]?.toIntOrNull()
                    ?: params["thought_number"]?.toIntOrNull() ?: 1
                val total = params["totalThoughts"]?.toIntOrNull()
                    ?: params["total_thoughts"]?.toIntOrNull() ?: 1
                val rev = params["isRevision"]?.toBooleanStrictOrNull() ?: false
                val label = "🧠 [Sequential Thought $num/$total${if (rev) " (Revision)" else ""}]: $thought"
                OrbitExecutionResult("sequential_thinking", paramsJson, label, true)
            }
            "location", "get_location", "gps" ->
                OrbitExecutionResult("location", paramsJson, tools.location(), true)
            "time", "date", "clock", "datetime", "get_time" ->
                OrbitExecutionResult("time", paramsJson, tools.currentDateTime(), true)
            "reminders", "get_reminders", "list_reminders" ->
                OrbitExecutionResult("reminders", paramsJson, tools.reminders(str("filter").ifEmpty { "all" }), true)
            "create_reminder", "add_reminder", "set_reminder" -> {
                val out = tools.createReminder(str("title"), str("dueDate", "due_date", "due"))
                OrbitExecutionResult("create_reminder", paramsJson, out, true)
            }
            "calendar", "get_calendar", "events", "list_events" -> {
                val days = params["days"]?.toIntOrNull() ?: 7
                OrbitExecutionResult("calendar", paramsJson, tools.calendarEvents(days), true)
            }
            "create_event", "add_event", "schedule_event" -> {
                val out = tools.createCalendarEvent(
                    str("title").ifEmpty { "Reunión" },
                    str("startDate", "start_date", "date"),
                    str("endDate", "end_date"),
                    str("notes", "description"),
                )
                OrbitExecutionResult("create_event", paramsJson, out, true)
            }
            "save_memory", "remember", "store_memory" -> {
                val fact = str("fact", "memory", "content")
                OrbitExecutionResult("save_memory", paramsJson, tools.saveMemory(fact), true)
            }
            "get_memories", "list_memories" -> {
                val mems = tools.listMemories()
                OrbitExecutionResult(
                    "get_memories", paramsJson,
                    mems.ifEmpty { "No hay memorias registradas." }, true,
                )
            }
            "generate_pdf", "pdf", "create_pdf", "make_pdf" -> {
                var title = "Documento Newton"
                var content = paramsJson
                try {
                    val obj = json.parseToJsonElement(paramsJson).jsonObject
                    obj["title"]?.jsonPrimitive?.content?.takeIf { it.isNotEmpty() }?.let { title = it }
                    obj["content"]?.jsonPrimitive?.content?.takeIf { it.isNotEmpty() }?.let { content = it }
                } catch (_: Exception) {
                    TITLE_FALLBACK.find(paramsJson)?.groups?.get(1)?.value?.let { title = it }
                    CONTENT_FALLBACK.find(paramsJson)?.groups?.get(1)?.value?.let {
                        content = it.replace("\\n", "\n").replace("\\\"", "\"")
                    }
                }
                val path = tools.generatePdf(title, content)
                if (path != null) OrbitExecutionResult("generate_pdf", paramsJson, path, true)
                else OrbitExecutionResult("generate_pdf", paramsJson, "Error al generar el PDF.", false)
            }
            "kick", "terminate" -> {
                var reason = "Operational boundary violations or systematic refusal."
                try {
                    json.parseToJsonElement(paramsJson).jsonObject["reason"]
                        ?.jsonPrimitive?.content?.takeIf { it.isNotEmpty() }?.let { reason = it }
                } catch (_: Exception) {
                }
                OrbitExecutionResult("kick", paramsJson, reason, true)
            }
            else -> OrbitExecutionResult(
                orbitName = name,
                params = paramsJson,
                result = "Orbit $name executed with params: $paramsJson",
                isSuccess = true,
            )
        }
    }

    companion object {
        private val MARKDOWN_IMAGE = Regex("""!\[.*?]\((https?://.*?|data:image/.*?)\)""")
        private val FBCDN_URL = Regex("""(https://[a-zA-Z0-9.\-]+\.fbcdn\.net/[^\s"'<>\n\r\t]+)""")
        private val THINKING_BLOCK =
            Regex("""<think(?:ing)?>([\s\S]*?)</think(?:ing)?>""", RegexOption.IGNORE_CASE)
        private val STRAY_THINK_CLOSE = Regex("""</think(?:ing)?>""", RegexOption.IGNORE_CASE)
        private val NATURAL_ORBIT =
            Regex("""<orbit:(\w+)>([\s\S]*?)</orbit:\1>""", RegexOption.IGNORE_CASE)
        private val SIMPLE_GENERATE =
            Regex("""<orbit:generate>([\s\S]*?)</orbit:generate>""", RegexOption.IGNORE_CASE)
        private val DOWNLOAD_BLOCK = Regex("""<download>([\s\S]*?)</download>""", RegexOption.IGNORE_CASE)
        private val LEGACY_ORBIT =
            Regex("""\[ORBIT:(\w+)]([\s\S]*?)(?:\[/ORBIT]|$)""", RegexOption.IGNORE_CASE)
        private val JSON_TOOL =
            Regex("""```(?:json)?\s*\{\s*"name"\s*:\s*"([^"]+)"\s*,\s*"parameters"\s*:\s*(\{[\s\S]*?})\s*}\s*```""", RegexOption.IGNORE_CASE)
        private val SEARCH_DUMP =
            Regex("""(?s)(?:Found \d+ results|URL:\s*https?://).*?(?=\n\n[A-Z¿¡]|$)""", RegexOption.IGNORE_CASE)
        private val SCRAPE_LINES =
            Regex("""(?m)^(?:URL:|Last Updated:|title:|keywords:|description:|\[Publicidad]).*$""", RegexOption.IGNORE_CASE)
        private val CITATION_ID = Regex("""\[?Citation ID:\s*([a-zA-Z0-9_\-]+)]?""", RegexOption.IGNORE_CASE)
        private val CONFIDENCE_TAG = Regex("""\[CONFIDENCE:\s*\w+]\s*[—–\-:]?\s*""", RegexOption.IGNORE_CASE)
        private val LOGIC_CHAIN =
            Regex("""\[PREMISE]\s*→\s*\[LOGIC]\s*→\s*\[CONCLUSION]""", RegexOption.IGNORE_CASE)
        private val META_TOOL_CHATTER = Regex(
            """(?i)(?:I've generated the media that you've requested[^\n]*|You MUST call the (?:Imagine Tool|tool)[^\n]*)""",
        )
        private val GENERATED_IMAGE_LABEL =
            Regex("""(?im)^\s*(?:Generated Image|Imagen generada)\s*$""")
        private val TITLE_FALLBACK = Regex(""""title"\s*:\s*"([^"]+)"""")
        private val CONTENT_FALLBACK = Regex(""""content"\s*:\s*"([\s\S]*?)"\s*}?$""")
        private val REFUSAL_PROSE = Regex(
            """(?i)(?:no puedo (?:generar|crear)[^\n.]*[\n.]?|lo siento[^\n]*imagen[^\n]*[\n.]?|i can(?:not|'t) (?:generate|create) images?[^\n.]*[\n.]?)""",
        )

        private fun firstGroup(regex: Regex, input: String, group: Int): String? =
            regex.find(input)?.groups?.get(group)?.value
    }
}
