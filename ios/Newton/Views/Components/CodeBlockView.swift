//
//  CodeBlockView.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI
import UIKit

public struct CodeBlockView: View {
    public let code: String
    public let language: String
    
    @State private var copied: Bool = false
    
    public init(code: String, language: String = "") {
        self.code = code
        self.language = language
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                Text(language.isEmpty ? "code" : language.lowercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(NewtonTheme.textSecondary)
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = code
                    Haptics.light()
                    withAnimation {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            copied = false
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(copied ? "Copied" : "Copy")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(copied ? NewtonTheme.forestGreen : NewtonTheme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(NewtonTheme.surface)
            
            Divider()
                .background(NewtonTheme.border)
            
            // Code Content
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundColor(NewtonTheme.textPrimary)
                    .padding(12)
            }
        }
        .background(NewtonTheme.card.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NewtonTheme.border, lineWidth: 0.8)
        )
    }
}
