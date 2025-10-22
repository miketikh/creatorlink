//
//  ConversationService.swift
//  CreatorLink
//
//  Service layer for conversation-related Firebase operations
//

import Foundation
import FirebaseFirestore

@Observable
class ConversationService {
    static let shared = ConversationService()

    let db = FirestoreService.shared.db
    private let conversationsCollection = FirestoreService.shared.conversationsCollection

    private init() {}

    // MARK: - Create Conversation

    /// Creates a new conversation or returns existing one if it already exists
    /// - Parameter participantIds: Array of user IDs participating in the conversation
    /// - Parameter currentUserId: The ID of the current user
    /// - Parameter groupName: Optional custom name for group conversations
    /// - Parameter groupImageUrl: Optional custom image URL for group conversations
    /// - Returns: The created or existing Conversation
    func createConversation(participantIds: [String], currentUserId: String, groupName: String? = nil, groupImageUrl: String? = nil) async throws -> Conversation {
        // Check if conversation already exists
        if let existingConversation = try await findExistingConversation(participantIds: participantIds, currentUserId: currentUserId) {
            return existingConversation
        }

        // Create new conversation
        let isGroupChat = participantIds.count > 2

        // Determine final groupImageUrl to use
        let finalGroupImageUrl: String?
        if let customUrl = groupImageUrl {
            finalGroupImageUrl = customUrl
        } else if isGroupChat, let name = groupName {
            finalGroupImageUrl = generateGroupPlaceholderUrl(groupName: name)
        } else if isGroupChat {
            finalGroupImageUrl = generateGroupPlaceholderUrl(groupName: "Group")
        } else {
            finalGroupImageUrl = nil
        }

        let conversationData: [String: Any] = [
            "participantIds": participantIds.sorted(), // Sort for consistent lookups
            "lastMessage": "",
            "lastMessageTime": Timestamp(date: Date()),
            "isGroupChat": isGroupChat,
            "groupName": groupName ?? NSNull(),
            "groupImageUrl": finalGroupImageUrl ?? NSNull()
        ]

        do {
            let docRef = try await conversationsCollection.addDocument(data: conversationData)

            let conversation = Conversation(
                id: docRef.documentID,
                participantIds: participantIds.sorted(),
                lastMessage: "",
                lastMessageTime: Date(),
                isGroupChat: isGroupChat,
                groupName: groupName,
                groupImageUrl: finalGroupImageUrl
            )

            return conversation
        } catch {
            throw ConversationError.creationFailed(error)
        }
    }

    // MARK: - Fetch Conversations

    /// Fetches a single conversation by ID
    /// - Parameter conversationId: The ID of the conversation
    /// - Returns: The Conversation if found
    func fetchConversation(conversationId: String) async throws -> Conversation? {
        do {
            let document = try await conversationsCollection.document(conversationId).getDocument()

            guard document.exists else {
                return nil
            }

            let conversation = try document.data(as: Conversation.self)
            return conversation
        } catch {
            throw ConversationError.fetchFailed(error)
        }
    }

    /// Fetches all conversations for a user
    /// - Parameter userId: The ID of the user
    /// - Returns: Array of conversations sorted by lastMessageTime (descending)
    func fetchConversations(userId: String) async throws -> [Conversation] {
        do {
            let snapshot = try await conversationsCollection
                .whereField("participantIds", arrayContains: userId)
                .order(by: "lastMessageTime", descending: true)
                .getDocuments()

            var conversations: [Conversation] = []
            for document in snapshot.documents {
                if let conversation = try? document.data(as: Conversation.self) {
                    conversations.append(conversation)
                }
            }

            return conversations
        } catch {
            throw ConversationError.fetchFailed(error)
        }
    }

    // MARK: - Real-time Listener

    /// Sets up a real-time listener for conversations
    /// - Parameters:
    ///   - userId: The ID of the user whose conversations to listen to
    ///   - completion: Closure called with updated conversations array
    /// - Returns: ListenerRegistration for cleanup
    func listenToConversations(userId: String, completion: @escaping ([Conversation]) -> Void) -> ListenerRegistration {
        return conversationsCollection
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    return
                }

                var conversations: [Conversation] = []
                for document in snapshot.documents {
                    do {
                        let conversation = try document.data(as: Conversation.self)
                        conversations.append(conversation)
                    } catch {
                    }
                }

                completion(conversations)
            }
    }

    // MARK: - Update Last Message

    /// Updates the last message information for a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - text: The text of the last message
    ///   - timestamp: The timestamp of the last message
    func updateLastMessage(conversationId: String, text: String, timestamp: Date) async throws {
        do {
            try await conversationsCollection.document(conversationId).updateData([
                "lastMessage": text,
                "lastMessageTime": Timestamp(date: timestamp)
            ])
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    // MARK: - Find Existing Conversation

    /// Finds an existing conversation with the given participants
    /// - Parameter participantIds: Array of user IDs
    /// - Parameter currentUserId: The ID of the current user (for security rules)
    /// - Returns: Existing Conversation if found, nil otherwise
    func findExistingConversation(participantIds: [String], currentUserId: String) async throws -> Conversation? {
        let sortedIds = Set(participantIds.sorted())

        do {
            // Query for conversations that contain the current user
            // This matches our security rule: request.auth.uid in resource.data.participantIds
            let snapshot = try await conversationsCollection
                .whereField("participantIds", arrayContains: currentUserId)
                .getDocuments()

            // Filter to find conversations with exact participant match
            for document in snapshot.documents {
                if let conversation = try? document.data(as: Conversation.self) {
                    let conversationParticipants = Set(conversation.participantIds.sorted())

                    // Check if the participant sets match exactly
                    if conversationParticipants == sortedIds {
                        return conversation
                    }
                }
            }

            return nil
        } catch {
            throw ConversationError.fetchFailed(error)
        }
    }

    // MARK: - Update Group Name

    /// Updates the name of a group conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - groupName: The new group name
    func updateGroupName(conversationId: String, groupName: String) async throws {
        // Validate name length (max 35 characters)
        guard groupName.count <= 35 else {
            throw ConversationError.invalidData
        }

        // Ensure name is not empty
        guard !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversationError.invalidData
        }

        do {
            try await conversationsCollection.document(conversationId).updateData([
                "groupName": groupName
            ])
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    // MARK: - Update Group Image

    /// Updates the image URL of a group conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - imageUrl: The new image URL (nil to remove custom image)
    func updateGroupImageUrl(conversationId: String, imageUrl: String?) async throws {
        // Validate URL format if provided
        if let url = imageUrl, !validateImageUrl(url) {
            throw ConversationError.invalidData
        }

        do {
            try await conversationsCollection.document(conversationId).updateData([
                "groupImageUrl": imageUrl ?? NSNull()
            ])
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    // MARK: - Delete Conversation

    /// Deletes a conversation
    /// - Parameter conversationId: The ID of the conversation to delete
    func deleteConversation(conversationId: String) async throws {
        do {
            try await conversationsCollection.document(conversationId).delete()
        } catch {
            throw ConversationError.deletionFailed(error)
        }
    }

    // MARK: - Helper Methods

    /// Generates a placeholder URL for group avatars using UI Avatars API
    /// - Parameter groupName: The name of the group
    /// - Returns: A URL string for the placeholder image
    private func generateGroupPlaceholderUrl(groupName: String) -> String {
        let firstLetter = String(groupName.prefix(1)).uppercased()
        let encodedLetter = firstLetter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "G"
        return "https://ui-avatars.com/api/?name=\(encodedLetter)&background=random"
    }

    /// Validates an image URL
    /// - Parameter url: The URL string to validate
    /// - Returns: True if valid, false otherwise
    private func validateImageUrl(_ url: String?) -> Bool {
        // Allow nil (will use fallback)
        guard let url = url, !url.isEmpty else {
            return true
        }

        // Check if starts with http:// or https://
        return url.hasPrefix("http://") || url.hasPrefix("https://")
    }
}

// MARK: - Error Types

enum ConversationError: LocalizedError {
    case creationFailed(Error)
    case fetchFailed(Error)
    case updateFailed(Error)
    case deletionFailed(Error)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .creationFailed(let error):
            return "Failed to create conversation: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch conversations: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update conversation: \(error.localizedDescription)"
        case .deletionFailed(let error):
            return "Failed to delete conversation: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid conversation data"
        }
    }
}
