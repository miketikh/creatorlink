//
//  ProfileView.swift
//  CreatorLink
//
//  User profile view with sign-out functionality
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @State private var authService = AuthService.shared
    @State private var isSigningOut = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let user = authService.currentUser {
                    // Profile Photo
                    // Supports both Google profile photos and generated avatars (UI Avatars API)
                    if let photoURL = user.photoURL {
                        AsyncImage(url: photoURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            )
                    }

                    // Display Name
                    Text(user.displayName ?? "Unknown User")
                        .font(.title)
                        .fontWeight(.bold)

                    // Email
                    Text(user.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Online Status
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("Online")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }

                    // Sign Out Button
                    Button(action: {
                        Task {
                            await signOut()
                        }
                    }) {
                        if isSigningOut {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Sign Out")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                        }
                    }
                    .background(Color.red)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(isSigningOut)
                } else {
                    Text("No user signed in")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Profile")
        }
    }

    private func signOut() async {
        isSigningOut = true
        errorMessage = nil

        do {
            try await authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }

        isSigningOut = false
    }
}

#Preview {
    ProfileView()
}
