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
    var senderProfiles: [String: UserProfile] = [:]  // Cache for sender profiles

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

    // MARK: - Sender Info Methods

    /// Fetches sender profile for a given user ID (with caching)
    /// - Parameter userId: The user ID to fetch
    /// - Returns: UserProfile if found, nil otherwise
    func fetchSenderProfile(userId: String) async -> UserProfile? {
        // Check cache first
        if let cached = senderProfiles[userId] {
            return cached
        }

        // Fetch from service
        do {
            let profile = try await userService.fetchUser(userId: userId)
            senderProfiles[userId] = profile
            return profile
        } catch {
            return nil
        }
    }

    /// Gets sender display name from cache (synchronous)
    /// - Parameter userId: The user ID
    /// - Returns: Display name or fallback
    func getSenderName(userId: String) -> String {
        return senderProfiles[userId]?.displayName ?? "Someone"
    }

    /// Gets sender photo URL from cache (synchronous)
    /// - Parameter userId: The user ID
    /// - Returns: Photo URL if available
    func getSenderPhotoUrl(userId: String) -> String? {
        return senderProfiles[userId]?.photoURL
    }

    /// Determines if sender info should be shown for a message (smart grouping logic)
    /// - Parameters:
    ///   - currentMessage: The message to check
    ///   - previousMessage: The previous message in the list
    ///   - currentUserId: The current user's ID
    /// - Returns: True if sender name/avatar should be shown
    func shouldShowSenderInfo(currentMessage: Message, previousMessage: Message?, currentUserId: String) -> Bool {
        // Never show for current user's messages
        if currentMessage.senderId == currentUserId {
            return false
        }

        // Always show for first message
        guard let previous = previousMessage else {
            return true
        }

        // Show if sender changed
        if previous.senderId != currentMessage.senderId {
            return true
        }

        // Show if time gap is > 2 minutes
        let timeGap = currentMessage.timestamp.timeIntervalSince(previous.timestamp)
        if timeGap > 120 { // 2 minutes in seconds
            return true
        }

        // Otherwise, don't show (smart grouping)
        return false
    }

    /// Determines if sender avatar should be shown for a message (WhatsApp-style: avatar on LAST message)
    /// - Parameters:
    ///   - currentMessage: The message to check
    ///   - nextMessage: The next message in the list
    ///   - currentUserId: The current user's ID
    /// - Returns: True if sender avatar should be shown
    func shouldShowSenderAvatar(currentMessage: Message, nextMessage: Message?, currentUserId: String) -> Bool {
        // Never show for current user's messages
        if currentMessage.senderId == currentUserId {
            return false
        }

        // Always show for last message (no next message)
        guard let next = nextMessage else {
            return true
        }

        // Show if next sender is different
        if next.senderId != currentMessage.senderId {
            return true
        }

        // Show if time gap to next message is > 2 minutes
        let timeGap = next.timestamp.timeIntervalSince(currentMessage.timestamp)
        if timeGap > 120 { // 2 minutes in seconds
            return true
        }

        // Otherwise, don't show (smart grouping)
        return false
    }

    // MARK: - Read Count Methods

    /// Calculates the number of participants who have read a message (excluding sender)
    /// - Parameters:
    ///   - message: The message to calculate read count for
    ///   - currentUserId: The current user's ID (sender)
    /// - Returns: Count of participants who have read the message
    func calculateReadCount(message: Message, currentUserId: String) -> Int {
        // Get the readBy dictionary which maps userId -> timestamp
        let readBy = message.readBy

        // Count entries excluding the current user (sender doesn't "read" their own message)
        let readCount = readBy.keys.filter { $0 != currentUserId }.count

        return readCount
    }

    /// Calculates the number of participants who have received the message (excluding sender)
    /// - Parameters:
    ///   - message: The message to calculate delivered count for
    ///   - currentUserId: The current user's ID (sender)
    /// - Returns: Count of participants who have received the message
    func calculateDeliveredCount(message: Message, currentUserId: String) -> Int {
        // For now, return a simplified count based on message status
        // Future enhancement: track per-user delivery status
        switch message.status {
        case .sending, .sent:
            return 0
        case .delivered, .read:
            // For delivered/read, assume all participants have received it
            let totalParticipants = message.participantIds.count - 1 // Exclude sender
            return totalParticipants
        }
    }

    /// Gets the total number of participants in a conversation (excluding current user)
    /// - Parameters:
    ///   - conversation: The conversation
    ///   - currentUserId: The current user's ID
    /// - Returns: Count of other participants
    func getTotalParticipantCount(conversation: Conversation, currentUserId: String) -> Int {
        return conversation.participantIds.filter { $0 != currentUserId }.count
    }

    // MARK: - Typing Indicator Methods

    /// Formats typing indicator text for display
    /// - Parameters:
    ///   - typingUserIds: Array of user IDs currently typing
    ///   - currentUserId: The current user's ID (to filter out)
    /// - Returns: Formatted string for typing indicator
    func formatTypingIndicatorText(typingUserIds: [String], currentUserId: String) -> String {
        // Filter out current user
        let otherTypingUsers = typingUserIds.filter { $0 != currentUserId }

        // Return empty string if no one else is typing
        guard !otherTypingUsers.isEmpty else {
            return ""
        }

        // Fetch display names for typing users from cache
        var displayNames: [String] = []
        for userId in otherTypingUsers {
            let name = getSenderName(userId: userId)
            displayNames.append(name)
        }

        // Format based on count
        switch displayNames.count {
        case 0:
            return ""
        case 1:
            return "\(displayNames[0]) is typing..."
        case 2:
            return "\(displayNames[0]) and \(displayNames[1]) are typing..."
        default:
            let othersCount = displayNames.count - 2
            return "\(displayNames[0]), \(displayNames[1]), and \(othersCount) \(othersCount == 1 ? "other" : "others") are typing..."
        }
    }

    /// Determines if typing indicator should be shown
    /// - Parameter typingUsers: Array of user IDs currently typing
    /// - Returns: True if indicator should be shown
    func shouldShowTypingIndicator(typingUsers: [String]) -> Bool {
        return !typingUsers.isEmpty
    }

    /// Gets avatar URLs for typing users (up to 3)
    /// - Parameter typingUserIds: Array of user IDs currently typing
    /// - Returns: Array of photo URLs
    func getTypingUserAvatars(typingUserIds: [String]) -> [String] {
        var avatars: [String] = []

        // Get up to 3 avatars
        let usersToShow = Array(typingUserIds.prefix(3))

        for userId in usersToShow {
            if let photoUrl = getSenderPhotoUrl(userId: userId) {
                avatars.append(photoUrl)
            }
        }

        return avatars
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
