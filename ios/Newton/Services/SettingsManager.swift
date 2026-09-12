//
//  SettingsManager.swift
//  Newton
//
//  Simplified for Newton Singularity — single model, no provider abstraction.
//  API key is managed exclusively by AuthManager (stored in Keychain).
//

import Foundation
import SwiftUI

public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    /// The single NWTN endpoint (direct, no proxy layer needed for non-auth calls)
    public static let nwtnBaseURL: String = "https://api.newton.daniellimon.uk/nwtn"

    /// Legacy alias kept so EndpointSyncService compiles without changes
    public static let hardcodedEndpoint: String = nwtnBaseURL

    // Model selection
    @AppStorage("currentModelId") public var currentModelId: String = "Singularity"
    @Published public var availableModels: [AIModel] = DefaultModelCatalog.models()

    public var currentModel: AIModel {
        availableModels.first(where: { $0.id == currentModelId }) ?? AIModel.singularity
    }

    public var currentModelDisplayName: String {
        currentModel.name
    }

    // User Preferences
    @AppStorage("appTheme")          public var appThemeRaw: String  = AppThemeMode.system.rawValue
    @AppStorage("hapticFeedback")    public var hapticFeedbackEnabled: Bool = true
    @AppStorage("autoScrollOnStream")public var autoScrollOnStream: Bool   = true
    @AppStorage("codeLineNumbers")   public var codeLineNumbers: Bool      = true
    @AppStorage("latexRendering")    public var latexRendering: Bool       = true
    @AppStorage("speechRate")        public var speechRate: Double         = 0.50

    public let temperature: Double = 0.7
    public let maxTokens: Int      = 4096

    // ── Compatibility shims (keep callers compiling) ───────────────
    /// The active NWTN endpoint (EndpointSyncService may override this)
    @AppStorage("customBaseUrl") public var customBaseUrl: String = nwtnBaseURL

    /// The current ntwn-... API key — always sourced from AuthManager/Keychain
    public var currentApiKey: String {
        AuthManager.shared.nwtnKey
    }

    public func isConfigured() -> Bool {
        !AuthManager.shared.nwtnKey.isEmpty
    }

    /// Returns the effective base URL for any provider (always NWTN)
    public func effectiveBaseUrl(for _: Any? = nil) -> String {
        customBaseUrl.isEmpty ? Self.nwtnBaseURL : customBaseUrl
    }

    public var appTheme: AppThemeMode {
        get { AppThemeMode(rawValue: appThemeRaw) ?? .system }
        set { appThemeRaw = newValue.rawValue }
    }

    private init() {}

    // ── Newton Singularity System Prompt ───────────────────────────
    public static let singularitySystemPrompt: String = """
    
    """
}
