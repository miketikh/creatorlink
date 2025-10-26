//
//  AuthService.swift
//  CreatorLink
//
//  Service layer for Firebase Authentication and Google Sign-In
//

import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

@Observable
class AuthService {
    static let shared = AuthService()

    var currentUser: User?
    var isAuthenticated: Bool {
        currentUser != nil
    }

    private var authStateListener: AuthStateDidChangeListenerHandle?

    private init() {
        // Auth state listener will be set up when first accessed
    }

    private var isListenerSetup = false

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth State Management

    private func setupAuthStateListener() {
        guard !isListenerSetup else { return }
        isListenerSetup = true
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
        }
    }

    func ensureInitialized() {
        setupAuthStateListener()
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async throws -> User {
        // Get the client ID from Info.plist (fallback to Firebase if available)
        let clientID: String
        if let firebaseClientID = FirebaseApp.app()?.options.clientID {
            clientID = firebaseClientID
        } else if let infoPlistClientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            clientID = infoPlistClientID
        } else {
            throw AuthError.missingClientID
        }

        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Get the presenting view controller
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootViewController
        }

        // Start Google Sign-In flow
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let user = result.user

        guard let idToken = user.idToken?.tokenString else {
            throw AuthError.missingIDToken
        }

        let accessToken = user.accessToken.tokenString

        // Create Firebase credential
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        // Sign in to Firebase
        let authResult = try await Auth.auth().signIn(with: credential)

        // Create user profile in Firestore
        do {
            try await UserService.shared.createUserProfile(
                userId: authResult.user.uid,
                displayName: authResult.user.displayName ?? "Unknown User",
                email: authResult.user.email ?? "",
                photoURL: authResult.user.photoURL?.absoluteString
            )
        } catch {
            // Don't throw - allow sign-in to complete even if profile creation fails
        }

        // Request notification permission after successful sign-in
        // Run in background - don't block sign-in flow
        Task {
            _ = await NotificationManager.shared.requestPermission()
        }

        return authResult.user
    }

    // MARK: - Email/Password Authentication

    func signUpWithEmail(email: String, password: String, displayName: String) async throws -> User {
        // Trim whitespace from inputs
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespaces)

        // Input validation
        guard !trimmedEmail.isEmpty else {
            throw AuthError.invalidEmail
        }

        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }

        // Use default name if display name is empty
        let finalDisplayName = trimmedDisplayName.isEmpty ? "User" : trimmedDisplayName

        // Create Firebase auth user
        let authResult: AuthDataResult
        do {
            authResult = try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
        } catch {
            throw AuthError.from(error)
        }

        // Update Firebase user profile with display name
        let changeRequest = authResult.user.createProfileChangeRequest()
        changeRequest.displayName = finalDisplayName
        try await changeRequest.commitChanges()

        // Generate avatar URL
        let avatarURL = generateAvatarURL(displayName: finalDisplayName, email: trimmedEmail)

        // Create user profile in Firestore
        do {
            try await UserService.shared.createUserProfile(
                userId: authResult.user.uid,
                displayName: finalDisplayName,
                email: trimmedEmail,
                photoURL: avatarURL
            )
        } catch {
            // Don't throw - allow sign-up to complete even if profile creation fails
            print("Failed to create user profile: \(error.localizedDescription)")
        }

        // Request notification permissions in background
        Task {
            _ = await NotificationManager.shared.requestPermission()
        }

        return authResult.user
    }

    func signInWithEmail(email: String, password: String) async throws -> User {
        // Trim whitespace from email
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        // Input validation
        guard !trimmedEmail.isEmpty else {
            throw AuthError.invalidEmail
        }

        guard !password.isEmpty else {
            throw AuthError.wrongPassword
        }

        // Sign in with Firebase
        let authResult: AuthDataResult
        do {
            authResult = try await Auth.auth().signIn(withEmail: trimmedEmail, password: password)
        } catch {
            throw AuthError.from(error)
        }

        // Update existing user profile in Firestore (edge case handling)
        // Fetch current profile to verify it exists
        let existingProfile = try? await UserService.shared.fetchUserProfile(userId: authResult.user.uid)

        // Only create profile if it doesn't exist (edge case)
        if existingProfile == nil {
            let displayName = authResult.user.displayName ?? "User"
            let avatarURL = authResult.user.photoURL?.absoluteString ?? generateAvatarURL(displayName: displayName, email: trimmedEmail)

            do {
                try await UserService.shared.createUserProfile(
                    userId: authResult.user.uid,
                    displayName: displayName,
                    email: trimmedEmail,
                    photoURL: avatarURL
                )
            } catch {
                // Don't throw - allow sign-in to complete even if profile creation fails
                print("Failed to create user profile: \(error.localizedDescription)")
            }
        }

        // Request notification permission after successful sign-in
        // Run in background - don't block sign-in flow
        Task {
            _ = await NotificationManager.shared.requestPermission()
        }

        return authResult.user
    }

    func resetPassword(email: String) async throws {
        // Trim whitespace from email
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        // Input validation
        guard !trimmedEmail.isEmpty else {
            throw AuthError.invalidEmail
        }

        // Basic email format validation (contains @ and .)
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            throw AuthError.invalidEmail
        }

        // Send password reset email
        do {
            try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
        } catch {
            throw AuthError.from(error)
        }
        // Method returns successfully without revealing if email exists
        // Firebase automatically sends email only if account exists (security best practice)
    }

    // MARK: - Avatar Generation

    private func generateAvatarURL(displayName: String, email: String) -> String {
        // Color palette for avatar backgrounds
        let colorOptions = ["FF6B6B", "4ECDC4", "45B7D1", "FFA07A", "98D8C8", "F7DC6F", "BB8FCE", "85C1E2"]

        // Hash email to select consistent color for same user
        let colorIndex = abs(email.hashValue) % colorOptions.count
        let color = colorOptions[colorIndex]

        // URL-encode display name to handle spaces and special characters
        let encodedName = displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? displayName

        // Construct UI Avatars API URL
        return "https://ui-avatars.com/api/?name=\(encodedName)&background=\(color)&color=fff&rounded=true&size=128&bold=true"
    }

    // MARK: - Sign Out

    func signOut() async throws {
        // Sign out from Firebase (works for all auth providers)
        try Auth.auth().signOut()

        // Sign out from Google Sign-In (no-op if user signed in with email)
        GIDSignIn.sharedInstance.signOut()
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case missingClientID
    case noRootViewController
    case missingIDToken
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case wrongPassword
    case userNotFound
    case userDisabled
    case networkError

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Missing Google Client ID. Check your Firebase configuration."
        case .noRootViewController:
            return "Unable to present sign-in screen. Please try again."
        case .missingIDToken:
            return "Failed to get authentication token from Google."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters long."
        case .emailAlreadyInUse:
            return "An account with this email already exists. Please sign in instead."
        case .wrongPassword:
            return "Incorrect email or password. Please try again."
        case .userNotFound:
            return "No account found with this email. Please sign up first."
        case .userDisabled:
            return "This account has been disabled. Please contact support."
        case .networkError:
            return "Network error. Please check your connection and try again."
        }
    }

    static func from(_ error: Error) -> AuthError {
        let nsError = error as NSError

        switch nsError.code {
        case AuthErrorCode.invalidEmail.rawValue:
            return .invalidEmail
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailAlreadyInUse
        case AuthErrorCode.wrongPassword.rawValue:
            return .wrongPassword
        case AuthErrorCode.userNotFound.rawValue:
            return .userNotFound
        case AuthErrorCode.userDisabled.rawValue:
            return .userDisabled
        case AuthErrorCode.networkError.rawValue:
            return .networkError
        default:
            // Return the original error if no mapping found
            return error as? AuthError ?? .networkError
        }
    }
}
