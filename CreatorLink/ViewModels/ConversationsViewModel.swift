//
//  ConversationsViewModel.swift
//  CreatorLink
//
//  ViewModel for managing conversation list
//

import Foundation
import FirebaseFirestore
import Observation

@Observable
@MainActor
class ConversationsViewModel {
    var conversations: [Conversation] = []
    var isLoading = false
    var errorMessage: String?

    private let conversationService = ConversationService.shared
    private let userService = UserService.shared
    private var conversationsListener: ListenerRegistration?
    var currentUserId: String?

    // MARK: - Initialization

    init() {
    }

    // MARK: - Public Methods

    /// Loads conversations for the current user
    func loadConversations() async {
        guard let userId = currentUserId ?? userService.currentUserId else {
            errorMessage = "No user logged in"
            return
        }

        // If listener is already set up for this user, don't reload - listener keeps data fresh
        if conversationsListener != nil && currentUserId == userId {
            return
        }
        currentUserId = userId
        isLoading = true
        errorMessage = nil

        do {
            conversations = try await conversationService.fetchConversations(userId: userId)
            isLoading = false

            // Set up real-time listener if not already active
            if conversationsListener == nil {
                setupListener(userId: userId)
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Creates a new conversation with the specified participants
    func createConversation(with participantIds: [String]) async throws -> Conversation {
        guard let currentUserId = currentUserId else {
            throw ConversationError.invalidData
        }

        var participants = participantIds
        if !participants.contains(currentUserId) {
            participants.append(currentUserId)
        }

        return try await conversationService.createConversation(participantIds: participants, currentUserId: currentUserId)
    }

    /// Refreshes the conversation list
    func refresh() async {
        guard let userId = currentUserId else {
            return
        }

        isLoading = true

        do {
            conversations = try await conversationService.fetchConversations(userId: userId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Gets the other participant in a 1-on-1 conversation
    func getOtherParticipant(in conversation: Conversation) async -> UserProfile? {
        guard !conversation.isGroupChat,
              let currentUserId = currentUserId,
              let otherUserId = conversation.participantIds.first(where: { $0 != currentUserId }) else {
            return nil
        }

        return try? await userService.fetchUser(userId: otherUserId)
    }

    /// Gets unread message count for a conversation
    /// Works for both one-on-one and group chats by counting messages:
    /// - Not sent by current user (senderId != currentUserId)
    /// - Not yet read by current user (currentUserId not in readBy map)
    ///
    /// Optimization Strategy:
    /// 1. First, try to use denormalized unreadCounts from conversation document
    /// 2. If not available, fall back to querying messages (slower but accurate)
    func getUnreadCount(for conversation: Conversation) async -> Int {
        guard let currentUserId = currentUserId else {
            return 0
        }

        // OPTIMIZATION: Use denormalized count if available
        if let unreadCounts = conversation.unreadCounts,
           let count = unreadCounts[currentUserId] {
            return count
        }

        // FALLBACK: Query messages if denormalized count not available
        // This happens for older conversations created before optimization
        guard let conversationId = conversation.id else {
            return 0
        }

        do {
            // Query messages where current user is a participant
            let snapshot = try await FirestoreService.shared.messagesCollection
                .whereField("conversationId", isEqualTo: conversationId)
                .whereField("participantIds", arrayContains: currentUserId)
                .getDocuments()

            var unreadCount = 0
            for document in snapshot.documents {
                let data = document.data()

                // Check if message is from another user and not in readBy
                let senderId = data["senderId"] as? String ?? ""
                let readBy = data["readBy"] as? [String: Any] ?? [:]

                // Count messages from others that haven't been read by current user
                if senderId != currentUserId && readBy[currentUserId] == nil {
                    unreadCount += 1
                }
            }

            return unreadCount
        } catch {
            // Return 0 on error rather than showing incorrect badge
            return 0
        }
    }

    // MARK: - Private Methods

    private func setupListener(userId: String) {
        // Only set up if not already listening
        guard conversationsListener == nil else {
            return
        }

        conversationsListener = conversationService.listenToConversations(userId: userId) { [weak self] conversations in
            // Use MainActor.assumeIsolated since the class is @MainActor
            MainActor.assumeIsolated {
                guard let self = self else {
                    return
                }

                self.conversations = conversations
            }
        }
    }

    func cleanup() {
        conversationsListener?.remove()
        conversationsListener = nil
    }
}
