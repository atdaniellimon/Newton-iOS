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
    @State private var taskPrompt: String = ""
    @State private var isExecuting: Bool = false
    @State private var activeSessionId: String? = nil
    @State private var steps: [CloudChatService.RemoteStepEvent] = []
    @State private var finalAnswer: String? = nil
    @State private var errorMessage: String? = nil
    @State private var streamTask: Task<Void, Never>? = nil
    
    private let quickPrompts = [
        "Revisa los archivos con git status",
        "Ejecuta los tests del proyecto",
        "Busca cuellos de botella y optimiza",
        "Lista los archivos del proyecto"
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                NewtonTheme.bg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Mac Connection Header
                    connectionHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                // Workspaces Picker Section
                                workspacesSection
                                
                                // Workspace Chats Picker Section
                                workspaceChatsSection
                                
                                // Quick Action Chips (if idle)
                                if !isExecuting && steps.isEmpty {
                                    quickActionsSection
                                }
                                
                                // Live Execution Timeline & Terminal Logs
                                if !steps.isEmpty || isExecuting {
                                    executionTimelineSection
                                }
                                
                                // Final Agent Output
                                if let answer = finalAnswer {
                                    finalAnswerSection(answer)
                                }
                                
                                // Bottom Spacer for autoscroll
                                Color.clear
                                    .frame(height: 20)
                                    .id("bottom_anchor")
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                        .onChange(of: steps.count) { _ in
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo("bottom_anchor", anchor: .bottom)
                            }
                        }
                    }
                    
                    // Bottom Input Dispatch Bar
                    bottomDispatchBar
                }
            }
            .navigationTitle("Mac Remote Studio")
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
                    Button {
                        Task { await refreshStatusAndWorkspaces() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(NewtonTheme.sand)
                    }
                }
            }
            .onAppear {
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
    
    // MARK: - Connection Header
    private var connectionHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((status?.online == true ? Color.green : Color.red).opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Circle()
                    .fill(status?.online == true ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(status?.online == true ? "Mac Desktop Conectada" : "Mac Desktop Desconectada")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(NewtonTheme.textPrimary)
                    
                    if status?.online == true {
                        Text("Matrix Agente")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(NewtonTheme.sand.opacity(0.15))
                            .foregroundColor(NewtonTheme.sand)
                            .cornerRadius(6)
                    }
                }
                
                Text(status?.online == true
                     ? "\(workspaces.count) workspaces sincronizados · Bucle autónomo activo"
                     : "Abre la aplicación Newton en tu Mac para sincronizar")
                    .font(.system(size: 12))
                    .foregroundColor(NewtonTheme.textMuted)
            }
            
            Spacer()
            
            if isExecuting {
                Button(role: .destructive) {
                    Task { await cancelCurrentTask() }
                } label: {
                    Text("Detener")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(Color.red)
                        .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(NewtonTheme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(NewtonTheme.border, lineWidth: 1)
        )
    }
    
    // MARK: - Workspaces Picker
    private var workspacesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORKSPACE EN LA MAC")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(NewtonTheme.textMuted)
            
            if workspaces.isEmpty {
                HStack {
                    Image(systemName: "folder.badge.questionmark")
                        .foregroundColor(NewtonTheme.textMuted)
                    Text("No hay carpetas registradas. Inicia Newton en tu Mac.")
                        .font(.system(size: 13))
                        .foregroundColor(NewtonTheme.textMuted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NewtonTheme.card)
                .cornerRadius(10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(workspaces) { ws in
                            let isSelected = (selectedWorkspace?.path == ws.path)
                            Button {
                                Haptics.selection()
                                selectedWorkspace = ws
                                selectedChat = ws.chats?.first
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(isSelected ? NewtonTheme.sand : NewtonTheme.textMuted)
                                        
                                        Text(ws.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(isSelected ? NewtonTheme.textPrimary : NewtonTheme.textMuted)
                                    }
                                    
                                    if let branch = ws.branch, !branch.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.triangle.branch")
                                                .font(.system(size: 10))
                                            Text(branch)
                                                .font(.system(size: 10))
                                        }
                                        .foregroundColor(isSelected ? NewtonTheme.sand.opacity(0.8) : NewtonTheme.textMuted.opacity(0.7))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(isSelected ? NewtonTheme.sand.opacity(0.12) : NewtonTheme.card)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? NewtonTheme.sand.opacity(0.5) : NewtonTheme.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Workspace Chats Picker
    private var workspaceChatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SESIONES DE CÓDIGO (CHATS)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(NewtonTheme.textMuted)
                
                Spacer()
                
                Button {
                    Haptics.light()
                    selectedChat = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Nueva tarea")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(selectedChat == nil ? NewtonTheme.sand : NewtonTheme.textMuted)
                }
            }
            
            let chats = selectedWorkspace?.chats ?? []
            if chats.isEmpty {
                HStack {
                    Image(systemName: "text.bubble")
                        .foregroundColor(NewtonTheme.textMuted)
                    Text("No hay tareas previas. Escribe tu primera orden abajo.")
                        .font(.system(size: 12))
                        .foregroundColor(NewtonTheme.textMuted)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NewtonTheme.card)
                .cornerRadius(10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "Nueva Tarea" chip
                        Button {
                            Haptics.selection()
                            selectedChat = nil
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Nueva sesión")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(selectedChat == nil ? NewtonTheme.sand.opacity(0.18) : NewtonTheme.card)
                            .foregroundColor(selectedChat == nil ? NewtonTheme.sand : NewtonTheme.textMuted)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedChat == nil ? NewtonTheme.sand.opacity(0.6) : NewtonTheme.border, lineWidth: 1)
                            )
                        }
                        
                        ForEach(chats) { chat in
                            let isChatSelected = (selectedChat?.id == chat.id)
                            Button {
                                Haptics.selection()
                                selectedChat = chat
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(isChatSelected ? NewtonTheme.sand : NewtonTheme.textMuted)
                                    
                                    Text(chat.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(isChatSelected ? NewtonTheme.textPrimary : NewtonTheme.textMuted)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(isChatSelected ? NewtonTheme.sand.opacity(0.15) : NewtonTheme.card)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isChatSelected ? NewtonTheme.sand.opacity(0.5) : NewtonTheme.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Action Chips
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ÓRDENES RÁPIDAS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(NewtonTheme.textMuted)
            
            FlowLayout(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { p in
                    Button {
                        Haptics.light()
                        taskPrompt = p
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11))
                                .foregroundColor(NewtonTheme.sand)
                            Text(p)
                                .font(.system(size: 12))
                                .foregroundColor(NewtonTheme.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(NewtonTheme.card)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(NewtonTheme.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Execution Timeline Section
    private var executionTimelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PASOS DEL AGENTE EN LA MAC")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(NewtonTheme.textMuted)
                
                Spacer()
                
                if isExecuting {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Ejecutando...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(NewtonTheme.sand)
                    }
                }
            }
            
            VStack(spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    stepCard(step)
                }
            }
        }
    }
    
    // MARK: - Step Card
    private func stepCard(_ step: CloudChatService.RemoteStepEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: iconForTool(step.toolName ?? step.stepType))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(NewtonTheme.sand)
                    .frame(width: 20)
                
                Text(step.toolName != nil ? "Herramienta: \(step.toolName!)" : step.stepType.capitalized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(NewtonTheme.textPrimary)
                
                Spacer()
                
                Text(badgeForStep(step))
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(colorForStep(step).opacity(0.15))
                    .foregroundColor(colorForStep(step))
                    .cornerRadius(4)
            }
            
            if let msg = step.message, !msg.isEmpty {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundColor(NewtonTheme.textMuted)
            }
            
            if let stdout = step.stdout, !stdout.isEmpty {
                terminalBlock(stdout, isError: false)
            }
            
            if let stderr = step.stderr, !stderr.isEmpty {
                terminalBlock(stderr, isError: true)
            }
        }
        .padding(12)
        .background(NewtonTheme.card)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(NewtonTheme.border, lineWidth: 1)
        )
    }
    
    private func terminalBlock(_ text: String, isError: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(isError ? Color.red : NewtonTheme.forestGreen)
                .padding(8)
        }
        .background(Color.black.opacity(0.4))
        .cornerRadius(6)
    }
    
    // MARK: - Final Answer Card
    private func finalAnswerSection(_ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(NewtonTheme.sand)
                Text("SOLUCIÓN FINAL DE MATRIX")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(NewtonTheme.sand)
            }
            
            Text(answer)
                .font(.system(size: 14))
                .foregroundColor(NewtonTheme.textPrimary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NewtonTheme.card)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(NewtonTheme.sand.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Bottom Dispatch Bar
    private var bottomDispatchBar: some View {
        VStack(spacing: 8) {
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(Color.red)
                    .padding(.horizontal, 16)
            }
            
            HStack(spacing: 10) {
                TextField("Instrucción para la Mac (e.g. arregla los tests)...", text: $taskPrompt)
                    .font(.system(size: 14))
                    .foregroundColor(NewtonTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(NewtonTheme.card)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(NewtonTheme.border, lineWidth: 1)
                    )
                
                Button {
                    Haptics.medium()
                    Task { await dispatchTask() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canDispatch ? NewtonTheme.sand : NewtonTheme.textMuted)
                }
                .disabled(!canDispatch)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(NewtonTheme.bg)
        }
    }
    
    private var canDispatch: Bool {
        !taskPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedWorkspace != nil &&
        !isExecuting
    }
    
    // MARK: - Helpers & Network Actions
    
    private func refreshStatusAndWorkspaces() async {
        do {
            let st = try await CloudChatService.shared.fetchDesktopStatus()
            let wsList = try await CloudChatService.shared.fetchDesktopWorkspaces()
            DispatchQueue.main.async {
                self.status = st
                self.workspaces = wsList
                if self.selectedWorkspace == nil, let first = wsList.first {
                    self.selectedWorkspace = first
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "No se pudo sincronizar con la Mac: \(error.localizedDescription)"
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
                    if step.stepType == "task_done" {
                        self.isExecuting = false
                        self.finalAnswer = step.message
                    } else if step.stepType == "error" {
                        self.isExecuting = false
                        self.errorMessage = step.message
                    }
                    self.steps.append(step)
                }
            }
        }
    }
    
    private func dispatchTask() async {
        guard let ws = selectedWorkspace else { return }
        let promptToSend = taskPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptToSend.isEmpty else { return }
        
        isExecuting = true
        steps.removeAll()
        finalAnswer = nil
        errorMessage = nil
        taskPrompt = ""
        
        do {
            let res = try await CloudChatService.shared.dispatchDesktopCommand(
                workspacePath: ws.path,
                chatId: selectedChat?.id,
                task: promptToSend,
                model: "Singularity-Matrix"
            )
            self.activeSessionId = res.sessionId
        } catch {
            self.isExecuting = false
            self.errorMessage = "Error al enviar comando: \(error.localizedDescription)"
        }
    }
    
    private func cancelCurrentTask() async {
        do {
            try await CloudChatService.shared.cancelDesktopCommand(sessionId: activeSessionId)
            DispatchQueue.main.async {
                self.isExecuting = false
            }
        } catch {}
    }
    
    private func iconForTool(_ name: String) -> String {
        switch name.lowercased() {
        case "list_files": return "folder.badge.gearshape"
        case "read_file": return "doc.text.magnifyingglass"
        case "edit_file": return "scissors"
        case "write_file", "create_file": return "plus.square"
        case "delete_file": return "trash"
        case "grep_search": return "magnifyingglass"
        case "exec_bash": return "terminal.fill"
        case "web_search": return "globe"
        default: return "gearshape.2.fill"
        }
    }
    
    private func badgeForStep(_ step: CloudChatService.RemoteStepEvent) -> String {
        if step.stepType == "tool_start" { return "RUNNING" }
        if step.stepType == "tool_done" { return "DONE" }
        if step.stepType == "task_done" { return "SUCCESS" }
        if step.stepType == "error" { return "ERROR" }
        return "INFO"
    }
    
    private func colorForStep(_ step: CloudChatService.RemoteStepEvent) -> Color {
        if step.stepType == "tool_start" { return NewtonTheme.sand }
        if step.stepType == "tool_done" { return Color.green }
        if step.stepType == "task_done" { return Color.green }
        if step.stepType == "error" { return Color.red }
        return NewtonTheme.textMuted
    }
}

// Simple FlowLayout helper for iOS 16
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for row in rows {
            let rowH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowH + spacing
        }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let s = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += rowH + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        let maxWidth = proposal.width ?? 0
        var rows: [[LayoutSubview]] = []
        var currentRow: [LayoutSubview] = []
        var currentWidth: CGFloat = 0
        
        for subview in subviews {
            let s = subview.sizeThatFits(.unspecified)
            if currentWidth + s.width > maxWidth, !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [subview]
                currentWidth = s.width + spacing
            } else {
                currentRow.append(subview)
                currentWidth += s.width + spacing
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }
        return rows
    }
}
