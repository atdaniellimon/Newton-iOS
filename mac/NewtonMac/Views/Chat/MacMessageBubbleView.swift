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
    
    public var body: some View {
        Text(content)
            .font(.system(size: 14, weight: .regular, design: .serif))
            .foregroundColor(isDark ? Color(red: 0.94, green: 0.96, blue: 0.98) : Color(red: 0.08, green: 0.11, blue: 0.16))
            .lineSpacing(4)
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
