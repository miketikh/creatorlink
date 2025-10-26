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
    @State private var showSignInOptions = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 40)

            // App Logo - Always visible
            Image("AppName")
                .resizable()
                .scaledToFit()
                .frame(height: 120)

            // Tagline - Always visible
            Text("Never miss an opportunity.\nNever sound robotic.")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(red: 107/255, green: 112/255, blue: 128/255))
                .multilineTextAlignment(.center)
                .kerning(0.3)
                .lineSpacing(1.4)
                .padding(.horizontal, 40)

            // Conditional Content
            if !showSignInOptions {
                // INITIAL VIEW: Screenshot and Start button
                Group {
                    // App Screenshot - Full width
                    Image("App_screenshot")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 500)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 4)
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                        .padding(.horizontal, 16)
                        .padding(.top, 28)

                    // Start Messaging Smarter Now Button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSignInOptions = true
                        }
                    }) {
                        Text("Start Messaging Smarter Now")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundColor(.white)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 14/255, green: 165/255, blue: 233/255),
                                        Color(red: 236/255, green: 72/255, blue: 153/255)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                }
                .transition(.opacity)
            } else {
                // SIGN-IN OPTIONS VIEW
                Group {
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
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 14/255, green: 165/255, blue: 233/255),
                                    Color(red: 236/255, green: 72/255, blue: 153/255)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSigningIn)
                    .padding(.horizontal, 40)
                    .padding(.top, 16)

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
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
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
                }
                .transition(.opacity)
            }

            Spacer()
                .frame(height: 40)
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
