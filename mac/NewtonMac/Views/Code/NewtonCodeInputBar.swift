//
//  NewtonCodeInputBar.swift
//  NewtonMac
//
//  Created for Newton Code on macOS.
//  Specialized coding input bar with permissions, context indicators, and workspace selector.
//

import SwiftUI
import AppKit

public struct NewtonCodeInputBar: View {
    @Binding public var text: String
    public var isStreaming: Bool
    public var onSend: () -> Void
    public var onStop: () -> Void
    
    @ObservedObject private var workspace = NewtonCodeWorkspaceManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var dynamicHeight: CGFloat = 28
    
    public init(
        text: Binding<String>,
        isStreaming: Bool,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self._text = text
        self.isStreaming = isStreaming
        self.onSend = onSend
        self.onStop = onStop
    }
    
    private var isDark: Bool { colorScheme == .dark }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Location / Context Pills
            HStack(spacing: 8) {
                // Local Badge
                HStack(spacing: 4) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 10.5))
                    Text("Local")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(isDark ? Color(red: 0.85, green: 0.88, blue: 0.94) : Color(red: 0.25, green: 0.30, blue: 0.38))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isDark ? Color(red: 0.16, green: 0.19, blue: 0.25) : Color(red: 0.90, green: 0.92, blue: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                // Workspace Directory Pill (Click to Change)
                Button(action: {
                    workspace.selectWorkspaceDirectory()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10.5))
                        Text(workspace.activeProjectName.isEmpty ? "Select Workspace" : workspace.activeProjectName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(isDark ? Color(red: 0.85, green: 0.88, blue: 0.94) : Color(red: 0.25, green: 0.30, blue: 0.38))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isDark ? Color(red: 0.16, green: 0.19, blue: 0.25) : Color(red: 0.90, green: 0.92, blue: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Change Workspace Directory (\(workspace.activeWorkspacePath))")
                
                Spacer()
            }
            .padding(.horizontal, 28)
            
            // Input Box Card
            VStack(spacing: 4) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Describe a task or ask a question (Type / for commands)...")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(isDark ? Color(red: 0.48, green: 0.53, blue: 0.60) : Color(red: 0.58, green: 0.63, blue: 0.70))
                            .padding(.horizontal, 14)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                    
                    MacAutoGrowingTextView(
                        text: $text,
                        dynamicHeight: $dynamicHeight,
                        onCommit: {
                            if canSend && !isStreaming {
                                onSend()
                            }
                        }
                    )
                    .frame(height: max(28, min(dynamicHeight, 140)))
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                }
                
                // Bottom Status & Controls Bar
                HStack(spacing: 12) {
                    // Left: Permissions Mode Menu
                    Menu {
                        ForEach(CodePermissionMode.allCases) { mode in
                            Button(action: {
                                workspace.permissionMode = mode
                            }) {
                                HStack {
                                    Text(mode.rawValue)
                                    if workspace.permissionMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(workspace.permissionMode.rawValue)
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.84) : Color(red: 0.35, green: 0.40, blue: 0.48))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isDark ? Color(red: 0.18, green: 0.22, blue: 0.28) : Color(red: 0.92, green: 0.94, blue: 0.97))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .menuStyle(.borderlessButton)
                    .help(workspace.permissionMode.description)
                    
                    Spacer()
                    
                    // Right: Model Pill
                    Text("Singularity")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isDark ? Color(red: 0.75, green: 0.80, blue: 0.88) : Color(red: 0.35, green: 0.40, blue: 0.48))
                    
                    // Reasoning Effort Gauge
                    HStack(spacing: 3) {
                        Text("High")
                            .font(.system(size: 11, weight: .medium))
                        Circle()
                            .stroke(NewtonTheme.sand, lineWidth: 1.5)
                            .frame(width: 8, height: 8)
                    }
                    .foregroundColor(isDark ? Color(red: 0.75, green: 0.80, blue: 0.88) : Color(red: 0.35, green: 0.40, blue: 0.48))
                    
                    // Context Window Gauge
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.medium")
                            .font(.system(size: 10))
                        Text(workspace.freeTokensFormatted)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(isDark ? Color(red: 0.60, green: 0.65, blue: 0.74) : Color(red: 0.50, green: 0.55, blue: 0.64))
                    
                    // Send / Stop button
                    if isStreaming {
                        Button(action: onStop) {
                            Circle()
                                .fill(NewtonTheme.coralRed)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white)
                                        .frame(width: 7, height: 7)
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            if canSend { onSend() }
                        }) {
                            Circle()
                                .fill(canSend ? (isDark ? NewtonTheme.sand : Color(red: 0.08, green: 0.11, blue: 0.16)) : (isDark ? Color(red: 0.22, green: 0.26, blue: 0.33) : Color(red: 0.80, green: 0.83, blue: 0.88)))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundColor(canSend ? (isDark ? Color(red: 0.08, green: 0.10, blue: 0.13) : .white) : Color.gray)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSend)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
                .padding(.top, 2)
            }
            .background(isDark ? Color(red: 0.13, green: 0.16, blue: 0.21) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isDark ? Color(red: 0.22, green: 0.26, blue: 0.34) : Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.04), radius: 6, x: 0, y: 2)
            .padding(.horizontal, 28)
            .padding(.bottom, 6)
        }
    }
}
