//
//  ChatView.swift
//  Newton
//
//  Created for Newton iOS.
//  Matching Newton Web and Studio UI.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum ActiveModalSheet: Identifiable {
    case camera
    case photoLibrary
    case settings
    case modelPicker
    
    var id: String {
        switch self {
        case .camera: return "camera"
        case .photoLibrary: return "photoLibrary"
        case .settings: return "settings"
        case .modelPicker: return "modelPicker"
        }
    }
}

public struct ChatView: View {
    @Binding public var conversation: Conversation
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var storage = StorageManager.shared
    
    @State private var inputText: String = ""
    @State private var attachedImage: UIImage? = nil
    @State private var attachedFileName: String? = nil
    @State private var attachedFileData: Data? = nil
    
    @State private var isStreaming: Bool = false
    @State private var currentStreamTask: Task<Void, Never>? = nil
    @State private var errorMessage: String? = nil
    @State private var activeSheet: ActiveModalSheet? = nil
    @State private var showFileImporter: Bool = false
    
    public init(conversation: Binding<Conversation>) {
        self._conversation = conversation
    }
    
    public var body: some View {
        ZStack {
            NewtonTheme.bg
                .ignoresSafeArea()
            
            // 3D Undulating wave grid background
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
                                .padding(.top, 24)
                            } else {
                                ForEach(conversation.messages) { message in
                                    MessageBubbleView(
                                        message: message,
                                        onRetry: {
                                            retryLastMessage()
                                        },
                                        onEdit: { msgToEdit in
                                            editMessage(msgToEdit)
                                        }
                                    )
                                    .id(message.id)
                                }
                            }
                            
                            // Single Unified 3D Thinking Indicator
                            if isStreaming && (conversation.messages.last?.content.isEmpty ?? true) {
                                HStack(spacing: 12) {
                                    ThinkingOrbView(size: 32, style: .globe)
                                    
                                    Text("Newton is reasoning...")
                                        .font(.system(size: 14, weight: .medium, design: .serif))
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
                        .padding(.vertical, 10)
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
                    .scrollDismissesKeyboard(.interactively)
                }
                
                // Ultra-Compact Studio Input Bar
                MessageInputBar(
                    text: $inputText,
                    attachedImage: $attachedImage,
                    attachedFileName: $attachedFileName,
                    isStreaming: isStreaming,
                    onTriggerCamera: {
                        activeSheet = .camera
                    },
                    onTriggerPhotos: {
                        activeSheet = .photoLibrary
                    },
                    onTriggerFiles: {
                        showFileImporter = true
                    },
                    onTriggerWebSearch: {
                        inputText += "[ORBIT:web_search]{\"query\": \"\"}[/ORBIT]"
                    },
                    onSend: sendMessage,
                    onStop: stopStreaming
                )
            }
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .camera:
                ImagePicker(sourceType: .camera) { img in
                    attachedImage = img
                }
            case .photoLibrary:
                ImagePicker(sourceType: .photoLibrary) { img in
                    attachedImage = img
                }
            case .settings:
                SettingsView()
            case .modelPicker:
                ModelPickerSheet(selectedModelId: $settings.currentModelId)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item, .text, .pdf, .sourceCode, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedUrl = urls.first else { return }
                attachedFileName = selectedUrl.lastPathComponent
                attachedFileData = try? Data(contentsOf: selectedUrl)
            case .failure(let error):
                print("File import error: \(error)")
            }
        }
    }
    
    private func editMessage(_ msg: Message) {
        if let idx = conversation.messages.firstIndex(where: { $0.id == msg.id }) {
            inputText = msg.content
            if let imgStr = msg.imageUrl, imgStr.hasPrefix("data:image/"),
               let commaIdx = imgStr.firstIndex(of: ","),
               let data = Data(base64Encoded: String(imgStr[imgStr.index(after: commaIdx)...])),
               let uiImg = UIImage(data: data) {
                attachedImage = uiImg
            }
            conversation.messages = Array(conversation.messages.prefix(upTo: idx))
            storage.updateConversation(conversation)
            Haptics.light()
        }
    }
    
    private func extractImagePrompt(from text: String) -> String? {
        let patterns = [
            "^/imagine\\s+(.+)$",
            "^(?:genera|generame|crea|creame|haz)\\s+(?:una\\s+)?(?:imagen|foto|dibujo|grafico)\\s+(?:de|sobre|para)?\\s*(.+)$",
            "^(?:generate|create|make)\\s+(?:an?\\s+)?(?:image|photo|drawing|picture)\\s+(?:of|about|for)?\\s*(.+)$",
            "^(?:dibuja|dibujame|pinta|pintame|draw|paint)\\s+(?:a|un|una)?\\s*(.+)$"
        ]
        
        for p in patterns {
            if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
                let ns = text as NSString
                if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
                   match.numberOfRanges >= 2 {
                    let extracted = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extracted.isEmpty {
                        return extracted
                    }
                }
            }
        }
        return nil
    }
    
    private func sendMessage() {
        var userPrompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if userPrompt.isEmpty && attachedImage != nil {
            userPrompt = "Describe and explain the details, text, and information shown in the attached content."
        }
        if userPrompt.isEmpty && attachedFileName != nil {
            userPrompt = "Please examine the contents of this file: \(attachedFileName ?? "")."
        }
        guard !userPrompt.isEmpty || attachedImage != nil else { return }
        
        let isFirstMessage = conversation.messages.isEmpty
        inputText = ""
        
        // Prepare image base64 if attached
        var imgBase64DataUrl: String? = nil
        if let img = attachedImage, let jpegData = img.jpegData(compressionQuality: 0.75) {
            imgBase64DataUrl = "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
        }
        
        // Prepare file content if text file
        if let fileData = attachedFileData, let textContent = String(data: fileData, encoding: .utf8) {
            userPrompt += "\n\n```\(attachedFileName ?? "file")\n\(textContent)\n```"
        }
        
        attachedImage = nil
        attachedFileName = nil
        attachedFileData = nil
        errorMessage = nil
        
        var userMessage = Message(role: .user, content: userPrompt)
        userMessage.imageUrl = imgBase64DataUrl
        conversation.messages.append(userMessage)
        
        if isFirstMessage {
            conversation.title = String(userPrompt.split(separator: " ").prefix(4).joined(separator: " "))
        }
        
        // Check for direct Image Generation prompt match
        if let imagePrompt = extractImagePrompt(from: userPrompt) {
            let baseUrl = settings.effectiveBaseUrl(for: settings.currentProvider)
            let apiKey = settings.getApiKey(for: settings.currentProvider)
            
            let assistantMessageId = UUID().uuidString
            let placeholder = Message(id: assistantMessageId, role: .assistant, content: "Generating image: *\(imagePrompt)*...", isStreaming: true)
            conversation.messages.append(placeholder)
            storage.updateConversation(conversation)
            
            Task {
                let imageUrl = await OrbitEngine.shared.generateImage(prompt: imagePrompt, baseUrl: baseUrl, apiKey: apiKey)
                await MainActor.run {
                    if let idx = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        conversation.messages[idx].content = "Here is your generated image for *\(imagePrompt)*:"
                        conversation.messages[idx].imageUrl = imageUrl
                        conversation.messages[idx].isStreaming = false
                    }
                    storage.updateConversation(conversation)
                    Haptics.success()
                }
            }
            return
        }
        
        let assistantMessageId = UUID().uuidString
        let assistantPlaceholder = Message(id: assistantMessageId, role: .assistant, content: "", isStreaming: true)
        conversation.messages.append(assistantPlaceholder)
        storage.updateConversation(conversation)
        
        isStreaming = true
        
        // Run with Background Task Protection
        NotificationManager.shared.beginBackgroundTask(name: "NewtonStreamTask") {
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
                        if let index = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                            conversation.messages[index].content = fullResponse
                            conversation.messages[index].thinkingContent = currentThinking.isEmpty ? nil : currentThinking
                        }
                    }
                }
                
                let (finalContent, orbitResults, detectedImgUrl) = await OrbitEngine.shared.processOrbitsInText(fullResponse)
                
                await MainActor.run {
                    if let index = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        conversation.messages[index].content = finalContent
                        conversation.messages[index].imageUrl = detectedImgUrl
                        conversation.messages[index].orbitResults = orbitResults
                        conversation.messages[index].isStreaming = false
                    }
                    
                    storage.updateConversation(conversation)
                    Haptics.success()
                }
                
                // Trigger background AI title generation if first message
                if isFirstMessage && !userPrompt.isEmpty {
                    Task {
                        await generateAITitle(forPrompt: userPrompt, response: finalContent)
                    }
                }
                
                // Notify user if response finished while app was backgrounded
                if UIApplication.shared.applicationState != .active {
                    NotificationManager.shared.sendResponseReadyNotification(title: conversation.title, body: finalContent)
                }
                
            } catch {
                await MainActor.run {
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
            }
            
            await MainActor.run {
                isStreaming = false
            }
        }
    }
    
    private func generateAITitle(forPrompt prompt: String, response: String) async {
        let titlePrompt = [
            Message(role: .user, content: "Create a concise, descriptive 2-4 word title in the language of this query: \"\(prompt)\". Output ONLY the title, no quotes or punctuation.")
        ]
        
        let provider = settings.currentProvider
        let modelId = settings.currentModelId
        let baseUrl = settings.effectiveBaseUrl(for: provider)
        let apiKey = settings.getApiKey(for: provider)
        
        do {
            let stream = LLMService.shared.streamCompletion(
                messages: titlePrompt,
                provider: provider,
                modelId: modelId,
                baseUrl: baseUrl,
                apiKey: apiKey,
                temperature: 0.3,
                maxTokens: 15,
                systemPrompt: "You are a concise title generator. Reply ONLY with a 2-4 word title."
            )
            
            var generatedTitle = ""
            for try await token in stream {
                generatedTitle += token
            }
            
            let cleanTitle = generatedTitle
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "\n", with: " ")
            
            if !cleanTitle.isEmpty {
                await MainActor.run {
                    conversation.title = cleanTitle
                    storage.updateConversation(conversation)
                }
            }
        } catch {
            // Fallback
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
            // Clean Newton Brand
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
