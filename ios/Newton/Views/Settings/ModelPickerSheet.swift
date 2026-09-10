//
//  ModelPickerSheet.swift
//  Newton
//
//  Stubbed — Newton Singularity is the only model. No picker needed.
//

import SwiftUI

/// Kept for build compatibility. Not presented anywhere in the UI.
public struct ModelPickerSheet: View {
    @Binding var selectedModelId: String

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "atom")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.6))
            Text("Newton Singularity")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Single model — no selection needed.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
