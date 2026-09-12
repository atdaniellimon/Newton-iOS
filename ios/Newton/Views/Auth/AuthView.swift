//
//  AuthView.swift
//  Newton
//
//  Login / Register screen shown when no ntwn-key is in Keychain.
//  Elegant dark theme with Newton branding.
//

import SwiftUI

public struct AuthView: View {
    @StateObject private var auth = AuthManager.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var mode: Mode = .login
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
    @State private var shakeError: Bool = false
    @State private var showPassword: Bool = false

    private enum Mode { case login, register }

    public var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.12).opacity(0.8),
                    Color.black.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + Branding
                VStack(spacing: 16) {
                    // Animated orb-like logo
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        NewtonTheme.sand.opacity(0.3),
                                        NewtonTheme.sand.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "atom")
                            .font(.system(size: 42, weight: .ultraLight))
                            .foregroundStyle(NewtonTheme.sand)
                    }

                    VStack(spacing: 6) {
                        Text("Newton")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Singularity")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(NewtonTheme.sand.opacity(0.8))
                            .tracking(3)
                    }
                }
                .padding(.bottom, 50)

                // Auth Card
                VStack(spacing: 24) {
                    // Mode Toggle
                    HStack(spacing: 0) {
                        modeButton(L10n.tr("Sign In", es: "Iniciar sesión"), selected: mode == .login) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                mode = .login
                            }
                        }
                        modeButton(L10n.tr("Create Account", es: "Crear cuenta"), selected: mode == .register) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                mode = .register
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Fields
                    VStack(spacing: 16) {
                        // Username
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("Username", es: "Usuario"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(NewtonTheme.sand.opacity(0.6))
                                    .frame(width: 20)
                                TextField("", text: $username)
                                    .foregroundStyle(.white)
                                    .font(.system(size: 16))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("Password", es: "Contraseña"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(NewtonTheme.sand.opacity(0.6))
                                    .frame(width: 20)
                                if showPassword {
                                    TextField("", text: $password)
                                        .foregroundStyle(.white)
                                        .font(.system(size: 16))
                                } else {
                                    SecureField("", text: $password)
                                        .foregroundStyle(.white)
                                        .font(.system(size: 16))
                                }
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Confirm Password (register only)
                        if mode == .register {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.tr("Confirm Password", es: "Confirmar contraseña"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(NewtonTheme.sand.opacity(0.6))
                                        .frame(width: 20)
                                    SecureField("", text: $passwordConfirm)
                                        .foregroundStyle(.white)
                                        .font(.system(size: 16))
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    // Error Message
                    if let err = auth.lastError {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                            Text(err)
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(Color(red: 1.0, green: 0.4, blue: 0.4))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .offset(x: shakeError ? -8 : 0)
                        .transition(.opacity)
                    }

                    // Action Button
                    Button {
                        Task { await submit() }
                    } label: {
                        ZStack {
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.black)
                                    .frame(height: 22)
                            } else {
                                Text(mode == .login ? L10n.tr("Sign In", es: "Iniciar sesión") : L10n.tr("Create Account", es: "Crear cuenta"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [NewtonTheme.sand, NewtonTheme.sandLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(auth.isLoading || username.isEmpty || password.isEmpty)
                    .opacity((auth.isLoading || username.isEmpty || password.isEmpty) ? 0.6 : 1)

                    // Trial info
                    if mode == .register {
                        VStack(spacing: 4) {
                            Text(L10n.tr("30 days free trial", es: "30 días gratis"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(NewtonTheme.sand)
                            Text(L10n.tr("$100 MXN/month thereafter", es: "$100 MXN/mes después"))
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.top, 4)
                        .transition(.opacity)
                    }
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )

                Spacer()

                // Footer
                Text("Newton Labs © 2026")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
    }

    // ── Helpers ──────────────────────────────────────────────────

    private func submit() async {
        let trimUser = username.trimmingCharacters(in: .whitespaces)
        guard !trimUser.isEmpty, !password.isEmpty else { return }

        if mode == .register {
            guard password == passwordConfirm else {
                await MainActor.run {
                    AuthManager.shared.lastError = L10n.tr("Passwords do not match", es: "Las contraseñas no coinciden")
                }
                triggerShake()
                return
            }
            guard password.count >= 8 else {
                await MainActor.run {
                    AuthManager.shared.lastError = L10n.tr("Minimum 8 characters", es: "Mínimo 8 caracteres")
                }
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
        withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) {
            shakeError = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shakeError = false }
    }

    @ViewBuilder
    private func modeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? .black : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selected ?
                    LinearGradient(
                        colors: [NewtonTheme.sand, NewtonTheme.sandLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
}
