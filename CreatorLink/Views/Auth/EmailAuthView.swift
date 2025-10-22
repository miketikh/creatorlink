//
//  EmailAuthView.swift
//  CreatorLink
//
//  Email/password authentication form UI
//

import SwiftUI

struct EmailAuthView: View {
    @Binding var isPresented: Bool
    @State private var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPasswordReset = false

    // Computed property to validate form inputs
    private var isFormValid: Bool {
        if email.isEmpty || password.isEmpty {
            return false
        }
        if isSignUp && displayName.isEmpty {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Full Name field (only shown for sign up)
                if isSignUp {
                    TextField("Full Name", text: $displayName)
                        .textContentType(.name)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                // Email field
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                // Password field
                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
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

                // Primary action button
                Button(action: {
                    handlePrimaryAction()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading || !isFormValid)

                // Mode toggle button
                Button(action: {
                    isSignUp.toggle()
                    errorMessage = nil
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }

                // Forgot password button (only shown when not in sign up mode)
                if !isSignUp {
                    Button(action: {
                        showPasswordReset = true
                    }) {
                        Text("Forgot Password?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showPasswordReset) {
                PasswordResetView(isPresented: $showPasswordReset)
            }
        }
    }

    // Handle primary action (sign up or sign in)
    private func handlePrimaryAction() {
        // Clear any existing error message
        errorMessage = nil
        isLoading = true

        Task {
            do {
                if isSignUp {
                    // Validate display name is not empty
                    guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
                        errorMessage = "Please enter your full name."
                        isLoading = false
                        return
                    }

                    // Call sign-up method
                    _ = try await authService.signUpWithEmail(
                        email: email,
                        password: password,
                        displayName: displayName
                    )
                } else {
                    // Call sign-in method
                    _ = try await authService.signInWithEmail(
                        email: email,
                        password: password
                    )
                }

                // On success, dismiss the sheet
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
    EmailAuthView(isPresented: .constant(true))
}
