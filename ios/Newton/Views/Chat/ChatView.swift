//
//  ChatView.swift
//  Newton
//
//  Created for Newton iOS.
//  Matching Newton Web and Studio UI with native Tool Calling.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PDFKit

private enum ActiveModalSheet: Identifiable {
    case camera
    case photoLibrary
    case settings
    case modelPicker
    case workspaces
    
    var id: String {
        switch self {
        case .camera: return "camera"
        case .photoLibrary: return "photoLibrary"
        case .settings: return "settings"
        case .modelPicker: return "modelPicker"
        case .workspaces: return "workspaces"
        }
    }
}

public struct ChatView: View {
    @Binding public var conversation: Conversation
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var workspaceManager = WorkspaceManager.shared
    
    @State private var inputText: String = ""
    @State private var attachedImage: UIImage? = nil
    @State private var attachedFileName: String? = nil
    @State private var attachedFileData: Data? = nil
    
    @State private var isStreaming: Bool = false
    @State private var currentStreamTask: Task<Void, Never>? = nil
    @State private var errorMessage: String? = nil
    @State private var activeSheet: ActiveModalSheet? = nil
    @State private var showFileImporter: Bool = false
    @State private var showVoiceCall: Bool = false
    @State private var exportFileUrl: URL? = nil
    
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
                // Ghost Mode Banner
                if conversation.isGhost {
                    HStack(spacing: 8) {
                        Image(systemName: "ghost.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.95))
                        Text("Ghost Mode • Messages vanish when session ends")
                            .font(.system(size: 11.5, weight: .medium, design: .serif))
                            .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.95))
                        Spacer()
                        Button("Vanish") {
                            Haptics.success()
                            conversation.messages.removeAll()
                            storage.deleteConversation(id: conversation.id)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(NewtonTheme.coralRed)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(red: 0.75, green: 0.55, blue: 0.95).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                
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
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        proxy.scrollTo("bottom_anchor", anchor: .bottom)
                                    }
                                }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(NewtonTheme.sand)
                                        .frame(width: 36, height: 36)
                                        .background(NewtonTheme.card.opacity(0.95))
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                                        .overlay(
                                            Circle()
                                                .stroke(NewtonTheme.border, lineWidth: 0.8)
                                        )
                                }
                                .padding(.trailing, 16)
                                .padding(.bottom, 12)
                            }
                        }
                    )
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
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                
                // Ultra-Compact Studio Input Bar OR Terminated Banner
                if isTerminated {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundColor(NewtonTheme.coralRed)
                        Text("Session ended by Newton.")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundColor(NewtonTheme.textSecondary)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(NewtonTheme.card)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(NewtonTheme.coralRed.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                } else {
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
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Haptics.light()
                    activeSheet = .workspaces
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: workspaceManager.activeWorkspace?.iconName ?? "globe")
                            .font(.system(size: 13, weight: .semibold))
                        Text(workspaceManager.activeWorkspace?.name ?? "Global")
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(NewtonTheme.sand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(NewtonTheme.sand.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Ghost Mode Toggle
                Button {
                    Haptics.medium()
                    if conversation.isGhost {
                        conversation.isGhost = false
                        storage.saveConversations()
                    } else {
                        let ghost = storage.createGhostConversation()
                        conversation = ghost
                    }
                } label: {
                    Image(systemName: conversation.isGhost ? "ghost.fill" : "ghost")
                        .font(.system(size: 17))
                        .foregroundColor(conversation.isGhost ? Color(red: 0.75, green: 0.55, blue: 0.95) : NewtonTheme.textSecondary)
                }
                
                // Live Voice Call Button
                Button {
                    Haptics.medium()
                    showVoiceCall = true
                } label: {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(NewtonTheme.sand)
                }
                
                // Export Menu (PDF / Markdown)
                Menu {
                    Button {
                        Haptics.light()
                        if let pdfUrl = ConversationExportManager.shared.exportToPDF(conversation: conversation) {
                            exportFileUrl = pdfUrl
                        }
                    } label: {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }
                    
                    Button {
                        Haptics.light()
                        if let mdUrl = ConversationExportManager.shared.exportToMarkdown(conversation: conversation) {
                            exportFileUrl = mdUrl
                        }
                    } label: {
                        Label("Export as Markdown", systemImage: "text.quote")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
            }
        }
        .fullScreenCover(isPresented: $showVoiceCall) {
            VoiceCallView(conversation: $conversation)
        }
        .sheet(item: Binding(
            get: { exportFileUrl.map { IdentifiableURL(url: $0) } },
            set: { exportFileUrl = $0?.url }
        )) { item in
            ActivityShareView(activityItems: [item.url])
        }
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
            case .workspaces:
                WorkspaceListView()
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item, .content, .data, .text, .plainText, .pdf, .sourceCode, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedUrl = urls.first else { return }
                let accessing = selectedUrl.startAccessingSecurityScopedResource()
                defer {
                    if accessing { selectedUrl.stopAccessingSecurityScopedResource() }
                }
                attachedFileName = selectedUrl.lastPathComponent
                if let data = try? Data(contentsOf: selectedUrl) {
                    attachedFileData = data
                    if let img = UIImage(data: data) {
                        attachedImage = img
                    }
                }
            case .failure(let error):
                print("File import error: \(error)")
            }
        }
    }
    
    private var isTerminated: Bool {
        conversation.messages.contains { msg in
            msg.orbitResults.contains { $0.orbitName.lowercased() == "kick" || $0.orbitName.lowercased() == "terminate" }
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
    
    private func sendMessage() {
        let rawInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        var displayPrompt = rawInput
        var backendPayloadPrompt = rawInput
        
        let hasFile = attachedFileData != nil
        let fileName = attachedFileName ?? "Document"
        
        var createdAttachments: [FileAttachment] = []
        
        if displayPrompt.isEmpty && attachedImage != nil {
            displayPrompt = "Describe and analyze this image."
            backendPayloadPrompt = displayPrompt
        }
        
        if hasFile, let fileData = attachedFileData {
            let ext = (fileName as NSString).pathExtension
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(fileData.count), countStyle: .file)
            var previewText: String? = nil
            var lines: Int? = nil
            
            if let textContent = String(data: fileData, encoding: .utf8) {
                previewText = String(textContent.prefix(500))
                lines = textContent.components(separatedBy: .newlines).count
                backendPayloadPrompt += "\n\n[File Attached: \(fileName)]:\n```\n\(textContent)\n```"
            } else if let pdfDoc = PDFDocument(data: fileData) {
                var extractedPdf = ""
                for pageIdx in 0..<min(pdfDoc.pageCount, 25) {
                    if let page = pdfDoc.page(at: pageIdx), let str = page.string {
                        extractedPdf += "--- Page \(pageIdx + 1) ---\n\(str)\n"
                    }
                }
                if !extractedPdf.isEmpty {
                    previewText = String(extractedPdf.prefix(500))
                    lines = extractedPdf.components(separatedBy: .newlines).count
                    backendPayloadPrompt += "\n\n[Extracted Text from Attached PDF: \(fileName)]:\n```\n\(extractedPdf)\n```"
                }
            }
            
            let attachment = FileAttachment(
                fileName: fileName,
                fileExtension: ext,
                fileSizeFormatted: sizeStr,
                lineCount: lines,
                previewSnippet: previewText
            )
            createdAttachments.append(attachment)
        }
        
        let userPrompt = displayPrompt
        guard !displayPrompt.isEmpty || attachedImage != nil || hasFile else { return }
        
        let isFirstMessage = conversation.messages.isEmpty
        inputText = ""
        
        // Prepare image base64 if attached
        var imgBase64DataUrl: String? = nil
        if let img = attachedImage, let jpegData = img.jpegData(compressionQuality: 0.75) {
            imgBase64DataUrl = "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
        }
        
        attachedImage = nil
        attachedFileName = nil
        attachedFileData = nil
        errorMessage = nil
        
        var userMessage = Message(role: .user, content: displayPrompt, attachments: createdAttachments)
        userMessage.imageUrl = imgBase64DataUrl
        conversation.messages.append(userMessage)
        
        if isFirstMessage {
            conversation.title = String(rawInput.isEmpty ? fileName : rawInput.split(separator: " ").prefix(4).joined(separator: " "))
        }
        
        let assistantMessageId = UUID().uuidString
        let assistantPlaceholder = Message(id: assistantMessageId, role: .assistant, content: "", isStreaming: true)
        conversation.messages.append(assistantPlaceholder)
        storage.updateConversation(conversation)
        
        isStreaming = true
        LiveActivityManager.shared.startActivity(type: "reasoning", query: displayPrompt, initialStatus: "Newton is reasoning...")
        
        // Prepare payload messages
        var messagesToSend = Array(conversation.messages.dropLast())
        if let lastIdx = messagesToSend.indices.last, messagesToSend[lastIdx].role == .user {
            messagesToSend[lastIdx].content = backendPayloadPrompt
        }
        
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
            var systemPrompt = SettingsManager.singularitySystemPrompt
            if let ws = workspaceManager.activeWorkspace, !ws.customSystemPrompt.isEmpty {
                systemPrompt += "\n\n[ACTIVE PROJECT WORKSPACE: \(ws.name)]\n\(ws.customSystemPrompt)"
            }
            
            do {
                let stream = LLMService.shared.streamCompletion(
                    messages: messagesToSend,
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
                
                // Process tool calling (image generation, web search, calculator)
                let (finalContent, orbitResults, detectedImgUrl) = await OrbitEngine.shared.processOrbitsInText(
                    fullResponse,
                    userPrompt: userPrompt,
                    baseUrl: baseUrl,
                    apiKey: apiKey
                )
                
                await MainActor.run {
                    if let index = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        conversation.messages[index].content = finalContent
                        conversation.messages[index].imageUrl = detectedImgUrl
                        conversation.messages[index].orbitResults = orbitResults
                        conversation.messages[index].isStreaming = false
                    }
                    
                    storage.updateConversation(conversation)
                    Haptics.success()
                    LiveActivityManager.shared.updateActivity(status: "Thought Complete", progress: 1.0, isComplete: true)
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

public struct IdentifiableURL: Identifiable {
    public let id = UUID()
    public let url: URL
}

public struct ActivityShareView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]? = nil
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
