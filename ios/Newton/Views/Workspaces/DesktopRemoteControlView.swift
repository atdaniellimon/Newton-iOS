//
//  DesktopRemoteControlView.swift
//  Newton
//
//  Remote Control Bridge for Newton Singularity Matrix on Mac Desktop.
//  Controls local workspaces, bash commands, file edits, and live terminal streaming from iPhone.
//

import SwiftUI

public struct DesktopRemoteControlView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var auth = AuthManager.shared
    
    @State private var status: CloudChatService.RemoteDesktopStatus? = nil
    @State private var workspaces: [CloudChatService.RemoteWorkspaceItem] = []
    @State private var selectedWorkspace: CloudChatService.RemoteWorkspaceItem? = nil
    @State private var selectedChat: CloudChatService.RemoteWorkspaceChat? = nil
    
    // Initial optional selections passed from caller
    private let initialWorkspace: CloudChatService.RemoteWorkspaceItem?
    private let initialChat: CloudChatService.RemoteWorkspaceChat?
    
    // Conversation State
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var isExecuting: Bool = false
    @State private var activeSessionId: String? = nil
    @State private var currentStepLogs: [CloudChatService.RemoteStepEvent] = []
    @State private var activeToolName: String? = nil
    @State private var errorMessage: String? = nil
    @State private var streamTask: Task<Void, Never>? = nil
    @State private var showWorkspaceSheet: Bool = false
    
    public init(
        initialWorkspace: CloudChatService.RemoteWorkspaceItem? = nil,
        initialChat: CloudChatService.RemoteWorkspaceChat? = nil
    ) {
        self.initialWorkspace = initialWorkspace
        self.initialChat = initialChat
        self._selectedWorkspace = State(initialValue: initialWorkspace)
        self._selectedChat = State(initialValue: initialChat)
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                NewtonTheme.bg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Minimal Workspace & Host Bar
                    workspaceHeaderBar
                    
                    // Main Chat Timeline
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                if messages.isEmpty && !isExecuting {
                                    emptyChatHeroView
                                        .padding(.top, 40)
                                } else {
                                    ForEach(messages) { msg in
                                        MessageBubbleView(
                                            message: msg,
                                            onRetry: nil,
                                            onEdit: nil
                                        )
                                        .id(msg.id)
                                    }
                                }
                                
                                // Live Reasoning / Tool Execution Orbit when executing
                                if isExecuting {
                                    executingLiveIndicator
                                        .id("live_executing_indicator")
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
                                    .frame(height: 10)
                                    .id("bottom_anchor")
                            }
                            .padding(.vertical, 14)
                        }
                        .onChange(of: messages.count) { _ in
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo("bottom_anchor", anchor: .bottom)
                            }
                        }
                        .onChange(of: isExecuting) { executing in
                            if executing {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    proxy.scrollTo("bottom_anchor", anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Native Bottom Input Bar (matching standard ChatView)
                    bottomInputBar
                }
            }
            .navigationTitle(selectedWorkspace?.name ?? L10n.tr("Remote Studio", es: "Remote Studio"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Haptics.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(NewtonTheme.textMuted)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            Haptics.light()
                            startNewChatSession()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(NewtonTheme.sand)
                        }
                        
                        Button {
                            showWorkspaceSheet = true
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(NewtonTheme.sand)
                        }
                    }
                }
            }
            .sheet(isPresented: $showWorkspaceSheet) {
                workspacePickerSheet
            }
            .onAppear {
                if let initChat = initialChat {
                    loadChatSession(initChat)
                }
                Task {
                    await refreshStatusAndWorkspaces()
                    startListeningToRemoteStream()
                }
            }
            .onDisappear {
                streamTask?.cancel()
            }
        }
    }
    
    // MARK: - Workspace & Host Header Bar
    private var workspaceHeaderBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status?.online == true ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(status?.online == true 
                 ? L10n.tr("Connected to host", es: "Conectado al host") 
                 : L10n.tr("Disconnected from host", es: "Desconectado del host"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(NewtonTheme.textSecondary)
                .lineLimit(1)
            
            Text("•")
                .foregroundColor(NewtonTheme.textMuted)
            
            Button {
                showWorkspaceSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundColor(NewtonTheme.sand)
                    
                    Text(selectedWorkspace?.name ?? L10n.tr("Select folder", es: "Seleccionar carpeta"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(NewtonTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if let b = selectedWorkspace?.branch, !b.isEmpty {
                        Text("(\(b))")
                            .font(.system(size: 10))
                            .foregroundColor(NewtonTheme.textMuted)
                            .lineLimit(1)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(NewtonTheme.textMuted)
                }
            }
            .layoutPriority(1)
            
            Spacer(minLength: 4)
            
            if isExecuting {
                Button(role: .destructive) {
                    Task { await cancelCurrentTask() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9))
                        Text(L10n.tr("Stop", es: "Detener"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.18))
                    .foregroundColor(Color.red)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(NewtonTheme.card.opacity(0.85))
        .overlay(
            Divider()
                .background(NewtonTheme.border),
            alignment: .bottom
        )
    }
    
    // MARK: - Empty Chat Hero View
    private var emptyChatHeroView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(NewtonTheme.sand.opacity(0.12))
                    .frame(width: 72, height: 72)
                
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 32))
                    .foregroundColor(NewtonTheme.sand)
            }
            
            VStack(spacing: 6) {
                Text(selectedWorkspace != nil ? selectedWorkspace!.name : L10n.tr("Remote Studio", es: "Remote Studio"))
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(NewtonTheme.textPrimary)
                
                Text(selectedWorkspace != nil
                     ? L10n.tr("Remote control active at \(selectedWorkspace!.path).\nAny command sent will execute on the host.",
                               es: "Control remoto activo en \(selectedWorkspace!.path).\nCualquier orden que envíes se ejecutará en el host.")
                     : L10n.tr("Connecting to host...", es: "Conectando al host..."))
                    .font(.system(size: 13))
                    .foregroundColor(NewtonTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Quick prompt suggestion pills
            VStack(spacing: 8) {
                ForEach([
                    L10n.tr("Check recent changes with git status", es: "Revisa los cambios recientes con git status"),
                    L10n.tr("List folder structure and files", es: "Lista la estructura de carpetas y archivos"),
                    L10n.tr("Run project tests in the terminal", es: "Ejecuta los tests del proyecto en la terminal")
                ], id: \.self) { prompt in
                    Button {
                        Haptics.light()
                        inputText = prompt
                        sendMessage()
                    } label: {
                        HStack {
                            Image(systemName: "sparkle")
                                .font(.system(size: 12))
                                .foregroundColor(NewtonTheme.sand)
                            Text(prompt)
                                .font(.system(size: 13))
                                .foregroundColor(NewtonTheme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(NewtonTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(NewtonTheme.border, lineWidth: 0.8)
                        )
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Live Reasoning & Tools Indicator
    private var executingLiveIndicator: some View {
        HStack(alignment: .top, spacing: 12) {
            ThinkingOrbView(size: 30, style: .globe)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(activeToolName != nil 
                         ? "\(L10n.tr("Executing tool", es: "Ejecutando herramienta")): \(activeToolName!)" 
                         : L10n.tr("Matrix is reasoning on host...", es: "Matrix está razonando en el host..."))
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(NewtonTheme.sand)
                    
                    ProgressView()
                        .scaleEffect(0.6)
                }
                
                // Collapsible inspection pill of live tool steps
                if !currentStepLogs.isEmpty {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(currentStepLogs.suffix(4).enumerated()), id: \.offset) { _, step in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(step.stepType == "tool_done" ? Color.green : NewtonTheme.sand)
                                        .frame(width: 5, height: 5)
                                    Text(step.message ?? step.stepType)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(NewtonTheme.textMuted)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        Text("\(currentStepLogs.count) \(L10n.tr("actions in terminal / files", es: "acciones en terminal / archivos"))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(NewtonTheme.textSecondary)
                    }
                    .accentColor(NewtonTheme.sand)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(NewtonTheme.card.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NewtonTheme.sand.opacity(0.3), lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Bottom Input Bar
    private var bottomInputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(NewtonTheme.border)
            
            HStack(spacing: 10) {
                // Text Input
                TextField(L10n.tr("Write an instruction for the host...", es: "Escribe una instrucción para el host..."), text: $inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(NewtonTheme.textPrimary)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(NewtonTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(NewtonTheme.border, lineWidth: 1)
                    )
                
                // Send Button
                Button {
                    Haptics.medium()
                    sendMessage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? NewtonTheme.sand : NewtonTheme.card)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(canSend ? NewtonTheme.bg : NewtonTheme.textMuted)
                    }
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(NewtonTheme.bg)
        }
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedWorkspace != nil &&
        !isExecuting
    }
    
    // MARK: - Workspace & Chat Picker Sheet
    private var workspacePickerSheet: some View {
        NavigationView {
            ZStack {
                NewtonTheme.bg.ignoresSafeArea()
                
                List {
                    Section(header: Text(L10n.tr("WORKSPACES ON HOST", es: "WORKSPACES EN EL HOST")).foregroundColor(NewtonTheme.textMuted)) {
                        if workspaces.isEmpty {
                            Text(L10n.tr("No workspaces reported by host.", es: "No hay workspaces reportados por el host."))
                                .font(.system(size: 13))
                                .foregroundColor(NewtonTheme.textMuted)
                        } else {
                            ForEach(workspaces) { ws in
                                let isWsSelected = selectedWorkspace?.path == ws.path
                                Button {
                                    Haptics.selection()
                                    selectWorkspace(ws)
                                    showWorkspaceSheet = false
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "folder.fill")
                                                    .foregroundColor(isWsSelected ? NewtonTheme.sand : NewtonTheme.textMuted)
                                                Text(ws.name)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(NewtonTheme.textPrimary)
                                            }
                                            
                                            Text(ws.path)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(NewtonTheme.textMuted)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        if isWsSelected {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(NewtonTheme.sand)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    if let ws = selectedWorkspace, let chats = ws.chats, !chats.isEmpty {
                        Section(header: Text(L10n.tr("CHATS IN \(ws.name)", es: "CHATS EN \(ws.name)")).foregroundColor(NewtonTheme.textMuted)) {
                            ForEach(chats) { chat in
                                let isChatSelected = selectedChat?.id == chat.id
                                Button {
                                    Haptics.selection()
                                    loadChatSession(chat)
                                    showWorkspaceSheet = false
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(chat.title)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(isChatSelected ? NewtonTheme.sand : NewtonTheme.textPrimary)
                                                .lineLimit(1)
                                            
                                            if let msgCount = chat.messages?.count, msgCount > 0 {
                                                Text("\(msgCount) \(L10n.tr("messages", es: "mensajes"))")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(NewtonTheme.textMuted)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if isChatSelected {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(NewtonTheme.sand)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle(L10n.tr("Select Workspace", es: "Seleccionar Workspace"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("Close", es: "Cerrar")) {
                        showWorkspaceSheet = false
                    }
                    .foregroundColor(NewtonTheme.sand)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func selectWorkspace(_ ws: CloudChatService.RemoteWorkspaceItem) {
        selectedWorkspace = ws
        if let firstChat = ws.chats?.first {
            loadChatSession(firstChat)
        } else {
            startNewChatSession()
        }
    }
    
    private func loadChatSession(_ chat: CloudChatService.RemoteWorkspaceChat) {
        selectedChat = chat
        errorMessage = nil
        
        // Populate messages array from chat history, filtering out internal agent loop tool steps
        var converted: [Message] = []
        if let rawMessages = chat.messages {
            for m in rawMessages {
                let roleStr = m["role"] ?? "assistant"
                var content = m["content"] ?? ""
                
                // If it's a user turn that was actually an internal tool result, skip it from normal user bubbles
                if roleStr == "user" && content.hasPrefix("[TOOL_RESULT:") {
                    continue
                }
                
                // If it's an assistant turn that only executed a tool_call without conversational text, skip it
                if roleStr == "assistant" && content.contains("<tool_call>") {
                    // Extract any conversational text outside of <tool_call>...</tool_call>
                    let cleaned = content.replacingOccurrences(of: "(?s)<tool_call>.*?</tool_call>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.isEmpty {
                        continue
                    }
                    content = cleaned
                }
                
                // Extract thinking tags if present
                var thinkingContent: String? = nil
                if let thinkRange = content.range(of: "(?s)<think(?:ing)?>.*?</think(?:ing)?>", options: .regularExpression) {
                    let fullTag = String(content[thinkRange])
                    let stripped = fullTag.replacingOccurrences(of: "<think>", with: "")
                        .replacingOccurrences(of: "</think>", with: "")
                        .replacingOccurrences(of: "<thinking>", with: "")
                        .replacingOccurrences(of: "</thinking>", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    thinkingContent = stripped
                    content = content.replacingCharacters(in: thinkRange, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                if !content.isEmpty {
                    converted.append(Message(
                        id: UUID().uuidString,
                        role: roleStr == "user" ? .user : .assistant,
                        content: content,
                        thinkingContent: thinkingContent
                    ))
                }
            }
        }
        messages = converted
    }
    
    private func startNewChatSession() {
        selectedChat = nil
        messages.removeAll()
        errorMessage = nil
        currentStepLogs.removeAll()
    }
    
    private func sendMessage() {
        guard let ws = selectedWorkspace else { return }
        let promptToSend = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptToSend.isEmpty else { return }
        
        // 1. Append user message bubble to chat
        let userMsg = Message(
            id: UUID().uuidString,
            role: .user,
            content: promptToSend
        )
        messages.append(userMsg)
        
        inputText = ""
        isExecuting = true
        activeToolName = nil
        currentStepLogs.removeAll()
        errorMessage = nil
        
        Task {
            do {
                let res = try await CloudChatService.shared.dispatchDesktopCommand(
                    workspacePath: ws.path,
                    chatId: selectedChat?.id,
                    task: promptToSend,
                    model: "Singularity-Matrix"
                )
                self.activeSessionId = res.sessionId
                
                // If this was a new task, update selectedChat ID
                if selectedChat == nil, let newCid = res.chatId {
                    self.selectedChat = CloudChatService.RemoteWorkspaceChat(
                        id: newCid,
                        title: promptToSend,
                        created_at: Date().timeIntervalSince1970,
                        messages: nil
                    )
                }
            } catch {
                self.isExecuting = false
                self.errorMessage = "\(L10n.tr("Error sending to host", es: "Error al enviar al host")): \(error.localizedDescription)"
            }
        }
    }
    
    private func cancelCurrentTask() async {
        do {
            try await CloudChatService.shared.cancelDesktopCommand(sessionId: activeSessionId)
            DispatchQueue.main.async {
                self.isExecuting = false
                self.activeToolName = nil
            }
        } catch {}
    }
    
    private func refreshStatusAndWorkspaces() async {
        do {
            let st = try await CloudChatService.shared.fetchDesktopStatus()
            let wsList = try await CloudChatService.shared.fetchDesktopWorkspaces()
            DispatchQueue.main.async {
                self.status = st
                self.workspaces = wsList
                
                // If a workspace was already selected, update its reference with latest chats
                if let currentWs = self.selectedWorkspace {
                    if let updated = wsList.first(where: { $0.path == currentWs.path }) {
                        self.selectedWorkspace = updated
                    }
                } else if let first = wsList.first {
                    self.selectWorkspace(first)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "\(L10n.tr("Could not sync with host", es: "No se pudo sincronizar con el host")): \(error.localizedDescription)"
            }
        }
    }
    
    private func startListeningToRemoteStream() {
        streamTask?.cancel()
        streamTask = Task {
            let stream = CloudChatService.shared.streamDesktopSession()
            for await step in stream {
                guard !Task.isCancelled else { break }
                DispatchQueue.main.async {
                    if step.stepType == "tool_start" {
                        self.activeToolName = step.toolName
                    } else if step.stepType == "tool_done" {
                        self.activeToolName = nil
                    } else if step.stepType == "task_done" {
                        self.isExecuting = false
                        self.activeToolName = nil
                        
                        // Append final assistant response as a normal bubble
                        if let rawAnswer = step.message, !rawAnswer.isEmpty {
                            var answer = rawAnswer.replacingOccurrences(of: "(?s)<tool_call>.*?</tool_call>", with: "", options: .regularExpression)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            var thinkingContent: String? = nil
                            if let thinkRange = answer.range(of: "(?s)<think(?:ing)?>.*?</think(?:ing)?>", options: .regularExpression) {
                                let fullTag = String(answer[thinkRange])
                                thinkingContent = fullTag.replacingOccurrences(of: "<think>", with: "")
                                    .replacingOccurrences(of: "</think>", with: "")
                                    .replacingOccurrences(of: "<thinking>", with: "")
                                    .replacingOccurrences(of: "</thinking>", with: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                answer = answer.replacingCharacters(in: thinkRange, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
                            if !answer.isEmpty {
                                let assistantMsg = Message(
                                    id: UUID().uuidString,
                                    role: .assistant,
                                    content: answer,
                                    thinkingContent: thinkingContent
                                )
                                self.messages.append(assistantMsg)
                            }
                        }
                    } else if step.stepType == "error" {
                        self.isExecuting = false
                        self.activeToolName = nil
                        self.errorMessage = step.message
                    }
                    self.currentStepLogs.append(step)
                }
            }
        }
    }
}
