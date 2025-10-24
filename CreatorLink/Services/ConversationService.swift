//
//  ConversationService.swift
//  CreatorLink
//
//  Service layer for conversation-related Firebase operations
//
//  This service handles all conversation management including:
//  - Creating and fetching conversations (both one-on-one and group)
//  - Managing group participants (adding/removing members)
//  - Updating group metadata (name, image, mute settings)
//  - Real-time conversation listeners
//
//  Key Architecture Decisions:
//  - Uses atomic Firestore operations (arrayUnion/arrayRemove) for concurrent safety
//  - Denormalizes unread counts for performance optimization
//  - Last person leaving a group triggers conversation deletion
//  - System messages are created for member join/leave events
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
    /// - Parameter aiEnabled: Optional flag to enable AI assistant for this conversation
    /// - Parameter aiConfig: Optional AI configuration settings
    /// - Returns: The created or existing Conversation
    func createConversation(participantIds: [String], currentUserId: String, groupName: String? = nil, groupImageUrl: String? = nil, aiEnabled: Bool? = nil, aiConfig: Conversation.AIConfig? = nil) async throws -> Conversation {
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

        // Initialize unreadCounts to 0 for all participants (optimization for unread badges)
        var unreadCounts: [String: Int] = [:]
        var finalParticipantIds = participantIds

        // If AI is enabled, add AI user to participants
        if let aiEnabled = aiEnabled, aiEnabled, !finalParticipantIds.contains(AIConstants.AI_USER_ID) {
            finalParticipantIds.append(AIConstants.AI_USER_ID)
        }

        for participantId in finalParticipantIds {
            unreadCounts[participantId] = 0
        }

        var conversationData: [String: Any] = [
            "participantIds": finalParticipantIds.sorted(), // Sort for consistent lookups
            "lastMessage": "",
            "lastMessageTime": Timestamp(date: Date()),
            "isGroupChat": isGroupChat,
            "groupName": groupName ?? NSNull(),
            "groupImageUrl": finalGroupImageUrl ?? NSNull(),
            "unreadCounts": unreadCounts
        ]

        // Add AI fields if provided
        if let aiEnabled = aiEnabled {
            conversationData["aiEnabled"] = aiEnabled
        }
        if let aiConfig = aiConfig {
            conversationData["aiConfig"] = [
                "faqDetectionEnabled": aiConfig.faqDetectionEnabled,
                "minimumSimilarity": aiConfig.minimumSimilarity
            ]
        }

        do {
            let docRef = try await conversationsCollection.addDocument(data: conversationData)

            let conversation = Conversation(
                id: docRef.documentID,
                participantIds: finalParticipantIds.sorted(),
                lastMessage: "",
                lastMessageTime: Date(),
                isGroupChat: isGroupChat,
                groupName: groupName,
                groupImageUrl: finalGroupImageUrl,
                unreadCounts: unreadCounts,
                aiEnabled: aiEnabled,
                aiConfig: aiConfig
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
    ///   - senderId: The ID of the user who sent the message
    func updateLastMessage(conversationId: String, text: String, timestamp: Date, senderId: String) async throws {
        do {
            try await conversationsCollection.document(conversationId).updateData([
                "lastMessage": text,
                "lastMessageTime": Timestamp(date: timestamp),
                "lastMessageSenderId": senderId
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

    // MARK: - Participant Management

    /// Adds a participant to a group conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user to add
    ///   - currentUserId: The ID of the user performing the action (for authorization)
    func addParticipant(conversationId: String, userId: String, currentUserId: String) async throws {
        do {
            // Fetch conversation document
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists,
                  let conversation = try? document.data(as: Conversation.self) else {
                throw ConversationError.invalidData
            }

            // Validate currentUserId is in the group (authorization check)
            guard conversation.participantIds.contains(currentUserId) else {
                throw ConversationError.unauthorized
            }

            // Check if userId is already in participantIds
            guard !conversation.participantIds.contains(userId) else {
                // User already in group, no action needed (handles concurrent add operations)
                return
            }

            // Use FieldValue.arrayUnion for atomic concurrent-safe operation
            // This ensures if two admins add the same user simultaneously, it only gets added once
            try await docRef.updateData([
                "participantIds": FieldValue.arrayUnion([userId]),
                "unreadCounts.\(userId)": 0
            ])

            // Create system message
            try await createSystemMessage(conversationId: conversationId, text: "added a new member to the group", senderId: currentUserId)
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    /// Removes a participant from a group conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user to remove
    ///   - currentUserId: The ID of the user performing the action (for authorization)
    func removeParticipant(conversationId: String, userId: String, currentUserId: String) async throws {
        do {
            // Prevent removing oneself (must use leaveGroup instead)
            guard userId != currentUserId else {
                throw ConversationError.cannotRemoveSelf
            }

            // Fetch conversation document
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists,
                  let conversation = try? document.data(as: Conversation.self) else {
                throw ConversationError.invalidData
            }

            // Validate currentUserId is in the group
            guard conversation.participantIds.contains(currentUserId) else {
                throw ConversationError.unauthorized
            }

            // Check if user is still in the group (handles concurrent removal or user already left)
            guard conversation.participantIds.contains(userId) else {
                // User already removed, no action needed
                return
            }

            // Use FieldValue.arrayRemove for atomic concurrent-safe operation
            // This ensures if two operations try to remove the same user, it's handled safely
            try await docRef.updateData([
                "participantIds": FieldValue.arrayRemove([userId]),
                "unreadCounts.\(userId)": FieldValue.delete()
            ])

            // Create system message
            try await createSystemMessage(conversationId: conversationId, text: "removed a member from the group", senderId: currentUserId)
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    /// Leaves a group conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user leaving
    func leaveGroup(conversationId: String, userId: String) async throws {
        do {
            // Fetch conversation document
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists,
                  let conversation = try? document.data(as: Conversation.self) else {
                throw ConversationError.invalidData
            }

            // Check if user is still in the group
            guard conversation.participantIds.contains(userId) else {
                // User already left, no action needed
                return
            }

            // Determine if this is the last participant
            let remainingParticipantCount = conversation.participantIds.count - 1

            // If this is the last person, delete conversation
            if remainingParticipantCount == 0 {
                try await deleteConversation(conversationId: conversationId)
            } else {
                // Create system message before updating
                try await createSystemMessage(conversationId: conversationId, text: "left the group", senderId: userId)

                // Update Firestore document using atomic operation
                // Also remove the unread count for the leaving user
                try await docRef.updateData([
                    "participantIds": FieldValue.arrayRemove([userId]),
                    "unreadCounts.\(userId)": FieldValue.delete()
                ])
            }
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    /// Creates a system message to indicate membership changes
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - text: The system message text
    ///   - senderId: The ID of the user who performed the action
    private func createSystemMessage(conversationId: String, text: String, senderId: String) async throws {
        do {
            // Fetch sender's name
            let senderProfile = try await UserService.shared.fetchUser(userId: senderId)
            let messageText = "\(senderProfile.displayName) \(text)"

            // Fetch current participant IDs for the message
            let document = try await conversationsCollection.document(conversationId).getDocument()
            guard let conversation = try? document.data(as: Conversation.self) else {
                return
            }

            let messageData: [String: Any] = [
                "conversationId": conversationId,
                "senderId": "system",
                "participantIds": conversation.participantIds,
                "text": messageText,
                "timestamp": Timestamp(date: Date()),
                "status": MessageStatus.sent.rawValue,
                "readBy": [:],
                "imageUrl": NSNull(),
                "metadata": ["isSystemMessage": true]
            ]

            let messagesCollection = db.collection("messages")
            try await messagesCollection.addDocument(data: messageData)

            // Update conversation's last message
            try await updateLastMessage(conversationId: conversationId, text: messageText, timestamp: Date(), senderId: "system")
        } catch {
            // Don't throw - system messages are nice to have but not critical
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

    // MARK: - Mute Notifications

    /// Toggles mute status for a conversation for a specific user
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user toggling mute
    ///   - isMuted: Whether to mute (true) or unmute (false)
    func toggleMute(conversationId: String, userId: String, isMuted: Bool) async throws {
        do {
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists,
                  let conversation = try? document.data(as: Conversation.self) else {
                throw ConversationError.invalidData
            }

            // Get current mutedBy array or initialize empty
            var mutedBy = conversation.mutedBy ?? []

            if isMuted {
                // Add userId to mutedBy if not already present
                if !mutedBy.contains(userId) {
                    mutedBy.append(userId)
                }
            } else {
                // Remove userId from mutedBy
                mutedBy.removeAll { $0 == userId }
            }

            // Update Firestore
            try await docRef.updateData([
                "mutedBy": mutedBy
            ])
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    // MARK: - AI Settings Management

    /// Updates AI settings for a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - aiEnabled: Whether AI assistant is enabled
    ///   - aiConfig: Optional AI configuration settings
    func updateAISettings(conversationId: String, aiEnabled: Bool, aiConfig: Conversation.AIConfig?) async throws {
        do {
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists,
                  let conversation = try? document.data(as: Conversation.self) else {
                throw ConversationError.invalidData
            }

            // Build update dictionary
            var updateData: [String: Any] = [
                "aiEnabled": aiEnabled
            ]

            // Add or remove AI config
            if let config = aiConfig, aiEnabled {
                updateData["aiConfig"] = [
                    "faqDetectionEnabled": config.faqDetectionEnabled,
                    "minimumSimilarity": config.minimumSimilarity
                ]
            } else if !aiEnabled {
                updateData["aiConfig"] = FieldValue.delete()
            }

            // Add or remove AI user from participants
            if aiEnabled {
                // Check if AI user is already in participants
                if !conversation.participantIds.contains(AIConstants.AI_USER_ID) {
                    updateData["participantIds"] = FieldValue.arrayUnion([AIConstants.AI_USER_ID])
                    updateData["unreadCounts.\(AIConstants.AI_USER_ID)"] = 0
                    print("✅ Adding AI user to conversation: \(conversationId)")
                }
            } else {
                // Remove AI user from participants
                if conversation.participantIds.contains(AIConstants.AI_USER_ID) {
                    updateData["participantIds"] = FieldValue.arrayRemove([AIConstants.AI_USER_ID])
                    updateData["unreadCounts.\(AIConstants.AI_USER_ID)"] = FieldValue.delete()
                    print("✅ Removing AI user from conversation: \(conversationId)")
                }
            }

            // Update Firestore
            try await docRef.updateData(updateData)
            print("✅ AI settings updated for conversation \(conversationId): enabled=\(aiEnabled)")
        } catch let error as ConversationError {
            throw error
        } catch {
            print("❌ Failed to update AI settings: \(error.localizedDescription)")
            throw ConversationError.updateFailed(error)
        }
    }

    // MARK: - Tag Management

    /// Updates category tags for a user in a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    ///   - tags: Array of category tags to set
    func updateCategoryTags(conversationId: String, userId: String, tags: [ConversationTag]) async throws {
        do {
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists else {
                throw ConversationError.invalidData
            }

            // Build user tag data with category tags
            let tagData: [String: Any] = [
                "categoryTags": tags.map { $0.rawValue }
            ]

            // Update tagsByUser map using dot notation for the specific user
            var updateData: [String: Any] = [
                "tagsByUser.\(userId)": tagData
            ]

            // Update Firestore
            try await docRef.updateData(updateData)
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    /// Updates status tags for a user in a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    ///   - tags: Array of status tags to set
    func updateStatusTags(conversationId: String, userId: String, tags: [StatusTag]) async throws {
        do {
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists else {
                throw ConversationError.invalidData
            }

            // Sanitize status tags before saving
            let sanitizedTags = sanitizeStatusTags(tags)

            // Build user tag data with status tags
            let tagData: [String: Any] = [
                "statusTags": sanitizedTags.map { $0.rawValue }
            ]

            // Update tagsByUser map using dot notation for the specific user
            var updateData: [String: Any] = [
                "tagsByUser.\(userId)": tagData
            ]

            // Set userOverrideStatus flag in metadata
            updateData["tagMetadata.userOverrideStatus"] = true

            // Update Firestore
            try await docRef.updateData(updateData)
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    /// Updates the denormalized primary category for efficient filtering
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - category: The primary category (or nil to clear)
    func updatePrimaryCategory(conversationId: String, category: ConversationTag?) async throws {
        do {
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists else {
                throw ConversationError.invalidData
            }

            var updateData: [String: Any] = [:]
            if let category = category {
                updateData["primaryCategory"] = category.rawValue
            } else {
                updateData["primaryCategory"] = FieldValue.delete()
            }

            // Update Firestore
            try await docRef.updateData(updateData)
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    /// Updates AI metadata for tag suggestions
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - metadata: The tag metadata to set
    func updateTagMetadata(conversationId: String, metadata: Conversation.TagMetadata) async throws {
        do {
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists else {
                throw ConversationError.invalidData
            }

            var metadataDict: [String: Any] = [
                "userOverrideCategory": metadata.userOverrideCategory,
                "userOverrideStatus": metadata.userOverrideStatus
            ]

            if let aiSuggestedCategory = metadata.aiSuggestedCategory {
                metadataDict["aiSuggestedCategory"] = aiSuggestedCategory.rawValue
            }
            if let aiConfidenceScore = metadata.aiConfidenceScore {
                metadataDict["aiConfidenceScore"] = aiConfidenceScore
            }
            if let lastAIAnalysisTime = metadata.lastAIAnalysisTime {
                metadataDict["lastAIAnalysisTime"] = Timestamp(date: lastAIAnalysisTime)
            }

            let updateData: [String: Any] = [
                "tagMetadata": metadataDict
            ]

            // Update Firestore
            try await docRef.updateData(updateData)
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    // MARK: - Quick Tag Operations

    /// Marks a conversation as urgent for a user
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    func markAsUrgent(conversationId: String, userId: String) async throws {
        // Fetch current conversation
        guard let conversation = try await fetchConversation(conversationId: conversationId) else {
            throw ConversationError.invalidData
        }

        // Get current status tags for this user
        var currentStatusTags: [StatusTag] = []
        if let tagsByUser = conversation.tagsByUser,
           let userTagData = tagsByUser[userId],
           let statusTags = userTagData.statusTags {
            currentStatusTags = statusTags
        }

        // Add Urgent if not already present
        if !currentStatusTags.contains(.urgent) {
            currentStatusTags.append(.urgent)
        }

        // Update status tags
        try await updateStatusTags(conversationId: conversationId, userId: userId, tags: currentStatusTags)
    }

    /// Marks a conversation as resolved for a user (removes Urgent and NeedsResponse)
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    func markAsResolved(conversationId: String, userId: String) async throws {
        // Fetch current conversation
        guard let conversation = try await fetchConversation(conversationId: conversationId) else {
            throw ConversationError.invalidData
        }

        // Get current status tags for this user
        var currentStatusTags: [StatusTag] = []
        if let tagsByUser = conversation.tagsByUser,
           let userTagData = tagsByUser[userId],
           let statusTags = userTagData.statusTags {
            currentStatusTags = statusTags
        }

        // Remove conflicting tags and add Resolved
        currentStatusTags.removeAll { $0 == .urgent || $0 == .needsResponse }
        if !currentStatusTags.contains(.resolved) {
            currentStatusTags.append(.resolved)
        }

        // Update status tags
        try await updateStatusTags(conversationId: conversationId, userId: userId, tags: currentStatusTags)
    }

    /// Marks a conversation as needing response for a user
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    func markAsNeedsResponse(conversationId: String, userId: String) async throws {
        // Fetch current conversation
        guard let conversation = try await fetchConversation(conversationId: conversationId) else {
            throw ConversationError.invalidData
        }

        // Get current status tags for this user
        var currentStatusTags: [StatusTag] = []
        if let tagsByUser = conversation.tagsByUser,
           let userTagData = tagsByUser[userId],
           let statusTags = userTagData.statusTags {
            currentStatusTags = statusTags
        }

        // Add NeedsResponse if not already present
        if !currentStatusTags.contains(.needsResponse) {
            currentStatusTags.append(.needsResponse)
        }

        // Update status tags
        try await updateStatusTags(conversationId: conversationId, userId: userId, tags: currentStatusTags)
    }

    /// Removes urgent flag from a conversation for a user
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    func removeUrgent(conversationId: String, userId: String) async throws {
        // Fetch current conversation
        guard let conversation = try await fetchConversation(conversationId: conversationId) else {
            throw ConversationError.invalidData
        }

        // Get current status tags for this user
        var currentStatusTags: [StatusTag] = []
        if let tagsByUser = conversation.tagsByUser,
           let userTagData = tagsByUser[userId],
           let statusTags = userTagData.statusTags {
            currentStatusTags = statusTags
        }

        // Remove Urgent
        currentStatusTags.removeAll { $0 == .urgent }

        // Update status tags
        try await updateStatusTags(conversationId: conversationId, userId: userId, tags: currentStatusTags)
    }

    // MARK: - Batch Tag Operations

    /// Updates category tags for multiple conversations at once
    /// - Parameters:
    ///   - conversationIds: Array of conversation IDs to update (max 500)
    ///   - userId: The ID of the user
    ///   - tags: Array of category tags to set
    func batchUpdateCategoryTags(conversationIds: [String], userId: String, tags: [ConversationTag]) async throws {
        // Validate inputs
        guard !conversationIds.isEmpty else {
            throw ConversationError.invalidData
        }

        guard conversationIds.count <= 500 else {
            throw ConversationError.invalidData
        }

        do {
            // Create Firestore batch
            let batch = db.batch()

            // Build tag data
            let tagData: [String: Any] = [
                "categoryTags": tags.map { $0.rawValue }
            ]

            // Add update operations for each conversation
            for conversationId in conversationIds {
                let docRef = conversationsCollection.document(conversationId)
                batch.updateData([
                    "tagsByUser.\(userId)": tagData
                ], forDocument: docRef)
            }

            // Commit batch atomically
            try await batch.commit()
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    // MARK: - Tag Validation Helpers

    /// Validates category tags array
    /// - Parameter tags: Array of category tags
    /// - Returns: True if valid (max 2 tags), false otherwise
    private func validateCategoryTags(_ tags: [ConversationTag]) -> Bool {
        return tags.count <= 2
    }

    /// Validates status tags array
    /// - Parameter tags: Array of status tags
    /// - Returns: True if valid (no conflicting rules), false otherwise
    private func validateStatusTags(_ tags: [StatusTag]) -> Bool {
        // Check for conflicting tags: Resolved should not coexist with Urgent or NeedsResponse
        let hasResolved = tags.contains(.resolved)
        let hasUrgent = tags.contains(.urgent)
        let hasNeedsResponse = tags.contains(.needsResponse)

        if hasResolved && (hasUrgent || hasNeedsResponse) {
            return false
        }

        return true
    }

    /// Sanitizes status tags by removing conflicts and duplicates
    /// - Parameter tags: Array of status tags to sanitize
    /// - Returns: Sanitized array following business rules
    private func sanitizeStatusTags(_ tags: [StatusTag]) -> [StatusTag] {
        var sanitized = tags

        // Remove duplicates
        sanitized = Array(Set(sanitized))

        // Business rule: If Resolved is present, remove Urgent and NeedsResponse
        if sanitized.contains(.resolved) {
            sanitized.removeAll { $0 == .urgent || $0 == .needsResponse }
        }

        // Business rule: If Urgent is present, ensure NeedsResponse is also present
        if sanitized.contains(.urgent) && !sanitized.contains(.needsResponse) {
            sanitized.append(.needsResponse)
        }

        return sanitized
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
    case unauthorized
    case cannotRemoveSelf
    case invalidTags
    case tooManyTags
    case tagConflict

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
        case .unauthorized:
            return "You must be a member of this group to perform this action"
        case .cannotRemoveSelf:
            return "Cannot remove yourself from the group. Use 'Leave Group' instead"
        case .invalidTags:
            return "The selected tags are not valid"
        case .tooManyTags:
            return "You can only select up to 2 category tags"
        case .tagConflict:
            return "The selected tags conflict with each other. Resolved cannot be combined with Urgent or Needs Response"
        }
    }
}
