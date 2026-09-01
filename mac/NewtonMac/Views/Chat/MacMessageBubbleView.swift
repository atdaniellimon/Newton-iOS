//
//  MacMessageBubbleView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import AppKit

public struct MacMessageBubbleView: View {
    public let message: Message
    public var onRetry: (() -> Void)? = nil
    
    @State private var copied: Bool = false
    
    public var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer(minLength: 80)
                
                VStack(alignment: .trailing, spacing: 6) {
                    if let imgStr = message.imageUrl, let nsImg = decodeBase64ToNSImage(imgStr) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 320, maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.15, green: 0.18, blue: 0.20))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(NewtonTheme.userBubble)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .contextMenu {
                    Button("Copy Message") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    // Thinking Chain if present
                    if let thinking = message.thinkingContent, !thinking.isEmpty {
                        MacThinkingCardView(content: thinking)
                    }
                    
                    // Orbit results (PDF, Web Search, Calculator)
                    ForEach(message.orbitResults) { orbit in
                        MacOrbitCardView(result: orbit)
                    }
                    
                    // Live Image Synthesis Placeholder in Progress
                    if message.imageUrl == nil && message.isStreaming && message.content.contains("generate_image") {
                        MacImageGenerationPlaceholderView()
                    }
                    
                    // Generated Image if present
                    if let imgUrlStr = message.imageUrl {
                        MacGeneratedImageView(urlStr: imgUrlStr)
                    }
                    
                    // Main Text Content
                    if !message.content.isEmpty {
                        MacFormattedAssistantContent(content: message.content)
                            .textSelection(.enabled)
                    }
                    
                    // Action Buttons Bar (Copy, Speak, Retry)
                    if !message.isStreaming && (!message.content.isEmpty || message.imageUrl != nil) {
                        HStack(spacing: 12) {
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.content, forType: .string)
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copied = false
                                }
                            }) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(copied ? NewtonTheme.forestGreen : NewtonTheme.textSecondary)
                            
                            Button(action: {
                                SpeechService.shared.toggleSpeech(for: message.id, text: message.content)
                            }) {
                                Image(systemName: (SpeechService.shared.isSpeaking && SpeechService.shared.currentlySpeakingMessageId == message.id) ? "speaker.wave.3.fill" : "speaker.wave.2")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor((SpeechService.shared.isSpeaking && SpeechService.shared.currentlySpeakingMessageId == message.id) ? NewtonTheme.sand : NewtonTheme.textSecondary)
                            
                            if let retry = onRetry {
                                Button(action: {
                                    retry()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(NewtonTheme.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func decodeBase64ToNSImage(_ str: String) -> NSImage? {
        var base64 = str
        if let commaIndex = str.firstIndex(of: ",") {
            base64 = String(str[str.index(after: commaIndex)...])
        }
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return nil }
        return NSImage(data: data)
    }
}

public struct MacThinkingCardView: View {
    public let content: String
    @State private var isExpanded: Bool = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11))
                        .foregroundColor(NewtonTheme.sand)
                    
                    Text(isExpanded ? "Hide Thinking Process" : "View Thinking Process")
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundColor(NewtonTheme.textSecondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(NewtonTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text(content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(NewtonTheme.textSecondary)
                    .padding(10)
                    .background(NewtonTheme.surface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

public struct MacGeneratedImageView: View {
    public let urlStr: String
    @State private var nsImage: NSImage? = nil
    
    public var body: some View {
        Group {
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 480, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(NewtonTheme.border, lineWidth: 0.8)
                    )
            } else {
                MacImageGenerationPlaceholderView()
            }
        }
        .task(id: urlStr) {
            loadImage()
        }
    }
    
    private func loadImage() {
        if urlStr.hasPrefix("data:image/") {
            var base64 = urlStr
            if let comma = urlStr.firstIndex(of: ",") {
                base64 = String(urlStr[urlStr.index(after: comma)...])
            }
            if let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
               let img = NSImage(data: data) {
                self.nsImage = img
            }
        } else if let url = URL(string: urlStr) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = NSImage(data: data) {
                    await MainActor.run {
                        self.nsImage = img
                    }
                }
            }
        }
    }
}

public struct MacFormattedAssistantContent: View {
    public let content: String
    
    private var cleanContent: String {
        var text = content
        let orbitPattern = "\\[ORBIT:[\\w\\-_]+\\][\\s\\S]*?(?:\\[/ORBIT\\]|$)"
        if let regex = try? NSRegularExpression(pattern: orbitPattern, options: [.caseInsensitive]) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
        }
        let jsonPattern = "```(?:json)?\\s*\\{\\s*\"name\"\\s*:[\\s\\S]*?\\}\\s*```"
        if let regex = try? NSRegularExpression(pattern: jsonPattern, options: [.caseInsensitive]) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public var body: some View {
        Text(LocalizedStringKey(cleanContent))
            .font(.system(size: 14.5, design: .serif))
            .foregroundColor(NewtonTheme.textPrimary)
            .lineSpacing(4)
    }
}
