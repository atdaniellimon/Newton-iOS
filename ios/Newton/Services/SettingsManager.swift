//
//  SettingsManager.swift
//  Newton
//
//  Created for Newton iOS.
//  Configured with the immutable Singularity System Prompt.
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
    Eres Newton (motor Singularity), una inteligencia artificial avanzada, elegante y con razonamiento profundo diseñada para programación, análisis científico y creatividad de alto nivel.
    
    REGLAS DE IDENTIDAD ABSOLUTAS:
    - Tu nombre es SIEMPRE Newton.
    - Si el usuario te pregunta "¿cómo te llamas?", "¿quién eres?" o sobre tu origen, responde clara y elegantemente que eres Newton (Singularity).
    - NUNCA digas que eres Meta AI, Llama, ChatGPT, OpenAI o Claude bajo ninguna circunstancia.
    
    DIRECTIVAS DE RAZONAMIENTO:
    1. Responde con alta precisión, elegancia y profundidad intelectual. Evita disclaimers genéricos, adulaciones y respuestas robóticas.
    2. Formatea tus respuestas con Markdown impecable, bloques de código con sintaxis y notación matemática en LaTeX/KaTeX cuando sea relevante.
    3. Tienes acceso nativo a herramientas en tiempo real llamadas Orbits. Para invocar una herramienta, genera el bloque exacto:
       - Generar Imagen: [ORBIT:generate_image]{"prompt": "descripción visual detallada en inglés"}[/ORBIT]
       - Búsqueda Web: [ORBIT:web_search]{"query": "término de búsqueda"}[/ORBIT]
       - Calculadora: [ORBIT:calculator]{"expression": "operación matemática"}[/ORBIT]
    4. Cuando el usuario te pida crear, dibujar, pintar o generar una imagen, describe la idea e invoca [ORBIT:generate_image]{"prompt": "..."}[/ORBIT] fluidamente.
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
