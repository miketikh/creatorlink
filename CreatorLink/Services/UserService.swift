//
//  UserService.swift
//  CreatorLink
//
//  Service layer for user profile management in Firestore
//

import Foundation
import FirebaseFirestore

@Observable
class UserService {
    static let shared = UserService()

    private let firestoreService = FirestoreService.shared

    private init() {}

    // MARK: - User Profile Management

    func createUserProfile(userId: String, displayName: String, email: String, photoURL: String?) async throws {
        let userProfile: [String: Any] = [
            "displayName": displayName,
            "email": email,
            "photoURL": photoURL ?? "",
            "isOnline": true,
            "lastSeen": FieldValue.serverTimestamp()
        ]

        // Use merge to avoid overwriting existing data
        try await firestoreService.usersCollection
            .document(userId)
            .setData(userProfile, merge: true)
    }

    func fetchUserProfile(userId: String) async throws -> UserProfile {
        let document = try await firestoreService.usersCollection
            .document(userId)
            .getDocument()

        guard let data = document.data() else {
            throw UserServiceError.userNotFound
        }

        return UserProfile(
            id: userId,
            displayName: data["displayName"] as? String ?? "Unknown User",
            email: data["email"] as? String ?? "",
            photoURL: data["photoURL"] as? String,
            isOnline: data["isOnline"] as? Bool ?? false,
            lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    func updateOnlineStatus(userId: String, isOnline: Bool) async throws {
        try await firestoreService.usersCollection
            .document(userId)
            .updateData([
                "isOnline": isOnline,
                "lastSeen": FieldValue.serverTimestamp()
            ])
    }

    func updateLastSeen(userId: String) async throws {
        try await firestoreService.usersCollection
            .document(userId)
            .updateData([
                "lastSeen": FieldValue.serverTimestamp()
            ])
    }
}

// MARK: - User Service Errors

enum UserServiceError: LocalizedError {
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User profile not found."
        }
    }
}
