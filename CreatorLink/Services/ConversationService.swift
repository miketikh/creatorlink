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
    /// - Returns: The created or existing Conversation
    func createConversation(participantIds: [String], currentUserId: String) async throws -> Conversation {
        // Check if conversation already exists
        if let existingConversation = try await findExistingConversation(participantIds: participantIds, currentUserId: currentUserId) {
            return existingConversation
        }

        // Create new conversation
        let isGroupChat = participantIds.count > 2
        let conversationData: [String: Any] = [
            "participantIds": participantIds.sorted(), // Sort for consistent lookups
            "lastMessage": "",
            "lastMessageTime": Timestamp(date: Date()),
            "isGroupChat": isGroupChat,
            "groupName": NSNull()
        ]

        do {
            let docRef = try await conversationsCollection.addDocument(data: conversationData)

            let conversation = Conversation(
                id: docRef.documentID,
                participantIds: participantIds.sorted(),
                lastMessage: "",
                lastMessageTime: Date(),
                isGroupChat: isGroupChat,
                groupName: nil
            )

            print("✨ [ConversationService] Created new conversation: \(docRef.documentID)")
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
        print("🔍 [ConversationService] fetchConversation called for ID: \(conversationId)")
        do {
            let document = try await conversationsCollection.document(conversationId).getDocument()
            print("📄 [ConversationService] Document fetched. Exists: \(document.exists)")

            guard document.exists else {
                print("❌ [ConversationService] Document does not exist")
                return nil
            }

            let conversation = try document.data(as: Conversation.self)
            print("✅ [ConversationService] Conversation decoded successfully. ID: \(conversation.id ?? "nil"), ParticipantIds: \(conversation.participantIds)")
            return conversation
        } catch {
            print("❌ [ConversationService] Error fetching conversation: \(error.localizedDescription)")
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
        print("👂 [ConversationService] Setting up listener for userId: \(userId)")
        return conversationsCollection
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    print("❌ [ConversationService] Listener error: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                print("📊 [ConversationService] Listener received \(snapshot.documents.count) documents")

                var conversations: [Conversation] = []
                for document in snapshot.documents {
                    print("📄 [ConversationService] Processing document ID: \(document.documentID)")
                    do {
                        let conversation = try document.data(as: Conversation.self)
                        print("✅ [ConversationService] Decoded conversation. ID from model: \(conversation.id ?? "nil"), ID from document: \(document.documentID)")
                        conversations.append(conversation)
                    } catch {
                        print("❌ [ConversationService] Failed to decode conversation: \(error)")
                    }
                }

                print("✅ [ConversationService] Listener returning \(conversations.count) conversations")
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
        print("🔄 [ConversationService] updateLastMessage called for conversationId: \(conversationId)")
        print("🔄 [ConversationService] New lastMessage: '\(text)', timestamp: \(timestamp)")

        do {
            try await conversationsCollection.document(conversationId).updateData([
                "lastMessage": text,
                "lastMessageTime": Timestamp(date: timestamp)
            ])
            print("✅ [ConversationService] Firestore update completed successfully")
        } catch {
            print("❌ [ConversationService] Firestore update failed: \(error.localizedDescription)")
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
        print("🔍 [ConversationService] Finding conversation for participants: \(participantIds)")

        do {
            // Query for conversations that contain the current user
            // This matches our security rule: request.auth.uid in resource.data.participantIds
            let snapshot = try await conversationsCollection
                .whereField("participantIds", arrayContains: currentUserId)
                .getDocuments()

            print("📊 [ConversationService] Query returned \(snapshot.documents.count) conversations")

            // Filter to find conversations with exact participant match
            var decodedCount = 0
            var matchingCount = 0

            for document in snapshot.documents {
                print("📄 [ConversationService] Document ID: \(document.documentID)")

                if let conversation = try? document.data(as: Conversation.self) {
                    decodedCount += 1
                    print("✅ [ConversationService] Decoded conversation ID: \(conversation.id ?? "nil"), participants: \(conversation.participantIds)")

                    let conversationParticipants = Set(conversation.participantIds.sorted())

                    // Check if the participant sets match exactly
                    if conversationParticipants == sortedIds {
                        matchingCount += 1
                        print("🎯 [ConversationService] Found matching conversation: \(conversation.id ?? "nil")")
                        return conversation
                    }
                } else {
                    print("❌ [ConversationService] Failed to decode conversation from document: \(document.documentID)")
                }
            }

            print("📈 [ConversationService] Summary - Decoded: \(decodedCount)/\(snapshot.documents.count), Matching: \(matchingCount)")
            return nil
        } catch {
            print("❌ [ConversationService] Error: \(error.localizedDescription)")
            throw ConversationError.fetchFailed(error)
        }
    }

    // MARK: - Update Group Name

    /// Updates the name of a group conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - groupName: The new group name
    func updateGroupName(conversationId: String, groupName: String) async throws {
        do {
            try await conversationsCollection.document(conversationId).updateData([
                "groupName": groupName
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
