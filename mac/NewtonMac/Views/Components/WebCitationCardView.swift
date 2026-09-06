//
//  WebCitationCardView.swift
//  Newton
//
//  Rich link preview & citation cards for Web Search Orbits.
//

import SwiftUI

public struct WebCitation: Identifiable {
    public let id = UUID()
    public let title: String
    public let urlString: String
    public let snippet: String
    public let citationNumber: Int
    
    public init(title: String, urlString: String, snippet: String = "", citationNumber: Int = 1) {
        self.title = title
        self.urlString = urlString
        self.snippet = snippet
        self.citationNumber = citationNumber
    }
}

public struct WebCitationCardView: View {
    public let citation: WebCitation
    
    public init(citation: WebCitation) {
        self.citation = citation
    }
    
    public var body: some View {
        if let url = URL(string: citation.urlString) {
            Link(destination: url) {
                cardBody
            }
            .buttonStyle(.plain)
        } else {
            cardBody
        }
    }
    
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("[\(citation.citationNumber)]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(NewtonTheme.sand)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(NewtonTheme.sand.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                
                Image(systemName: "globe")
                    .font(.system(size: 11))
                    .foregroundColor(NewtonTheme.sand)
                
                Text(hostName(from: citation.urlString))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            Text(citation.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            if !citation.snippet.isEmpty {
                Text(citation.snippet)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(9)
        .frame(width: 220, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(NewtonTheme.sand.opacity(0.25), lineWidth: 0.8)
        )
    }
    
    private func hostName(from urlStr: String) -> String {
        guard let url = URL(string: urlStr), let host = url.host else {
            return urlStr
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
    
    public static func extractCitations(from text: String) -> [WebCitation] {
        var citations: [WebCitation] = []
        let pattern = #"\[(.*?)\]\((https?:\/\/[^\s\)]+)\)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            var index = 1
            for match in matches.prefix(5) {
                if match.numberOfRanges >= 3 {
                    let title = nsString.substring(with: match.range(at: 1))
                    let urlStr = nsString.substring(with: match.range(at: 2))
                    if !citations.contains(where: { $0.urlString == urlStr }) {
                        citations.append(WebCitation(title: title, urlString: urlStr, snippet: "", citationNumber: index))
                        index += 1
                    }
                }
            }
        }
        return citations
    }
}
