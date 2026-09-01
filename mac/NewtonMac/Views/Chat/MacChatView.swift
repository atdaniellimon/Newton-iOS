//
//  MacChatView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import AppKit

public struct MacChatView: View {
    @Binding public var conversation: Conversation
    @StateObject private var storage = StorageManager.shared
    @StateObject private var settings = SettingsManager.shared
    
    @State private var inputText: String = ""
    @State private var isStreaming: Bool = false
    @State private var streamTask: Task<Void, Never>? = nil
    
    public init(conversation: Binding<Conversation>) {
        self._conversation = conversation
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.title.isEmpty ? "New Conversation" : conversation.title)
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(NewtonTheme.forestGreen)
                            .frame(width: 6, height: 6)
                        
                        Text("\(settings.currentProvider.displayName) • \(settings.currentModelId)")
                            .font(.system(size: 11))
                            .foregroundColor(NewtonTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Export Menu
                Menu {
                    Button("Export to Editorial PDF") {
                        if let url = ConversationExportManager.shared.generateCustomDocumentPDF(title: conversation.title, content: conversation.messages.map { "\($0.role == .user ? "User" : "Newton"): \($0.content)" }.joined(separator: "\n\n")) {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                    Button("Export to Markdown") {
                        if let url = ConversationExportManager.shared.exportToMarkdown(conversation: conversation) {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(NewtonTheme.surface)
            
            Divider()
            
            // Messages Timeline or 3D Canvas
            if conversation.messages.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    MacHero3DCanvasView(isThinking: isStreaming)
                        .frame(width: 220, height: 220)
                    
                    Text("Newton Singularity")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                    
                    Text("Reasoning deeply across science, engineering, and art.")
                        .font(.system(size: 13))
                        .foregroundColor(NewtonTheme.textSecondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(conversation.messages) { message in
                                MacMessageBubbleView(message: message, onRetry: {
                                    retryMessage(message)
                                })
                                .id(message.id)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .onChange(of: conversation.messages.count) { _ in
                        if let lastId = conversation.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Message Input Bar
            MacMessageInputBar(
                text: $inputText,
                isStreaming: isStreaming,
                onSend: sendMessage,
                onStop: stopStreaming,
                onAttachFile: openFilePicker
            )
        }
        .background(NewtonTheme.background)
    }
    
    private func sendMessage() {
        let userPrompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userPrompt.isEmpty else { return }
        
        let isFirstMessage = conversation.messages.isEmpty
        inputText = ""
        
        let userMessage = Message(role: .user, content: userPrompt)
        conversation.messages.append(userMessage)
        
        if isFirstMessage {
            conversation.title = String(userPrompt.split(separator: " ").prefix(4).joined(separator: " "))
        }
        
        let assistantMessageId = UUID().uuidString
        let assistantPlaceholder = Message(id: assistantMessageId, role: .assistant, content: "", isStreaming: true)
        conversation.messages.append(assistantPlaceholder)
        storage.updateConversation(conversation)
        
        isStreaming = true
        
        streamTask = Task {
            var fullResponse = ""
            var currentThinking = ""
            var isInsideThinkingTag = false
            
            let provider = settings.currentProvider
            let modelId = settings.currentModelId
            let baseUrl = settings.effectiveBaseUrl(for: provider)
            let apiKey = settings.getApiKey(for: provider)
            let temp = settings.temperature
            let maxTokens = settings.maxTokens
            let systemPrompt = settings.defaultSystemPrompt()
            
            do {
                let stream = LLMService.shared.streamCompletion(
                    messages: conversation.messages.dropLast(),
                    provider: provider,
                    modelId: modelId,
                    baseUrl: baseUrl,
                    apiKey: apiKey,
                    temperature: temp,
                    maxTokens: maxTokens,
                    systemPrompt: systemPrompt
                )
                
                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    
                    if token.contains("<think>") {
                        isInsideThinkingTag = true
                    }
                    
                    if isInsideThinkingTag {
                        currentThinking += token.replacingOccurrences(of: "<think>", with: "")
                        if token.contains("</think>") {
                            isInsideThinkingTag = false
                            currentThinking = currentThinking.replacingOccurrences(of: "</think>", with: "")
                        }
                    } else {
                        fullResponse += token
                    }
                    
                    await MainActor.run {
                        self.updateStreamingToken(assistantMessageId: assistantMessageId, text: fullResponse, thinking: currentThinking)
                    }
                }
                
                let (finalContent, orbitResults, detectedImgUrl) = await OrbitEngine.shared.processOrbitsInText(
                    fullResponse,
                    userPrompt: userPrompt,
                    baseUrl: baseUrl,
                    apiKey: apiKey
                )
                
                await MainActor.run {
                    self.finalizeStreaming(
                        assistantMessageId: assistantMessageId,
                        content: finalContent,
                        imgUrl: detectedImgUrl,
                        orbits: orbitResults
                    )
                }
            } catch {
                await MainActor.run {
                    self.failStreaming(assistantMessageId: assistantMessageId, errorText: error.localizedDescription)
                }
            }
        }
    }
    
    @MainActor
    private func updateStreamingToken(assistantMessageId: String, text: String, thinking: String) {
        if let index = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
            conversation.messages[index].content = text
            conversation.messages[index].thinkingContent = thinking.isEmpty ? nil : thinking
        }
    }
    
    @MainActor
    private func finalizeStreaming(assistantMessageId: String, content: String, imgUrl: String?, orbits: [OrbitExecutionResult]) {
        if let index = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
            conversation.messages[index].content = content
            conversation.messages[index].imageUrl = imgUrl
            conversation.messages[index].orbitResults = orbits
            conversation.messages[index].isStreaming = false
        }
        storage.updateConversation(conversation)
        isStreaming = false
    }
    
    @MainActor
    private func failStreaming(assistantMessageId: String, errorText: String) {
        if let index = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
            conversation.messages[index].content = "Error: \(errorText)"
            conversation.messages[index].isStreaming = false
        }
        isStreaming = false
    }
    
    private func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }
    
    private func retryMessage(_ message: Message) {
        if let idx = conversation.messages.firstIndex(where: { $0.id == message.id }), idx > 0 {
            let previousUser = conversation.messages[idx - 1]
            if previousUser.role == .user {
                inputText = previousUser.content
                sendMessage()
            }
        }
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                inputText += "\n\n```\(url.lastPathComponent)\n\(content)\n```"
            }
        }
    }
}
