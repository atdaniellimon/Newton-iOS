//
//  WorkspaceManager.swift
//  Newton
//
//  Manager for switching, persisting, and configuring Project Workspaces.
//

import Foundation
import Combine
import SwiftUI

public final class WorkspaceManager: ObservableObject {
    public static let shared = WorkspaceManager()
    
    @Published public var activeWorkspaceId: String {
        didSet {
            UserDefaults.standard.set(activeWorkspaceId, forKey: "activeWorkspaceId")
        }
    }
    @Published public var workspaces: [Workspace] = []
    
    private let storageKey = "newton_workspaces_list"
    
    private init() {
        self.activeWorkspaceId = UserDefaults.standard.string(forKey: "activeWorkspaceId") ?? "default"
        loadWorkspaces()
    }
    
    public var activeWorkspace: Workspace? {
        if activeWorkspaceId == "default" {
            return nil
        }
        return workspaces.first(where: { $0.id == activeWorkspaceId })
    }
    
    public func loadWorkspaces() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let list = try? JSONDecoder().decode([Workspace].self, from: data) {
            self.workspaces = list
        } else {
            self.workspaces = [
                
            ]
            saveWorkspaces()
        }
    }
    
    public func saveWorkspaces() {
        if let data = try? JSONEncoder().encode(workspaces) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    public func addWorkspace(name: String, icon: String = "folder.fill", color: String = "#F5A623", prompt: String = "") -> Workspace {
        let ws = Workspace(name: name, iconName: icon, colorHex: color, customSystemPrompt: prompt)
        workspaces.append(ws)
        saveWorkspaces()
        return ws
    }
    
    public func deleteWorkspace(id: String) {
        workspaces.removeAll(where: { $0.id == id })
        if activeWorkspaceId == id {
            activeWorkspaceId = "default"
        }
        saveWorkspaces()
    }
    
    public func updateWorkspace(_ ws: Workspace) {
        if let idx = workspaces.firstIndex(where: { $0.id == ws.id }) {
            workspaces[idx] = ws
            saveWorkspaces()
        }
    }
}
