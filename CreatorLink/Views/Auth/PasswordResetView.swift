//
//  PasswordResetView.swift
//  CreatorLink
//
//  Password reset form UI
//

import SwiftUI

struct PasswordResetView: View {
    @Binding var isPresented: Bool
    @State private var authService = AuthService.shared
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Instructional text
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                // Email input field
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                // Error message display
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // Success message display
                if let successMessage = successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }

                // Send Reset Link button
                Button(action: {
                    handlePasswordReset()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Reset Link")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(email.isEmpty || isLoading)

                Spacer()
            }
            .padding()
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    // Handle password reset
    private func handlePasswordReset() {
        // Clear any existing messages
        errorMessage = nil
        successMessage = nil
        isLoading = true

        Task {
            do {
                // Call reset password method
                try await authService.resetPassword(email: email.trimmingCharacters(in: .whitespaces))

                // On success, show success message
                successMessage = "Password reset link sent! Check your email."

                // Wait 2 seconds before dismissing
                try? await Task.sleep(nanoseconds: 2_000_000_000)

                // Dismiss the sheet
                isPresented = false
            } catch {
                // On error, display the error message
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}

#Preview {
    PasswordResetView(isPresented: .constant(true))
}
