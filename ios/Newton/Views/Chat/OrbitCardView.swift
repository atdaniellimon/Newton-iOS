//
//  OrbitCardView.swift
//  Newton
//
//  Created for Newton iOS.
//

import SwiftUI

public struct OrbitCardView: View {
    public let result: OrbitExecutionResult
    
    public init(result: OrbitExecutionResult) {
        self.result = result
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "circle.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(NewtonTheme.forestGreen)
                
                Text("Orbit: \(result.orbitName.uppercased())")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(NewtonTheme.forestGreen)
                
                Spacer()
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11))
                    .foregroundColor(NewtonTheme.forestGreen)
            }
            
            Text(result.result)
                .font(.system(size: 12))
                .foregroundColor(NewtonTheme.textPrimary)
                .lineLimit(6)
        }
        .padding(10)
        .background(NewtonTheme.surfaceDark.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(NewtonTheme.forestGreen.opacity(0.4), lineWidth: 0.8)
        )
    }
}
