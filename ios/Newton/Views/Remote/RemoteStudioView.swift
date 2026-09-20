//
//  RemoteStudioView.swift
//  Newton
//
//  Newton Remote Studio — Live Desktop Host Control & Workspaces.
//  Connects directly with Newton Desktop Host (Mac/PC) via api.newton.daniellimon.uk:
//  - Live Host Presence Status (/nwtn/desktop/status) with rapid heartbeat
//  - Host Workspaces Explorer (/nwtn/desktop/workspaces)
//  - Remote Code Task Dispatcher (/nwtn/desktop/dispatch)
//  - Live Streaming Console Logs (/nwtn/desktop/session/stream)
//

import SwiftUI

public typealias RemoteDesktopStatus = CloudChatService.RemoteDesktopStatus
public typealias RemoteWorkspaceItem = CloudChatService.RemoteWorkspaceItem
public typealias RemoteStepEvent = CloudChatService.RemoteStepEvent
public typealias RemoteWorkspaceChat = CloudChatService.RemoteWorkspaceChat

public struct RemoteStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cloudService = CloudChatService.shared
    @ObservedObject var auth = AuthManager.shared
    
    @State private var desktopStatus: RemoteDesktopStatus? = nil
    @State private var workspaces: [RemoteWorkspaceItem] = []
    @State private var selectedWorkspace: RemoteWorkspaceItem? = nil
    @State private var selectedChatId: String? = nil
    
    @State private var taskPrompt: String = ""
    @State private var isExecuting: Bool = false
    @State private var steps: [RemoteStepEvent] = []
    @State private var finalAnswer: String? = nil
    @State private var errorMessage: String? = nil
    
    @State private var heartbeatTimer: Timer? = nil
    @State private var streamTask: Task<Void, Never>? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                NewtonTheme.bg
                    .ignoresSafeArea()
                
                Hero3DCanvasView()
                    .opacity(0.35)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                // 1. Host Presence Card
                                hostPresenceCard
                                
                                // 2. Workspaces on Mac
                                hostWorkspacesSection
                                
                                // 3. Workspace Code Sessions / Chats
                                if let ws = selectedWorkspace, let chats = ws.chats, !chats.isEmpty {
                                    workspaceChatsSection(chats: chats)
                                }
                                
                                // 4. Live Session Output / Agent Steps
                                if !steps.isEmpty || isExecuting || finalAnswer != nil {
                                    sessionOutputSection(scrollProxy: scrollProxy)
                                }
                                
                                Spacer(minLength: 24)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        }
                    }
                    
                    // Bottom Task Input Bar
                    bottomDispatchBar
                }
            }
            .navigationTitle("Remote Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        stopHeartbeat()
                        streamTask?.cancel()
                        dismiss()
                    }
                    .foregroundColor(NewtonTheme.sand)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshAll) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(NewtonTheme.sand)
                    }
                }
            }
            .onAppear {
                refreshAll()
                startHeartbeat()
            }
            .onDisappear {
                stopHeartbeat()
                streamTask?.cancel()
            }
        }
    }
    
    // MARK: - 1. Host Presence Card
    
    private var hostPresenceCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((desktopStatus?.online == true) ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: (desktopStatus?.online == true) ? "desktopcomputer" : "desktopcomputer.trianglebadge.exclamationmark")
                    .font(.system(size: 20))
                    .foregroundColor((desktopStatus?.online == true) ? .green : .red)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill((desktopStatus?.online == true) ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text((desktopStatus?.online == true) ? "Mac Host Conectado" : "Mac Host Desconectado")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(NewtonTheme.textPrimary)
                }
                
                if desktopStatus?.online == true {
                    Text("\(workspaces.count) workspace(s) sincronizados")
                        .font(.system(size: 12))
                        .foregroundColor(NewtonTheme.textSecondary)
                } else {
                    Text("Abre Newton en tu Mac para controlar tus proyectos")
                        .font(.system(size: 12))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
            }
            
            Spacer()
            
            if isExecuting {
                Button(action: cancelRemoteTask) {
                    Text("Detener")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(NewtonTheme.coralRed)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(NewtonTheme.coralRed.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(NewtonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NewtonTheme.border, lineWidth: 0.8)
        )
    }
    
    // MARK: - 2. Host Workspaces Section
    
    private var hostWorkspacesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORKSPACES EN LA MAC")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(NewtonTheme.textMuted)
                .padding(.horizontal, 4)
            
            if workspaces.isEmpty {
                HStack {
                    Image(systemName: "folder.badge.questionmark")
                        .foregroundColor(NewtonTheme.textMuted)
                    Text("No hay carpetas registradas en Newton Mac")
                        .font(.system(size: 13))
                        .foregroundColor(NewtonTheme.textSecondary)
                    Spacer()
                }
                .padding(14)
                .background(NewtonTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NewtonTheme.border, lineWidth: 0.8)
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(workspaces, id: \.path) { ws in
                            let isSelected = selectedWorkspace?.path == ws.path
                            Button(action: {
                                Haptics.selection()
                                selectedWorkspace = ws
                                selectedChatId = ws.chats?.first?.id
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(isSelected ? NewtonTheme.sand : NewtonTheme.textSecondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ws.name)
                                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                            .foregroundColor(isSelected ? NewtonTheme.textPrimary : NewtonTheme.textSecondary)
                                        
                                        if let b = ws.branch, !b.isEmpty {
                                            Text(b)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(NewtonTheme.sand.opacity(0.8))
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? NewtonTheme.sand.opacity(0.12) : NewtonTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(isSelected ? NewtonTheme.sand.opacity(0.4) : NewtonTheme.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 3. Workspace Chats Section
    
    private func workspaceChatsSection(chats: [RemoteWorkspaceChat]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SESIONES DE CÓDIGO (CHATS)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(NewtonTheme.textMuted)
                
                Spacer()
                
                Button(action: {
                    Haptics.light()
                    selectedChatId = nil
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Nueva tarea")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(selectedChatId == nil ? NewtonTheme.sand : NewtonTheme.textSecondary)
                }
            }
            .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chats, id: \.id) { chat in
                        let isSelected = selectedChatId == chat.id
                        Button(action: {
                            Haptics.selection()
                            selectedChatId = chat.id
                        }) {
                            Text(chat.title)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? NewtonTheme.textPrimary : NewtonTheme.textSecondary)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected ? NewtonTheme.sand.opacity(0.12) : NewtonTheme.card)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? NewtonTheme.sand.opacity(0.4) : NewtonTheme.border, lineWidth: 0.8)
                                )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 4. Live Session Output Section
    
    private func sessionOutputSection(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LOG EN VIVO DEL HOST")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(NewtonTheme.textMuted)
                
                Spacer()
                
                if isExecuting {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Ejecutando...")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(NewtonTheme.sand)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: iconForStep(step.stepType))
                            .font(.system(size: 11))
                            .foregroundColor(colorForStep(step.stepType))
                            .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if let tool = step.toolName, !tool.isEmpty {
                                Text(tool)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(NewtonTheme.sand)
                            }
                            
                            if let msg = step.message, !msg.isEmpty {
                                Text(msg)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(NewtonTheme.textPrimary)
                            }
                            
                            if let out = step.stdout, !out.isEmpty {
                                Text(out)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(NewtonTheme.textSecondary)
                                    .lineLimit(4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .id("step_\(idx)")
                }
                
                if let answer = finalAnswer, !answer.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Resultado final")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(NewtonTheme.textPrimary)
                        }
                        Text(answer)
                            .font(.system(size: 12))
                            .foregroundColor(NewtonTheme.textPrimary)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .id("final_answer_anchor")
                }
            }
            .padding(12)
            .background(NewtonTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NewtonTheme.border, lineWidth: 0.8)
            )
            .onChange(of: steps.count) { _ in
                if let lastIdx = steps.indices.last {
                    withAnimation {
                        scrollProxy.scrollTo("step_\(lastIdx)", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Bottom Dispatch Bar
    
    private var bottomDispatchBar: some View {
        VStack(spacing: 6) {
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(NewtonTheme.coralRed)
                    .lineLimit(1)
            }
            
            HStack(spacing: 8) {
                TextField("Instrucción para la Mac (e.g. compila el proyecto)...", text: $taskPrompt)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(NewtonTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(NewtonTheme.border, lineWidth: 0.8)
                    )
                
                let canDispatch = !taskPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedWorkspace != nil && !isExecuting && (desktopStatus?.online == true)
                
                Button(action: dispatchTask) {
                    ZStack {
                        Circle()
                            .fill(canDispatch ? NewtonTheme.sand : NewtonTheme.card)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(canDispatch ? NewtonTheme.bg : NewtonTheme.textMuted)
                    }
                }
                .disabled(!canDispatch)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(NewtonTheme.bg)
        }
    }
    
    // MARK: - Helpers & Actions
    
    private func refreshAll() {
        Task {
            do {
                let status = try await cloudService.fetchDesktopStatus()
                let wsList = try await cloudService.fetchDesktopWorkspaces()
                await MainActor.run {
                    self.desktopStatus = status
                    self.workspaces = wsList
                    if self.selectedWorkspace == nil {
                        self.selectedWorkspace = wsList.first
                        self.selectedChatId = wsList.first?.chats?.first?.id
                    }
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "No se pudo sincronizar con la Mac: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task {
                if let status = try? await cloudService.fetchDesktopStatus() {
                    await MainActor.run {
                        self.desktopStatus = status
                    }
                }
            }
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func dispatchTask() {
        guard let ws = selectedWorkspace else { return }
        let prompt = taskPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        
        taskPrompt = ""
        isExecuting = true
        steps.removeAll()
        finalAnswer = nil
        errorMessage = nil
        Haptics.medium()
        
        Task {
            do {
                _ = try await cloudService.dispatchDesktopCommand(
                    workspacePath: ws.path,
                    chatId: selectedChatId,
                    task: prompt,
                    model: "Singularity-Matrix"
                )
                startStreamingSession()
            } catch {
                await MainActor.run {
                    self.isExecuting = false
                    self.errorMessage = "Error al despachar: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func startStreamingSession() {
        streamTask?.cancel()
        streamTask = Task {
            let stream = cloudService.streamDesktopSession()
            for await step in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.steps.append(step)
                    if step.stepType == "task_done" {
                        self.isExecuting = false
                        self.finalAnswer = step.message
                    } else if step.stepType == "error" {
                        self.isExecuting = false
                        self.errorMessage = step.message
                    }
                }
            }
            await MainActor.run {
                if self.isExecuting {
                    self.isExecuting = false
                }
            }
        }
    }
    
    private func cancelRemoteTask() {
        Haptics.warning()
        streamTask?.cancel()
        isExecuting = false
        Task {
            try? await cloudService.cancelDesktopCommand()
        }
    }
    
    private func iconForStep(_ type: String) -> String {
        switch type {
        case "tool_start": return "hammer.fill"
        case "tool_result": return "checkmark.circle"
        case "task_done": return "flag.checkered"
        case "error": return "exclamationmark.triangle.fill"
        default: return "terminal"
        }
    }
    
    private func colorForStep(_ type: String) -> Color {
        switch type {
        case "tool_start": return NewtonTheme.sand
        case "tool_result": return .green
        case "task_done": return .blue
        case "error": return NewtonTheme.coralRed
        default: return NewtonTheme.textSecondary
        }
    }
}
