//
//  MacWorkspaceSelector.swift
//  NewtonMac
//
//  macOS Workspace selector dropdown & manager.
//

import SwiftUI

public struct MacWorkspaceSelector: View {
    @ObservedObject var workspaceManager = WorkspaceManager.shared
    
    public init() {}
    
    public var body: some View {
        Menu {
            Button(action: {
                workspaceManager.activeWorkspaceId = "default"
            }) {
                HStack {
                    Text("Global Workspace (Default)")
                    if workspaceManager.activeWorkspaceId == "default" {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            ForEach(workspaceManager.workspaces) { ws in
                Button(action: {
                    workspaceManager.activeWorkspaceId = ws.id
                }) {
                    HStack {
                        Image(systemName: ws.iconName)
                        Text(ws.name)
                        if workspaceManager.activeWorkspaceId == ws.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: workspaceManager.activeWorkspace?.iconName ?? "globe")
                    .foregroundColor(NewtonTheme.sand)
                Text(workspaceManager.activeWorkspace?.name ?? "Global")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(NSColor.labelColor))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .menuStyle(.borderlessButton)
    }
}
