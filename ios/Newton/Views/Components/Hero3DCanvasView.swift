//
//  Hero3DCanvasView.swift
//  Newton
//
//  Created for Newton iOS.
//  120Hz GPU-accelerated 3D Undulating Kinetic Wave Grid matching Newton's Three.js canvas.
//

import SwiftUI

public struct Hero3DCanvasView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let isDark = colorScheme == .dark
            
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let cx = w / 2.0
                let cy = h * 0.58
                
                let rows = 32
                let cols = 30
                let gridSpacing: CGFloat = 34.0
                let cameraHeight: CGFloat = 220.0
                let fov: CGFloat = 380.0
                
                var gridPoints: [[CGPoint]] = Array(repeating: Array(repeating: .zero, count: cols), count: rows)
                
                for r in 0..<rows {
                    for c in 0..<cols {
                        let xWorld = (CGFloat(c) - CGFloat(cols) / 2.0) * gridSpacing
                        let zWorld = CGFloat(r) * gridSpacing + 30.0
                        
                        // Wave equation: dynamic harmonic kinetic wave motion
                        let u = Double(xWorld) * 0.034
                        let v = Double(zWorld) * 0.034
                        let wave = sin(u + time * 0.8) * cos(v + time * 0.8) * 38.0
                        let yWorld = wave - 12.0
                        
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
                    let alpha = max(0.06, depthRatio * (isDark ? 0.35 : 0.28))
                    let lineColor = isDark ? NewtonTheme.sand : Color(red: 0.35, green: 0.40, blue: 0.38)
                    context.stroke(path, with: .color(lineColor.opacity(alpha)), lineWidth: 0.95)
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
                    let alpha = isDark ? 0.16 : 0.14
                    let lineColor = isDark ? NewtonTheme.forestGreen : Color(red: 0.45, green: 0.48, blue: 0.45)
                    context.stroke(path, with: .color(lineColor.opacity(alpha)), lineWidth: 0.7)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
