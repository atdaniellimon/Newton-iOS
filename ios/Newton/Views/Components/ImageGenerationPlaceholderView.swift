//
//  ImageGenerationPlaceholderView.swift
//  Newton
//
//  Created for Newton iOS.
//  Stunning animated placeholder card shown while an AI image is being synthesized and rendered.
//

import SwiftUI

public struct ImageGenerationPlaceholderView: View {
    public var prompt: String? = nil
    
    @State private var shimmerPhase: CGFloat = -1.0
    @State private var pulseScale: CGFloat = 0.95
    @State private var dotCount: Int = 1
    @State private var timer: Timer? = nil
    
    public init(prompt: String? = nil) {
        self.prompt = prompt
    }
    
    public var body: some View {
        ZStack {
            // Shimmering Canvas Background
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NewtonTheme.card)
            
            // Animated Luminous Shimmer Wave
            GeometryReader { geo in
                let width = geo.size.width
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        NewtonTheme.sand.opacity(0.12),
                        Color.white.opacity(0.35),
                        NewtonTheme.sand.opacity(0.12),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: width * 0.8)
                .offset(x: shimmerPhase * width)
                .blur(radius: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            
            // Content Core
            VStack(spacing: 14) {
                // Glowing Animated Icon Badge
                ZStack {
                    Circle()
                        .fill(NewtonTheme.sand.opacity(0.15))
                        .frame(width: 52, height: 52)
                        .scaleEffect(pulseScale)
                    
                    Circle()
                        .stroke(NewtonTheme.sand.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(NewtonTheme.sand)
                }
                
                VStack(spacing: 6) {
                    HStack(spacing: 2) {
                        Text("Synthesizing visual artwork")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundColor(NewtonTheme.textPrimary)
                        
                        Text(String(repeating: ".", count: dotCount))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(NewtonTheme.sand)
                            .frame(width: 20, alignment: .leading)
                    }
                    
                    if let p = prompt, !p.isEmpty {
                        Text("“\(p)”")
                            .font(.system(size: 11.5, design: .serif))
                            .foregroundColor(NewtonTheme.textSecondary)
                            .italic()
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        Text("Diffusion model in progress • 1024×1024")
                            .font(.system(size: 11))
                            .foregroundColor(NewtonTheme.textSecondary.opacity(0.7))
                    }
                }
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NewtonTheme.sand.opacity(0.25), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.5
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.12
            }
            startDotAnimation()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startDotAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
            dotCount = (dotCount % 3) + 1
        }
    }
}
