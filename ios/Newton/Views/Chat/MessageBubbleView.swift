//
//  MessageBubbleView.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI
import UIKit

public struct MessageBubbleView: View {
    public let message: Message
    public var onRetry: (() -> Void)? = nil
    public var onEdit: ((Message) -> Void)? = nil
    
    @State private var copied: Bool = false
    @State private var previewImageString: String? = nil
    @State private var showingSnapshotCard: Bool = false
    
    public var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
                
                // User Message Bubble (Sand pill with context menu)
                VStack(alignment: .trailing, spacing: 6) {
                    if let imgStr = message.imageUrl {
                        Button {
                            Haptics.light()
                            previewImageString = imgStr
                        } label: {
                            UserAttachedImageView(imageString: imgStr)
                        }
                    }
                    
                    // Native Visual File Attachments
                    ForEach(message.attachments) { att in
                        AttachmentCardView(attachment: att)
                            .frame(maxWidth: 280)
                    }
                    
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.15, green: 0.18, blue: 0.20))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(NewtonTheme.userBubble)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.content
                        Haptics.light()
                    } label: {
                        Label("Copy Message", systemImage: "doc.on.doc")
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
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                
            } else {
                // Assistant Message (Clean serif typography on canvas)
                VStack(alignment: .leading, spacing: 10) {
                    // Thinking Chain if present
                    if let thinking = message.thinkingContent, !thinking.isEmpty {
                        ThinkingCardView(content: thinking)
                    }
                    
                    // Orbit results (with Web Citations)
                    ForEach(message.orbitResults) { orbit in
                        if orbit.orbitName.lowercased().contains("search") || orbit.orbitName.lowercased().contains("web") {
                            WebCitationCardView(citation: WebCitation(
                                title: "Búsqueda Web: \(orbit.params)",
                                urlString: "https://duckduckgo.com/?q=\(orbit.params.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                                snippet: orbit.result,
                                citationNumber: 1
                            ))
                        } else {
                            OrbitCardView(result: orbit)
                        }
                    }
                    
                    // Native Visual File Attachments
                    ForEach(message.attachments) { att in
                        AttachmentCardView(attachment: att)
                    }
                    
                    // Interactive Chart if detected
                    if let chartPayload = InteractiveChartView.extractChartData(from: message.content) {
                        InteractiveChartView(data: chartPayload)
                    }
                    
                    // Live Image Synthesis Placeholder in Progress
                    if message.imageUrl == nil && message.isStreaming && message.content.contains("generate_image") {
                        ImageGenerationPlaceholderView()
                    }
                    
                    // Generated Image (tap to open full screen)
                    if let imgUrlStr = message.imageUrl {
                        Button {
                            Haptics.light()
                            previewImageString = imgUrlStr
                        } label: {
                            GeneratedImageCardView(urlStr: imgUrlStr)
                        }
                    }
                    
                    // Main Text Content with elegant Serif typography
                    if !message.content.isEmpty {
                        FormattedAssistantContent(content: message.content)
                            .textSelection(.enabled)
                    }
                    
                    // Action Buttons Bar (Copy, TTS, Snapshot Card, Share, Regenerate)
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
                            
                            // TTS Speak Aloud Button
                            Button(action: {
                                Haptics.light()
                                SpeechService.shared.toggleSpeech(for: message.id, text: message.content)
                            }) {
                                Image(systemName: (SpeechService.shared.isSpeaking && SpeechService.shared.currentlySpeakingMessageId == message.id) ? "speaker.wave.3.fill" : "speaker.wave.2")
                                    .font(.system(size: 13))
                                    .foregroundColor((SpeechService.shared.isSpeaking && SpeechService.shared.currentlySpeakingMessageId == message.id) ? NewtonTheme.sand : NewtonTheme.textSecondary)
                            }
                            
                            // Shareable Code / Snapshot Card Button
                            Button(action: {
                                showingSnapshotCard = true
                                Haptics.light()
                            }) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 13))
                                    .foregroundColor(NewtonTheme.textSecondary)
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
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                
                Spacer(minLength: 24)
            }
        }
        .fullScreenCover(item: Binding(
            get: { previewImageString.map { IdentifiableString(value: $0) } },
            set: { previewImageString = $0?.value }
        )) { item in
            FullScreenImageViewer(imageString: item.value, onDismiss: {
                previewImageString = nil
            })
        }
        .sheet(isPresented: $showingSnapshotCard) {
            ShareableCardGenerator(codeSnippet: message.content, language: "swift", title: "Newton Singularity")
        }
    }
}

public struct IdentifiableString: Identifiable {
    public let id = UUID()
    public let value: String
}

public struct FullScreenImageViewer: View {
    public let imageString: String
    public var onDismiss: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var loadedUIImage: UIImage? = nil
    @State private var savedToast: Bool = false
    
    public init(imageString: String, onDismiss: (() -> Void)? = nil) {
        self.imageString = imageString
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Image with pinch-to-zoom and pan gestures
            if let uiImg = loadedUIImage {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { val in
                                let delta = val / lastScale
                                lastScale = val
                                scale = min(max(scale * delta, 1.0), 5.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 { withAnimation { scale = 1.0; offset = .zero } }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { val in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + val.translation.width,
                                        height: lastOffset.height + val.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
            } else {
                ProgressView()
                    .tint(.white)
            }
            
            // Top Controls Bar
            VStack {
                HStack {
                    Button(action: {
                        if let dismissCallback = onDismiss {
                            dismissCallback()
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    if let img = loadedUIImage {
                        // Copy image
                        Button(action: {
                            UIPasteboard.general.image = img
                            Haptics.success()
                        }) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.trailing, 8)
                        
                        // Save image to Camera Roll
                        Button(action: saveToCameraRoll) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.trailing, 8)
                        
                        // Share Sheet
                        ShareLink(item: Image(uiImage: img), preview: SharePreview("Newton Image", image: Image(uiImage: img))) {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
                
                if savedToast {
                    Text("Saved to Photos")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .padding(.bottom, 40)
                }
            }
        }
        .task {
            loadImageData()
        }
    }
    
    private func loadImageData() {
        if let img = imageString.decodeBase64ToUIImage() {
            self.loadedUIImage = img
        } else if let url = URL(string: imageString) {
            Task {
                var request = URLRequest(url: url)
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
                if let (data, _) = try? await URLSession.shared.data(for: request),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        self.loadedUIImage = img
                    }
                }
            }
        }
    }
    
    private func saveToCameraRoll() {
        if let uiImg = loadedUIImage {
            UIImageWriteToSavedPhotosAlbum(uiImg, nil, nil, nil)
            Haptics.success()
            withAnimation { savedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { savedToast = false }
            }
        }
    }
}

public struct UserAttachedImageView: View {
    public let imageString: String
    @State private var uiImage: UIImage? = nil
    
    public var body: some View {
        Group {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: 220, maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(NewtonTheme.border, lineWidth: 0.8)
                    )
            } else {
                ProgressView()
                    .frame(width: 120, height: 120)
            }
        }
        .task(id: imageString) {
            if let img = imageString.decodeBase64ToUIImage() {
                self.uiImage = img
            } else if let url = URL(string: imageString) {
                var request = URLRequest(url: url)
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
                if let (data, _) = try? await URLSession.shared.data(for: request),
                   let img = UIImage(data: data) {
                    await MainActor.run { self.uiImage = img }
                }
            }
        }
    }
}

public struct GeneratedImageCardView: View {
    public let urlStr: String
    @State private var uiImage: UIImage? = nil
    @State private var isLoading: Bool = true
    @State private var loadFailed: Bool = false
    
    public var body: some View {
        Group {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(NewtonTheme.border, lineWidth: 0.8)
                    )
            } else if isLoading {
                ImageGenerationPlaceholderView()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundColor(NewtonTheme.coralRed)
                    Text("Unable to load generated image")
                        .font(.system(size: 12))
                        .foregroundColor(NewtonTheme.textSecondary)
                    Button("Retry") {
                        Task { await loadImageAsync() }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(NewtonTheme.sand)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .background(NewtonTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(.vertical, 4)
        .task(id: urlStr) {
            await loadImageAsync()
        }
    }
    
    @MainActor
    private func loadImageAsync() async {
        isLoading = true
        loadFailed = false
        
        // 1. Instant robust Base64 decoding
        if let decodedImg = urlStr.decodeBase64ToUIImage() {
            self.uiImage = decodedImg
            self.isLoading = false
            return
        }
        
        // 2. Remote URL handling with URLSession
        guard let url = URL(string: urlStr) else {
            self.isLoading = false
            self.loadFailed = true
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
               let img = UIImage(data: data) {
                self.uiImage = img
                self.isLoading = false
            } else {
                self.isLoading = false
                self.loadFailed = true
            }
        } catch is CancellationError {
            // Ignore cancellation on view redraw
            return
        } catch {
            guard !Task.isCancelled else { return }
            self.isLoading = false
            self.loadFailed = true
        }
    }
}

public struct FormattedAssistantContent: View {
    public let content: String
    
    private var cleanContent: String {
        var text = content
        // Strip any full or partially streaming [ORBIT:name]...[/ORBIT] tags
        let orbitPattern = "\\[ORBIT:[\\w\\-_]+\\][\\s\\S]*?(?:\\[/ORBIT\\]|$)"
        if let regex = try? NSRegularExpression(pattern: orbitPattern, options: [.caseInsensitive]) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
        }
        // Strip natural chain-of-thought + orbit/download tags (parsed into cards, never shown raw)
        let thinkTagPattern = "<think(?:ing)?>[\\s\\S]*?(?:</think(?:ing)?>|$)"
        if let regex = try? NSRegularExpression(pattern: thinkTagPattern, options: [.caseInsensitive]) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
        }
        let natOrbitPattern = "<orbit:[^>]*>[\\s\\S]*?(?:</orbit:[^>]*>|$)"
        if let regex = try? NSRegularExpression(pattern: natOrbitPattern, options: [.caseInsensitive]) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
        }
        let dlTagPattern = "<download>[\\s\\S]*?(?:</download>|$)"
        if let regex = try? NSRegularExpression(pattern: dlTagPattern, options: [.caseInsensitive]) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
        }
        // Strip json tool calls
        let jsonPattern = "```(?:json)?\\s*\\{\\s*\"name\"\\s*:[\\s\\S]*?\\}\\s*```"
        if let regex = try? NSRegularExpression(pattern: jsonPattern, options: [.caseInsensitive]) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
        }
        let mdImgPattern = "!\\[.*?\\]\\(.*?\\)"
        if let regex = try? NSRegularExpression(pattern: mdImgPattern, options: []) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
        }
        text = text.replacingOccurrences(of: "Generated Image", with: "")
        text = text.replacingOccurrences(of: "Imagen generada", with: "")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var blocks: [ContentBlock] {
        parseContentBlocks(cleanContent)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                if block.isCode, let code = block.code {
                    CodeBlockView(code: code, language: block.language ?? "")
                } else if let txt = block.text {
                    Text(LocalizedStringKey(txt))
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                        .lineSpacing(4)
                }
            }
        }
    }
    
    private func parseContentBlocks(_ raw: String) -> [ContentBlock] {
        var resultBlocks: [ContentBlock] = []
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

public struct ContentBlock: Identifiable {
    public let id = UUID()
    public let text: String?
    public let language: String?
    public let code: String?
    public let isCode: Bool
    
    public static func text(_ str: String) -> ContentBlock {
        ContentBlock(text: str, language: nil, code: nil, isCode: false)
    }
    
    public static func code(language: String, code: String) -> ContentBlock {
        ContentBlock(text: nil, language: language, code: code, isCode: true)
    }
}
