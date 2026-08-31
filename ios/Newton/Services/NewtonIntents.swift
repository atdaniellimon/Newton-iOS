//
//  NewtonIntents.swift
//  Newton
//
//  Created for Newton iOS.
//  Siri & Shortcuts AppIntents integration ("Ask Newton", "Pregúntale a Newton").
//

import AppIntents
import Foundation

@available(iOS 16.0, *)
public struct AskNewtonIntent: AppIntent {
    public static var title: LocalizedStringResource = "Ask Newton"
    public static var description = IntentDescription("Ask Newton a question using AI reasoning.")
    
    @Parameter(title: "Prompt", description: "What would you like to ask Newton?")
    public var prompt: String
    
    public init() {}
    
    public init(prompt: String) {
        self.prompt = prompt
    }
    
    public func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        let settings = SettingsManager.shared
        let provider = settings.currentProvider
        let modelId = settings.currentModelId
        let baseUrl = settings.effectiveBaseUrl(for: provider)
        let apiKey = settings.getApiKey(for: provider)
        
        let messages = [
            Message(role: .user, content: prompt)
        ]
        
        var fullAnswer = ""
        do {
            let stream = LLMService.shared.streamCompletion(
                messages: messages,
                provider: provider,
                modelId: modelId,
                baseUrl: baseUrl,
                apiKey: apiKey,
                temperature: 0.7,
                maxTokens: 2048,
                systemPrompt: "You are Newton. Give a clear, insightful, and direct answer."
            )
            
            for try await token in stream {
                fullAnswer += token
            }
        } catch {
            fullAnswer = "Newton error: \(error.localizedDescription)"
        }
        
        // Clean any thinking or tags
        let cleanAnswer = fullAnswer
            .replacingOccurrences(of: "<think>[\\s\\S]*?</think>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Also save to a conversation in Newton
        await MainActor.run {
            var convo = StorageManager.shared.createConversation(
                provider: provider,
                modelId: modelId,
                title: String(prompt.prefix(30))
            )
            convo.messages.append(Message(role: .user, content: prompt))
            convo.messages.append(Message(role: .assistant, content: cleanAnswer))
            StorageManager.shared.updateConversation(convo)
        }
        
        return .result(value: cleanAnswer, dialog: IntentDialog(stringLiteral: cleanAnswer))
    }
}

@available(iOS 16.0, *)
public struct NewtonShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskNewtonIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) \(\.$prompt)",
                "Pregúntale a \(.applicationName)",
                "Pregunta a \(.applicationName) \(\.$prompt)"
            ],
            shortTitle: "Ask Newton",
            systemImageName: "sparkles"
        )
    }
}
