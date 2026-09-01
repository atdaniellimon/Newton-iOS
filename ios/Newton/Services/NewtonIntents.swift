//
//  NewtonAppIntents.swift
//  Newton
//
//  Created for Newton iOS.
//  Siri Shortcuts, Action Button, and App Intents integration.
//

import Foundation
import AppIntents
import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
public struct AskNewtonIntent: AppIntent {
    public static var title: LocalizedStringResource = "Ask Newton"
    public static var description = IntentDescription("Ask a question to Newton Singularity and receive an immediate answer.")
    
    @Parameter(title: "Question", description: "What would you like to ask Newton?")
    public var query: String
    
    public init() {}
    
    public init(query: String) {
        self.query = query
    }
    
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(value: "Please ask a question.", dialog: "What would you like to ask Newton?")
        }
        
        let settings = SettingsManager.shared
        let messages = [Message(role: .user, content: trimmed)]
        
        var responseText = ""
        do {
            let stream = LLMService.shared.streamCompletion(
                messages: messages,
                provider: settings.currentProvider,
                modelId: settings.currentModelId,
                baseUrl: SettingsManager.hardcodedEndpoint,
                apiKey: settings.currentApiKey,
                temperature: 0.7,
                maxTokens: 1024,
                systemPrompt: SettingsManager.singularitySystemPrompt
            )
            
            for try await token in stream {
                responseText += token
            }
            
            // Clean up any orbits or tags for spoken Siri response
            var spoken = responseText
            if let regex = try? NSRegularExpression(pattern: "\\[ORBIT:[^\\]]+\\].*?\\[/ORBIT\\]", options: [.dotMatchesLineSeparators]) {
                spoken = regex.stringByReplacingMatches(in: spoken, options: [], range: NSRange(location: 0, length: (spoken as NSString).length), withTemplate: "")
            }
            spoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
            if spoken.isEmpty { spoken = "Done." }
            
            return .result(value: spoken, dialog: IntentDialog(stringLiteral: spoken))
        } catch {
            let errStr = "Error contacting Newton: \(error.localizedDescription)"
            return .result(value: errStr, dialog: IntentDialog(stringLiteral: errStr))
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct StartVoiceCallIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Newton Voice Call"
    public static var description = IntentDescription("Opens Newton directly in Live Voice Call mode.")
    public static var openAppWhenRun: Bool = true
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        if let url = URL(string: "newton://voice") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct StartGhostSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open Ghost Session"
    public static var description = IntentDescription("Opens Newton in a secure, ephemeral Ghost Session.")
    public static var openAppWhenRun: Bool = true
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        if let url = URL(string: "newton://ghost") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct NewtonShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskNewtonIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Pregúntale a \(.applicationName)",
                "Consultar con \(.applicationName)"
            ],
            shortTitle: "Ask Newton",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: StartVoiceCallIntent(),
            phrases: [
                "Talk with \(.applicationName)",
                "Llamar a \(.applicationName)",
                "Hablar con \(.applicationName)"
            ],
            shortTitle: "Voice Call",
            systemImageName: "waveform.circle.fill"
        )
        AppShortcut(
            intent: StartGhostSessionIntent(),
            phrases: [
                "Ghost Mode in \(.applicationName)",
                "Modo Ghost en \(.applicationName)"
            ],
            shortTitle: "Ghost Session",
            systemImageName: "ghost.fill"
        )
    }
}
