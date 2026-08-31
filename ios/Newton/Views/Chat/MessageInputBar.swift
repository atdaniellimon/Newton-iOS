//
//  MessageInputBar.swift
//  Newton
//
//  Created for Newton iOS.
//  Floating modern studio input bar matching Claude iOS & Newton Web.
//

import SwiftUI

public struct MessageInputBar: View {
    @Binding public var text: String
    public let isStreaming: Bool
    public let modelName: String
    public let onModelTap: () -> Void
    public let onSend: () -> Void
    public let onStop: () -> Void
    
    @FocusState private var isFocused: Bool
    
    public init(
        text: Binding<String>,
        isStreaming: Bool,
        modelName: String,
        onModelTap: @escaping () -> Void,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self._text = text
        self.isStreaming = isStreaming
        self.modelName = modelName
        self.onModelTap = onModelTap
        self.onSend = onSend
        self.onStop = onStop
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                // Expanding text input field
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Reply to Newton...")
                            .font(.system(size: 15.5))
                            .foregroundColor(NewtonTheme.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                    }
                    
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .font(.system(size: 15.5))
                        .foregroundColor(NewtonTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 38, maxHeight: 110)
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                
                // Bottom Action Row inside pill: (+) [Model Badge] ... (Send/Stop)
                HStack(spacing: 8) {
                    // Plus Menu for Orbits
                    Menu {
                        Button(action: { insertOrbitSnippet("web_search", param: "query") }) {
                            Label("Web Search Orbit", systemImage: "globe")
                        }
                        Button(action: { insertOrbitSnippet("calculator", param: "expression") }) {
                            Label("Calculator Orbit", systemImage: "function")
                        }
                        Button(action: { insertOrbitSnippet("time", param: "") }) {
                            Label("Current Time Orbit", systemImage: "clock")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(NewtonTheme.surface)
                                .frame(width: 32, height: 32)
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(NewtonTheme.textSecondary)
                        }
                    }
                    
                    // Model Selector Pill Badge
                    Button(action: {
                        Haptics.selection()
                        onModelTap()
                    }) {
                        HStack(spacing: 4) {
                            Text(modelName)
                                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                .foregroundColor(NewtonTheme.textPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundColor(NewtonTheme.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(NewtonTheme.surface)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
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
                                .fill(isStreaming ? NewtonTheme.coralRed : (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NewtonTheme.surface : NewtonTheme.sand))
                                .frame(width: 34, height: 34)
                            
                            Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isStreaming ? .white : (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NewtonTheme.textMuted : .black))
                        }
                    }
                    .disabled(!isStreaming && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .padding(6)
            .background(NewtonTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(NewtonTheme.border, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .padding(.top, 4)
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
