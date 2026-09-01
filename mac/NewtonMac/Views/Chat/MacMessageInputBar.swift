//
//  MacMessageInputBar.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  1:1 Faithful replication of the Newton Web input bar with seamless Light & Dark mode.
//

import SwiftUI
import AppKit

public struct MacMessageInputBar: View {
    @Binding public var text: String
    public var isStreaming: Bool
    public var onSend: () -> Void
    public var onStop: () -> Void
    public var onAttachFile: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isWebSearchEnabled: Bool = false
    @FocusState private var isFocused: Bool
    
    public init(
        text: Binding<String>,
        isStreaming: Bool,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onAttachFile: @escaping () -> Void
    ) {
        self._text = text
        self.isStreaming = isStreaming
        self.onSend = onSend
        self.onStop = onStop
        self.onAttachFile = onAttachFile
    }
    
    private var isDark: Bool { colorScheme == .dark }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Floating Input Container
            VStack(spacing: 0) {
                // Text input area
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Ask Newton anything...")
                            .font(.system(size: 13.5))
                            .foregroundColor(isDark ? Color(red: 0.50, green: 0.55, blue: 0.62) : Color(red: 0.60, green: 0.65, blue: 0.72))
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $text)
                        .font(.system(size: 13.5))
                        .foregroundColor(isDark ? Color(red: 0.94, green: 0.96, blue: 0.98) : Color(red: 0.08, green: 0.11, blue: 0.16))
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .frame(minHeight: 42, maxHeight: 130)
                        .focused($isFocused)
                }
                
                // Bottom Toolbar (Attachments, Search, Send)
                HStack(spacing: 12) {
                    // Paperclip Attachment Button
                    Button(action: onAttachFile) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 14))
                            .foregroundColor(isDark ? Color(red: 0.65, green: 0.70, blue: 0.78) : Color(red: 0.45, green: 0.50, blue: 0.58))
                    }
                    .buttonStyle(.plain)
                    .help("Attach PDF, Code or Documents")
                    
                    // Web Search Toggle Button
                    Button(action: {
                        isWebSearchEnabled.toggle()
                        if isWebSearchEnabled && !text.contains("[ORBIT:web_search]") {
                            text = "[ORBIT:web_search]{\"query\": \"\"}[/ORBIT] " + text
                        }
                    }) {
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                            .foregroundColor(isWebSearchEnabled ? NewtonTheme.sand : (isDark ? Color(red: 0.65, green: 0.70, blue: 0.78) : Color(red: 0.45, green: 0.50, blue: 0.58)))
                    }
                    .buttonStyle(.plain)
                    .help("Enable Real-Time Web Search Orbit")
                    
                    Spacer()
                    
                    // Send / Stop Button
                    if isStreaming {
                        Button(action: onStop) {
                            ZStack {
                                Circle()
                                    .fill(isDark ? NewtonTheme.coralRed : Color(red: 0.06, green: 0.09, blue: 0.16))
                                    .frame(width: 28, height: 28)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white)
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            if canSend {
                                onSend()
                                isWebSearchEnabled = false
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(canSend ? (isDark ? NewtonTheme.sand : Color(red: 0.06, green: 0.09, blue: 0.16)) : (isDark ? Color(red: 0.22, green: 0.26, blue: 0.33) : Color(red: 0.80, green: 0.83, blue: 0.88)))
                                    .frame(width: 28, height: 28)
                                
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(canSend ? (isDark ? Color(red: 0.08, green: 0.10, blue: 0.13) : Color.white) : (isDark ? Color(red: 0.45, green: 0.50, blue: 0.58) : Color(red: 0.55, green: 0.60, blue: 0.68)))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSend)
                        .keyboardShortcut(.return, modifiers: [])
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .padding(.top, 4)
            }
            .background(isDark ? Color(red: 0.14, green: 0.17, blue: 0.22) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isFocused ? (isDark ? NewtonTheme.sand.opacity(0.8) : Color(red: 0.70, green: 0.75, blue: 0.82)) : (isDark ? Color(red: 0.24, green: 0.28, blue: 0.36) : Color(red: 0.88, green: 0.90, blue: 0.94)), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.25 : 0.04), radius: 10, x: 0, y: 3)
            .padding(.horizontal, 48)
            
            // Bottom Disclaimer Text matching Web Screenshot
            Text("Newton AI may produce creative or technical output. Verify important data.")
                .font(.system(size: 10.5))
                .foregroundColor(isDark ? Color(red: 0.48, green: 0.53, blue: 0.60) : Color(red: 0.58, green: 0.63, blue: 0.70))
                .padding(.bottom, 4)
        }
    }
}
