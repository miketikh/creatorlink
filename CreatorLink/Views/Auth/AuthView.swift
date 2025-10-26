//
//  AuthView.swift
//  CreatorLink
//
//  Authentication view with Google Sign-In
//

import SwiftUI

struct AuthView: View {
    @State private var authService = AuthService.shared
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var showEmailAuth = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // App Logo
            Image("AppName")
                .resizable()
                .scaledToFit()
                .frame(height: 120)

            // Tagline
            Text("Messaging for Content Creators")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            // Error Message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            // Sign in with Google Button
            Button(action: {
                Task {
                    await signInWithGoogle()
                }
            }) {
                HStack {
                    if isSigningIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                        Text("Sign in with Google")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isSigningIn)
            .padding(.horizontal, 40)

            // OR divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
                Text("OR")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal, 40)

            // Sign in with Email Button
            Button(action: {
                showEmailAuth = true
            }) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.title2)
                    Text("Sign in with Email")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal, 40)

            #if DEBUG
            // TODO: Remove before production release
            // Debug-only shortcuts for faster testing
            HStack(spacing: 16) {
                Button(action: {
                    Task {
                        await signInAsAlice()
                    }
                }) {
                    Text("Sign in as Alice")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(isSigningIn)

                Button(action: {
                    Task {
                        await signInAsBob()
                    }
                }) {
                    Text("Sign in as Bob")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(isSigningIn)
            }
            .padding(.top, 8)
            #endif

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView(isPresented: $showEmailAuth)
        }
    }

    private func signInWithGoogle() async {
        isSigningIn = true
        errorMessage = nil

        do {
            _ = try await authService.signInWithGoogle()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSigningIn = false
    }

    #if DEBUG
    // Debug-only sign-in for testing
    private func signInAsAlice() async {
        isSigningIn = true
        errorMessage = nil

        do {
            _ = try await authService.signInWithEmail(
                email: "alice.johnson@test.com",
                password: "password"
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isSigningIn = false
    }

    private func signInAsBob() async {
        isSigningIn = true
        errorMessage = nil

        do {
            _ = try await authService.signInWithEmail(
                email: "bob.martinez@test.com",
                password: "password"
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isSigningIn = false
    }
    #endif
}

#Preview {
    AuthView()
}
