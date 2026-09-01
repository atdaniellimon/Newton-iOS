//
//  MacMessageInputBar.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Faithfully recreates the web desktop floating card input bar.
//

import SwiftUI
import AppKit

public struct MacMessageInputBar: View {
    @Binding public var text: String
    public var isStreaming: Bool
    public var onSend: () -> Void
    public var onStop: () -> Void
    public var onAttachFile: (() -> Void)? = nil
    
    @State private var isWebSearchEnabled: Bool = false
    
    public init(text: Binding<String>, isStreaming: Bool, onSend: @escaping () -> Void, onStop: @escaping () -> Void, onAttachFile: (() -> Void)? = nil) {
        self._text = text
        self.isStreaming = isStreaming
        self.onSend = onSend
        self.onStop = onStop
        self.onAttachFile = onAttachFile
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                // Multiline text input
                MacTextEditorRepresentable(text: $text, onCommit: onSend)
                    .frame(minHeight: 36, maxHeight: 120)
                    .background(Color.clear)
                
                // Bottom Toolbar inside the input card
                HStack(spacing: 14) {
                    // Paperclip
                    if let onAttachFile = onAttachFile {
                        Button(action: onAttachFile) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.45, green: 0.50, blue: 0.58))
                        }
                        .buttonStyle(.plain)
                        .help("Attach file or image")
                    }
                    
                    // Web Search Toggle
                    Button(action: {
                        isWebSearchEnabled.toggle()
                        if isWebSearchEnabled && !text.contains("[ORBIT:web_search]") {
                            Haptics.light()
                        }
                    }) {
                        Image(systemName: "globe")
                            .font(.system(size: 15))
                            .foregroundColor(isWebSearchEnabled ? Color(red: 0.06, green: 0.09, blue: 0.16) : Color(red: 0.45, green: 0.50, blue: 0.58))
                    }
                    .buttonStyle(.plain)
                    .help("Web Search Toggle")
                    
                    Spacer()
                    
                    // Send / Stop Arrow Button
                    if isStreaming {
                        Button(action: onStop) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.88, green: 0.35, blue: 0.30))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: onSend) {
                            ZStack {
                                Circle()
                                    .fill(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(red: 0.70, green: 0.74, blue: 0.80) : Color(red: 0.06, green: 0.09, blue: 0.16))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(red: 0.88, green: 0.91, blue: 0.94), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
            
            // Bottom Disclaimer
            Text("Newton AI may produce creative or technical output. Verify important data.")
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.58, green: 0.64, blue: 0.72))
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: 800)
    }
}

public struct MacTextEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    
    public func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1.0)
        
        // Placeholder text support
        if text.isEmpty {
            textView.string = ""
        }
        return textView
    }
    
    public func updateNSView(_ nsView: NSTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacTextEditorRepresentable
        
        init(_ parent: MacTextEditorRepresentable) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
        
        public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                    return false // Shift+Enter allows newline
                } else {
                    parent.onCommit()
                    return true
                }
            }
            return false
        }
    }
}
