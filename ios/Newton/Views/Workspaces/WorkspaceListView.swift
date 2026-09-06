//
//  WorkspaceListView.swift
//  Newton
//
//  Dedicated Projects & Workspaces switcher and context manager.
//

import SwiftUI

public struct WorkspaceListView: View {
    @ObservedObject var workspaceManager = WorkspaceManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingNewWorkspaceSheet: Bool = false
    @State private var newWsName: String = ""
    @State private var newWsPrompt: String = ""
    @State private var selectedIcon: String = "folder.fill"
    
    let availableIcons = ["folder.fill", "brain.head.profile", "cpu", "cube.transparent", "atom", "terminal.fill", "sparkles", "hammer.fill"]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                List {
                    Section(header: Text("ACTIVE PROJECT CONTEXT")) {
                        Button(action: {
                            workspaceManager.activeWorkspaceId = "default"
                            Haptics.selection()
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.system(size: 18))
                                    .foregroundColor(NewtonTheme.sand)
                                    .frame(width: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Global Workspace (Default)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(UIColor.label))
                                    Text("General knowledge without project constraints")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                }
                                
                                Spacer()
                                
                                if workspaceManager.activeWorkspaceId == "default" {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(NewtonTheme.sand)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Section(header: Text("PROJECT WORKSPACES")) {
                        ForEach(workspaceManager.workspaces) { ws in
                            Button(action: {
                                workspaceManager.activeWorkspaceId = ws.id
                                Haptics.selection()
                                dismiss()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: ws.iconName)
                                        .font(.system(size: 18))
                                        .foregroundColor(NewtonTheme.sand)
                                        .frame(width: 28)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ws.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color(UIColor.label))
                                        if !ws.customSystemPrompt.isEmpty {
                                            Text(ws.customSystemPrompt)
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(UIColor.secondaryLabel))
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if workspaceManager.activeWorkspaceId == ws.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(NewtonTheme.sand)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    workspaceManager.deleteWorkspace(id: ws.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workspaces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(NewtonTheme.sand)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewWorkspaceSheet = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(NewtonTheme.sand)
                    }
                }
            }
            .sheet(isPresented: $showingNewWorkspaceSheet) {
                newWorkspaceSheet
            }
        }
    }
    
    private var newWorkspaceSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("PROJECT DETAILS")) {
                    TextField("Workspace Name (e.g. RISC-V Kernel)", text: $newWsName)
                    
                    Picker("Icon", selection: $selectedIcon) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Label(icon, systemImage: icon).tag(icon)
                        }
                    }
                }
                
                Section(header: Text("CUSTOM SYSTEM PROMPT / CONTEXT")) {
                    TextEditor(text: $newWsPrompt)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("New Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingNewWorkspaceSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let trimmed = newWsName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        _ = workspaceManager.addWorkspace(name: trimmed, icon: selectedIcon, prompt: newWsPrompt)
                        newWsName = ""
                        newWsPrompt = ""
                        showingNewWorkspaceSheet = false
                    }
                    .disabled(newWsName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(NewtonTheme.sand)
                }
            }
        }
    }
}
