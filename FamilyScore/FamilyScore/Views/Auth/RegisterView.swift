// FamilyScore/Views/Auth/RegisterView.swift
// Target Membership: FamilyScore (App) ONLY
// Apple Health Aesthetik: dunkler Hintergrund, klare Felder
// Passwort-Match-Validierung: visuelles Feedback bei Nichtuebereinsstimmung
// iOS 16: @EnvironmentObject (NICHT @Environment — iOS 17+ Syntax)

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var focusedField: Field?

    enum Field { case name, email, password, passwordConfirm }

    private var passwordsMatch: Bool { password == passwordConfirm || passwordConfirm.isEmpty }

    private var canSubmit: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 &&
        password == passwordConfirm
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
                    Button { authService.authError = nil } label: {
                        Image(systemName: "xmark").foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 24)
            }

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Dein Name")
                    .font(.caption).foregroundColor(.secondary)
                TextField("", text: $displayName)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)

            // E-Mail
            VStack(alignment: .leading, spacing: 4) {
                Text("E-Mail")
                    .font(.caption).foregroundColor(.secondary)
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

            // Passwort
            VStack(alignment: .leading, spacing: 4) {
                Text("Passwort (min. 6 Zeichen)")
                    .font(.caption).foregroundColor(.secondary)
                SecureField("", text: $password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .passwordConfirm }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)

            // Passwort bestaetigen
            VStack(alignment: .leading, spacing: 4) {
                Text("Passwort bestaetigen")
                    .font(.caption).foregroundColor(.secondary)
                SecureField("", text: $passwordConfirm)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .passwordConfirm)
                    .submitLabel(.go)
                    .onSubmit { if canSubmit { Task { await submitRegister() } } }
                    .padding(12)
                    .background(passwordsMatch ? Color.white.opacity(0.08) : Color.red.opacity(0.15))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                if !passwordsMatch {
                    Text("Passwoerter stimmen nicht ueberein")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 24)

            // Registrieren Button
            Button {
                Task { await submitRegister() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text("Konto erstellen").font(.headline)
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
        }
    }

    private func submitRegister() async {
        guard canSubmit else { return }
        print("[Register] submitRegister() → \(email.trimmingCharacters(in: .whitespaces))")
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespaces)
            )
            print("[Register] signUp() OK")
        } catch {
            print("[Register] signUp() Fehler: \(error)")
            authService.authError = authService.localizedError(from: error)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RegisterView()
            .environmentObject(AuthService())
    }
}
