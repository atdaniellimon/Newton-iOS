//
//  MacMenuBarView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import AppKit

public struct MacMenuBarView: View {
    @State private var quickPrompt: String = ""
    @State private var quickAnswer: String = ""
    @State private var isAnswering: Bool = false
    @StateObject private var settings = SettingsManager.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(NewtonTheme.sand)
                
                Text("Newton Quick Assistant")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(NewtonTheme.textSecondary)
            }
            
            Divider()
            
            HStack {
                TextField("Ask Newton anything...", text: $quickPrompt, onCommit: askQuickPrompt)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isAnswering)
                
                if isAnswering {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 24)
                } else {
                    Button(action: askQuickPrompt) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(NewtonTheme.sand)
                    }
                    .buttonStyle(.plain)
                    .disabled(quickPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            if !quickAnswer.isEmpty {
                ScrollView {
                    Text(quickAnswer)
                        .font(.system(size: 12, design: .serif))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NewtonTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(14)
        .frame(width: 340)
    }
    
    private func askQuickPrompt() {
        let prompt = quickPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        
        isAnswering = true
        quickAnswer = ""
        
        Task {
            let provider = settings.currentProvider
            let modelId = settings.currentModelId
            let baseUrl = settings.effectiveBaseUrl(for: provider)
            let apiKey = settings.getApiKey(for: provider)
            
            do {
                let stream = LLMService.shared.streamCompletion(
                    messages: [Message(role: .user, content: prompt)],
                    provider: provider,
                    modelId: modelId,
                    baseUrl: baseUrl,
                    apiKey: apiKey,
                    temperature: 0.7,
                    maxTokens: 1024,
                    systemPrompt: settings.defaultSystemPrompt()
                )
                
                for try await token in stream {
                    await MainActor.run {
                        self.quickAnswer += token
                    }
                }
                await MainActor.run {
                    self.isAnswering = false
                }
            } catch {
                await MainActor.run {
                    self.quickAnswer = "Error: \(error.localizedDescription)"
                    self.isAnswering = false
                }
            }
        }
    }
}
