//
//  MacChatView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  1:1 Faithful replication of the Newton Web desktop interface with full Light & Dark mode.
//

import SwiftUI
import AppKit
import PDFKit

public struct MacChatView: View {
    @Binding public var conversation: Conversation
    @Binding public var isSidebarCollapsed: Bool
    
    @StateObject private var storage = StorageManager.shared
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var inputText: String = ""
    @State private var isStreaming: Bool = false
    @State private var streamTask: Task<Void, Never>? = nil
    @State private var showModelSheet: Bool = false
    @State private var attachedFileName: String? = nil
    @State private var attachedFileData: Data? = nil
    
    public init(conversation: Binding<Conversation>, isSidebarCollapsed: Binding<Bool> = .constant(false)) {
        self._conversation = conversation
        self._isSidebarCollapsed = isSidebarCollapsed
    }
    
    private var isDark: Bool { colorScheme == .dark }
    
    public var body: some View {
        ZStack {
            // Background Kinetic 3D Wave Grid (120Hz Canvas matching iOS)
            MacHero3DCanvasView(isThinking: isStreaming)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header Bar: Model Selector Pill
                topHeaderBar
                
                // Main Content: Hero Welcome OR Messages ScrollView
                if conversation.messages.isEmpty {
                    heroWelcomeScreen
                } else {
                    messagesScrollView
                }
                
                // Bottom Input Area OR Terminated Banner
                if isTerminated {
                    terminatedBanner
                } else {
                    MacMessageInputBar(
                        text: $inputText,
                        isStreaming: isStreaming,
                        onSend: sendMessage,
                        onStop: stopStreaming,
                        onAttachFile: openFilePicker
                    )
                    .padding(.bottom, 8)
                }
            }
        }
        .popover(isPresented: $showModelSheet) {
            MacModelPickerPopover()
        }
    }
    
    private var isTerminated: Bool {
        conversation.messages.contains { msg in
            msg.orbitResults.contains { $0.orbitName.lowercased() == "kick" || $0.orbitName.lowercased() == "terminate" }
        }
    }
    
    private var modelDisplayName: String {
        if settings.currentModelId.contains("singularity") {
            return "Singularity"
        } else if settings.currentModelId.contains("sonnet") {
            return "Newton I"
        } else if settings.currentModelId.contains("r1") {
            return "Newton R1"
        } else if settings.currentModelId.contains("gpt-4o") {
            return "Newton Omni"
        }
        return "Singularity"
    }
    
    @ViewBuilder
    private var topHeaderBar: some View {
        HStack(spacing: 10) {
            // Traffic Light spacer when sidebar is collapsed
            if isSidebarCollapsed {
                Color.clear
                    .frame(width: 68, height: 28)
                
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isSidebarCollapsed = false
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.84) : Color(red: 0.40, green: 0.45, blue: 0.52))
                        .frame(width: 28, height: 28)
                        .background(isDark ? Color(red: 0.16, green: 0.19, blue: 0.25) : Color(red: 0.90, green: 0.92, blue: 0.96))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Show Sidebar")
            }
            
            // Model Pill matching Web screenshot
            Button(action: {
                showModelSheet.toggle()
            }) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(conversation.isGhost ? Color(red: 0.75, green: 0.55, blue: 0.95) : (isDark ? NewtonTheme.sand : Color(red: 0.65, green: 0.70, blue: 0.76)))
                        .frame(width: 7, height: 7)
                    
                    Text(conversation.isGhost ? "Ghost Session" : modelDisplayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDark ? Color(red: 0.92, green: 0.94, blue: 0.98) : Color(red: 0.12, green: 0.15, blue: 0.20))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(isDark ? Color(red: 0.60, green: 0.65, blue: 0.72) : Color(red: 0.55, green: 0.60, blue: 0.68))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isDark ? Color(red: 0.14, green: 0.17, blue: 0.22) : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isDark ? Color(red: 0.24, green: 0.28, blue: 0.36) : Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(isDark ? 0.20 : 0.02), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            
            MacWorkspaceSelector()
            
            if conversation.isGhost {
                Button(action: {
                    conversation.messages.removeAll()
                    storage.deleteConversation(id: conversation.id)
                }) {
                    Text("Vanish")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 0.92, green: 0.35, blue: 0.30))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isDark ? Color(red: 0.14, green: 0.17, blue: 0.22) : Color.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.92, green: 0.35, blue: 0.30).opacity(0.4), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.horizontal, isSidebarCollapsed ? 12 : 24)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .frame(height: 52)
    }
    
    @ViewBuilder
    private var heroWelcomeScreen: some View {
        Spacer()
        
        VStack(spacing: 20) {
            // Hand-Drawn Newton Lightbulb Logo with "Newton" text below
            VStack(spacing: 6) {
                if let img = NSImage(named: "NewtonLogo") ?? NSImage(contentsOfFile: Bundle.main.bundlePath + "/Contents/Resources/NewtonLogo.png") {
                    Image(nsImage: img)
                        .resizable()
                        .renderingMode(isDark ? .template : .original)
                        .scaledToFit()
                        .foregroundColor(isDark ? NewtonTheme.sand : nil)
                        .frame(width: 58, height: 58)
                } else {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 42, weight: .light))
                        .foregroundColor(isDark ? NewtonTheme.sand : Color(red: 0.10, green: 0.13, blue: 0.18))
                }
                
                Text("Newton")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(isDark ? Color(red: 0.92, green: 0.94, blue: 0.98) : Color(red: 0.08, green: 0.11, blue: 0.16))
            }
            
            // Hero Serif Headline matching screenshot
            Text("What will you discover today?")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundColor(isDark ? Color(red: 0.92, green: 0.94, blue: 0.98) : Color(red: 0.08, green: 0.11, blue: 0.16))
                .padding(.bottom, 8)
            
            // 2x2 Suggestion Cards Grid matching screenshot 1:1
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    suggestionCard(
                        icon: "lightbulb",
                        title: "Explain a Concept",
                        subtitle: "Quantum computing basics",
                        prompt: "Explain quantum computing basics with an intuitive real-world analogy."
                    )
                    
                    suggestionCard(
                        icon: "terminal",
                        title: "Code & Debug",
                        subtitle: "Python web scraper script",
                        prompt: "Write a high-performance Python script for web scraping with async request handling."
                    )
                }
                
                HStack(spacing: 14) {
                    suggestionCard(
                        icon: "doc.text",
                        title: "Write & Draft",
                        subtitle: "Technical architecture spec",
                        prompt: "Draft a comprehensive technical architecture specification document for a cloud platform."
                    )
                    
                    suggestionCard(
                        icon: "sparkles",
                        title: "Analyze & Compare",
                        subtitle: "Claude 3.5 vs DeepSeek R1",
                        prompt: "What are the core technical and architectural differences between Claude 3.5 Sonnet and DeepSeek R1?"
                    )
                }
            }
            .frame(maxWidth: 580)
        }
        .padding(.horizontal, 40)
        
        Spacer()
    }
    
    @ViewBuilder
    private func suggestionCard(icon: String, title: String, subtitle: String, prompt: String) -> some View {
        Button(action: {
            inputText = prompt
            sendMessage()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(isDark ? NewtonTheme.sand : Color(red: 0.35, green: 0.40, blue: 0.48))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isDark ? Color(red: 0.92, green: 0.94, blue: 0.98) : Color(red: 0.08, green: 0.11, blue: 0.16))
                    
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(isDark ? Color(red: 0.60, green: 0.65, blue: 0.72) : Color(red: 0.50, green: 0.55, blue: 0.62))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isDark ? Color(red: 0.14, green: 0.17, blue: 0.22) : Color.white.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isDark ? Color(red: 0.24, green: 0.28, blue: 0.36) : Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.20 : 0.02), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(conversation.messages) { message in
                        MacMessageBubbleView(message: message, onRetry: {
                            retryMessage(message)
                        })
                        .id(message.id)
                    }
                    
                    Color.clear
                        .frame(height: 1)
                        .id("mac_bottom_anchor")
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 20)
            }
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                proxy.scrollTo("mac_bottom_anchor", anchor: .bottom)
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(NewtonTheme.sand)
                                .frame(width: 32, height: 32)
                                .background(isDark ? Color(red: 0.16, green: 0.20, blue: 0.26) : Color.white.opacity(0.95))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                                .overlay(
                                    Circle()
                                        .stroke(isDark ? Color(red: 0.24, green: 0.28, blue: 0.36) : Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 32)
                        .padding(.bottom, 12)
                    }
                }
            )
            .onChange(of: conversation.messages.count) { _ in
                withAnimation {
                    proxy.scrollTo("mac_bottom_anchor", anchor: .bottom)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo("mac_bottom_anchor", anchor: .bottom)
                }
            }
        }
    }
    
    @ViewBuilder
    private var terminatedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13))
                .foregroundColor(NewtonTheme.coralRed)
            Text("Session ended by Newton.")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.82) : Color(red: 0.45, green: 0.50, blue: 0.58))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 24)
        .background(isDark ? Color(red: 0.14, green: 0.17, blue: 0.22) : Color.white)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(NewtonTheme.coralRed.opacity(0.4), lineWidth: 1)
        )
        .padding(.bottom, 14)
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item, .content, .data, .text, .plainText, .pdf, .sourceCode, .image]
        
        if panel.runModal() == .OK, let selectedUrl = panel.url {
            attachedFileName = selectedUrl.lastPathComponent
            if let data = try? Data(contentsOf: selectedUrl) {
                attachedFileData = data
            }
        }
    }
    
    private func retryMessage(_ msg: Message) {
        if let idx = conversation.messages.firstIndex(where: { $0.id == msg.id }) {
            let previousPrompt = conversation.messages.prefix(upTo: idx).last(where: { $0.role == .user })?.content ?? ""
            conversation.messages = Array(conversation.messages.prefix(upTo: idx))
            inputText = previousPrompt
            sendMessage()
        }
    }
    
    private func sendMessage() {
        let rawInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        var backendPayloadPrompt = rawInput
        var attachmentsList: [FileAttachment] = []
        
        let hasFile = attachedFileData != nil
        let fileName = attachedFileName ?? "Document"
        
        if hasFile, let fileData = attachedFileData {
            var extractedSnippet: String? = nil
            var lineCount: Int? = nil
            
            if let textContent = String(data: fileData, encoding: .utf8) {
                lineCount = textContent.components(separatedBy: "\n").count
                let previewLines = textContent.components(separatedBy: "\n").prefix(5).joined(separator: "\n")
                extractedSnippet = previewLines.isEmpty ? nil : previewLines
                backendPayloadPrompt += "\n\n[File Attached: \(fileName)]:\n```\n\(textContent)\n```"
            } else if let pdfDoc = PDFDocument(data: fileData) {
                var extractedPdf = ""
                for pageIdx in 0..<min(pdfDoc.pageCount, 25) {
                    if let page = pdfDoc.page(at: pageIdx), let str = page.string {
                        extractedPdf += "--- Page \(pageIdx + 1) ---\n\(str)\n"
                    }
                }
                if !extractedPdf.isEmpty {
                    backendPayloadPrompt += "\n\n[Extracted Text from Attached PDF: \(fileName)]:\n```\n\(extractedPdf)\n```"
                    let previewLines = extractedPdf.components(separatedBy: "\n").prefix(5).joined(separator: "\n")
                    extractedSnippet = previewLines.isEmpty ? nil : previewLines
                }
            }
            
            let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(fileData.count), countStyle: .file)
            let attachment = FileAttachment(
                id: UUID().uuidString,
                fileName: fileName,
                fileExtension: (fileName as NSString).pathExtension,
                fileSizeFormatted: formattedSize,
                lineCount: lineCount,
                previewSnippet: extractedSnippet
            )
            attachmentsList.append(attachment)
        }
        
        guard !rawInput.isEmpty || !attachmentsList.isEmpty else { return }
        
        let isFirstMessage = conversation.messages.isEmpty
        inputText = ""
        attachedFileName = nil
        attachedFileData = nil
        
        let userMessage = Message(
            role: .user,
            content: rawInput,
            attachments: attachmentsList
        )
        conversation.messages.append(userMessage)
        
        if isFirstMessage {
            conversation.title = String(rawInput.isEmpty ? fileName : rawInput.split(separator: " ").prefix(4).joined(separator: " "))
        }
        
        let assistantMessageId = UUID().uuidString
        let assistantPlaceholder = Message(id: assistantMessageId, role: .assistant, content: "", isStreaming: true)
        conversation.messages.append(assistantPlaceholder)
        storage.updateConversation(conversation)
        
        isStreaming = true
        
        var messagesToSend = Array(conversation.messages.dropLast())
        if let lastIdx = messagesToSend.indices.last, messagesToSend[lastIdx].role == .user {
            messagesToSend[lastIdx].content = backendPayloadPrompt
        }
        
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
            var systemPrompt = SettingsManager.singularitySystemPrompt
            
            // Append active workspace custom system prompt if available
            if let activeWs = WorkspaceManager.shared.activeWorkspace,
               !activeWs.customSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                systemPrompt += "\n\n[ACTIVE PROJECT WORKSPACE: \(activeWs.name)]\n\(activeWs.customSystemPrompt)"
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
                    if Task.isCancelled { break }
                    
                    var cleanToken = token
                    
                    if cleanToken.contains("<think>") {
                        isInsideThinkingTag = true
                        cleanToken = cleanToken.replacingOccurrences(of: "<think>", with: "")
                    }
                    
                    if isInsideThinkingTag {
                        if cleanToken.contains("</think>") {
                            let parts = cleanToken.components(separatedBy: "</think>")
                            currentThinking += parts.first ?? ""
                            isInsideThinkingTag = false
                            if parts.count > 1 {
                                fullResponse += parts[1]
                            }
                        } else {
                            currentThinking += cleanToken
                        }
                    } else {
                        fullResponse += cleanToken
                    }
                    
                    if let idx = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        conversation.messages[idx].content = fullResponse
                        conversation.messages[idx].thinkingContent = currentThinking.isEmpty ? nil : currentThinking
                    }
                }
                
                // Process Orbits
                let orbitResults = await OrbitEngine.shared.processOrbitsInText(
                    fullResponse,
                    userPrompt: rawInput,
                    baseUrl: baseUrl,
                    apiKey: apiKey
                )
                if let idx = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    conversation.messages[idx].content = orbitResults.processedText
                    conversation.messages[idx].orbitResults = orbitResults.results
                    conversation.messages[idx].imageUrl = orbitResults.imageUrl
                    conversation.messages[idx].isStreaming = false
                    storage.updateConversation(conversation)
                    
                    // Notify if unfocused
                    NotificationService.shared.sendCompletionNotification(
                        title: "Newton Singularity",
                        body: orbitResults.processedText
                    )
                }
            } catch {
                if let idx = conversation.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    conversation.messages[idx].content = "⚠️ Error: \(error.localizedDescription)"
                    conversation.messages[idx].isStreaming = false
                    storage.updateConversation(conversation)
                }
            }
            
            isStreaming = false
        }
    }
    
    private func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let lastIdx = conversation.messages.indices.last {
            conversation.messages[lastIdx].isStreaming = false
            storage.updateConversation(conversation)
        }
    }
}

public struct MacModelPickerPopover: View {
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active Engine")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isDark ? Color(red: 0.60, green: 0.65, blue: 0.72) : Color(red: 0.50, green: 0.55, blue: 0.62))
                .padding(.horizontal, 8)
                .padding(.top, 6)
            
            Button(action: {
                settings.currentModelId = "newton-singularity"
            }) {
                modelRow(name: "Singularity", desc: "Newton Singularity Model Core", isSelected: true)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .frame(width: 240)
        .background(isDark ? Color(red: 0.14, green: 0.17, blue: 0.22) : Color.white)
    }
    
    @ViewBuilder
    private func modelRow(name: String, desc: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isSelected ? NewtonTheme.sand : (isDark ? Color(red: 0.30, green: 0.35, blue: 0.42) : Color(red: 0.75, green: 0.78, blue: 0.84)))
                .frame(width: 7, height: 7)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isDark ? Color(red: 0.92, green: 0.94, blue: 0.98) : Color(red: 0.10, green: 0.13, blue: 0.18))
                
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(isDark ? Color(red: 0.60, green: 0.65, blue: 0.72) : Color(red: 0.55, green: 0.60, blue: 0.68))
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(NewtonTheme.sand)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? (isDark ? Color(red: 0.20, green: 0.25, blue: 0.32) : Color(red: 0.95, green: 0.96, blue: 0.98)) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
