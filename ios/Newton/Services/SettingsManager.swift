//
//  SettingsManager.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation
import SwiftUI
import Combine

public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    @AppStorage("newton_current_provider") public var currentProviderRaw: String = AIProvider.openrouter.rawValue {
        didSet {
            objectWillChange.send()
        }
    }
    
    @AppStorage("newton_base_url") public var customBaseUrl: String = "http://localhost:1234/v1" {
        didSet {
            objectWillChange.send()
        }
    }
    
    @AppStorage("newton_current_model") public var currentModelId: String = "anthropic/claude-3.5-sonnet" {
        didSet {
            objectWillChange.send()
        }
    }
    
    @AppStorage("newton_temperature") public var temperature: Double = 0.7 {
        didSet {
            objectWillChange.send()
        }
    }
    
    @AppStorage("newton_max_tokens") public var maxTokens: Int = 2048 {
        didSet {
            objectWillChange.send()
        }
    }
    
    @AppStorage("newton_custom_system_prompt") public var customSystemPrompt: String = "" {
        didSet {
            objectWillChange.send()
        }
    }
    
    @AppStorage("newton_app_theme") public var appTheme: String = "dark" {
        didSet {
            objectWillChange.send()
        }
    }
    
    public var currentProvider: AIProvider {
        get {
            AIProvider(rawValue: currentProviderRaw) ?? .openrouter
        }
        set {
            currentProviderRaw = newValue.rawValue
            currentModelId = newValue.defaultModelId
        }
    }
    
    public var currentApiKey: String {
        get {
            KeychainManager.shared.getApiKey(for: currentProvider)
        }
        set {
            KeychainManager.shared.saveApiKey(newValue, for: currentProvider)
            objectWillChange.send()
        }
    }
    
    public func getApiKey(for provider: AIProvider) -> String {
        KeychainManager.shared.getApiKey(for: provider)
    }
    
    public func setApiKey(_ key: String, for provider: AIProvider) {
        KeychainManager.shared.saveApiKey(key, for: provider)
        objectWillChange.send()
    }
    
    public func isConfigured() -> Bool {
        if currentProvider == .ollama {
            return true
        }
        if currentProvider == .openaiCompatible || currentProvider == .anthropicCompatible {
            return !customBaseUrl.isEmpty || !currentApiKey.isEmpty
        }
        return !currentApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public func effectiveBaseUrl(for provider: AIProvider) -> String {
        if provider.isCustomOrLocal && !customBaseUrl.isEmpty {
            return customBaseUrl
        }
        return provider.defaultBaseUrl
    }
    
    public func defaultSystemPrompt() -> String {
        if !customSystemPrompt.isEmpty {
            return customSystemPrompt
        }
        return """
        You are Newton AI, an intelligent, scientific, and precise AI assistant.
        Provide clear, accurate, and insightful responses. Use Markdown for formatting code and structure.
        """
    }
}
