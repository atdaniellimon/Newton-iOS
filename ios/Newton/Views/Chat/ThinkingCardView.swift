//
//  ThinkingCardView.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct ThinkingCardView: View {
    public let content: String
    @State private var isExpanded: Bool = false
    
    public init(content: String) {
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                Haptics.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                        .foregroundColor(NewtonTheme.aqua)
                    
                    Text("Reasoning Chain")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(NewtonTheme.aqua)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(NewtonTheme.textSecondary)
                }
            }
            
            if isExpanded {
                Text(content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(NewtonTheme.textSecondary)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(NewtonTheme.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(NewtonTheme.aqua.opacity(0.3), lineWidth: 0.8)
        )
    }
}
