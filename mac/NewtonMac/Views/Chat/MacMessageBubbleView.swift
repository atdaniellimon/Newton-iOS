//
//  MacMessageBubbleView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  Message bubble with 3D Thinking Orb when generating responses.
//

import SwiftUI
import AppKit

public struct MacMessageBubbleView: View {
    public let message: Message
    public var onRetry: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var copied: Bool = false
    
    private var isDark: Bool { colorScheme == .dark }
    
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
                    
                    // Live Generating / Thinking 3D Orb Indicator
                    if message.isStreaming && message.content.isEmpty {
                        HStack(spacing: 10) {
                            ThinkingOrbView(size: 26, style: .globe)
                            
                            Text("Newton is reasoning...")
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .foregroundColor(NewtonTheme.sand)
                        }
                        .padding(.vertical, 6)
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
                        
                        // Mini streaming indicator orb while tokens are flowing
                        if message.isStreaming {
                            HStack(spacing: 6) {
                                ThinkingOrbView(size: 14, style: .orbits)
                                Text("Synthesizing...")
                                    .font(.system(size: 11, design: .serif))
                                    .foregroundColor(NewtonTheme.sand.opacity(0.8))
                            }
                            .padding(.top, 2)
                        }
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
                            .foregroundColor(copied ? NewtonTheme.forestGreen : (isDark ? Color(red: 0.65, green: 0.70, blue: 0.78) : NewtonTheme.textSecondary))
                            
                            Button(action: {
                                SpeechService.shared.toggleSpeech(for: message.id, text: message.content)
                            }) {
                                Image(systemName: (SpeechService.shared.isSpeaking && SpeechService.shared.currentlySpeakingMessageId == message.id) ? "speaker.wave.3.fill" : "speaker.wave.2")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor((SpeechService.shared.isSpeaking && SpeechService.shared.currentlySpeakingMessageId == message.id) ? NewtonTheme.sand : (isDark ? Color(red: 0.65, green: 0.70, blue: 0.78) : NewtonTheme.textSecondary))
                            
                            if let onRetry = onRetry {
                                Button(action: onRetry) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(isDark ? Color(red: 0.65, green: 0.70, blue: 0.78) : NewtonTheme.textSecondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.leading, 8)
                
                Spacer(minLength: 40)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func decodeBase64ToNSImage(_ base64Str: String) -> NSImage? {
        let clean = base64Str.replacingOccurrences(of: "data:image/png;base64,", with: "")
            .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
        guard let data = Data(base64Encoded: clean) else { return nil }
        return NSImage(data: data)
    }
}

public struct MacThinkingCardView: View {
    public let content: String
    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.system(size: 11))
                        .foregroundColor(NewtonTheme.sand)
                    
                    Text("Thought Process")
                        .font(.system(size: 11.5, weight: .semibold, design: .serif))
                        .foregroundColor(isDark ? Color(red: 0.85, green: 0.88, blue: 0.94) : Color(red: 0.30, green: 0.35, blue: 0.40))
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isDark ? Color(red: 0.60, green: 0.65, blue: 0.72) : Color(red: 0.50, green: 0.55, blue: 0.60))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isDark ? Color(red: 0.16, green: 0.19, blue: 0.25) : Color(red: 0.95, green: 0.96, blue: 0.98))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text(content)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(isDark ? Color(red: 0.75, green: 0.80, blue: 0.88) : Color(red: 0.35, green: 0.40, blue: 0.45))
                    .padding(10)
                    .background(isDark ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color(red: 0.97, green: 0.98, blue: 0.99))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

public struct MacFormattedAssistantContent: View {
    public let content: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
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
    
    private var blocks: [MacContentBlock] {
        parseContentBlocks(cleanContent)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                if block.isCode, let code = block.code {
                    MacCodeBlockView(code: code, language: block.language ?? "")
                } else if let txt = block.text {
                    Text(LocalizedStringKey(txt))
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundColor(isDark ? Color(red: 0.94, green: 0.96, blue: 0.98) : Color(red: 0.08, green: 0.11, blue: 0.16))
                        .lineSpacing(4)
                }
            }
        }
    }
    
    private func parseContentBlocks(_ raw: String) -> [MacContentBlock] {
        var resultBlocks: [MacContentBlock] = []
        let pattern = "```([a-zA-Z0-9_-]*)\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(raw)]
        }
        
        let nsString = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(location: 0, length: nsString.length))
        
        var currentIndex = 0
        for match in matches {
            let matchRange = match.range
            if matchRange.location > currentIndex {
                let textPart = nsString.substring(with: NSRange(location: currentIndex, length: matchRange.location - currentIndex))
                if !textPart.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    resultBlocks.append(.text(textPart))
                }
            }
            
            let lang = match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound ? nsString.substring(with: match.range(at: 1)) : ""
            let code = match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound ? nsString.substring(with: match.range(at: 2)) : ""
            resultBlocks.append(.code(language: lang, code: code))
            
            currentIndex = matchRange.location + matchRange.length
        }
        
        if currentIndex < nsString.length {
            let remainder = nsString.substring(from: currentIndex)
            if !remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resultBlocks.append(.text(remainder))
            }
        }
        
        return resultBlocks.isEmpty ? [.text(raw)] : resultBlocks
    }
}

public struct MacContentBlock: Identifiable {
    public let id = UUID()
    public let text: String?
    public let language: String?
    public let code: String?
    public let isCode: Bool
    
    public static func text(_ str: String) -> MacContentBlock {
        MacContentBlock(text: str, language: nil, code: nil, isCode: false)
    }
    
    public static func code(language: String, code: String) -> MacContentBlock {
        MacContentBlock(text: nil, language: language, code: code, isCode: true)
    }
}

public struct MacCodeBlockView: View {
    public let code: String
    public let language: String
    @State private var copied: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool { colorScheme == .dark }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(language.isEmpty ? "code" : language.lowercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isDark ? Color(red: 0.70, green: 0.75, blue: 0.82) : Color(red: 0.45, green: 0.50, blue: 0.58))
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(copied ? NewtonTheme.forestGreen : (isDark ? Color(red: 0.70, green: 0.75, blue: 0.82) : Color(red: 0.45, green: 0.50, blue: 0.58)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isDark ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color(red: 0.93, green: 0.94, blue: 0.96))
            
            Divider()
            
            // Code Text
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundColor(isDark ? Color(red: 0.90, green: 0.93, blue: 0.98) : Color(red: 0.10, green: 0.13, blue: 0.18))
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
        .background(isDark ? Color(red: 0.09, green: 0.11, blue: 0.14) : Color(red: 0.98, green: 0.98, blue: 0.99))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isDark ? Color(red: 0.20, green: 0.24, blue: 0.30) : Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 0.8)
        )
        .padding(.vertical, 4)
    }
}

public struct MacGeneratedImageView: View {
    public let urlStr: String
    
    public var body: some View {
        if let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 240, height: 240)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                case .failure:
                    Text("Failed to load generated image")
                        .font(.system(size: 11))
                        .foregroundColor(NewtonTheme.coralRed)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}
