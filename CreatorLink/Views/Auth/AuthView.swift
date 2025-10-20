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

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // App Logo/Icon
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            // App Title
            Text("CreatorLink")
                .font(.largeTitle)
                .fontWeight(.bold)

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

            Spacer()
        }
        .padding()
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
}

#Preview {
    AuthView()
}
