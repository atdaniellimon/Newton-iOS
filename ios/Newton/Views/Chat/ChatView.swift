//
//  ChatView.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct ChatView: View {
    @Binding public var conversation: Conversation
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var storage = StorageManager.shared
    
    @State private var inputText: String = ""
    @State private var isStreaming: Bool = false
    @State private var currentStreamTask: Task<Void, Never>? = nil
    @State private var errorMessage: String? = nil
    @State private var showSettings: Bool = false
    @State private var showModelPicker: Bool = false
    
    public init(conversation: Binding<Conversation>) {
        self._conversation = conversation
    }
    
    public var body: some View {
        ZStack {
            NewtonTheme.bgDark
                .ignoresSafeArea()
            
            // 3D Undulating wave grid background
            if conversation.messages.isEmpty {
                Hero3DCanvasView()
                    .ignoresSafeArea()
                    .opacity(0.85)
            }
            
            VStack(spacing: 0) {
                // Header Status Pill & Model info
                HStack {
                    Button(action: {
                        showModelPicker = true
                    }) {
                        StatusPillView()
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundColor(NewtonTheme.textSecondary)
                            .padding(8)
                            .background(NewtonTheme.surfaceDark)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                Divider()
                    .background(NewtonTheme.borderDark)
                
                // Messages Scroll View
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if conversation.messages.isEmpty {
                                EmptyStateView(onPromptSelected: { prompt in
                                    inputText = prompt
                                    sendMessage()
                                })
                                .padding(.top, 24)
                            } else {
                                ForEach(conversation.messages) { message in
                                    MessageBubbleView(message: message)
                                        .id(message.id)
                                }
                            }
                            
                            // 3D Animated Thinking Orb when streaming / thinking
                            if isStreaming {
                                HStack(spacing: 12) {
                                    ThinkingOrbView(size: 42, style: .globe)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Newton is reasoning...")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(NewtonTheme.sand)
                                        Text("Processing context and active orbits")
                                            .font(.system(size: 11))
                                            .foregroundColor(NewtonTheme.textSecondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(NewtonTheme.cardDark.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(NewtonTheme.sand.opacity(0.3), lineWidth: 0.8)
                                )
                                .padding(.horizontal, 16)
                                .id("thinking_orb_card")
                            }
                            
                            if let error = errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(NewtonTheme.coralRed)
                                    Text(error)
                                        .font(.system(size: 13))
                                        .foregroundColor(NewtonTheme.coralRed)
                                }
                                .padding(12)
                                .background(NewtonTheme.coralRed.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                                .id("error_bubble")
                            }
                            
                            Color.clear
                                .frame(height: 1)
                                .id("bottom_anchor")
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: conversation.messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: conversation.messages.last?.content) { _ in
                        proxy.scrollTo("bottom_anchor", anchor: .bottom)
                    }
                    .onChange(of: isStreaming) { _ in
                        withAnimation {
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                    }
                }
                
                // Input Bar
                MessageInputBar(
                    text: $inputText,
                    isStreaming: isStreaming,
                    onSend: sendMessage,
                    onStop: stopStreaming
                )
            }
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(selectedModelId: $settings.currentModelId)
        }
    }
    
    private func sendMessage() {
        let userPrompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userPrompt.isEmpty else { return }
        
        inputText = ""
        errorMessage = nil
        
        let userMessage = Message(role: .user, content: userPrompt)
        conversation.messages.append(userMessage)
        
        if conversation.title == "New Conversation" || conversation.title == "Welcome to Newton" {
            let words = userPrompt.split(separator: " ").prefix(5).joined(separator: " ")
            conversation.title = String(words)
        }
        
        let assistantMessageId = UUID().uuidString
        let assistantPlaceholder = Message(id: assistantMessageId, role: .assistant, content: "", isStreaming: true)
        conversation.messages.append(assistantPlaceholder)
        storage.updateConversation(conversation)
        
        isStreaming = true
        
        currentStreamTask = Task {
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
                    
                    if let index = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        conversation.messages[index].content = fullResponse
                        conversation.messages[index].thinkingContent = currentThinking.isEmpty ? nil : currentThinking
                    }
                }
                
                let (finalContent, orbitResults) = await OrbitEngine.shared.processOrbitsInText(fullResponse)
                
                if let index = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    conversation.messages[index].content = finalContent
                    conversation.messages[index].orbitResults = orbitResults
                    conversation.messages[index].isStreaming = false
                }
                
                storage.updateConversation(conversation)
                Haptics.success()
                
            } catch {
                if let index = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    if fullResponse.isEmpty {
                        conversation.messages.remove(at: index)
                    } else {
                        conversation.messages[index].isStreaming = false
                    }
                }
                errorMessage = error.localizedDescription
                Haptics.error()
            }
            
            isStreaming = false
        }
    }
    
    private func stopStreaming() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
        isStreaming = false
        
        if let index = conversation.messages.indices.last {
            conversation.messages[index].isStreaming = false
        }
        storage.updateConversation(conversation)
    }
}
