//
//  MacChatView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Faithfully matches the web desktop interface design.
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
    @State private var showModelSheet: Bool = false
    
    public init(conversation: Binding<Conversation>) {
        self._conversation = conversation
    }
    
    public var body: some View {
        ZStack {
            // Background Kinetic 3D Wireframe Mesh
            MacHero3DCanvasView(isThinking: isStreaming)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header Bar with Model Pill & Ghost Mode
                HStack {
                    Button(action: {
                        showModelSheet.toggle()
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(conversation.isGhost ? Color(red: 0.75, green: 0.55, blue: 0.95) : Color(red: 0.65, green: 0.70, blue: 0.75))
                                .frame(width: 8, height: 8)
                            
                            Text(conversation.isGhost ? "Ghost Session (No Memory)" : modelDisplayName)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(Color(red: 0.15, green: 0.18, blue: 0.22))
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(red: 0.55, green: 0.60, blue: 0.68))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(conversation.isGhost ? Color(red: 0.75, green: 0.55, blue: 0.95).opacity(0.6) : Color(red: 0.88, green: 0.91, blue: 0.94), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    
                    // Ghost Mode Quick Toggle / Burn Button
                    Button(action: {
                        if conversation.isGhost {
                            conversation.messages.removeAll()
                            storage.deleteConversation(id: conversation.id)
                        } else {
                            let ghost = storage.createGhostConversation()
                            conversation = ghost
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: conversation.isGhost ? "ghost.fill" : "ghost")
                                .font(.system(size: 11))
                            Text(conversation.isGhost ? "Vanish" : "Ghost Mode")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(conversation.isGhost ? Color(red: 0.92, green: 0.35, blue: 0.30) : Color(red: 0.45, green: 0.50, blue: 0.58))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.88, green: 0.91, blue: 0.94), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(conversation.isGhost ? "Incinerate ghost session messages instantly" : "Start ephemeral Ghost session (no history saved)")
                    
                    Spacer()
                    
                    // Export Options
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
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.45, green: 0.50, blue: 0.58))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.88, green: 0.91, blue: 0.94), lineWidth: 0.8)
                            )
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 32)
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                // Content: Empty State Hero OR Conversation ScrollView
                if conversation.messages.isEmpty {
                    Spacer()
                    
                    VStack(spacing: 24) {
                        // Hand-Drawn Newton Lightbulb Logo
                        Image("NewtonLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                        
                        // Hero Serif Title
                        Text("What will you discover today?")
                            .font(.system(size: 28, weight: .regular, design: .serif))
                            .foregroundColor(Color(red: 0.08, green: 0.11, blue: 0.16))
                        
                        // 2x2 Suggestion Cards Grid
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                            SuggestionCard(
                                icon: "lightbulb",
                                title: "Explain a Concept",
                                subtitle: "Quantum computing basics",
                                prompt: "Explain quantum computing basics with a simple real-world analogy."
                            ) { selectedPrompt in
                                inputText = selectedPrompt
                                sendMessage()
                            }
                            
                            SuggestionCard(
                                icon: "terminal",
                                title: "Code & Debug",
                                subtitle: "Python web scraper script",
                                prompt: "Write an efficient Python script for web scraping with async request handling."
                            ) { selectedPrompt in
                                inputText = selectedPrompt
                                sendMessage()
                            }
                            
                            SuggestionCard(
                                icon: "doc.text",
                                title: "Write & Draft",
                                subtitle: "Technical architecture spec",
                                prompt: "Draft a clean technical specification document for a cloud microservices architecture."
                            ) { selectedPrompt in
                                inputText = selectedPrompt
                                sendMessage()
                            }
                            
                            SuggestionCard(
                                icon: "sparkles",
                                title: "Analyze & Compare",
                                subtitle: "Claude 3.5 vs DeepSeek R1",
                                prompt: "What are the key architectural differences between Claude 3.5 Sonnet and DeepSeek R1?"
                            ) { selectedPrompt in
                                inputText = selectedPrompt
                                sendMessage()
                            }
                        }
                        .frame(maxWidth: 620)
                    }
                    
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(conversation.messages) { message in
                                    MacMessageBubbleView(message: message, onRetry: {
                                        retryMessage(message)
                                    })
                                    .id(message.id)
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.vertical, 20)
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
                
                // Floating Bottom Input Bar Card
                MacMessageInputBar(
                    text: $inputText,
                    isStreaming: isStreaming,
                    onSend: sendMessage,
                    onStop: stopStreaming,
                    onAttachFile: openFilePicker
                )
            }
        }
        .popover(isPresented: $showModelSheet) {
            MacModelPickerPopover()
        }
    }
    
    private var modelDisplayName: String {
        if settings.currentModelId.contains("sonnet") {
            return "Newton I (Claude 3.5 Sonnet)"
        } else if settings.currentModelId.contains("r1") {
            return "Newton R1 (DeepSeek)"
        } else if settings.currentModelId.contains("gpt-4o") {
            return "Newton Omni (GPT-4o)"
        }
        return "Newton I"
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

public struct SuggestionCard: View {
    public let icon: String
    public let title: String
    public let subtitle: String
    public let prompt: String
    public let onSelect: (String) -> Void
    
    @State private var isHovered: Bool = false
    
    public var body: some View {
        Button(action: {
            onSelect(prompt)
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.25, green: 0.30, blue: 0.38))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.08, green: 0.11, blue: 0.16))
                    
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(Color(red: 0.45, green: 0.50, blue: 0.58))
                }
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isHovered ? Color(red: 0.70, green: 0.75, blue: 0.82) : Color(red: 0.88, green: 0.91, blue: 0.94), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.06 : 0.02), radius: 6, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovered = hover
        }
    }
}

public struct MacModelPickerPopover: View {
    @StateObject private var settings = SettingsManager.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Model Engine")
                .font(.system(size: 13, weight: .bold))
                .padding(.bottom, 2)
            
            ForEach(DefaultModelCatalog.models(for: settings.currentProvider)) { model in
                Button(action: {
                    settings.currentModelId = model.id
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.name)
                                .font(.system(size: 12.5, weight: model.id == settings.currentModelId ? .semibold : .regular))
                                .foregroundColor(Color(red: 0.08, green: 0.11, blue: 0.16))
                            
                            Text(model.description)
                                .font(.system(size: 10.5))
                                .foregroundColor(Color(red: 0.45, green: 0.50, blue: 0.58))
                        }
                        Spacer()
                        if model.id == settings.currentModelId {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.08, green: 0.11, blue: 0.16))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(model.id == settings.currentModelId ? Color(red: 0.92, green: 0.95, blue: 0.98) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}
