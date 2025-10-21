//
//  ChatViewModel.swift
//  CreatorLink
//
//  ViewModel for managing individual chat threads
//

import Foundation
import FirebaseFirestore
import FirebaseDatabase
import Observation

@Observable
@MainActor
class ChatViewModel {
    var messages: [Message] = []
    var isLoading = false
    var errorMessage: String?
    var isSending = false
    var conversation: Conversation?
    var typingUserIds: [String] = []
    var typingUserNames: [String] = []
    var isViewActive = false  // Track if chat view is currently visible

    private let messageService = MessageService.shared
    private let conversationService = ConversationService.shared
    private let userService = UserService.shared
    private let typingService = TypingService.shared
    private var messagesListener: ListenerRegistration?
    private var conversationListener: ListenerRegistration?
    private var typingListener: DatabaseHandle?
    private var typingDebounceTimer: Timer?

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
        guard let userId = userService.currentUserId else {
            errorMessage = "No user logged in"
            return
        }

        currentUserId = userId
        isLoading = true
        errorMessage = nil

        do {
            // Load conversation to get participantIds
            if let conversation = try await conversationService.fetchConversation(conversationId: conversationId) {
                self.conversation = conversation
                participantIds = conversation.participantIds
            } else {
                throw ConversationError.invalidData
            }

            messages = try await messageService.fetchMessages(conversationId: conversationId, userId: userId)
            isLoading = false

            // Set up real-time listeners
            setupMessageListener()
            setupConversationListener()
            setupTypingListener()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Sends a message with optimistic UI update
    func sendMessage(text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        guard let currentUserId = currentUserId else {
            errorMessage = "No user logged in"
            return
        }

        guard !participantIds.isEmpty else {
            errorMessage = "Cannot send message: participant information not loaded"
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

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

            // Clear typing indicator when message is sent
            typingService.clearTyping(conversationId: conversationId, userId: currentUserId)

            // Update conversation's last message
            try await conversationService.updateLastMessage(
                conversationId: conversationId,
                text: trimmedText,
                timestamp: sentMessage.timestamp
            )

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

        // Filter for unread messages (not sent by current user and not in readBy map)
        let unreadMessages = messages.filter { message in
            message.senderId != currentUserId &&
            message.readBy[currentUserId] == nil
        }

        // Extract message IDs
        let messageIds = unreadMessages.compactMap { $0.id }

        guard !messageIds.isEmpty else { return }

        do {
            // Use batch update for efficiency
            try await messageService.markMessagesAsRead(messageIds: messageIds, userId: currentUserId)
        } catch {
            // Don't throw - this is a non-critical operation that shouldn't block the UI
        }
    }

    // MARK: - Helper Methods

    /// Checks if a message is from the current user
    func isFromCurrentUser(_ message: Message) -> Bool {
        return message.senderId == currentUserId
    }

    /// Called when user is typing in the text field
    /// - Parameter isTyping: Whether the user is currently typing
    func handleTypingChange(isTyping: Bool) {
        guard let currentUserId = currentUserId else { return }

        // Cancel existing timer
        typingDebounceTimer?.invalidate()

        if isTyping {
            // Debounce: wait 500ms before sending typing indicator
            typingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.typingService.setTyping(
                        conversationId: self.conversationId,
                        userId: currentUserId,
                        isTyping: true
                    )
                }
            }
        } else {
            // Clear typing immediately when user stops
            typingService.clearTyping(conversationId: conversationId, userId: currentUserId)
        }
    }

    // MARK: - Private Methods

    private func setupMessageListener() {
        messagesListener?.remove()

        guard let userId = currentUserId else {
            return
        }

        messagesListener = messageService.listenToMessages(conversationId: conversationId, userId: userId) { [weak self] messages in
            // Use MainActor.assumeIsolated for @MainActor class (per ios_dev_notes.md)
            MainActor.assumeIsolated {
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

                // NOTE: Auto-delivery is now handled by global listener in CreatorLinkApp.swift
                // This prevents duplicate updates and ensures delivery marking works even when chat is not open
            }
        }
    }

    private func setupConversationListener() {
        conversationListener?.remove()

        guard let userId = currentUserId else {
            return
        }

        // Listen to this specific conversation for updates
        conversationListener = conversationService.db
            .collection("conversations")
            .document(conversationId)
            .addSnapshotListener { [weak self] snapshot, error in
                // Use MainActor.assumeIsolated for @MainActor class (per ios_dev_notes.md)
                MainActor.assumeIsolated {
                    guard let self = self else { return }

                    if let error = error {
                        return
                    }

                    guard let snapshot = snapshot, snapshot.exists else {
                        return
                    }

                    if let updatedConversation = try? snapshot.data(as: Conversation.self) {
                        self.conversation = updatedConversation
                    }
                }
            }
    }

    private func setupTypingListener() {
        guard let userId = currentUserId else { return }

        typingListener = typingService.listenToTyping(
            conversationId: conversationId,
            currentUserId: userId
        ) { [weak self] typingUserIds in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.typingUserIds = typingUserIds

                // Fetch user names for typing users
                var names: [String] = []
                for userId in typingUserIds {
                    if let user = try? await self.userService.fetchUser(userId: userId) {
                        names.append(user.displayName)
                    }
                }
                self.typingUserNames = names
            }
        }
    }

    func cleanup() {
        messagesListener?.remove()
        messagesListener = nil
        conversationListener?.remove()
        conversationListener = nil

        if let handle = typingListener {
            typingService.removeTypingListener(conversationId: conversationId, handle: handle)
            typingListener = nil
        }

        typingDebounceTimer?.invalidate()
        typingDebounceTimer = nil

        // Clear typing state when leaving chat
        if let currentUserId = currentUserId {
            typingService.clearTyping(conversationId: conversationId, userId: currentUserId)
        }
    }
}
