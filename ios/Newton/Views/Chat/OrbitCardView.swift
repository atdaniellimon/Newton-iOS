//
//  OrbitCardView.swift
//  Newton
//
//  Created for Newton iOS.
//  Clean, executive cards for Orbit Tools: PDF Generation, Web Search Citations, and Calculators.
//

import SwiftUI
import QuickLook
import SafariServices

public struct OrbitCardView: View {
    public let result: OrbitExecutionResult
    
    public init(result: OrbitExecutionResult) {
        self.result = result
    }
    
    public var body: some View {
        let name = result.orbitName.lowercased()
        if name == "image_gen" || name == "generate_image" || name == "imagine" || name == "draw" {
            EmptyView()
        } else if name == "generate_pdf" || name == "pdf" || name == "create_pdf" || name == "make_pdf" {
            PDFDocumentCardView(result: result)
        } else if name == "web_search" || name == "search" || name == "search_web" {
            WebSearchSourcesCardView(result: result)
        } else if name == "kick" || name == "terminate" {
            KickProtocolCardView(result: result)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "circle.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(NewtonTheme.sand)
                    
                    Text("Orbit: \(result.orbitName.uppercased())")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(NewtonTheme.sand)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundColor(NewtonTheme.sand)
                }
                
                Text(result.result)
                    .font(.system(size: 12))
                    .foregroundColor(NewtonTheme.textPrimary)
                    .lineLimit(4)
            }
            .padding(10)
            .background(NewtonTheme.surface.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(NewtonTheme.border, lineWidth: 0.8)
            )
        }
    }
}

public struct KickProtocolCardView: View {
    public let result: OrbitExecutionResult
    
    private var kickReason: String {
        if let data = result.params.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let reason = json["reason"] as? String, !reason.isEmpty {
            return reason
        }
        if let titleRegex = try? NSRegularExpression(pattern: "\"reason\"\\s*:\\s*\"([^\"]+)\""),
           let match = titleRegex.firstMatch(in: result.params, range: NSRange(location: 0, length: (result.params as NSString).length)),
           match.numberOfRanges > 1 {
            return (result.params as NSString).substring(with: match.range(at: 1))
        }
        return result.result.isEmpty ? "Operational boundary violations or systematic refusal." : result.result
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 14))
                    .foregroundColor(NewtonTheme.coralRed)
                
                Text("Session ended by Newton")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundColor(NewtonTheme.coralRed)
                
                Spacer()
                
                Text("TERMINATED")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(NewtonTheme.coralRed)
                    .clipShape(Capsule())
            }
            
            Text("Reason: \(kickReason)")
                .font(.system(size: 12, design: .serif))
                .foregroundColor(NewtonTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(NewtonTheme.coralRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NewtonTheme.coralRed.opacity(0.4), lineWidth: 1)
        )
    }
}


public struct WebSearchSourceItem: Identifiable {
    public let id: String
    public let title: String
    public let url: URL
    public let domain: String
    public let snippet: String
}

public struct WebSearchSourcesCardView: View {
    public let result: OrbitExecutionResult
    @State private var isExpanded: Bool = false
    @State private var selectedSafariUrl: URL? = nil
    
    private var sources: [WebSearchSourceItem] {
        var items: [WebSearchSourceItem] = []
        let raw = result.result
        
        // Parse "URL: https://..." and titles
        let lines = raw.components(separatedBy: .newlines)
        var currentTitle: String? = nil
        var currentUrl: URL? = nil
        var currentSnippet: String = ""
        var currentId: String = UUID().uuidString
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Citation ID:") {
                currentId = trimmed.replacingOccurrences(of: "Citation ID:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("URL:") || trimmed.hasPrefix("url:") {
                let urlStr = trimmed.replacingOccurrences(of: "URL:", with: "").replacingOccurrences(of: "url:", with: "").trimmingCharacters(in: .whitespaces)
                if let u = URL(string: urlStr) {
                    currentUrl = u
                }
            } else if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                if let u = URL(string: trimmed) {
                    currentUrl = u
                }
            } else if trimmed.hasPrefix("title:") || trimmed.hasPrefix("Title:") {
                currentTitle = trimmed.replacingOccurrences(of: "title:", with: "").replacingOccurrences(of: "Title:", with: "").trimmingCharacters(in: .whitespaces)
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("Found ") && !trimmed.hasPrefix("Last Updated:") && !trimmed.hasPrefix("description:") && !trimmed.hasPrefix("keywords:") && currentTitle == nil {
                currentTitle = trimmed
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("Last Updated:") && !trimmed.hasPrefix("keywords:") {
                if currentSnippet.isEmpty {
                    currentSnippet = trimmed
                }
            }
            
            if let u = currentUrl {
                let d = u.host?.replacingOccurrences(of: "www.", with: "") ?? "web"
                let t = currentTitle ?? d
                items.append(WebSearchSourceItem(id: currentId, title: t, url: u, domain: d, snippet: currentSnippet))
                currentTitle = nil
                currentUrl = nil
                currentSnippet = ""
                currentId = UUID().uuidString
            }
        }
        
        // Deduplicate by URL
        var unique: [WebSearchSourceItem] = []
        var seenUrls: Set<String> = []
        for item in items {
            let key = item.url.absoluteString
            if !seenUrls.contains(key) {
                seenUrls.insert(key)
                unique.append(item)
            }
        }
        return unique
    }
    
    public var body: some View {
        let parsed = sources
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 13))
                        .foregroundColor(NewtonTheme.sand)
                    
                    Text(parsed.isEmpty ? "Web Search" : "\(parsed.count) Sources Consulted")
                        .font(.system(size: 12.5, weight: .semibold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            
            // Horizontal scrolling source chips when collapsed
            if !isExpanded && !parsed.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(parsed.prefix(4).enumerated()), id: \.element.id) { index, item in
                            Button(action: {
                                selectedSafariUrl = item.url
                            }) {
                                HStack(spacing: 5) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(NewtonTheme.sand)
                                    
                                    Text(item.domain)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(NewtonTheme.textPrimary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(NewtonTheme.surface)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(NewtonTheme.border, lineWidth: 0.6)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // Expanded full list of sources
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(parsed.enumerated()), id: \.element.id) { index, item in
                        Button(action: {
                            selectedSafariUrl = item.url
                        }) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("[\(index + 1)]")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(NewtonTheme.sand)
                                    .frame(width: 24, alignment: .leading)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(NewtonTheme.textPrimary)
                                        .lineLimit(1)
                                    
                                    Text(item.domain)
                                        .font(.system(size: 10.5))
                                        .foregroundColor(NewtonTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9))
                                    .foregroundColor(NewtonTheme.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(NewtonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NewtonTheme.border, lineWidth: 0.8)
        )
        .sheet(item: Binding(
            get: { selectedSafariUrl.map { IdentifiableURL(url: $0) } },
            set: { selectedSafariUrl = $0?.url }
        )) { item in
            SafariView(url: item.url)
        }
    }
}

public struct SafariView: UIViewControllerRepresentable {
    public let url: URL
    
    public func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    public func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

public struct PDFDocumentCardView: View {
    public let result: OrbitExecutionResult
    @State private var shareUrl: URL? = nil
    
    private var pdfUrl: URL? {
        let path = result.result.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("file://"), let url = URL(string: path) {
            return url
        }
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        if let start = path.range(of: "](")?.upperBound,
           let end = path.range(of: ")", range: start..<path.endIndex)?.lowerBound {
            let extracted = String(path[start..<end])
            if extracted.hasPrefix("file://"), let url = URL(string: extracted) {
                return url
            }
            if FileManager.default.fileExists(atPath: extracted) {
                return URL(fileURLWithPath: extracted)
            }
        }
        return nil
    }
    
    private var documentTitle: String {
        if let data = result.params.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let title = json["title"] as? String, !title.isEmpty {
            return title
        }
        if let pdfUrl = pdfUrl {
            return pdfUrl.deletingPathExtension().lastPathComponent
        }
        return "Documento Newton"
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(NewtonTheme.coralRed.opacity(0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 22))
                        .foregroundColor(NewtonTheme.coralRed)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(documentTitle)
                        .font(.system(size: 14.5, weight: .semibold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                        .lineLimit(1)
                    
                    Text("Documento PDF • Listo para ver y compartir")
                        .font(.system(size: 11.5))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
                
                Spacer()
            }
            
            if let url = pdfUrl {
                HStack(spacing: 10) {
                    Button {
                        shareUrl = url
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Compartir PDF")
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        .foregroundColor(NewtonTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(NewtonTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    
                    ShareLink(item: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Guardar")
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        .foregroundColor(NewtonTheme.sand)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(NewtonTheme.sand.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .background(NewtonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NewtonTheme.border, lineWidth: 0.8)
        )
        .sheet(item: Binding(
            get: { shareUrl.map { IdentifiableURL(url: $0) } },
            set: { shareUrl = $0?.url }
        )) { item in
            ActivityShareView(activityItems: [item.url])
        }
    }
}
