//
//  ShareableCardGenerator.swift
//  Newton
//
//  Generates Ray.so / Carbon style magazine-grade image snapshots of code and messages.
//

import SwiftUI

public struct ShareableCardGenerator: View {
    public let codeSnippet: String
    public let language: String
    public let title: String
    @Environment(\.dismiss) private var dismiss
    
    public init(codeSnippet: String, language: String = "swift", title: String = "Newton Singularity") {
        self.codeSnippet = codeSnippet
        self.language = language
        self.title = title
    }
    
    var cardView: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.12),
                    Color(red: 0.18, green: 0.14, blue: 0.10),
                    Color(red: 0.08, green: 0.08, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Code Card Window
            VStack(alignment: .leading, spacing: 0) {
                // Window Header with macOS Traffic Lights
                HStack(spacing: 8) {
                    Circle().fill(Color.red).frame(width: 10, height: 10)
                    Circle().fill(Color.yellow).frame(width: 10, height: 10)
                    Circle().fill(Color.green).frame(width: 10, height: 10)
                    
                    Spacer()
                    
                    Text(title)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text(language.uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(NewtonTheme.sand)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                
                Divider().background(Color.white.opacity(0.1))
                
                // Code Content
                ScrollView {
                    Text(codeSnippet)
                        .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.92))
                        .lineSpacing(4)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Watermark Footer
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "atom")
                            .font(.system(size: 10))
                        Text("Newton Singularity Core")
                            .font(.system(size: 10, weight: .medium, design: .serif))
                    }
                    .foregroundColor(NewtonTheme.sand.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
            .background(Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
            .padding(24)
        }
        .frame(width: 360, height: 440)
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    cardView
                    
                    ShareLink(item: renderImage(), preview: SharePreview("Newton Code Snapshot", image: renderImage())) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Compartir Tarjeta HD")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(NewtonTheme.sand)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .navigationTitle("Code Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(NewtonTheme.sand)
                }
            }
        }
    }
    
    @MainActor
    private func renderImage() -> Image {
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }
}
