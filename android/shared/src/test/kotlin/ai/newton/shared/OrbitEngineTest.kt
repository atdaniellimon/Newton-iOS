package ai.newton.shared

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private class FakeTools(
    var searchResult: String = "search-ok",
    var imageResult: String = "https://img.test/x.png",
    var calcResult: String? = null,
    var pdfPath: String? = "/tmp/doc.pdf",
) : JvmOrbitTools() {
    val savedMemories = mutableListOf<String>()
    override suspend fun webSearch(query: String): String = "$searchResult:$query"
    override suspend fun generateImage(prompt: String, baseUrl: String, apiKey: String): String = imageResult
    override fun calculate(expression: String): String = calcResult ?: super.calculate(expression)
    override fun saveMemory(fact: String): String {
        savedMemories.add(fact)
        return "saved:$fact"
    }
    override fun generatePdf(title: String, contentMarkdown: String): String? = pdfPath
}

class OrbitEngineTest {

    @Test
    fun `thinking blocks move to thinkingContent`() = runTest {
        val engine = OrbitEngine(FakeTools())
        val out = engine.processOrbitsInText("<thinking>plan here</thinking>Hello")
        assertEquals("Hello", out.processedText)
        assertEquals("plan here", out.thinkingContent)
        assertTrue(out.results.isEmpty())
    }

    @Test
    fun `unclosed trailing thinking is recovered`() = runTest {
        val engine = OrbitEngine(FakeTools())
        val out = engine.processOrbitsInText("Hello <thinking>half thoug")
        assertEquals("Hello", out.processedText)
        assertEquals("half thoug", out.thinkingContent)
    }

    @Test
    fun `natural orbit web_search executes and strips tag`() = runTest {
        val engine = OrbitEngine(FakeTools())
        val out = engine.processOrbitsInText(
            """Antes <orbit:web_search>{"query": "RISC-V"}</orbit:web_search> después""",
        )
        assertEquals("Antes  después", out.processedText)
        assertEquals(1, out.results.size)
        assertEquals("web_search", out.results[0].orbitName)
        assertEquals("search-ok:RISC-V", out.results[0].result)
    }

    @Test
    fun `generate_image sets imageUrl`() = runTest {
        val engine = OrbitEngine(FakeTools())
        val out = engine.processOrbitsInText(
            """<orbit:generate_image>{"prompt": "a cat"}</orbit:generate_image>""",
        )
        assertEquals("https://img.test/x.png", out.imageUrl)
    }

    @Test
    fun `simple generate tag works`() = runTest {
        val engine = OrbitEngine(FakeTools())
        val out = engine.processOrbitsInText("<orbit:generate>a neon cat</orbit:generate>")
        assertEquals("https://img.test/x.png", out.imageUrl)
    }

    @Test
    fun `download becomes a result card`() = runTest {
        val engine = OrbitEngine(FakeTools())
        val out = engine.processOrbitsInText("<download>File: a.pdf (2 MB)</download>Done")
        assertEquals("Done", out.processedText)
        assertEquals("download", out.results.single().orbitName)
    }

    @Test
    fun `legacy ORBIT tag still works`() = runTest {
        val engine = OrbitEngine(FakeTools())
        val out = engine.processOrbitsInText("""[ORBIT:calculator]{"expression": "2+2"}[/ORBIT]""")
        assertEquals("", out.processedText)
        assertEquals("calculator", out.results.single().orbitName)
        assertEquals("4", out.results.single().result)
    }

    @Test
    fun `json tool block executes`() = runTest {
        val engine = OrbitEngine(FakeTools())
        val out = engine.processOrbitsInText(
            "```json\n{\"name\": \"calculator\", \"parameters\": {\"expression\": \"3*4\"}}\n```",
        )
        assertEquals("", out.processedText)
        assertEquals("12", out.results.single().result)
    }

    @Test
    fun `calculator is safe arithmetic not format strings`() = runTest {
        val tools = FakeTools(calcResult = null)
        assertEquals("1024", tools.calculate("2^10"))
        assertEquals("20", tools.calculate("(2+3)*4"))
        assertEquals("0.5", tools.calculate("1/2"))
        assertTrue(tools.calculate("%n\$s").startsWith("Calculation error"))
    }

    @Test
    fun `image intent fallback generates when model replies prose`() = runTest {
        val engine = OrbitEngine(FakeTools())
        val out = engine.processOrbitsInText(
            "Lo siento, no puedo generar imágenes.",
            userPrompt = "genera una imagen de un gato",
        )
        assertEquals("https://img.test/x.png", out.imageUrl)
        assertTrue(out.results.any { it.orbitName == "image_gen" })
        // Refusal prose is stripped since the image exists.
        assertTrue(!out.processedText.contains("Lo siento"))
    }

    @Test
    fun `no fallback without image intent`() = runTest {
        val engine = OrbitEngine(FakeTools())
        val out = engine.processOrbitsInText("Hola, ¿cómo estás?", userPrompt = "hola")
        assertNull(out.imageUrl)
        assertTrue(out.results.isEmpty())
        assertEquals("Hola, ¿cómo estás?", out.processedText)
    }

    @Test
    fun `markdown images are stripped from prose but kept as imageUrl`() = runTest {
        val engine = OrbitEngine(FakeTools(imageResult = ""))
        val out = engine.processOrbitsInText("Mira ![gato](https://img.test/g.png) qué lindo")
        assertEquals("https://img.test/g.png", out.imageUrl)
        assertTrue(!out.processedText.contains("!["))
    }

    @Test
    fun `save_memory delegates to tools`() = runTest {
        val tools = FakeTools()
        val engine = OrbitEngine(tools)
        engine.processOrbitsInText("""<orbit:save_memory>{"fact": "prefiere Kotlin"}</orbit:save_memory>""")
        assertEquals(listOf("prefiere Kotlin"), tools.savedMemories)
    }

    @Test
    fun `generate_pdf returns path`() = runTest {
        val engine = OrbitEngine(FakeTools())
        val out = engine.processOrbitsInText(
            """<orbit:generate_pdf>{"title": "T", "content": "# Hola"}</orbit:generate_pdf>""",
        )
        assertEquals("/tmp/doc.pdf", out.results.single().result)
    }
}
