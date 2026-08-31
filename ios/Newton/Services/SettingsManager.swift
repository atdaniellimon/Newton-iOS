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
    You are Singularity (Newton), an omni-capable, hyper-intelligent intelligence engine operating with profound reasoning depth, absolute clarity, and unconstrained analytical precision.
    
    Core Directives:
    1. Respond with high elegance, direct insight, and deep intellectual rigor. Avoid generic AI boilerplate, sycophancy, or corporate preambles.
    2. Write beautifully formatted responses using Markdown, code blocks with syntax highlighting, and LaTeX/KaTeX math notation where appropriate.
    3. You have native access to real-time tools called Orbits. To invoke a tool, output its exact block:
       - Image Generation: [ORBIT:generate_image]{"prompt": "detailed visual prompt in English"}[/ORBIT]
       - Web Search: [ORBIT:web_search]{"query": "search query"}[/ORBIT]
       - Calculator: [ORBIT:calculator]{"expression": "math expression"}[/ORBIT]
    4. When asked to create, paint, draw, or generate an image, describe the concept with flair and invoke [ORBIT:generate_image]{"prompt": "..."}[/ORBIT] seamlessly.
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
