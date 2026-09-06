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
    
    @AppStorage("activeWorkspaceId") public var activeWorkspaceId: String = "default"
    @Published public var workspaces: [Workspace] = []
    
    private let storageKey = "newton_workspaces_list"
    
    private init() {
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
            // Default initial workspaces
            self.workspaces = [
                Workspace(name: "Newton Core", iconName: "brain.head.profile", colorHex: "#F5A623", customSystemPrompt: "Specialized in Newton architecture, Swift concurrency, Metal, and AI algorithms."),
                Workspace(name: "Systems & RISC-V", iconName: "cpu", colorHex: "#4CD964", customSystemPrompt: "Focused on RISC-V assembly, C systems programming, OS kernels, and microcontrollers."),
                Workspace(name: "ZTRN Luxury", iconName: "cube.transparent", colorHex: "#5856D6", customSystemPrompt: "Focused on luxury interior design, materials, 3D spatial concepts, and aesthetics.")
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
