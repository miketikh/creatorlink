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

    init() {}

    // MARK: - Public Methods

    /// Loads conversations for the current user
    func loadConversations() async {
        guard let userId = currentUserId ?? userService.currentUserId else {
            errorMessage = "No user logged in"
            return
        }

        currentUserId = userId
        isLoading = true
        errorMessage = nil

        do {
            conversations = try await conversationService.fetchConversations(userId: userId)
            isLoading = false

            // Set up real-time listener
            setupListener(userId: userId)
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
        await loadConversations()
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
        conversationsListener?.remove()

        conversationsListener = conversationService.listenToConversations(userId: userId) { [weak self] conversations in
            Task { @MainActor in
                self?.conversations = conversations
            }
        }
    }

    func cleanup() {
        conversationsListener?.remove()
        conversationsListener = nil
    }
}
