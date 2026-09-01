//
//  MacMessageInputBar.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Fully focusable, auto-expanding input bar with Enter to send, Shift+Enter for newline, and transparent background.
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
    @State private var dynamicHeight: CGFloat = 26
    
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
        VStack(spacing: 6) {
            // Floating Input Container
            VStack(spacing: 2) {
                // Auto-growing Text Input
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Ask Newton anything...")
                            .font(.system(size: 13.5))
                            .foregroundColor(isDark ? Color(red: 0.50, green: 0.55, blue: 0.62) : Color(red: 0.60, green: 0.65, blue: 0.72))
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
                                isWebSearchEnabled = false
                            }
                        }
                    )
                    .frame(height: max(26, min(dynamicHeight, 130)))
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                }
                
                // Bottom Toolbar (Attachments, Search, Send)
                HStack(spacing: 12) {
                    // Paperclip Attachment Button
                    Button(action: onAttachFile) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 13.5))
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
                            .font(.system(size: 13.5))
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
                                    .frame(width: 26, height: 26)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white)
                                    .frame(width: 9, height: 9)
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
                                    .frame(width: 26, height: 26)
                                
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(canSend ? (isDark ? Color(red: 0.08, green: 0.10, blue: 0.13) : Color.white) : (isDark ? Color(red: 0.45, green: 0.50, blue: 0.58) : Color(red: 0.55, green: 0.60, blue: 0.68)))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSend)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
                .padding(.top, 2)
            }
            .background(isDark ? Color(red: 0.14, green: 0.17, blue: 0.22) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isDark ? Color(red: 0.24, green: 0.28, blue: 0.36) : Color(red: 0.88, green: 0.90, blue: 0.94), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.25 : 0.04), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 48)
            
            // Bottom Disclaimer Text
            Text("Newton AI may produce creative or technical output. Verify important data.")
                .font(.system(size: 10))
                .foregroundColor(isDark ? Color(red: 0.48, green: 0.53, blue: 0.60) : Color(red: 0.58, green: 0.63, blue: 0.70))
                .padding(.bottom, 2)
        }
    }
}

public struct MacAutoGrowingTextView: NSViewRepresentable {
    @Binding public var text: String
    @Binding public var dynamicHeight: CGFloat
    public var onCommit: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 4
        layoutManager.addTextContainer(textContainer)
        
        let textView = CustomNSTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0.0, height: 22)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = NSFont.systemFont(ofSize: 13.5)
        textView.textColor = colorScheme == .dark ? NSColor.white : NSColor(red: 0.08, green: 0.11, blue: 0.16, alpha: 1.0)
        textView.insertionPointColor = colorScheme == .dark ? NSColor.white : NSColor.black
        textView.delegate = context.coordinator
        textView.onCommit = onCommit
        
        scrollView.documentView = textView
        return scrollView
    }
    
    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CustomNSTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
        
        textView.textColor = colorScheme == .dark ? NSColor.white : NSColor(red: 0.08, green: 0.11, blue: 0.16, alpha: 1.0)
        textView.insertionPointColor = colorScheme == .dark ? NSColor.white : NSColor.black
        textView.onCommit = onCommit
        
        DispatchQueue.main.async {
            self.recalculateHeight(textView)
        }
    }
    
    private func recalculateHeight(_ textView: NSTextView) {
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let newHeight = max(26, min(usedRect.height + 4, 130))
        if abs(dynamicHeight - newHeight) > 1 {
            dynamicHeight = newHeight
        }
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacAutoGrowingTextView
        
        init(_ parent: MacAutoGrowingTextView) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.recalculateHeight(textView)
        }
    }
}

public class CustomNSTextView: NSTextView {
    public var onCommit: (() -> Void)? = nil
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 { // Return Key
            if event.modifierFlags.contains(.shift) {
                // Shift+Return: Insert newline
                super.insertNewline(nil)
            } else {
                // Return only: Send Message
                onCommit?()
            }
        } else {
            super.keyDown(with: event)
        }
    }
}
