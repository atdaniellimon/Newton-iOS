//
//  MainMacSplitView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Matches the web desktop layout with full Light & Dark mode and Newton Code mode adaptation.
//

import SwiftUI
import AppKit

public struct MainMacSplitView: View {
    @StateObject private var storage = StorageManager.shared
    @StateObject private var settings = SettingsManager.shared
    @ObservedObject private var workspace = NewtonCodeWorkspaceManager.shared
    @ObservedObject private var auth = AuthManager.shared
    
    @State private var selectedConversation: Conversation? = nil
    @State private var selectedSidebarTab: SidebarTab = .chat
    @State private var dashboardPrompt: String = ""
    @State private var isSidebarCollapsed: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    public var body: some View {
        if !auth.isLoggedIn {
            AuthView()
        } else {
        HStack(spacing: 0) {
            // Sidebar Column
            if !isSidebarCollapsed {
                MacConversationListView(
                    selectedConversation: $selectedConversation,
                    selectedSidebarTab: $selectedSidebarTab,
                    isSidebarCollapsed: $isSidebarCollapsed
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            
            // Main Canvas Area
            if selectedSidebarTab == .code {
                if let selected = bindingForSelectedConversation(), !selected.wrappedValue.messages.isEmpty {
                    NewtonCodeChatView(
                        conversation: selected,
                        isSidebarCollapsed: $isSidebarCollapsed
                    )
                } else {
                    NewtonCodeDashboardView(
                        inputPrompt: $dashboardPrompt,
                        isSidebarCollapsed: $isSidebarCollapsed,
                        onStartTask: { prompt in
                            var newConvo = storage.createConversation()
                            newConvo.workspacePath = workspace.activeWorkspacePath
                            newConvo.title = String(prompt.prefix(28))
                            let userMsg = Message(role: .user, content: prompt)
                            newConvo.messages.append(userMsg)
                            storage.updateConversation(newConvo)
                            selectedConversation = newConvo
                        }
                    )
                }
            } else {
                if let selected = bindingForSelectedConversation() {
                    MacChatView(
                        conversation: selected,
                        isSidebarCollapsed: $isSidebarCollapsed
                    )
                } else {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colorScheme == .dark ? Color(red: 0.08, green: 0.10, blue: 0.13) : Color(red: 0.98, green: 0.98, blue: 0.99))
                }
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .background(colorScheme == .dark ? Color(red: 0.08, green: 0.10, blue: 0.13) : Color(red: 0.98, green: 0.98, blue: 0.99))
        .preferredColorScheme(settings.appTheme.colorScheme)
        .onAppear {
            if selectedConversation == nil {
                selectedConversation = storage.conversations.first ?? storage.createConversation()
            }
        }
        } // end else (auth)
    }
    
    private func bindingForSelectedConversation() -> Binding<Conversation>? {
        guard let sel = selectedConversation,
              let idx = storage.conversations.firstIndex(where: { $0.id == sel.id }) else {
            return nil
        }
        return $storage.conversations[idx]
    }
}
