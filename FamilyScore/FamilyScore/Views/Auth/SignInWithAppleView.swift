// FamilyScore/Views/Auth/SignInWithAppleView.swift
// Target Membership: FamilyScore (App) ONLY
// Source: offizielles gotrue-swift Beispiel + Supabase Docs "Sign in with Apple (native)"
// KRITISCH: rawNonce an Supabase, sha256(rawNonce) an Apple — NIEMALS vertauschen
// iOS 16 Minimum: @EnvironmentObject verwenden, NICHT @Environment (iOS 17+)

import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase

struct SignInWithAppleView: View {
    @EnvironmentObject private var authService: AuthService

    // rawNonce wird zwischen Request (requestedNonce) und Completion (handleAppleSignIn) gespeichert
    @State private var currentNonce: String = ""

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            // Neuen rawNonce generieren fuer diese spezifische Anfrage
            let nonce = randomNonce()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            // Apple erhaelt SHA256-Hash — rawNonce bleibt im App-Memory fuer Supabase
            request.nonce = sha256(nonce)
        } onCompletion: { result in
            Task {
                await handleAppleSignIn(result: result)
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 50)
        .cornerRadius(12)
    }

    // MARK: - Apple Sign In Handler

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        print("[Apple] handleAppleSignIn() aufgerufen")
        switch result {
        case .success(let auth):
            print("[Apple] Credential-Typ: \(type(of: auth.credential))")
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let idTokenData = credential.identityToken,
                let idToken = String(data: idTokenData, encoding: .utf8)
            else {
                print("[Apple] FEHLER: identityToken fehlt oder nicht decodierbar")
                authService.authError = "Apple-Anmeldung fehlgeschlagen. Bitte erneut versuchen."
                return
            }

            print("[Apple] idToken erhalten (\(idToken.count) Zeichen), nonce: \(currentNonce.prefix(8))…")
            do {
                try await supabase.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: currentNonce  // rawNonce! Nicht sha256(currentNonce)!
                    )
                )
                print("[Apple] signInWithIdToken() OK")

                // Apple fullName nur beim ERSTEN Login verfuegbar — sofort persistieren!
                // Source: RESEARCH.md Pitfall 1 — bei zweitem Login ist credential.fullName nil
                if let fullName = credential.fullName,
                   let givenName = fullName.givenName,
                   !givenName.isEmpty {
                    let displayName = [givenName, fullName.familyName]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    print("[Apple] fullName persistieren: \(displayName)")
                    try? await supabase.auth.update(
                        user: UserAttributes(data: ["full_name": .string(displayName)])
                    )
                }

            } catch {
                print("[Apple] signInWithIdToken() Fehler: \(error)")
                authService.authError = authService.localizedError(from: error)
            }

        case .failure(let error as ASAuthorizationError) where error.code == .canceled:
            print("[Apple] User hat Dialog abgebrochen (kein Fehler)")
            break

        case .failure(let error):
            print("[Apple] Fehler: \(error)")
            authService.authError = error.localizedDescription
        }
    }

    // MARK: - Kryptographische Nonce-Helpers
    // Source: offizielles gotrue-swift Beispiel (github.com/supabase-community/gotrue-swift)

    private func randomNonce(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            // SecRandomCopyBytes-Fehler ist ein Systemfehler — fatalError ist hier korrekt
            fatalError("Nonce-Generierung fehlgeschlagen: SecRandomCopyBytes Fehler \(errorCode)")
        }
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let hashedData = SHA256.hash(data: Data(input.utf8))
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
