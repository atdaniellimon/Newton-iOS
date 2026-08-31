//
//  MessageBubbleView.swift
//  Newton
//
//  Created for Newton iOS.
//  Clean studio-grade typography layout matching Claude iOS & Newton Web.
//

import SwiftUI
import UIKit

public struct MessageBubbleView: View {
    public let message: Message
    public var onRetry: (() -> Void)? = nil
    public var onEdit: ((Message) -> Void)? = nil
    
    @State private var copied: Bool = false
    
    public init(message: Message, onRetry: (() -> Void)? = nil, onEdit: ((Message) -> Void)? = nil) {
        self.message = message
        self.onRetry = onRetry
        self.onEdit = onEdit
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if message.role == .user {
                // User Message Pill (Aligned to trailing with image attachment support)
                HStack {
                    Spacer(minLength: 48)
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        // User attached image preview
                        if let imgStr = message.imageUrl {
                            UserAttachedImageView(imageString: imgStr)
                        }
                        
                        if !message.content.isEmpty {
                            Text(message.content)
                                .font(.system(size: 15.5, weight: .regular))
                                .foregroundColor(Color.black.opacity(0.9))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(NewtonTheme.userBubble)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                            Haptics.light()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        if let onEdit = onEdit {
                            Button {
                                Haptics.light()
                                onEdit(message)
                            } label: {
                                Label("Edit Message", systemImage: "pencil")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                
            } else {
                // Assistant Message (Clean serif typography on canvas, no heavy bounding box)
                VStack(alignment: .leading, spacing: 10) {
                    // Thinking Chain if present
                    if let thinking = message.thinkingContent, !thinking.isEmpty {
                        ThinkingCardView(content: thinking)
                    }
                    
                    // Orbit results
                    ForEach(message.orbitResults) { orbit in
                        OrbitCardView(result: orbit)
                    }
                    
                    // Generated Image (if present)
                    if let imgUrlStr = message.imageUrl, let url = URL(string: imgUrlStr) {
                        GeneratedImageCardView(url: url)
                    }
                    
                    // Main Text Content with elegant Serif typography
                    if !message.content.isEmpty {
                        FormattedAssistantContent(content: message.content)
                            .textSelection(.enabled)
                    }
                    
                    // Action Buttons Bar (Copy, Share, Regenerate)
                    if !message.isStreaming && (!message.content.isEmpty || message.imageUrl != nil) {
                        HStack(spacing: 16) {
                            Button(action: {
                                UIPasteboard.general.string = message.content
                                Haptics.light()
                                withAnimation { copied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { copied = false }
                                }
                            }) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 13))
                                    .foregroundColor(copied ? NewtonTheme.forestGreen : NewtonTheme.textSecondary)
                            }
                            
                            ShareLink(item: message.content) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 13))
                                    .foregroundColor(NewtonTheme.textSecondary)
                            }
                            
                            if let retry = onRetry {
                                Button(action: {
                                    Haptics.light()
                                    retry()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 13))
                                        .foregroundColor(NewtonTheme.textSecondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
    }
}

public struct UserAttachedImageView: View {
    public let imageString: String
    
    public var body: some View {
        if imageString.hasPrefix("data:image/"),
           let commaIndex = imageString.firstIndex(of: ","),
           let data = Data(base64Encoded: String(imageString[imageString.index(after: commaIndex)...])),
           let uiImg = UIImage(data: data) {
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: 220, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(NewtonTheme.border, lineWidth: 0.8)
                )
        } else if let url = URL(string: imageString) {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(maxWidth: 220, maxHeight: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

public struct GeneratedImageCardView: View {
    public let url: URL
    
    public var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Generating image...")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(NewtonTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(NewtonTheme.border, lineWidth: 0.8)
                    )
                    .contextMenu {
                        ShareLink(item: url) {
                            Label("Share Image", systemImage: "square.and.arrow.up")
                        }
                    }
                
            case .failure:
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundColor(NewtonTheme.coralRed)
                    Text("Unable to load generated image")
                        .font(.system(size: 12))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .background(NewtonTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                
            @unknown default:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }
}

public struct FormattedAssistantContent: View {
    public let content: String
    
    public init(content: String) {
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let blocks = parseContent(content)
            ForEach(0..<blocks.count, id: \.self) { idx in
                let block = blocks[idx]
                if block.isCode {
                    CodeBlockView(code: block.text, language: block.language)
                } else {
                    // Serif typography for AI responses matching Newton & Claude
                    Text(LocalizedStringKey(block.text))
                        .font(.system(size: 16.5, weight: .regular, design: .serif))
                        .lineSpacing(5.0)
                        .foregroundColor(NewtonTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
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
