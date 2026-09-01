//
//  MacHero3DCanvasView.swift
//  NewtonMac
//
//  Created for Newton macOS.
//  120Hz GPU-accelerated 3D Undulating Kinetic Wave Grid matching iOS & Web canvas.
//

import SwiftUI
import AppKit

public struct MacHero3DCanvasView: View {
    public var isThinking: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    public init(isThinking: Bool = false) {
        self.isThinking = isThinking
    }
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let isDark = colorScheme == .dark
            let speedMultiplier = isThinking ? 1.8 : 0.85
            
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let cx = w / 2.0
                let cy = h * 0.60
                
                let rows = 36
                let cols = 34
                let gridSpacing: CGFloat = 32.0
                let cameraHeight: CGFloat = 200.0
                let fov: CGFloat = 400.0
                
                var gridPoints: [[CGPoint]] = Array(repeating: Array(repeating: .zero, count: cols), count: rows)
                
                for r in 0..<rows {
                    for c in 0..<cols {
                        let xWorld = (CGFloat(c) - CGFloat(cols) / 2.0) * gridSpacing
                        let zWorld = CGFloat(r) * gridSpacing + 25.0
                        
                        // Wave equation: dynamic harmonic kinetic wave motion
                        let u = Double(xWorld) * 0.032
                        let v = Double(zWorld) * 0.032
                        let wave = sin(u + time * speedMultiplier) * cos(v + time * speedMultiplier) * 36.0
                        let yWorld = wave - 10.0
                        
                        let depth = zWorld
                        guard depth > 10 else { continue }
                        let scale = fov / (fov + depth)
                        
                        let xProj = cx + xWorld * scale
                        let yProj = cy + (cameraHeight - yWorld) * scale
                        
                        gridPoints[r][c] = CGPoint(x: xProj, y: yProj)
                    }
                }
                
                // Draw Horizontal Wave Lines
                for r in 0..<rows {
                    var path = Path()
                    var started = false
                    for c in 0..<cols {
                        let pt = gridPoints[r][c]
                        if pt != .zero {
                            if !started {
                                path.move(to: pt)
                                started = true
                            } else {
                                path.addLine(to: pt)
                            }
                        }
                    }
                    
                    let depthRatio = 1.0 - Double(r) / Double(rows)
                    let alpha = max(0.04, depthRatio * (isDark ? 0.32 : 0.22))
                    let lineColor = isDark ? NewtonTheme.sand : Color(red: 0.30, green: 0.36, blue: 0.44)
                    context.stroke(path, with: .color(lineColor.opacity(alpha)), lineWidth: 0.9)
                }
                
                // Draw Vertical Perspective Lines
                for c in 0..<cols {
                    var path = Path()
                    var started = false
                    for r in 0..<rows {
                        let pt = gridPoints[r][c]
                        if pt != .zero {
                            if !started {
                                path.move(to: pt)
                                started = true
                            } else {
                                path.addLine(to: pt)
                            }
                        }
                    }
                    let alpha = isDark ? 0.14 : 0.10
                    let lineColor = isDark ? NewtonTheme.forestGreen : Color(red: 0.40, green: 0.46, blue: 0.54)
                    context.stroke(path, with: .color(lineColor.opacity(alpha)), lineWidth: 0.65)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
