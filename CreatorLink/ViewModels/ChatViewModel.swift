//
//  ChatViewModel.swift
//  CreatorLink
//
//  ViewModel for managing individual chat threads
//

import Foundation
import FirebaseFirestore
import Observation

@Observable
@MainActor
class ChatViewModel {
    var messages: [Message] = []
    var isLoading = false
    var errorMessage: String?
    var isSending = false
    var conversation: Conversation?

    private let messageService = MessageService.shared
    private let conversationService = ConversationService.shared
    private let userService = UserService.shared
    private var messagesListener: ListenerRegistration?
    private var conversationListener: ListenerRegistration?

    let conversationId: String
    private var currentUserId: String?
    private var participantIds: [String] = []

    // MARK: - Initialization

    init(conversationId: String) {
        self.conversationId = conversationId
    }

    // MARK: - Public Methods

    /// Loads messages for the conversation
    func loadMessages() async {
        print("🔵 [ChatViewModel] loadMessages() started for conversationId: \(conversationId)")

        guard let userId = userService.currentUserId else {
            print("❌ [ChatViewModel] No user logged in")
            errorMessage = "No user logged in"
            return
        }

        print("✅ [ChatViewModel] Current user ID: \(userId)")
        currentUserId = userId
        isLoading = true
        errorMessage = nil

        do {
            print("🔍 [ChatViewModel] Fetching conversation...")
            // Load conversation to get participantIds
            if let conversation = try await conversationService.fetchConversation(conversationId: conversationId) {
                self.conversation = conversation
                participantIds = conversation.participantIds
                print("✅ [ChatViewModel] Conversation fetched. ParticipantIds: \(participantIds)")
            } else {
                print("❌ [ChatViewModel] Conversation not found for ID: \(conversationId)")
                throw ConversationError.invalidData
            }

            print("💬 [ChatViewModel] Fetching messages...")
            messages = try await messageService.fetchMessages(conversationId: conversationId, userId: userId)
            print("✅ [ChatViewModel] Fetched \(messages.count) messages")
            isLoading = false

            // Set up real-time listeners
            print("👂 [ChatViewModel] Setting up real-time listeners...")
            setupMessageListener()
            setupConversationListener()
            print("✅ [ChatViewModel] loadMessages() completed successfully")
        } catch {
            print("❌ [ChatViewModel] Error in loadMessages: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Sends a message with optimistic UI update
    func sendMessage(text: String) async {
        print("📤 [ChatViewModel] sendMessage() started")

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ [ChatViewModel] Empty message text, skipping send")
            return
        }

        guard let currentUserId = currentUserId else {
            print("❌ [ChatViewModel] No user logged in")
            errorMessage = "No user logged in"
            return
        }

        guard !participantIds.isEmpty else {
            print("❌ [ChatViewModel] ParticipantIds is empty!")
            errorMessage = "Cannot send message: participant information not loaded"
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        print("✅ [ChatViewModel] Sending message: '\(trimmedText)' from \(currentUserId) to \(participantIds)")

        // Create temporary message for optimistic UI update
        let tempMessage = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: currentUserId,
            participantIds: participantIds,
            text: trimmedText,
            timestamp: Date(),
            status: .sending,
            readBy: [:],
            imageUrl: nil,
            metadata: nil
        )

        // Add to messages array immediately (optimistic update)
        messages.append(tempMessage)
        isSending = true

        do {
            // Send message to Firestore
            let sentMessage = try await messageService.sendMessage(
                conversationId: conversationId,
                text: trimmedText,
                senderId: currentUserId,
                participantIds: participantIds
            )

            // Replace temporary message with real message
            if let tempId = tempMessage.id,
               let index = messages.firstIndex(where: { $0.id == tempId }) {
                messages[index] = sentMessage
            }

            // Update conversation's last message
            print("🔄 [ChatViewModel] Updating conversation lastMessage to: '\(trimmedText)'")
            try await conversationService.updateLastMessage(
                conversationId: conversationId,
                text: trimmedText,
                timestamp: sentMessage.timestamp
            )
            print("✅ [ChatViewModel] Conversation lastMessage updated successfully")

            isSending = false
        } catch {
            // Mark message as failed
            if let tempId = tempMessage.id,
               let index = messages.firstIndex(where: { $0.id == tempId }) {
                messages.remove(at: index)
            }

            errorMessage = "Failed to send message: \(error.localizedDescription)"
            isSending = false
        }
    }

    /// Marks messages as read by the current user
    func markMessagesAsRead() async {
        guard let currentUserId = currentUserId else { return }

        let unreadMessages = messages.filter { message in
            message.senderId != currentUserId &&
            message.readBy[currentUserId] == nil
        }

        for message in unreadMessages {
            guard let messageId = message.id else { continue }
            try? await messageService.markMessageAsRead(messageId: messageId, userId: currentUserId)
        }
    }

    // MARK: - Helper Methods

    /// Checks if a message is from the current user
    func isFromCurrentUser(_ message: Message) -> Bool {
        return message.senderId == currentUserId
    }

    // MARK: - Private Methods

    private func setupMessageListener() {
        messagesListener?.remove()

        guard let userId = currentUserId else {
            print("❌ [ChatViewModel] Cannot setup listener: no current user ID")
            return
        }

        messagesListener = messageService.listenToMessages(conversationId: conversationId, userId: userId) { [weak self] messages in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Build a set of optimistic message identifiers (text + senderId + rough timestamp)
                // to match against incoming Firestore messages
                var optimisticMessages: [String: Message] = [:]
                for message in self.messages where message.status == .sending {
                    let key = "\(message.senderId)|\(message.text)|\(Int(message.timestamp.timeIntervalSince1970))"
                    optimisticMessages[key] = message
                }

                // Process messages from Firestore
                var updatedMessages: [Message] = []
                var processedOptimisticKeys = Set<String>()

                for message in messages {
                    // Check if this message matches an optimistic one
                    let key = "\(message.senderId)|\(message.text)|\(Int(message.timestamp.timeIntervalSince1970))"

                    if optimisticMessages[key] != nil {
                        // This is the confirmed version of an optimistic message
                        processedOptimisticKeys.insert(key)
                    }

                    updatedMessages.append(message)
                }

                // Add any optimistic messages that haven't been confirmed yet
                for (key, message) in optimisticMessages {
                    if !processedOptimisticKeys.contains(key) {
                        updatedMessages.append(message)
                    }
                }

                // Sort by timestamp
                updatedMessages.sort { $0.timestamp < $1.timestamp }

                self.messages = updatedMessages
            }
        }
    }

    private func setupConversationListener() {
        conversationListener?.remove()

        guard let userId = currentUserId else {
            print("❌ [ChatViewModel] Cannot setup conversation listener: no current user ID")
            return
        }

        // Listen to this specific conversation for updates
        conversationListener = conversationService.db
            .collection("conversations")
            .document(conversationId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    if let error = error {
                        print("❌ [ChatViewModel] Conversation listener error: \(error.localizedDescription)")
                        return
                    }

                    guard let snapshot = snapshot, snapshot.exists else {
                        print("❌ [ChatViewModel] Conversation document does not exist")
                        return
                    }

                    if let updatedConversation = try? snapshot.data(as: Conversation.self) {
                        print("✅ [ChatViewModel] Conversation updated: \(updatedConversation.lastMessage)")
                        self.conversation = updatedConversation
                    }
                }
            }
    }

    func cleanup() {
        messagesListener?.remove()
        messagesListener = nil
        conversationListener?.remove()
        conversationListener = nil
    }
}
