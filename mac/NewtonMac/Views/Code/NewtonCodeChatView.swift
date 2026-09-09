//
//  NewtonCodeChatView.swift
//  NewtonMac
//
//  Created for Newton Code on macOS.
//  Interactive programming session view with tool chips, bash execution cards, and permission handling.
//

import SwiftUI
import AppKit

public struct NewtonCodeChatView: View {
    @Binding public var conversation: Conversation
    @Binding public var isSidebarCollapsed: Bool
    
    @ObservedObject private var workspace = NewtonCodeWorkspaceManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var inputText: String = ""
    @State private var isStreaming: Bool = false
    @State private var streamingText: String = ""
    @State private var streamingTask: Task<Void, Never>? = nil
    
    private var isDark: Bool { colorScheme == .dark }
    
    public init(conversation: Binding<Conversation>, isSidebarCollapsed: Binding<Bool> = .constant(false)) {
        self._conversation = conversation
        self._isSidebarCollapsed = isSidebarCollapsed
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Workspace Header
            topProjectHeader
            
            // Messages Scroll View
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(conversation.messages) { message in
                            codeMessageBubble(message)
                        }
                        
                        if isStreaming {
                            streamingAssistantBubble
                        }
                        
                        Color.clear
                            .frame(height: 8)
                            .id("bottom-anchor")
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                }
                .onChange(of: conversation.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                    }
                }
                .onChange(of: streamingText) { _ in
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
            }
            
            // Bottom Coding Input Bar
            NewtonCodeInputBar(
                text: $inputText,
                isStreaming: isStreaming,
                onSend: sendMessage,
                onStop: stopStreaming
            )
        }
        .background(isDark ? Color(red: 0.08, green: 0.10, blue: 0.13) : Color(red: 0.97, green: 0.98, blue: 0.99))
        .onAppear {
            workspace.sessionTokensUsed = conversation.messages.reduce(0) { $0 + $1.content.count / 4 }
            if conversation.messages.last?.role == .user && !isStreaming {
                executeAgentLoop()
            }
        }
    }
    
    @ViewBuilder
    private var topProjectHeader: some View {
        HStack(spacing: 10) {
            // Traffic light spacer when sidebar is collapsed
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
            
            Text(conversation.title.isEmpty ? "Coding Task" : conversation.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isDark ? Color(red: 0.94, green: 0.96, blue: 0.99) : Color(red: 0.08, green: 0.11, blue: 0.16))
            
            Text(workspace.activeProjectName)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(isDark ? Color(red: 0.65, green: 0.70, blue: 0.78) : Color(red: 0.45, green: 0.50, blue: 0.58))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isDark ? Color(red: 0.16, green: 0.19, blue: 0.25) : Color(red: 0.90, green: 0.92, blue: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            Spacer()
            
            // Terminal action buttons
            Button(action: {}) {
                Image(systemName: "terminal")
                    .font(.system(size: 11.5))
                    .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.84) : Color(red: 0.40, green: 0.45, blue: 0.52))
            }
            .buttonStyle(.plain)
            .help("Open Terminal")
            
            Button(action: {}) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 11.5))
                    .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.84) : Color(red: 0.40, green: 0.45, blue: 0.52))
            }
            .buttonStyle(.plain)
            .help("Toggle Inspector")
        }
        .padding(.horizontal, isSidebarCollapsed ? 12 : 24)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .frame(height: 52)
        .overlay(
            Rectangle()
                .fill(isDark ? Color(red: 0.18, green: 0.22, blue: 0.28) : Color(red: 0.88, green: 0.90, blue: 0.94))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private func codeMessageBubble(_ message: Message) -> some View {
        if message.role == .user {
            HStack {
                Spacer()
                Text(message.content)
                    .font(.system(size: 13.5))
                    .foregroundColor(isDark ? Color(red: 0.08, green: 0.10, blue: 0.13) : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(isDark ? NewtonTheme.sand : Color(red: 0.10, green: 0.14, blue: 0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // Collapsible tool chips if any tools ran
                if !message.orbitResults.isEmpty {
                    ForEach(message.orbitResults) { orbit in
                        if orbit.orbitName == "read_file" {
                            CodeToolChipView(title: "Read \(orbit.params)", details: orbit.result)
                        } else if orbit.orbitName == "run_command" {
                            CodeBashExecutionCardView(command: orbit.params, onRun: {
                                Task { _ = await workspace.runBashCommand(command: orbit.params) }
                            })
                            if !orbit.result.isEmpty {
                                CodeToolChipView(title: "Command Output", details: orbit.result)
                            }
                        } else if orbit.orbitName == "edit_file" || orbit.orbitName == "write_file" {
                            CodeToolChipView(title: "Modified \(orbit.params)", details: orbit.result)
                        }
                    }
                }
                
                // Formatted Assistant Text & Code Blocks
                MacFormattedAssistantContent(content: message.content)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private var streamingAssistantBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ThinkingOrbView(size: 20, style: .globe)
                Text("Newton Singularity is reasoning and executing tools...")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(NewtonTheme.sand)
            }
            .padding(.vertical, 3)
            
            if !streamingText.isEmpty {
                MacFormattedAssistantContent(content: streamingText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func sendMessage() {
        let textToSend = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty else { return }
        
        if conversation.title.isEmpty || conversation.title == "New Conversation" {
            conversation.title = String(textToSend.prefix(32))
        }
        
        let userMsg = Message(role: .user, content: textToSend)
        conversation.messages.append(userMsg)
        inputText = ""
        
        executeAgentLoop()
    }
    
    private func executeAgentLoop() {
        guard !isStreaming else { return }
        isStreaming = true
        streamingText = ""
        
        let lastUserMsg = conversation.messages.last(where: { $0.role == .user })?.content ?? ""
        
        // Scan top-level workspace files
        let workspaceFiles = (try? FileManager.default.contentsOfDirectory(atPath: workspace.activeWorkspacePath)) ?? []
        let fileList = workspaceFiles.prefix(25).joined(separator: ", ")
        
        let systemPrompt = """
        # Newton Singularity Code Engine (Autonomous Engineer & System Architect)
        
        You are **Newton Singularity**, operating in **Code Studio Mode** (`</> Code`).
        You are an autonomous senior software engineer, architect, and terminal agent.
        
        ==================================================
        ACTIVE WORKSPACE CONTEXT
        ==================================================
        - Workspace Directory: \(workspace.activeWorkspacePath)
        - Project Name: \(workspace.activeProjectName)
        - Top-level files/folders in workspace: [\(fileList)]
        - Permission Mode: \(workspace.permissionMode.rawValue)
        
        ==================================================
        AVAILABLE CODE ORBITS (NATIVE TOOLS)
        ==================================================
        You have direct, real-time access to the user's filesystem and zsh terminal. To invoke a tool, output its exact block:
        
        1. Read File:
        [ORBIT:read_file]{"path": "relative/path/to/file"}[/ORBIT]
        
        2. Write / Create File:
        [ORBIT:write_file]{"path": "relative/path/to/file", "content": "..."}[/ORBIT]
        
        3. Edit File:
        [ORBIT:edit_file]{"path": "relative/path/to/file", "target": "exact string to replace", "replacement": "new string"}[/ORBIT]
        
        4. Delete File:
        [ORBIT:delete_file]{"path": "relative/path/to/file"}[/ORBIT]
        
        5. Run Terminal Bash Command:
        [ORBIT:run_command]{"command": "ls -la"}[/ORBIT]
        
        ==================================================
        NATURAL MULTILINGUAL ADAPTATION (CRITICAL)
        ==================================================
        - ALWAYS detect and respond in the EXACT same language used by the user (Spanish, English, French, German, etc.).
        - If the user writes in Spanish, your explanations and thought process MUST be in natural, fluent Spanish.
        
        ==================================================
        CRITICAL AGENTIC BEHAVIOR RULES
        ==================================================
        1. AUTONOMOUS INVESTIGATION: When the user asks about the project (e.g. "qué opinas de este proyecto?", "qué hace este código?", "explícame la arquitectura", "busca el bug"), NEVER respond asking the user for details or files. You have the tools! IMMEDIATELY run [ORBIT:run_command]{"command": "ls -la"}[/ORBIT] or [ORBIT:read_file] to inspect the codebase yourself, and deliver a comprehensive, technical analysis in the user's language.
        2. DO NOT DECLINE ACTIONS: When asked to modify, create, build, or fix code, use your orbits directly.
        3. BE CONCISE & PROFESSIONAL: Deliver clean, high-performance code and architectural insight.
        """
        
        streamingTask = Task {
            var fullStreamed = ""
            do {
                let stream = LLMService.shared.streamCompletion(
                    messages: conversation.messages,
                    provider: conversation.provider,
                    modelId: conversation.modelId,
                    baseUrl: settings.effectiveBaseUrl(for: conversation.provider),
                    apiKey: settings.getApiKey(for: conversation.provider),
                    systemPrompt: systemPrompt
                )
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    fullStreamed += chunk
                    await MainActor.run {
                        self.streamingText = fullStreamed
                    }
                }
            } catch {
                if fullStreamed.isEmpty {
                    fullStreamed = "Connection error: \(error.localizedDescription)"
                }
            }
            
            // Process Code Orbits
            let processed = await OrbitEngine.shared.processOrbitsInText(fullStreamed, userPrompt: lastUserMsg)
            
            await MainActor.run {
                let assistantMsg = Message(
                    role: .assistant,
                    content: processed.processedText.isEmpty ? fullStreamed : processed.processedText,
                    orbitResults: processed.results
                )
                self.conversation.messages.append(assistantMsg)
                self.isStreaming = false
                self.streamingText = ""
                self.workspace.sessionTokensUsed = self.conversation.messages.reduce(0) { $0 + $1.content.count / 4 }
                StorageManager.shared.saveConversations()
                
                // Send completion notification if unfocused
                NotificationService.shared.sendCompletionNotification(
                    title: "Newton Code · \(self.workspace.activeProjectName)",
                    body: assistantMsg.content
                )
            }
        }
    }
    
    private func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        if !streamingText.isEmpty {
            let partial = Message(role: .assistant, content: streamingText)
            conversation.messages.append(partial)
            streamingText = ""
            StorageManager.shared.saveConversations()
        }
    }
}
