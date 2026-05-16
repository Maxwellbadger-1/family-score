// FamilyScore/Views/Auth/LoginView.swift
// Target Membership: FamilyScore (App) ONLY
// Apple Health Aesthetik: dunkler Hintergrund, klare Felder, kein Farb-Bloat
// 3 Taps Maximum: Felder ausfuellen + Login-Button antippen
// iOS 16: @EnvironmentObject (NICHT @Environment — iOS 17+ Syntax)

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6
    }

    var body: some View {
        VStack(spacing: 16) {
            // Fehler-Banner
            if let error = authService.authError {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Spacer()
                    Button {
                        authService.authError = nil
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 24)
            }

            // E-Mail Feld
            VStack(alignment: .leading, spacing: 4) {
                Text("E-Mail")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)

            // Passwort Feld
            VStack(alignment: .leading, spacing: 4) {
                Text("Passwort")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if canSubmit { Task { await submitLogin() } } }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)

            // Login Button
            Button {
                Task { await submitLogin() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Einloggen")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canSubmit ? Color.white : Color.white.opacity(0.3))
                .foregroundColor(.black)
                .cornerRadius(12)
            }
            .disabled(!canSubmit || isLoading)
            .padding(.horizontal, 24)
            .padding(.top, 8)

            // Trennlinie "oder"
            HStack {
                VStack { Divider().background(Color.secondary) }
                Text("oder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                VStack { Divider().background(Color.secondary) }
            }
            .padding(.horizontal, 24)

            // Sign in with Apple
            SignInWithAppleView()
                .padding(.horizontal, 24)
        }
    }

    private func submitLogin() async {
        guard canSubmit else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.signIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        } catch {
            authService.authError = authService.localizedError(from: error)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LoginView()
            .environmentObject(AuthService())
    }
}
