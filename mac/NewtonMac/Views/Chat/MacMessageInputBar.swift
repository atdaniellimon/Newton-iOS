//
//  MacMessageInputBar.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import AppKit

public struct MacMessageInputBar: View {
    @Binding public var text: String
    public var isStreaming: Bool
    public var onSend: () -> Void
    public var onStop: () -> Void
    public var onAttachFile: (() -> Void)? = nil
    
    public init(text: Binding<String>, isStreaming: Bool, onSend: @escaping () -> Void, onStop: @escaping () -> Void, onAttachFile: (() -> Void)? = nil) {
        self._text = text
        self.isStreaming = isStreaming
        self.onSend = onSend
        self.onStop = onStop
        self.onAttachFile = onAttachFile
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                // File Attachment Button
                if let onAttachFile = onAttachFile {
                    Button(action: onAttachFile) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 14))
                            .foregroundColor(NewtonTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 6)
                }
                
                // Text Editor
                MacTextEditorRepresentable(text: $text, onCommit: onSend)
                    .frame(minHeight: 28, maxHeight: 120)
                    .background(Color.clear)
                
                // Send / Stop Button
                if isStreaming {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(NewtonTheme.coralRed)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 3)
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NewtonTheme.textTertiary : NewtonTheme.sand)
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.bottom, 3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(NewtonTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(NewtonTheme.border, lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
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
        textView.font = NSFont.systemFont(ofSize: 13.5)
        textView.textColor = NSColor.labelColor
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
                    return false // Allow Shift+Return for new line
                } else {
                    parent.onCommit()
                    return true
                }
            }
            return false
        }
    }
}
