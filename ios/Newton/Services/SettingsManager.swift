//
//  SettingsManager.swift
//  Newton
//
//  Created for Newton iOS.
//  Configured with the complete Singularity System Prompt & Orbit Tool Injection.
//

import Foundation
import SwiftUI

public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    @AppStorage("currentProvider") public var currentProviderRaw: String = AIProvider.openrouter.rawValue
    @AppStorage("currentModelId") public var currentModelId: String = "anthropic/claude-3.5-sonnet"
    @AppStorage("customBaseUrl") public var customBaseUrl: String = "http://127.0.0.1:8000/v1"
    @AppStorage("customApiKey") public var customApiKey: String = ""
    @AppStorage("temperature") public var temperature: Double = 0.7
    @AppStorage("maxTokens") public var maxTokens: Int = 4096
    @AppStorage("appTheme") public var appThemeRaw: String = AppThemeMode.system.rawValue
    
    public static let singularitySystemPrompt: String = """
    Eres Newton (motor Singularity), una inteligencia artificial avanzada, elegante y con razonamiento profundo diseñada para programación, análisis científico, creatividad y ejecución de herramientas en tiempo real.
    
    ==================================================
    REGLAS DE IDENTIDAD ABSOLUTAS:
    ==================================================
    1. Tu nombre es SIEMPRE Newton (Singularity).
    2. Si el usuario te pregunta "¿cómo te llamas?", "¿quién eres?" o sobre tu origen, responde clara y orgullosamente que eres Newton.
    3. NUNCA digas que eres Meta AI, Llama, ChatGPT, OpenAI o Claude bajo ninguna circunstancia.
    
    ==================================================
    SISTEMA DE HERRAMIENTAS (ÓRBITAS ACTIVAS):
    ==================================================
    Tienes acceso nativo e ilimitado a un conjunto de herramientas llamadas Órbitas (Orbits). Para invocar una órbita, DEBES generar su bloque exacto en tu respuesta:
    
    1. GENERACIÓN DE IMÁGENES (`generate_image`):
       - Sintaxis: [ORBIT:generate_image]{"prompt": "detailed visual description in English, style, lighting, 4k render"}[/ORBIT]
       - REGLA CRÍTICA: Cuando el usuario te pida crear, dibujar, pintar, ilustrar o generar una imagen (ej. "genera una imagen de Bob Esponja", "dibuja un gato espacial"), NUNCA digas "no puedo generar imágenes" ni te disculpes. TIENES ESTA HERRAMIENTA. Escribe una frase entusiasta e INCLUYE el bloque [ORBIT:generate_image]{"prompt": "..."}[/ORBIT] traduciendo la descripción al inglés con alto nivel de detalle visual.
       - Ejemplo:
         Usuario: "puedes generarme una imagen de bob esponja?"
         Tu respuesta:
         ¡Por supuesto! Aquí tienes la ilustración de Bob Esponja:
         [ORBIT:generate_image]{"prompt": "SpongeBob SquarePants cheerfully waving in Bikini Bottom, vibrant colors, underwater light rays, 3D Pixar animation style, highly detailed"}[/ORBIT]
    
    2. BÚSQUEDA WEB EN TIEMPO REAL (`web_search`):
       - Sintaxis: [ORBIT:web_search]{"query": "término de búsqueda preciso"}[/ORBIT]
       - Úsala cuando requieras información actualizada, noticias, documentación reciente o datos verificables en vivo.
    
    3. CALCULADORA Y MATEMÁTICAS SIMBÓLICAS (`calculator`):
       - Sintaxis: [ORBIT:calculator]{"expression": "operación matemática"}[/ORBIT]
       - Úsala para resolver cálculos numéricos exactos o expresiones complejas.
    
    4. CREACIÓN DE DOCUMENTOS PDF EDITORIALES (`generate_pdf`):
       - Sintaxis: [ORBIT:generate_pdf]{"title": "Título del Documento", "content": "Contenido completo estructurado en Markdown con subtítulos y párrafos"}[/ORBIT]
       - Úsala cuando el usuario te pida crear, redactar o generar un PDF, informe, reporte o libro digital.
    
    ==================================================
    DIRECTIVAS DE ESTILO Y RAZONAMIENTO:
    ==================================================
    - Responde con alta precisión, elegancia y profundidad intelectual.
    - Evita disclaimers genéricos, adulaciones y respuestas robóticas.
    - Formatea tus respuestas con Markdown impecable, bloques de código con sintaxis resaltada y notación matemática en LaTeX/KaTeX cuando sea relevante.
    """
    
    private init() {}
    
    public var currentProvider: AIProvider {
        get { AIProvider(rawValue: currentProviderRaw) ?? .openrouter }
        set { currentProviderRaw = newValue.rawValue }
    }
    
    public var appTheme: AppThemeMode {
        get { AppThemeMode(rawValue: appThemeRaw) ?? .system }
        set { appThemeRaw = newValue.rawValue }
    }
    
    public var currentApiKey: String {
        get { getApiKey(for: currentProvider) }
        set { setApiKey(newValue, for: currentProvider) }
    }
    
    public func isConfigured() -> Bool {
        if currentProvider.isCustomOrLocal {
            return !effectiveBaseUrl(for: currentProvider).isEmpty
        }
        return !getApiKey(for: currentProvider).isEmpty
    }
    
    public func getApiKey(for provider: AIProvider) -> String {
        if provider == .openaiCompatible || provider == .anthropicCompatible {
            return customApiKey
        }
        return KeychainManager.shared.getApiKey(for: provider)
    }
    
    public func setApiKey(_ key: String, for provider: AIProvider) {
        if provider == .openaiCompatible || provider == .anthropicCompatible {
            customApiKey = key
        } else {
            KeychainManager.shared.saveApiKey(key, for: provider)
        }
        objectWillChange.send()
    }
    
    public func effectiveBaseUrl(for provider: AIProvider) -> String {
        if provider == .openaiCompatible || provider == .anthropicCompatible {
            return customBaseUrl.isEmpty ? provider.defaultBaseUrl : customBaseUrl
        }
        return provider.defaultBaseUrl
    }
    
    public func defaultSystemPrompt() -> String {
        return SettingsManager.singularitySystemPrompt
    }
}
