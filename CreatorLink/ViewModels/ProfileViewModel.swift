//
//  ProfileViewModel.swift
//  CreatorLink
//
//  ViewModel for managing user profile screen business logic
//
//  Responsibilities:
//  - Loading and displaying user profile information
//  - Updating user display name and photo URL
//  - Providing user-friendly error messages
//
//  Related Files:
//  - ProfileView.swift: The view this ViewModel supports
//  - UserService.swift: Handles Firebase operations
//

import Foundation
import Observation
import FirebaseFirestore

@Observable
@MainActor
class ProfileViewModel {
    var userProfile: UserProfile?
    var displayName: String = ""
    var photoURL: String = ""
    var aiResponseModeEnabled: Bool = false
    var isLoading = false
    var errorMessage: String?
    var profileListener: ListenerRegistration?

    private let userService = UserService.shared

    // MARK: - Initialization

    init() {}

    // MARK: - Load User Profile

    /// Sets up a real-time listener for the current user's profile
    func setupProfileListener() {
        guard let userId = userService.currentUserId else {
            errorMessage = "No user signed in"
            return
        }

        // Listen to user profile for real-time updates
        profileListener = FirestoreService.shared.usersCollection
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let error = error {
                        self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                        return
                    }

                    guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                        self.errorMessage = "Profile not found"
                        return
                    }

                    self.userProfile = UserProfile(
                        id: userId,
                        displayName: data["displayName"] as? String ?? "Unknown User",
                        email: data["email"] as? String ?? "",
                        photoURL: data["photoURL"] as? String,
                        isOnline: data["isOnline"] as? Bool ?? false,
                        lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue() ?? Date(),
                        aiResponseModeEnabled: data["aiResponseModeEnabled"] as? Bool
                    )

                    // Update local state
                    self.displayName = self.userProfile?.displayName ?? ""
                    self.photoURL = self.userProfile?.photoURL ?? ""
                    self.aiResponseModeEnabled = self.userProfile?.isAIResponseModeEnabled ?? false
                }
            }
    }

    /// Removes the profile listener
    func removeListener() {
        profileListener?.remove()
        profileListener = nil
    }

    // MARK: - Update Display Name

    /// Updates the user's display name
    /// - Parameter newName: The new display name
    func updateDisplayName(newName: String) async throws {
        guard let userId = userService.currentUserId else {
            throw UserServiceError.userNotFound
        }

        // Validate name
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw UserServiceError.emptyDisplayName
        }

        guard trimmedName.count <= 50 else {
            throw UserServiceError.displayNameTooLong
        }

        isLoading = true
        errorMessage = nil

        do {
            try await userService.updateDisplayName(
                userId: userId,
                displayName: trimmedName
            )

            // Update local state
            displayName = trimmedName
            isLoading = false

            // Track analytics
            AnalyticsService.shared.trackEvent("profile_name_updated")
        } catch {
            errorMessage = "Couldn't update display name. Please check your connection and try again."
            isLoading = false
            throw error
        }
    }

    // MARK: - Update Photo URL

    /// Updates the user's photo URL
    /// - Parameter newPhotoURL: The new photo URL
    func updatePhotoURL(newPhotoURL: String) async throws {
        guard let userId = userService.currentUserId else {
            throw UserServiceError.userNotFound
        }

        // Validate URL
        let trimmedURL = newPhotoURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Allow empty URL (will use fallback)
        if !trimmedURL.isEmpty {
            guard trimmedURL.hasPrefix("http://") || trimmedURL.hasPrefix("https://") else {
                throw UserServiceError.invalidPhotoURL
            }
        }

        isLoading = true
        errorMessage = nil

        do {
            try await userService.updatePhotoURL(
                userId: userId,
                photoURL: trimmedURL
            )

            // Update local state
            photoURL = trimmedURL
            isLoading = false

            // Track analytics
            AnalyticsService.shared.trackEvent("profile_photo_updated")
        } catch {
            errorMessage = "Couldn't update profile photo. Please check your connection and try again."
            isLoading = false
            throw error
        }
    }

    // MARK: - Update AI Response Mode

    /// Updates the user's AI response mode setting
    /// - Parameter enabled: Whether AI response mode should be enabled
    func updateAIResponseMode(enabled: Bool) async throws {
        guard let userId = userService.currentUserId else {
            throw UserServiceError.userNotFound
        }

        errorMessage = nil

        do {
            try await userService.updateAIResponseMode(
                userId: userId,
                enabled: enabled
            )

            // Update local state
            aiResponseModeEnabled = enabled

            // Track analytics
            AnalyticsService.shared.trackEvent("ai_response_mode_\(enabled ? "enabled" : "disabled")")
        } catch {
            errorMessage = "Couldn't update AI response mode. Please check your connection and try again."
            throw error
        }
    }
}
