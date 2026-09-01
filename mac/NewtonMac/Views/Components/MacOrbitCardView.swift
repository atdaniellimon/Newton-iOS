//
//  MacOrbitCardView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//

import SwiftUI
import AppKit

public struct MacOrbitCardView: View {
    public let result: OrbitExecutionResult
    
    public init(result: OrbitExecutionResult) {
        self.result = result
    }
    
    public var body: some View {
        let name = result.orbitName.lowercased()
        if name == "generate_pdf" || name == "pdf" || name == "create_pdf" || name == "make_pdf" {
            MacPDFDocumentCardView(result: result)
        } else if name == "web_search" || name == "search" || name == "search_web" {
            MacWebSearchSourcesCardView(result: result)
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
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(NewtonTheme.border, lineWidth: 0.8)
            )
        }
    }
}

public struct MacWebSearchSourceItem: Identifiable {
    public let id: String
    public let title: String
    public let url: URL
    public let domain: String
    public let snippet: String
}

public struct MacSourcePillView: View {
    public let index: Int
    public let item: MacWebSearchSourceItem
    
    public var body: some View {
        Button(action: {
            NSWorkspace.shared.open(item.url)
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

public struct MacSourceRowView: View {
    public let index: Int
    public let item: MacWebSearchSourceItem
    
    public var body: some View {
        Button(action: {
            NSWorkspace.shared.open(item.url)
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

public struct MacWebSearchSourcesCardView: View {
    public let result: OrbitExecutionResult
    @State private var isExpanded: Bool = false
    
    private var sources: [MacWebSearchSourceItem] {
        var items: [MacWebSearchSourceItem] = []
        let raw = result.result
        
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
                items.append(MacWebSearchSourceItem(id: currentId, title: t, url: u, domain: d, snippet: currentSnippet))
                currentTitle = nil
                currentUrl = nil
                currentSnippet = ""
                currentId = UUID().uuidString
            }
        }
        
        var unique: [MacWebSearchSourceItem] = []
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
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            
            if !isExpanded && !parsed.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(parsed.prefix(4).enumerated()), id: \.element.id) { index, item in
                            MacSourcePillView(index: index, item: item)
                        }
                    }
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(parsed.enumerated()), id: \.element.id) { index, item in
                        MacSourceRowView(index: index, item: item)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(NewtonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NewtonTheme.border, lineWidth: 0.8)
        )
    }
}

public struct MacPDFDocumentCardView: View {
    public let result: OrbitExecutionResult
    
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
        if let titleRegex = try? NSRegularExpression(pattern: "\"title\"\\s*:\\s*\"([^\"]+)\""),
           let match = titleRegex.firstMatch(in: result.params, range: NSRange(location: 0, length: (result.params as NSString).length)),
           match.numberOfRanges > 1 {
            return (result.params as NSString).substring(with: match.range(at: 1))
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
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20))
                        .foregroundColor(NewtonTheme.coralRed)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(documentTitle)
                        .font(.system(size: 13.5, weight: .semibold, design: .serif))
                        .foregroundColor(NewtonTheme.textPrimary)
                        .lineLimit(1)
                    
                    Text("Documento PDF • Listo para ver y compartir")
                        .font(.system(size: 11))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
                
                Spacer()
            }
            
            if let url = pdfUrl {
                HStack(spacing: 10) {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                            Text("Mostrar en Finder")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(NewtonTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(NewtonTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye")
                                .font(.system(size: 11))
                            Text("Abrir PDF")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(NewtonTheme.sand)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(NewtonTheme.sand.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(NewtonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NewtonTheme.border, lineWidth: 0.8)
        )
    }
}
