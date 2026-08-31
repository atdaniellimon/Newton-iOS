//
//  ChatView.swift
//  Newton
//
//  Created for Newton iOS.
//  Matching Newton Web and Studio UI.
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
    
    private var shortModelDisplayName: String {
        if let last = settings.currentModelId.split(separator: "/").last {
            return String(last)
        }
        return settings.currentModelId
    }
    
    public var body: some View {
        ZStack {
            NewtonTheme.bg
                .ignoresSafeArea()
            
            // 3D Undulating wave grid background (visible across whole chat canvas)
            Hero3DCanvasView()
                .ignoresSafeArea()
                .opacity(0.88)
            
            VStack(spacing: 0) {
                // Messages Scroll View
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if conversation.messages.isEmpty {
                                // Newton Hero Welcome Screen matching web screenshot
                                NewtonHeroWelcomeView(onPromptSelected: { prompt in
                                    inputText = prompt
                                    sendMessage()
                                })
                                .padding(.top, 28)
                            } else {
                                ForEach(conversation.messages) { message in
                                    MessageBubbleView(
                                        message: message,
                                        onRetry: {
                                            retryLastMessage()
                                        },
                                        onEdit: { editedText in
                                            inputText = editedText
                                        }
                                    )
                                    .id(message.id)
                                }
                            }
                            
                            // Single Unified 3D Thinking Indicator (No redundant boxes)
                            if isStreaming && (conversation.messages.last?.content.isEmpty ?? true) {
                                HStack(spacing: 12) {
                                    ThinkingOrbView(size: 32, style: .globe)
                                    
                                    Text("Newton is reasoning...")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(NewtonTheme.sand)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .id("thinking_indicator")
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
                                .padding(.horizontal, 20)
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
                
                // Floating Studio Input Bar
                MessageInputBar(
                    text: $inputText,
                    isStreaming: isStreaming,
                    modelName: shortModelDisplayName,
                    onModelTap: {
                        showModelPicker = true
                    },
                    onSend: sendMessage,
                    onStop: stopStreaming
                )
            }
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
            }
        }
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
        
        // Check if user is asking for image generation directly
        let lower = userPrompt.lowercased()
        if lower.hasPrefix("/imagine ") || lower.hasPrefix("draw ") || lower.hasPrefix("generate image") || lower.hasPrefix("genera una imagen") || lower.hasPrefix("dibuja ") {
            let prompt = lower
                .replacingOccurrences(of: "/imagine ", with: "")
                .replacingOccurrences(of: "generate image of ", with: "")
                .replacingOccurrences(of: "genera una imagen de ", with: "")
                .replacingOccurrences(of: "dibuja ", with: "")
                .replacingOccurrences(of: "draw ", with: "")
            
            let imageUrl = OrbitEngine.shared.generateImage(prompt: prompt)
            let assistantMessage = Message(
                role: .assistant,
                content: "Here is your generated image for: *\(prompt)*",
                imageUrl: imageUrl
            )
            conversation.messages.append(assistantMessage)
            storage.updateConversation(conversation)
            Haptics.success()
            return
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
                
                let (finalContent, orbitResults, detectedImgUrl) = await OrbitEngine.shared.processOrbitsInText(fullResponse)
                
                if let index = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    conversation.messages[index].content = finalContent
                    conversation.messages[index].imageUrl = detectedImgUrl
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
    
    private func retryLastMessage() {
        guard let lastUserMsg = conversation.messages.last(where: { $0.role == .user }) else { return }
        if conversation.messages.last?.role == .assistant {
            conversation.messages.removeLast()
        }
        inputText = lastUserMsg.content
        sendMessage()
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

// MARK: - Newton Hero Welcome View (Matching Screenshot 5)

public struct NewtonHeroWelcomeView: View {
    public let onPromptSelected: (String) -> Void
    
    public init(onPromptSelected: @escaping (String) -> Void) {
        self.onPromptSelected = onPromptSelected
    }
    
    private struct CardItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let prompt: String
    }
    
    private let cards: [CardItem] = [
        CardItem(
            icon: "lightbulb.fill",
            title: "Explain a Concept",
            subtitle: "Quantum computing basics",
            prompt: "Explain the fundamental principles of quantum computing and qubits with a clear analogy."
        ),
        CardItem(
            icon: "chevron.left.forwardslash.chevron.right",
            title: "Code & Debug",
            subtitle: "Python web scraper script",
            prompt: "Write a modern, robust Python script using asyncio and BeautifulSoup to scrape and parse data."
        ),
        CardItem(
            icon: "doc.text.fill",
            title: "Write & Draft",
            subtitle: "Technical architecture spec",
            prompt: "Draft a concise technical architecture specification for a high-performance streaming API."
        ),
        CardItem(
            icon: "sparkles",
            title: "Analyze & Compare",
            subtitle: "Claude 3.5 vs DeepSeek R1",
            prompt: "Compare the reasoning capabilities, architecture, and tradeoffs of Claude 3.5 Sonnet vs DeepSeek R1."
        )
    ]
    
    public var body: some View {
        VStack(spacing: 24) {
            // Clean Newton Brand (No bulb icon, clean serif "Newton")
            VStack(spacing: 6) {
                Text("Newton")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundColor(NewtonTheme.textPrimary)
                
                Text("What will you discover today?")
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(NewtonTheme.textSecondary)
            }
            .padding(.top, 16)
            
            // 2x2 Grid of Pill Cards matching Newton Web
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(cards) { item in
                    Button(action: {
                        Haptics.selection()
                        onPromptSelected(item.prompt)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(NewtonTheme.sand)
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(NewtonTheme.textPrimary)
                            }
                            
                            Text(item.subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(NewtonTheme.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(NewtonTheme.card.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(NewtonTheme.border, lineWidth: 0.8)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
