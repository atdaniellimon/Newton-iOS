//
//  MessageBubbleView.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct MessageBubbleView: View {
    public let message: Message
    
    public init(message: Message) {
        self.message = message
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .assistant {
                // Newton Avatar
                ZStack {
                    Circle()
                        .fill(NewtonTheme.sand.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(NewtonTheme.sand)
                }
            } else {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Thinking card if present
                if let thinking = message.thinkingContent, !thinking.isEmpty {
                    ThinkingCardView(content: thinking)
                }
                
                // Orbit result cards
                ForEach(message.orbitResults) { orbit in
                    OrbitCardView(result: orbit)
                }
                
                // Message body
                if message.role == .user {
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(NewtonTheme.messageUserGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    FormattedAssistantContent(content: message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(NewtonTheme.cardDark)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(NewtonTheme.borderDark, lineWidth: 0.6)
                        )
                }
                
                if message.isStreaming {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Newton is thinking...")
                            .font(.system(size: 11))
                            .foregroundColor(NewtonTheme.textSecondary)
                    }
                    .padding(.leading, 4)
                }
            }
            
            if message.role == .user {
                // User Avatar
                ZStack {
                    Circle()
                        .fill(NewtonTheme.surfaceDark)
                        .frame(width: 32, height: 32)
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(NewtonTheme.textPrimary)
                }
            } else {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

public struct FormattedAssistantContent: View {
    public let content: String
    
    public init(content: String) {
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let blocks = parseContent(content)
            ForEach(0..<blocks.count, id: \.self) { idx in
                let block = blocks[idx]
                if block.isCode {
                    CodeBlockView(code: block.text, language: block.language)
                } else {
                    Text(LocalizedStringKey(block.text))
                        .font(.system(size: 14.5))
                        .foregroundColor(NewtonTheme.textPrimary)
                        .textSelection(.enabled)
                }
            }
        }
    }
    
    private struct ContentBlock {
        let text: String
        let isCode: Bool
        let language: String
    }
    
    private func parseContent(_ raw: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let parts = raw.components(separatedBy: "```")
        
        for (i, part) in parts.enumerated() {
            if i % 2 == 1 {
                // Code block
                var lang = ""
                var codeText = part
                if let firstLineEnd = part.firstIndex(of: "\n") {
                    lang = String(part[..<firstLineEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
                    codeText = String(part[part.index(after: firstLineEnd)...])
                }
                blocks.append(ContentBlock(text: codeText.trimmingCharacters(in: .whitespacesAndNewlines), isCode: true, language: lang))
            } else {
                // Normal markdown text
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    blocks.append(ContentBlock(text: trimmed, isCode: false, language: ""))
                }
            }
        }
        
        if blocks.isEmpty {
            blocks.append(ContentBlock(text: raw, isCode: false, language: ""))
        }
        return blocks
    }
}
