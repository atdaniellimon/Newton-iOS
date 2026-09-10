//
//  AuthView.swift
//  NewtonMac
//
//  Login / Register screen shown when no ntwn-key is in Keychain.
//

import SwiftUI

public struct AuthView: View {
    @StateObject private var auth = AuthManager.shared
    @State private var mode: Mode = .login
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
    @State private var shakeError: Bool = false

    private enum Mode { case login, register }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(white: 0.07)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + title
                VStack(spacing: 12) {
                    Image(systemName: "atom")
                        .font(.system(size: 52, weight: .ultraLight))
                        .foregroundStyle(.white)

                    Text("Newton")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Singularity · Newton Labs")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.bottom, 40)

                // Card
                VStack(spacing: 20) {
                    // Mode switcher
                    HStack(spacing: 0) {
                        modeButton("Iniciar sesión", selected: mode == .login) {
                            withAnimation(.easeInOut(duration: 0.2)) { mode = .login }
                        }
                        modeButton("Crear cuenta", selected: mode == .register) {
                            withAnimation(.easeInOut(duration: 0.2)) { mode = .register }
                        }
                    }
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Fields
                    VStack(spacing: 12) {
                        field(icon: "person", placeholder: "Usuario", text: $username)
                        secureField(icon: "lock", placeholder: "Contraseña", text: $password)

                        if mode == .register {
                            secureField(icon: "lock.fill", placeholder: "Confirmar contraseña", text: $passwordConfirm)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

                    // Error
                    if let err = auth.lastError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(err)
                        }
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .offset(x: shakeError ? -6 : 0)
                        .transition(.opacity)
                    }

                    // Action button
                    Button {
                        Task { await submit() }
                    } label: {
                        ZStack {
                            if auth.isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text(mode == .login ? "Entrar" : "Crear cuenta")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isLoading || username.isEmpty || password.isEmpty)
                    .opacity((auth.isLoading || username.isEmpty || password.isEmpty) ? 0.5 : 1)

                    // Trial note
                    if mode == .register {
                        Text("30 días gratis · $100 MXN/mes después")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.3))
                            .transition(.opacity)
                    }
                }
                .padding(28)
                .frame(width: 380)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                Spacer()
                Spacer()
            }
        }
        .frame(minWidth: 480, minHeight: 520)
    }

    // ── Helpers ──────────────────────────────────────────────────

    private func submit() async {
        let trimUser = username.trimmingCharacters(in: .whitespaces)
        guard !trimUser.isEmpty, !password.isEmpty else { return }

        if mode == .register {
            guard password == passwordConfirm else {
                AuthManager.shared.lastError = "Las contraseñas no coinciden"
                triggerShake()
                return
            }
            guard password.count >= 8 else {
                AuthManager.shared.lastError = "La contraseña debe tener al menos 8 caracteres"
                triggerShake()
                return
            }
            let ok = await auth.register(username: trimUser, password: password)
            if !ok { triggerShake() }
        } else {
            let ok = await auth.login(username: trimUser, password: password)
            if !ok { triggerShake() }
        }
    }

    private func triggerShake() {
        withAnimation(.easeInOut(duration: 0.08).repeatCount(3, autoreverses: true)) {
            shakeError = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { shakeError = false }
    }

    @ViewBuilder
    private func modeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? Color.white.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(2)
    }

    @ViewBuilder
    private func field(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 20)
            TextField(placeholder, text: text)
                .foregroundStyle(.white)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func secureField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 20)
            SecureField(placeholder, text: text)
                .foregroundStyle(.white)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    AuthView()
}
