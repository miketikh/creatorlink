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
        try await UserService.shared.createUserProfile(
            userId: authResult.user.uid,
            displayName: authResult.user.displayName ?? "Unknown User",
            email: authResult.user.email ?? "",
            photoURL: authResult.user.photoURL?.absoluteString
        )

        return authResult.user
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case missingClientID
    case noRootViewController
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Missing Google Client ID. Check your Firebase configuration."
        case .noRootViewController:
            return "Unable to present sign-in screen. Please try again."
        case .missingIDToken:
            return "Failed to get authentication token from Google."
        }
    }
}
