//
//  WebCitationCardView.swift
//  Newton
//
//  Rich link preview & citation cards for Web Search Orbits.
//

import SwiftUI

public struct WebCitationCardView: View {
    public let title: String
    public let urlString: String
    public let snippet: String
    public let citationNumber: Int
    
    public init(title: String, urlString: String, snippet: String, citationNumber: Int = 1) {
        self.title = title
        self.urlString = urlString
        self.snippet = snippet
        self.citationNumber = citationNumber
    }
    
    public var body: some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                cardBody
            }
            .buttonStyle(.plain)
        } else {
            cardBody
        }
    }
    
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("[\(citationNumber)]")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(NewtonTheme.sand)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(NewtonTheme.sand.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Image(systemName: "globe")
                    .font(.system(size: 12))
                    .foregroundColor(NewtonTheme.sand)
                
                Text(hostName(from: urlString))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(UIColor.label))
                .lineLimit(2)
            
            if !snippet.isEmpty {
                Text(snippet)
                    .font(.system(size: 11.5))
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
}
