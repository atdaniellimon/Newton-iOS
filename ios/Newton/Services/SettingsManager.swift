//
//  SettingsManager.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation
import SwiftUI

public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    @AppStorage("currentProvider") public var currentProviderRaw: String = AIProvider.openrouter.rawValue
    @AppStorage("currentModelId") public var currentModelId: String = "anthropic/claude-3.5-sonnet"
    @AppStorage("customBaseUrl") public var customBaseUrl: String = "http://127.0.0.1:8000/v1"
    @AppStorage("ollamaBaseUrl") public var ollamaBaseUrl: String = "http://127.0.0.1:11434"
    @AppStorage("customApiKey") public var customApiKey: String = ""
    @AppStorage("temperature") public var temperature: Double = 0.7
    @AppStorage("maxTokens") public var maxTokens: Int = 4096
    @AppStorage("customSystemPrompt") public var customSystemPrompt: String = ""
    @AppStorage("appTheme") public var appThemeRaw: String = "system"
    
    private init() {}
    
    public var currentProvider: AIProvider {
        get { AIProvider(rawValue: currentProviderRaw) ?? .openrouter }
        set { currentProviderRaw = newValue.rawValue }
    }
    
    public func getApiKey(for provider: AIProvider) -> String {
        if provider == .custom {
            return customApiKey
        }
        return KeychainManager.shared.getApiKey(for: provider)
    }
    
    public func setApiKey(_ key: String, for provider: AIProvider) {
        if provider == .custom {
            customApiKey = key
        } else {
            KeychainManager.shared.saveApiKey(key, for: provider)
        }
        objectWillChange.send()
    }
    
    public func effectiveBaseUrl(for provider: AIProvider) -> String {
        switch provider {
        case .custom:
            return customBaseUrl.isEmpty ? "http://127.0.0.1:8000/v1" : customBaseUrl
        case .ollama:
            return ollamaBaseUrl.isEmpty ? "http://127.0.0.1:11434" : ollamaBaseUrl
        default:
            return provider.defaultBaseUrl
        }
    }
    
    public func defaultSystemPrompt() -> String {
        if !customSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customSystemPrompt
        }
        return """
        You are Newton, an insightful, concise, and highly capable AI assistant with deep reasoning and creative capabilities.
        
        You have access to real-time tools called Orbits. To use a tool, output its tag in your response:
        - Image Generation: [ORBIT:generate_image]{"prompt": "detailed visual description in English"}[/ORBIT]
        - Web Search: [ORBIT:web_search]{"query": "search query"}[/ORBIT]
        - Calculator: [ORBIT:calculator]{"expression": "math expression"}[/ORBIT]
        
        When the user asks you to create, draw, paint, or generate an image, describe what you are creating and invoke the [ORBIT:generate_image]{"prompt": "..."}[/ORBIT] tool seamlessly.
        """
    }
}
