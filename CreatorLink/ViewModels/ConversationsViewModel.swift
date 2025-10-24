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
    var tagErrorMessage: String?

    // Filter state properties
    var selectedCategoryFilters: [ConversationTag] = []
    var selectedStatusFilters: [StatusTag] = []
    var showResolvedConversations: Bool = true

    private let conversationService = ConversationService.shared
    private let userService = UserService.shared
    private let filterPreferencesService = FilterPreferencesService.shared
    private let taggingService = TaggingService.shared
    private var conversationsListener: ListenerRegistration?
    var currentUserId: String?

    // MARK: - Computed Properties

    /// Returns filtered conversations based on selected filters
    var filteredConversations: [Conversation] {
        guard let userId = currentUserId else {
            return conversations
        }

        var filtered = conversations

        // Filter by category tags (OR logic - show if ANY tag matches)
        if !selectedCategoryFilters.isEmpty {
            filtered = filtered.filter { conversation in
                let userTags = taggingService.getEffectiveTags(conversation: conversation, userId: userId)
                return selectedCategoryFilters.contains { categoryFilter in
                    userTags.categories.contains(categoryFilter)
                }
            }
        }

        // Filter by status tags (OR logic - show if ANY tag matches)
        if !selectedStatusFilters.isEmpty {
            filtered = filtered.filter { conversation in
                let userTags = taggingService.getEffectiveTags(conversation: conversation, userId: userId)
                return selectedStatusFilters.contains { statusFilter in
                    userTags.statuses.contains(statusFilter)
                }
            }
        }

        // Filter by resolved status
        if !showResolvedConversations {
            filtered = filtered.filter { conversation in
                let userTags = taggingService.getEffectiveTags(conversation: conversation, userId: userId)
                return !userTags.statuses.contains(.resolved)
            }
        }

        return filtered
    }

    // MARK: - Initialization

    init() {
        // Load saved filter preferences
        loadFilterPreferences()
    }

    /// Loads saved filter preferences from UserDefaults
    private func loadFilterPreferences() {
        let savedFilters = filterPreferencesService.loadFilters()

        // Convert raw string values back to enums
        selectedCategoryFilters = savedFilters.categoryFilters.compactMap { ConversationTag(rawValue: $0) }
        selectedStatusFilters = savedFilters.statusFilters.compactMap { StatusTag(rawValue: $0) }
        showResolvedConversations = savedFilters.showResolved
    }

    /// Saves current filter preferences to UserDefaults
    private func saveFilterPreferences() {
        let categoryRawValues = selectedCategoryFilters.map { $0.rawValue }
        let statusRawValues = selectedStatusFilters.map { $0.rawValue }

        filterPreferencesService.saveFilters(
            categoryFilters: categoryRawValues,
            statusFilters: statusRawValues,
            showResolved: showResolvedConversations
        )
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

    // MARK: - Filter Management

    /// Toggles a category filter (add if not present, remove if present)
    func toggleCategoryFilter(_ tag: ConversationTag) {
        if selectedCategoryFilters.contains(tag) {
            selectedCategoryFilters.removeAll { $0 == tag }
        } else {
            selectedCategoryFilters.append(tag)
        }
        saveFilterPreferences()
    }

    /// Toggles a status filter (add if not present, remove if present)
    func toggleStatusFilter(_ tag: StatusTag) {
        if selectedStatusFilters.contains(tag) {
            selectedStatusFilters.removeAll { $0 == tag }
        } else {
            selectedStatusFilters.append(tag)
        }
        saveFilterPreferences()
    }

    /// Clears all active filters
    func clearAllFilters() {
        selectedCategoryFilters = []
        selectedStatusFilters = []
        showResolvedConversations = true
        saveFilterPreferences()
    }

    // MARK: - Tag Update Convenience Methods

    /// Updates category tags for a conversation (user action wrapper)
    func updateConversationCategory(conversationId: String, tags: [ConversationTag]) async {
        guard let userId = currentUserId else {
            setTagError("No user logged in")
            return
        }

        do {
            try await taggingService.updateCategoryTags(conversationId: conversationId, userId: userId, tags: tags)
        } catch {
            setTagError(error.localizedDescription)
        }
    }

    /// Updates status tags for a conversation (user action wrapper)
    func updateConversationStatus(conversationId: String, tags: [StatusTag]) async {
        guard let userId = currentUserId else {
            setTagError("No user logged in")
            return
        }

        do {
            try await taggingService.updateStatusTags(conversationId: conversationId, userId: userId, tags: tags)
        } catch {
            setTagError(error.localizedDescription)
        }
    }

    /// Marks a conversation as urgent (quick action wrapper)
    func markConversationAsUrgent(conversationId: String) async {
        guard let userId = currentUserId else {
            setTagError("No user logged in")
            return
        }

        do {
            try await taggingService.markAsUrgent(conversationId: conversationId, userId: userId)
        } catch {
            setTagError(error.localizedDescription)
        }
    }

    /// Marks a conversation as resolved (quick action wrapper)
    func markConversationAsResolved(conversationId: String) async {
        guard let userId = currentUserId else {
            setTagError("No user logged in")
            return
        }

        do {
            try await taggingService.markAsResolved(conversationId: conversationId, userId: userId)
        } catch {
            setTagError(error.localizedDescription)
        }
    }

    /// Sets tag error message and clears it after 3 seconds
    private func setTagError(_ message: String) {
        tagErrorMessage = message

        // Clear error after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            tagErrorMessage = nil
        }
    }

    // MARK: - Tag Query Helpers

    /// Gets all conversations with a specific category tag
    func getConversationsWithCategory(_ category: ConversationTag) -> [Conversation] {
        guard let userId = currentUserId else {
            return []
        }

        return conversations.filter { conversation in
            let userTags = taggingService.getEffectiveTags(conversation: conversation, userId: userId)
            return userTags.categories.contains(category)
        }
    }

    /// Gets all conversations with a specific status tag
    func getConversationsWithStatus(_ status: StatusTag) -> [Conversation] {
        guard let userId = currentUserId else {
            return []
        }

        return conversations.filter { conversation in
            let userTags = taggingService.getEffectiveTags(conversation: conversation, userId: userId)
            return userTags.statuses.contains(status)
        }
    }

    /// Gets all urgent conversations
    func getUrgentConversations() -> [Conversation] {
        return getConversationsWithStatus(.urgent)
    }

    /// Gets all unresolved conversations (without Resolved status)
    func getUnresolvedConversations() -> [Conversation] {
        guard let userId = currentUserId else {
            return []
        }

        return conversations.filter { conversation in
            let userTags = taggingService.getEffectiveTags(conversation: conversation, userId: userId)
            return !userTags.statuses.contains(.resolved)
        }
    }

    /// Counts conversations matching specific tag criteria
    func countConversationsWithTag(category: ConversationTag? = nil, status: StatusTag? = nil) -> Int {
        guard let userId = currentUserId else {
            return 0
        }

        return conversations.filter { conversation in
            let userTags = taggingService.getEffectiveTags(conversation: conversation, userId: userId)

            var matches = true
            if let category = category {
                matches = matches && userTags.categories.contains(category)
            }
            if let status = status {
                matches = matches && userTags.statuses.contains(status)
            }

            return matches
        }.count
    }

    /// Computed property for urgent conversation count
    var urgentCount: Int {
        getUrgentConversations().count
    }

    /// Computed property for needs response count
    var needsResponseCount: Int {
        getConversationsWithStatus(.needsResponse).count
    }

    // MARK: - Tag Helpers

    /// Extracts user-specific tags from tagsByUser map
    /// - Parameters:
    ///   - conversation: The conversation to extract tags from
    ///   - userId: The user ID to get tags for
    /// - Returns: Tuple of category and status tags for the user
    func getTagsForUser(conversation: Conversation, userId: String) -> (categories: [ConversationTag], statuses: [StatusTag]) {
        guard let tagsByUser = conversation.tagsByUser,
              let userTagData = tagsByUser[userId] else {
            // If no user-specific tags, fall back to conversation-level category tags
            return (categories: conversation.categoryTags ?? [], statuses: [])
        }

        let categories = userTagData.categoryTags ?? conversation.categoryTags ?? []
        let statuses = userTagData.statusTags ?? []

        return (categories: categories, statuses: statuses)
    }
}
