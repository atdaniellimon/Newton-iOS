//
//  MessageInputBar.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct MessageInputBar: View {
    @Binding public var text: String
    public let isStreaming: Bool
    public let onSend: () -> Void
    public let onStop: () -> Void
    
    @FocusState private var isFocused: Bool
    
    public init(text: Binding<String>, isStreaming: Bool, onSend: @escaping () -> Void, onStop: @escaping () -> Void) {
        self._text = text
        self.isStreaming = isStreaming
        self.onSend = onSend
        self.onStop = onStop
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                // Orbit quick shortcut
                Menu {
                    Button(action: {
                        insertOrbitSnippet("web_search", param: "query")
                    }) {
                        Label("Web Search Orbit", systemImage: "globe")
                    }
                    Button(action: {
                        insertOrbitSnippet("calculator", param: "expression")
                    }) {
                        Label("Calculator Orbit", systemImage: "function")
                    }
                    Button(action: {
                        insertOrbitSnippet("time", param: "")
                    }) {
                        Label("Current Time Orbit", systemImage: "clock")
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(NewtonTheme.surfaceDark)
                            .frame(width: 36, height: 36)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(NewtonTheme.textSecondary)
                    }
                }
                
                // Auto-expanding text input
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Message Newton...")
                            .font(.system(size: 15))
                            .foregroundColor(NewtonTheme.textMuted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .font(.system(size: 15))
                        .foregroundColor(NewtonTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(minHeight: 38, maxHeight: 120)
                }
                .background(NewtonTheme.surfaceDark)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(NewtonTheme.borderDark, lineWidth: 0.8)
                )
                
                // Send / Stop Button
                Button(action: {
                    if isStreaming {
                        Haptics.medium()
                        onStop()
                    } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Haptics.light()
                        onSend()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isStreaming ? NewtonTheme.coralRed : (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NewtonTheme.surfaceDark : NewtonTheme.sand))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isStreaming ? .white : (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NewtonTheme.textMuted : .black))
                    }
                }
                .disabled(!isStreaming && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(NewtonTheme.cardDark.opacity(0.95))
            .overlay(
                Rectangle()
                    .frame(height: 0.6)
                    .foregroundColor(NewtonTheme.borderDark),
                alignment: .top
            )
        }
    }
    
    private func insertOrbitSnippet(_ name: String, param: String) {
        Haptics.selection()
        if param.isEmpty {
            text += "[ORBIT:\(name)]{}[/ORBIT]"
        } else {
            text += "[ORBIT:\(name)]{\"\(param)\": \"\"}[/ORBIT]"
        }
    }
}
