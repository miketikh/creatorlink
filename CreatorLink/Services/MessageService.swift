//
//  MessageService.swift
//  CreatorLink
//
//  Service layer for message-related Firebase operations
//

import Foundation
import FirebaseFirestore

@Observable
class MessageService {
    static let shared = MessageService()

    private let db = FirestoreService.shared.db
    private let messagesCollection = FirestoreService.shared.messagesCollection

    private init() {}

    // MARK: - Send Message

    /// Sends a message to a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - text: The message text
    ///   - senderId: The ID of the user sending the message
    ///   - participantIds: Array of user IDs who are participants in the conversation
    /// - Returns: The created Message with Firestore-generated ID
    func sendMessage(conversationId: String, text: String, senderId: String, participantIds: [String]) async throws -> Message {
        do {
            // Create message data for Firestore
            let messageData: [String: Any] = [
                "conversationId": conversationId,
                "senderId": senderId,
                "participantIds": participantIds,
                "text": text,
                "timestamp": Timestamp(date: Date()),
                "status": MessageStatus.sent.rawValue, // Set to 'sent' once written to Firestore
                "readBy": [:],
                "imageUrl": NSNull(),
                "metadata": NSNull()
            ]

            // Add document to Firestore
            let docRef = try await messagesCollection.addDocument(data: messageData)

            // OPTIMIZATION: Increment denormalized unread count for all participants except sender
            let otherParticipants = participantIds.filter { $0 != senderId }
            for participantId in otherParticipants {
                try? await incrementUnreadCount(conversationId: conversationId, userId: participantId)
            }

            // Return message with Firestore-generated ID
            return Message(
                id: docRef.documentID,
                conversationId: conversationId,
                senderId: senderId,
                participantIds: participantIds,
                text: text,
                timestamp: Date(),
                status: .sent,
                readBy: [:],
                imageUrl: nil,
                metadata: nil
            )
        } catch {
            throw MessageError.sendFailed(error)
        }
    }

    // MARK: - Fetch Messages

    /// Fetches all messages for a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the current user (required for security rules)
    /// - Returns: Array of messages sorted by timestamp (ascending)
    func fetchMessages(conversationId: String, userId: String) async throws -> [Message] {
        do {
            let snapshot = try await messagesCollection
                .whereField("conversationId", isEqualTo: conversationId)
                .whereField("participantIds", arrayContains: userId)
                .order(by: "timestamp", descending: false)
                .getDocuments()

            var messages: [Message] = []
            for document in snapshot.documents {
                do {
                    let message = try document.data(as: Message.self)
                    messages.append(message)
                } catch {
                }
            }

            return messages
        } catch {
            throw MessageError.fetchFailed(error)
        }
    }

    // MARK: - Real-time Listener

    /// Sets up a real-time listener for messages in a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation to listen to
    ///   - userId: The ID of the current user (required for security rules)
    ///   - completion: Closure called with updated messages array
    /// - Returns: ListenerRegistration for cleanup
    func listenToMessages(conversationId: String, userId: String, completion: @escaping ([Message]) -> Void) -> ListenerRegistration {
        return messagesCollection
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("participantIds", arrayContains: userId)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    return
                }

                var messages: [Message] = []
                for document in snapshot.documents {
                    if let message = try? document.data(as: Message.self) {
                        messages.append(message)
                    }
                }

                completion(messages)
            }
    }

    // MARK: - Update Message Status

    /// Updates the status of a message
    /// - Parameters:
    ///   - messageId: The ID of the message to update
    ///   - status: The new status
    func updateMessageStatus(messageId: String, status: MessageStatus) async throws {
        do {
            try await messagesCollection.document(messageId).updateData([
                "status": status.rawValue
            ])
        } catch {
            throw MessageError.updateFailed(error)
        }
    }

    // MARK: - Mark Message as Read

    /// Marks a message as read by a user
    /// - Parameters:
    ///   - messageId: The ID of the message
    ///   - userId: The ID of the user who read the message
    ///   - conversationId: The ID of the conversation (optional, for unread count optimization)
    func markMessageAsRead(messageId: String, userId: String, conversationId: String? = nil) async throws {
        do {
            try await messagesCollection.document(messageId).updateData([
                "readBy.\(userId)": FieldValue.serverTimestamp(),
                "status": MessageStatus.read.rawValue
            ])

            // OPTIMIZATION: Decrement denormalized unread count in conversation
            if let conversationId = conversationId {
                try? await decrementUnreadCount(conversationId: conversationId, userId: userId)
            }
        } catch {
            throw MessageError.updateFailed(error)
        }
    }

    /// Batch marks multiple messages as read by a user
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as read
    ///   - userId: The ID of the user who read the messages
    ///   - conversationId: The ID of the conversation (optional, for unread count optimization)
    func markMessagesAsRead(messageIds: [String], userId: String, conversationId: String? = nil) async throws {
        guard !messageIds.isEmpty else { return }

        do {
            let batch = db.batch()

            for messageId in messageIds {
                let messageRef = messagesCollection.document(messageId)
                let updateData: [String: Any] = [
                    "readBy.\(userId)": FieldValue.serverTimestamp(),
                    "status": MessageStatus.read.rawValue
                ]
                batch.updateData(updateData, forDocument: messageRef)
            }

            try await batch.commit()

            // OPTIMIZATION: Update denormalized unread count after batch read
            if let conversationId = conversationId {
                // Decrement by the number of messages marked as read
                try? await decrementUnreadCount(conversationId: conversationId, userId: userId, amount: messageIds.count)
            }
        } catch {
            throw MessageError.updateFailed(error)
        }
    }

    // MARK: - Unread Count Optimization

    /// Increments the denormalized unread count for a user in a conversation
    /// Called when a new message is sent (other participants get +1 unread)
    private func incrementUnreadCount(conversationId: String, userId: String) async throws {
        let conversationRef = FirestoreService.shared.conversationsCollection.document(conversationId)
        try await conversationRef.updateData([
            "unreadCounts.\(userId)": FieldValue.increment(Int64(1))
        ])
    }

    /// Decrements the denormalized unread count for a user in a conversation
    /// Called when messages are marked as read
    private func decrementUnreadCount(conversationId: String, userId: String, amount: Int = 1) async throws {
        let conversationRef = FirestoreService.shared.conversationsCollection.document(conversationId)
        try await conversationRef.updateData([
            "unreadCounts.\(userId)": FieldValue.increment(Int64(-amount))
        ])
    }

    /// Resets the unread count to zero for a user in a conversation
    /// Called when all messages in a conversation are marked as read
    func resetUnreadCount(conversationId: String, userId: String) async throws {
        let conversationRef = FirestoreService.shared.conversationsCollection.document(conversationId)
        try await conversationRef.updateData([
            "unreadCounts.\(userId)": 0
        ])
    }
}

// MARK: - Error Types

enum MessageError: LocalizedError {
    case sendFailed(Error)
    case fetchFailed(Error)
    case updateFailed(Error)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .sendFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch messages: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update message: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid message data"
        }
    }
}
