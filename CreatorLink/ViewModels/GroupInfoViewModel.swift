//
//  GroupInfoViewModel.swift
//  CreatorLink
//
//  ViewModel for managing group information screen business logic
//
//  Responsibilities:
//  - Loading and displaying group participants
//  - Updating group name and image
//  - Managing participant removal and leaving group
//  - Providing user-friendly error messages
//
//  Related Files:
//  - GroupInfoView.swift: The view this ViewModel supports
//  - ConversationService.swift: Handles Firebase operations
//  - ParticipantRowView.swift: Displays individual participants
//

import Foundation
import Observation

@Observable
@MainActor
class GroupInfoViewModel {
    var participants: [UserProfile] = []
    var groupName: String
    var groupImageUrl: String
    var isLoading = false
    var errorMessage: String?

    private let conversation: Conversation
    private let userService = UserService.shared
    private let conversationService = ConversationService.shared

    // MARK: - Initialization

    init(conversation: Conversation) {
        self.conversation = conversation
        self.groupName = conversation.groupName ?? "Group Chat"
        self.groupImageUrl = conversation.groupImageUrl ?? ""
    }

    // MARK: - Load Participants

    /// Loads all participant profiles for the group
    func loadParticipants() async {
        isLoading = true
        errorMessage = nil

        do {
            var fetchedParticipants: [UserProfile] = []

            for participantId in conversation.participantIds {
                do {
                    let profile = try await userService.fetchUser(userId: participantId)
                    fetchedParticipants.append(profile)
                } catch {
                    // Continue loading other participants even if one fails
                    continue
                }
            }

            participants = fetchedParticipants
            isLoading = false
        } catch {
            errorMessage = "Couldn't load group members. Please check your connection and try again."
            isLoading = false
        }
    }

    // MARK: - Update Group Name

    /// Updates the group name
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - newName: The new group name
    func updateGroupName(conversationId: String, newName: String) async throws {
        // Validate name
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw GroupInfoError.emptyName
        }

        guard trimmedName.count <= 35 else {
            throw GroupInfoError.nameTooLong
        }

        isLoading = true
        errorMessage = nil

        do {
            try await conversationService.updateGroupName(
                conversationId: conversationId,
                groupName: trimmedName
            )

            // Update local state
            groupName = trimmedName
            isLoading = false

            // Track analytics
            AnalyticsService.shared.trackGroupNameUpdated()
        } catch {
            errorMessage = "Couldn't update group name. Please check your connection and try again."
            isLoading = false
            throw error
        }
    }

    // MARK: - Update Group Image

    /// Updates the group image URL
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - newImageUrl: The new image URL
    func updateGroupImage(conversationId: String, newImageUrl: String) async throws {
        // Validate URL
        let trimmedUrl = newImageUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        // Allow empty URL (will use fallback)
        if !trimmedUrl.isEmpty {
            guard validateImageUrl(trimmedUrl) else {
                throw GroupInfoError.invalidImageUrl
            }
        }

        isLoading = true
        errorMessage = nil

        do {
            try await conversationService.updateGroupImageUrl(
                conversationId: conversationId,
                imageUrl: trimmedUrl.isEmpty ? nil : trimmedUrl
            )

            // Update local state
            groupImageUrl = trimmedUrl
            isLoading = false

            // Track analytics
            AnalyticsService.shared.trackGroupImageUpdated()
        } catch {
            errorMessage = "Couldn't update group image. Please check your connection and try again."
            isLoading = false
            throw error
        }
    }

    // MARK: - Leave Group

    /// Leaves the group
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user leaving
    func leaveGroup(conversationId: String, userId: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            // Track analytics before leaving
            AnalyticsService.shared.trackGroupLeft(groupSize: conversation.participantIds.count - 1)

            try await conversationService.leaveGroup(
                conversationId: conversationId,
                userId: userId
            )
            isLoading = false
        } catch {
            errorMessage = "Couldn't leave the group. Please check your connection and try again."
            isLoading = false
            throw error
        }
    }

    // MARK: - Remove Participant

    /// Removes a participant from the group
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user to remove
    ///   - currentUserId: The ID of the user performing the action
    func removeParticipant(conversationId: String, userId: String, currentUserId: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            try await conversationService.removeParticipant(
                conversationId: conversationId,
                userId: userId,
                currentUserId: currentUserId
            )

            // Remove participant from local list
            participants.removeAll { $0.id == userId }
            isLoading = false

            // Track analytics
            AnalyticsService.shared.trackParticipantRemoved(groupSize: conversation.participantIds.count - 1)
        } catch {
            errorMessage = "Couldn't remove participant. Please check your connection and try again."
            isLoading = false
            throw error
        }
    }

    // MARK: - Helper Methods

    /// Validates an image URL
    /// - Parameter url: The URL string to validate
    /// - Returns: True if valid, false otherwise
    private func validateImageUrl(_ url: String) -> Bool {
        // Allow nil/empty (will use fallback)
        if url.isEmpty {
            return true
        }

        // Check if starts with http:// or https://
        return url.hasPrefix("http://") || url.hasPrefix("https://")
    }
}

// MARK: - Error Types

enum GroupInfoError: LocalizedError {
    case emptyName
    case nameTooLong
    case invalidImageUrl

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Group name cannot be empty"
        case .nameTooLong:
            return "Group name must be 35 characters or less"
        case .invalidImageUrl:
            return "Image URL must start with http:// or https://"
        }
    }
}
