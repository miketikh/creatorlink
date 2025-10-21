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
    private var currentUserId: String?

    // MARK: - Initialization

    init() {
        print("🔵 [ConversationsViewModel] init() called")
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
            print("⏭️ [ConversationsViewModel] Listener already active for user \(userId), skipping reload")
            return
        }

        print("🔵 [ConversationsViewModel] loadConversations() called for userId: \(userId)")
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
            print("✅ [ConversationsViewModel] Initial load complete, listener active")
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
            print("⚠️ [ConversationsViewModel] Cannot refresh: no user ID")
            return
        }

        print("🔄 [ConversationsViewModel] Manual refresh triggered")
        isLoading = true

        do {
            conversations = try await conversationService.fetchConversations(userId: userId)
            isLoading = false
            print("✅ [ConversationsViewModel] Manual refresh complete")
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ [ConversationsViewModel] Refresh failed: \(error.localizedDescription)")
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

    // MARK: - Private Methods

    private func setupListener(userId: String) {
        // Only set up if not already listening
        guard conversationsListener == nil else {
            print("⚠️ [ConversationsViewModel] Listener already exists, not creating new one")
            return
        }

        print("🔵 [ConversationsViewModel] Setting up listener for userId: \(userId)")

        conversationsListener = conversationService.listenToConversations(userId: userId) { [weak self] conversations in
            print("🔔 [ConversationsViewModel] Listener callback fired with \(conversations.count) conversations")

            // Log details of each conversation
            for (index, conv) in conversations.enumerated() {
                print("📋 [ConversationsViewModel] Conversation [\(index)]: ID=\(conv.id ?? "nil"), lastMessage=\(conv.lastMessage), lastMessageTime=\(conv.lastMessageTime)")
            }

            // Use MainActor.assumeIsolated since the class is @MainActor
            MainActor.assumeIsolated {
                guard let self = self else {
                    print("⚠️ [ConversationsViewModel] Self is nil in listener callback")
                    return
                }

                print("✅ [ConversationsViewModel] Updating conversations array on MainActor")
                let oldCount = self.conversations.count
                let oldFirstMessage = self.conversations.first?.lastMessage ?? "none"

                self.conversations = conversations

                let newCount = self.conversations.count
                let newFirstMessage = self.conversations.first?.lastMessage ?? "none"

                print("📊 [ConversationsViewModel] Array updated: \(oldCount) -> \(newCount) conversations")
                print("📊 [ConversationsViewModel] First conversation lastMessage: '\(oldFirstMessage)' -> '\(newFirstMessage)'")
                print("🔄 [ConversationsViewModel] Triggering SwiftUI update")
            }
        }

        print("✅ [ConversationsViewModel] Listener setup complete")
    }

    func cleanup() {
        conversationsListener?.remove()
        conversationsListener = nil
    }
}
