//
//  NewtonCodeWorkspaceManager.swift
//  NewtonMac
//
//  Created for Newton Code on macOS.
//  Manages workspaces, file system access, terminal execution, permissions, and token analytics.
//

import SwiftUI
import Foundation
import AppKit

public enum CodePermissionMode: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case acceptEdits = "Accept edits"
    case plan = "Plan"
    case bypass = "Bypass permissions"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .manual:
            return "Always ask before changing something"
        case .acceptEdits:
            return "Automatically accept all file edits"
        case .plan:
            return "Create a plan before changing things"
        case .bypass:
            return "Allow all edits and bash commands"
        }
    }
}

public struct CodeProject: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var path: String
    public var sessionIds: [String]
    
    public init(id: String = UUID().uuidString, name: String, path: String, sessionIds: [String] = []) {
        self.id = id
        self.name = name
        self.path = path
        self.sessionIds = sessionIds
    }
}

public struct CodeCommandExecution: Identifiable, Equatable {
    public var id = UUID()
    public var command: String
    public var output: String
    public var exitCode: Int32
    public var timestamp: Date = Date()
}

public struct CodeFileOperation: Identifiable, Equatable {
    public var id = UUID()
    public var operationType: String // "read", "edit", "write", "delete"
    public var filePath: String
    public var details: String
    public var isPendingApproval: Bool = false
}

public final class NewtonCodeWorkspaceManager: ObservableObject {
    public static let shared = NewtonCodeWorkspaceManager()
    
    @Published public var activeWorkspacePath: String = "/Volumes/Daniel/projects/Newton/Moke Newton"
    @Published public var activeProjectName: String = "Moke Newton"
    @Published public var projects: [CodeProject] = []
    @Published public var permissionMode: CodePermissionMode = .bypass
    
    // Token & Context Analytics
    @Published public var totalTokensUsed: Int = 4_420_000
    @Published public var sessionTokensUsed: Int = 18_450
    @Published public var contextWindowMax: Int = 200_000
    @Published public var activeDaysCount: Int = 32
    @Published public var currentStreak: Int = 4
    @Published public var longestStreak: Int = 15
    @Published public var totalSessionsCount: Int = 116
    @Published public var totalMessagesCount: Int = 77_664
    
    // Command & File execution history
    @Published public var recentCommands: [CodeCommandExecution] = []
    @Published public var recentFileOps: [CodeFileOperation] = []
    
    private let projectsKey = "NewtonCode_Projects_List"
    private let activePathKey = "NewtonCode_Active_Path"
    private let permissionKey = "NewtonCode_Permission_Mode"
    
    private init() {
        loadSettings()
    }
    
    public var freeTokens: Int {
        max(0, contextWindowMax - sessionTokensUsed)
    }
    
    public var freeTokensFormatted: String {
        let freeK = freeTokens / 1000
        let maxK = contextWindowMax / 1000
        return "\(freeK)k / \(maxK)k free"
    }
    
    // MARK: - Workspace Picker (Native macOS NSOpenPanel)
    @MainActor
    public func selectWorkspaceDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Select Project / Workspace Directory for Newton Code"
        panel.prompt = "Choose Workspace"
        
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            let name = url.lastPathComponent
            
            self.activeWorkspacePath = path
            self.activeProjectName = name
            
            if !projects.contains(where: { $0.path == path }) {
                let newProj = CodeProject(name: name, path: path)
                self.projects.append(newProj)
            }
            saveSettings()
        }
    }
    
    // MARK: - Native File System Operations
    public func readFile(relativePath: String, maxLines: Int = 500) -> (content: String, error: String?) {
        let fullPath = resolvePath(relativePath)
        guard FileManager.default.fileExists(atPath: fullPath) else {
            return ("", "File not found at \(fullPath)")
        }
        
        do {
            let content = try String(contentsOfFile: fullPath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let trimmed = lines.prefix(maxLines).joined(separator: "\n")
            
            DispatchQueue.main.async {
                self.recentFileOps.append(CodeFileOperation(operationType: "read", filePath: relativePath, details: "Read \(min(lines.count, maxLines)) lines"))
            }
            return (trimmed, nil)
        } catch {
            return ("", error.localizedDescription)
        }
    }
    
    public func writeFile(relativePath: String, content: String) -> (success: Bool, error: String?) {
        let fullPath = resolvePath(relativePath)
        let dir = (fullPath as NSString).deletingLastPathComponent
        
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.async {
                self.recentFileOps.append(CodeFileOperation(operationType: "write", filePath: relativePath, details: "Wrote \(content.count) bytes"))
            }
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    public func editFile(relativePath: String, target: String, replacement: String) -> (success: Bool, error: String?) {
        let fullPath = resolvePath(relativePath)
        guard FileManager.default.fileExists(atPath: fullPath) else {
            return (false, "File not found at \(fullPath)")
        }
        
        do {
            let existing = try String(contentsOfFile: fullPath, encoding: .utf8)
            guard existing.contains(target) else {
                return (false, "Target string to replace not found in \(relativePath)")
            }
            
            let updated = existing.replacingOccurrences(of: target, with: replacement)
            try updated.write(toFile: fullPath, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.async {
                self.recentFileOps.append(CodeFileOperation(operationType: "edit", filePath: relativePath, details: "Replaced \(target.count) chars with \(replacement.count) chars"))
            }
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    public func deleteFile(relativePath: String) -> (success: Bool, error: String?) {
        let fullPath = resolvePath(relativePath)
        guard FileManager.default.fileExists(atPath: fullPath) else {
            return (false, "File not found at \(fullPath)")
        }
        
        do {
            try FileManager.default.removeItem(atPath: fullPath)
            DispatchQueue.main.async {
                self.recentFileOps.append(CodeFileOperation(operationType: "delete", filePath: relativePath, details: "Deleted file"))
            }
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    // MARK: - Native Bash Terminal Execution
    public func runBashCommand(command: String) async -> (output: String, exitCode: Int32) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]
                process.currentDirectoryURL = URL(fileURLWithPath: self.activeWorkspacePath)
                process.standardOutput = pipe
                process.standardError = pipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    let code = process.terminationStatus
                    
                    DispatchQueue.main.async {
                        self.recentCommands.append(CodeCommandExecution(command: command, output: output, exitCode: code))
                        self.sessionTokensUsed += max(50, output.count / 4)
                        self.totalTokensUsed += max(50, output.count / 4)
                    }
                    
                    continuation.resume(returning: (output, code))
                } catch {
                    continuation.resume(returning: ("Execution error: \(error.localizedDescription)", 1))
                }
            }
        }
    }
    
    private func resolvePath(_ relative: String) -> String {
        if relative.hasPrefix("/") {
            return relative
        }
        return (activeWorkspacePath as NSString).appendingPathComponent(relative)
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(activeWorkspacePath, forKey: activePathKey)
        UserDefaults.standard.set(permissionMode.rawValue, forKey: permissionKey)
        if let encoded = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(encoded, forKey: projectsKey)
        }
    }
    
    private func loadSettings() {
        if let savedPath = UserDefaults.standard.string(forKey: activePathKey) {
            self.activeWorkspacePath = savedPath
            self.activeProjectName = (savedPath as NSString).lastPathComponent
        }
        if let savedPerm = UserDefaults.standard.string(forKey: permissionKey), let perm = CodePermissionMode(rawValue: savedPerm) {
            self.permissionMode = perm
        }
        if let data = UserDefaults.standard.data(forKey: projectsKey), let decoded = try? JSONDecoder().decode([CodeProject].self, from: data), !decoded.isEmpty {
            self.projects = decoded
        } else {
            // Default to current active workspace
            self.projects = [
                CodeProject(name: "Moke Newton", path: "/Volumes/Daniel/projects/Newton/Moke Newton")
            ]
        }
    }
}
