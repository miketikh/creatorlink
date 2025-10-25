//
//  ConversationRowView.swift
//  CreatorLink
//
//  Reusable row component for displaying conversation previews
//

import SwiftUI
import FirebaseFirestore
import FirebaseDatabase

struct ConversationRowView: View {
    let conversation: Conversation
    let viewModel: ConversationsViewModel

    @State private var otherUser: UserProfile?
    @State private var isOnline = false
    @State private var lastSeen: Date?
    @State private var unreadCount = 0
    @State private var unreadCountTask: Task<Void, Never>?
    @State private var messageListener: ListenerRegistration?
    @State private var userProfileListener: ListenerRegistration?
    @State private var presenceHandle: DatabaseHandle?
    @State private var typingHandle: DatabaseHandle?
    @State private var isOtherUserTyping = false
    @State private var lastMessageSenderName: String?
    @State private var typingIndicatorText: String = ""
    @State private var typingUserProfiles: [String: UserProfile] = [:]
    @State private var lastMessageReadCount: Int?

    var body: some View {
        HStack(spacing: 12) {
            // Profile photo with online/offline indicator
            ZStack(alignment: .bottomTrailing) {
                profilePhoto

                // Online/offline indicator (green or grey dot)
                if !conversation.isGroupChat {
                    Circle()
                        .fill(isOnline ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }
            }

            // Conversation info
            VStack(alignment: .leading, spacing: 4) {
                // Name with category icon before and status icon after
                HStack(spacing: 6) {
                    // Category icon (left of name)
                    if let currentUserId = viewModel.currentUserId,
                       let categoryBadge = getCategoryBadge(userId: currentUserId) {
                        TagBadgeView(
                            emoji: categoryBadge.emoji,
                            backgroundColor: categoryBadge.backgroundColor,
                            accessibilityLabel: categoryBadge.accessibilityLabel,
                            size: 20
                        )
                    }

                    // Name
                    Text(displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .fontWeight(unreadCount > 0 ? .bold : .semibold)

                    // Status icons (right of name) with separator
                    if let currentUserId = viewModel.currentUserId,
                       let statusBadges = getStatusBadges(userId: currentUserId),
                       !statusBadges.isEmpty {
                        Text("|")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        ForEach(statusBadges.indices, id: \.self) { index in
                            TagBadgeView(
                                emoji: statusBadges[index].emoji,
                                backgroundColor: statusBadges[index].backgroundColor,
                                accessibilityLabel: statusBadges[index].accessibilityLabel,
                                size: 18
                            )
                        }
                    }
                }

                // Show typing indicator, draft preview, or last message
                if isOtherUserTyping {
                    Text(typingIndicatorText.isEmpty ? "typing..." : typingIndicatorText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                } else if let draft = getDraft() {
                    // Show draft preview with AI icon
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.indigo)

                        Text("AI DRAFT: \(draft.previewText)")
                            .font(.subheadline)
                            .foregroundColor(.indigo)
                            .lineLimit(2)
                    }
                } else {
                    HStack(spacing: 4) {
                        // Show status icon if last message is from current user
                        if let senderId = conversation.lastMessageSenderId,
                           senderId == viewModel.currentUserId,
                           let status = conversation.lastMessageStatus {
                            if conversation.isGroupChat, let readCount = lastMessageReadCount {
                                // Show read count for group chats
                                groupStatusIcon(readCount: readCount)
                            } else {
                                // Show regular status for one-on-one
                                statusIcon(for: status)
                            }
                        }

                        Text(formattedLastMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }

            Spacer()

            // Timestamp and unread badge
            VStack(alignment: .trailing, spacing: 4) {
                // Show draft timestamp if draft exists, otherwise show last message time
                if let draft = getDraft() {
                    Text(DateFormatters.formatMessageTimestamp(draft.updatedAt))
                        .font(.caption)
                        .foregroundColor(.indigo)
                } else {
                    Text(formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Unread count badge
                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 8)
        .background(isUrgent ? Color.red.opacity(0.03) : Color.clear)
        .overlay(alignment: .leading) {
            // Left border for urgent conversations
            if isUrgent {
                Rectangle()
                    .fill(Color.red.opacity(0.4))
                    .frame(width: 3)
            }
        }
        .contextMenu {
            contextMenuContent
        }
        .task {
            await loadOtherUser()
            await loadUnreadCount()
            await loadLastMessageReadCount()
            setupTypingListener()
        }
        .onAppear {
            // Refresh unread count when view appears (e.g., returning from chat)
            unreadCountTask?.cancel()
            unreadCountTask = Task {
                await loadUnreadCount()
            }
        }
        .onDisappear {
            unreadCountTask?.cancel()
            messageListener?.remove()
            userProfileListener?.remove()

            // Clean up presence listener
            if let otherUserId = otherUser?.id, let handle = presenceHandle {
                PresenceService.shared.removePresenceListener(userId: otherUserId, handle: handle)
            }

            // Clean up typing listener
            if let conversationId = conversation.id, let handle = typingHandle {
                TypingService.shared.removeTypingListener(conversationId: conversationId, handle: handle)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var contextMenuContent: some View {
        // Get current user's tags
        let userId = viewModel.currentUserId ?? ""
        let tags = TaggingService.shared.getEffectiveTags(conversation: conversation, userId: userId)
        let hasUrgent = tags.statuses.contains(.urgent)
        let hasResolved = tags.statuses.contains(.resolved)

        // Quick tag actions
        Button {
            handleTagAction(.markUrgent)
        } label: {
            Label(hasUrgent ? "Remove Urgent" : "Mark as Urgent", systemImage: hasUrgent ? "flame.fill" : "flame")
        }
        .accessibilityLabel(hasUrgent ? "Remove urgent flag" : "Mark conversation as urgent")
        .accessibilityHint(hasUrgent ? "Removes urgent priority from this conversation" : "Flags this conversation as urgent requiring immediate attention")

        Button {
            handleTagAction(.markResolved)
        } label: {
            Label(hasResolved ? "Mark as Unresolved" : "Mark as Resolved", systemImage: hasResolved ? "checkmark.circle.fill" : "checkmark.circle")
        }
        .accessibilityLabel(hasResolved ? "Mark as unresolved" : "Mark conversation as resolved")
        .accessibilityHint(hasResolved ? "Marks this conversation as needing attention" : "Marks this conversation as completed")

        Divider()

        // Category tags submenu
        Menu {
            ForEach([ConversationTag.business, .collaboration, .social, .fan], id: \.self) { tag in
                Button {
                    handleTagAction(.toggleCategory(tag))
                } label: {
                    Label(tag.displayName, systemImage: tags.categories.contains(tag) ? "checkmark" : "")
                }
                .accessibilityLabel("Tag as \(tag.displayName)")
                .accessibilityHint(tags.categories.contains(tag) ? "Currently tagged, tap to remove" : "Tap to add \(tag.displayName) tag")
            }
        } label: {
            Label("Change Category", systemImage: "folder")
        }
        .accessibilityLabel("Change conversation category")
        .accessibilityHint("Opens menu to select conversation category tags")

        Divider()

        // Remove all tags
        Button(role: .destructive) {
            handleTagAction(.removeAll)
        } label: {
            Label("Remove Tags", systemImage: "trash")
        }
        .accessibilityLabel("Remove all tags")
        .accessibilityHint("Removes all category and status tags from this conversation")
    }

    private var profilePhoto: some View {
        Group {
            if conversation.isGroupChat {
                // Show group avatar for group chats
                GroupAvatarView(
                    groupImageUrl: conversation.groupImageUrl,
                    participantIds: conversation.participantIds,
                    size: 50
                )
            } else {
                // Show single user photo for one-on-one chats
                // Supports both Google profile photos and generated avatars (UI Avatars API)
                if let photoURL = otherUser?.photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        case .failure:
                            placeholderImage
                        @unknown default:
                            placeholderImage
                        }
                    }
                } else {
                    placeholderImage
                }
            }
        }
    }

    private var placeholderImage: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 50, height: 50)

            Text(initials)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
    }

    // MARK: - Computed Properties

    private var displayName: String {
        if conversation.isGroupChat {
            return conversation.groupName ?? "Group Chat"
        } else {
            return otherUser?.displayName ?? "User"
        }
    }

    private var initials: String {
        if conversation.isGroupChat {
            return "G"
        } else {
            let name = otherUser?.displayName ?? "U"
            let components = name.split(separator: " ")
            if components.count >= 2 {
                return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
            } else {
                return String(name.prefix(1)).uppercased()
            }
        }
    }

    private var formattedTimestamp: String {
        DateFormatters.formatMessageTimestamp(conversation.lastMessageTime)
    }

    private var formattedLastMessage: String {
        // For group chats, prefix with sender name
        if conversation.isGroupChat {
            // Check if current user sent the last message
            if let senderId = conversation.lastMessageSenderId, senderId == viewModel.currentUserId {
                return "You: \(conversation.lastMessage)"
            } else if let senderName = lastMessageSenderName {
                return "\(senderName): \(conversation.lastMessage)"
            } else {
                // Fallback if sender name not loaded yet
                return conversation.lastMessage
            }
        } else {
            // For one-on-one chats, just show the message
            return conversation.lastMessage
        }
    }

    private var hasAnyTags: Bool {
        guard let userId = viewModel.currentUserId else { return false }
        let tags = TaggingService.shared.getEffectiveTags(conversation: conversation, userId: userId)
        return !tags.categories.isEmpty || !tags.statuses.isEmpty
    }

    private var isUrgent: Bool {
        guard let userId = viewModel.currentUserId else { return false }
        let tags = TaggingService.shared.getEffectiveTags(conversation: conversation, userId: userId)
        return tags.statuses.contains(.urgent)
    }

    // Badge info structure for inline display
    private struct BadgeInfo {
        let emoji: String
        let backgroundColor: Color
        let accessibilityLabel: String
    }

    /// Get category badge for inline display (first category only)
    private func getCategoryBadge(userId: String) -> BadgeInfo? {
        let tags = TaggingService.shared.getEffectiveTags(conversation: conversation, userId: userId)
        guard !tags.categories.isEmpty else { return nil }

        let category = tags.categories[0]
        return BadgeInfo(
            emoji: category.emoji,
            backgroundColor: .clear,
            accessibilityLabel: "\(category.displayName) category"
        )
    }

    /// Get status badges for inline display
    private func getStatusBadges(userId: String) -> [BadgeInfo]? {
        let tags = TaggingService.shared.getEffectiveTags(conversation: conversation, userId: userId)
        guard !tags.statuses.isEmpty else { return nil }

        var badges: [BadgeInfo] = []

        // Priority order: urgent, needsResponse, awaitingReply, resolved
        if tags.statuses.contains(.urgent) {
            badges.append(BadgeInfo(
                emoji: StatusTag.urgent.emoji,
                backgroundColor: Color.red.opacity(0.1),
                accessibilityLabel: "Urgent status"
            ))
        }

        if tags.statuses.contains(.needsResponse) {
            badges.append(BadgeInfo(
                emoji: StatusTag.needsResponse.emoji,
                backgroundColor: .clear,
                accessibilityLabel: "Needs response status"
            ))
        }

        if tags.statuses.contains(.awaitingReply) {
            badges.append(BadgeInfo(
                emoji: StatusTag.awaitingReply.emoji,
                backgroundColor: .clear,
                accessibilityLabel: "Awaiting reply status"
            ))
        }

        if tags.statuses.contains(.resolved) {
            badges.append(BadgeInfo(
                emoji: StatusTag.resolved.emoji,
                backgroundColor: .clear,
                accessibilityLabel: "Resolved status"
            ))
        }

        // Limit to max 2 status badges
        return badges.isEmpty ? nil : Array(badges.prefix(2))
    }

    // MARK: - Tag Actions

    private enum TagAction {
        case markUrgent
        case markResolved
        case toggleCategory(ConversationTag)
        case removeAll
    }

    private func handleTagAction(_ action: TagAction) {
        guard let conversationId = conversation.id,
              let userId = viewModel.currentUserId else {
            return
        }

        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        Task {
            do {
                let currentTags = TaggingService.shared.getEffectiveTags(conversation: conversation, userId: userId)

                switch action {
                case .markUrgent:
                    // Toggle urgent status
                    if currentTags.statuses.contains(.urgent) {
                        try await TaggingService.shared.removeUrgent(conversationId: conversationId, userId: userId)
                    } else {
                        try await TaggingService.shared.markAsUrgent(conversationId: conversationId, userId: userId)
                    }

                case .markResolved:
                    // Toggle resolved status
                    if currentTags.statuses.contains(.resolved) {
                        // Remove resolved status
                        var newStatuses = currentTags.statuses
                        newStatuses.removeAll { $0 == .resolved }
                        try await TaggingService.shared.updateStatusTags(conversationId: conversationId, userId: userId, tags: newStatuses)
                    } else {
                        try await TaggingService.shared.markAsResolved(conversationId: conversationId, userId: userId)
                    }

                case .toggleCategory(let tag):
                    // Toggle category tag
                    var newCategories = currentTags.categories
                    if newCategories.contains(tag) {
                        newCategories.removeAll { $0 == tag }
                    } else {
                        newCategories.append(tag)
                        // Limit to max 2 tags
                        if newCategories.count > 2 {
                            newCategories = Array(newCategories.suffix(2))
                        }
                    }
                    try await TaggingService.shared.updateCategoryTags(conversationId: conversationId, userId: userId, tags: newCategories)

                case .removeAll:
                    // Remove all tags
                    try await TaggingService.shared.updateCategoryTags(conversationId: conversationId, userId: userId, tags: [])
                    try await TaggingService.shared.updateStatusTags(conversationId: conversationId, userId: userId, tags: [])
                }
            } catch {
                // Silently fail - real-time listener will show current state
                print("Error updating tags: \(error)")
            }
        }
    }

    // MARK: - Methods

    private func loadOtherUser() async {
        if !conversation.isGroupChat {
            otherUser = await viewModel.getOtherParticipant(in: conversation)

            // Start listening to presence for the other user
            if let otherUserId = otherUser?.id {
                listenToPresence(userId: otherUserId)
                setupUserProfileListener(userId: otherUserId)
            }
        } else {
            // For group chats, load the last message sender name
            await fetchLastMessageSender()
        }
    }

    private func setupUserProfileListener(userId: String) {
        // Remove existing listener if any
        userProfileListener?.remove()

        // Set up real-time listener for the other user's profile
        userProfileListener = FirestoreService.shared.usersCollection
            .document(userId)
            .addSnapshotListener { [self] snapshot, error in
                guard let snapshot = snapshot,
                      snapshot.exists,
                      let data = snapshot.data() else {
                    return
                }

                // Update otherUser with new profile data
                Task { @MainActor in
                    self.otherUser = UserProfile(
                        id: userId,
                        displayName: data["displayName"] as? String ?? "Unknown User",
                        email: data["email"] as? String ?? "",
                        photoURL: data["photoURL"] as? String,
                        isOnline: data["isOnline"] as? Bool ?? false,
                        lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue() ?? Date(),
                        aiResponseModeEnabled: data["aiResponseModeEnabled"] as? Bool
                    )
                }
            }
    }

    private func fetchLastMessageSender() async {
        // Skip if current user sent the message
        guard let senderId = conversation.lastMessageSenderId,
              senderId != viewModel.currentUserId else {
            return
        }

        // Fetch sender profile
        do {
            let senderProfile = try await UserService.shared.fetchUser(userId: senderId)
            lastMessageSenderName = senderProfile.displayName
        } catch {
            // Silently fail - will show message without sender prefix
            lastMessageSenderName = nil
        }
    }

    private func listenToPresence(userId: String) {
        presenceHandle = PresenceService.shared.listenToPresence(userId: userId) { [self] online, lastSeenDate in
            Task { @MainActor in
                self.isOnline = online
                self.lastSeen = lastSeenDate
            }
        }
    }

    private func formattedLastSeen(_ date: Date) -> String {
        DateFormatters.formatLastOnline(date)
    }

    private func loadLastMessageReadCount() async {
        // Only calculate read count for group chats where current user sent the last message
        guard conversation.isGroupChat,
              let senderId = conversation.lastMessageSenderId,
              senderId == viewModel.currentUserId,
              let conversationId = conversation.id else {
            return
        }

        // Fetch the last message to get readBy data
        do {
            if let currentUserId = viewModel.currentUserId {
                let messages = try await MessageService.shared.fetchMessages(conversationId: conversationId, userId: currentUserId)
                if let lastMessage = messages.last {
                    // Calculate read count (excluding current user)
                    let readCount = lastMessage.readBy.keys.filter { $0 != currentUserId }.count
                    lastMessageReadCount = readCount
                }
            }
        } catch {
            // Silently fail - will show regular status icon
            lastMessageReadCount = nil
        }
    }

    private func statusIcon(for status: MessageStatus) -> some View {
        Group {
            switch status {
            case .sending:
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.gray)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.gray)
            case .delivered:
                Image(systemName: "checkmark.checkmark")
                    .font(.caption2)
                    .foregroundColor(.gray)
            case .read:
                Image(systemName: "checkmark.checkmark")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
    }

    private func groupStatusIcon(readCount: Int) -> some View {
        HStack(spacing: 2) {
            // Double checkmark
            ZStack {
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(readCount > 0 ? .blue : .gray)
                    .offset(x: -1)
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(readCount > 0 ? .blue : .gray)
                    .offset(x: 1)
            }

            // Read count
            Text("\(readCount)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func loadUnreadCount() async {
        // OPTIMIZATION: First check denormalized count in conversation document
        if let unreadCounts = conversation.unreadCounts,
           let currentUserId = viewModel.currentUserId,
           let count = unreadCounts[currentUserId] {
            // Use denormalized count from conversation document (fast)
            unreadCount = count
        } else {
            // Fallback: Calculate from messages (slower)
            let count = await viewModel.getUnreadCount(for: conversation)
            unreadCount = count
        }

        // Set up real-time listener to update unread count when messages change
        setupUnreadCountListener()
    }

    private func setupUnreadCountListener() {
        guard let conversationId = conversation.id,
              let currentUserId = viewModel.currentUserId else {
            return
        }

        // Remove existing listener if any
        messageListener?.remove()

        // Listen to message changes in this conversation
        messageListener = MessageService.shared.listenToMessages(conversationId: conversationId, userId: currentUserId) { [self] messages in
            // Count unread messages (messages not sent by current user and not in readBy)
            // This logic works for both one-on-one and group chats:
            // - Filter out messages from current user (don't count own messages as unread)
            // - Filter out messages where current user is in readBy dictionary
            let newUnreadCount = messages.filter { message in
                message.senderId != currentUserId && message.readBy[currentUserId] == nil
            }.count

            Task { @MainActor in
                if self.unreadCount != newUnreadCount {
                    self.unreadCount = newUnreadCount
                }
            }
        }
    }

    private func setupTypingListener() {
        guard let conversationId = conversation.id,
              let currentUserId = viewModel.currentUserId else {
            return
        }

        // Listen to typing indicators for this conversation
        typingHandle = TypingService.shared.listenToTyping(
            conversationId: conversationId,
            currentUserId: currentUserId
        ) { [self] typingUserIds in
            Task { @MainActor in
                // Update typing state - we only care if ANYONE else is typing
                self.isOtherUserTyping = !typingUserIds.isEmpty

                // Fetch and format typing indicator with names for ALL chat types
                if !typingUserIds.isEmpty {
                    await self.updateTypingIndicatorText(typingUserIds: typingUserIds, currentUserId: currentUserId)
                } else {
                    self.typingIndicatorText = ""
                }
            }
        }
    }

    /// Updates the typing indicator text with formatted user names
    private func updateTypingIndicatorText(typingUserIds: [String], currentUserId: String) async {
        // Filter out current user
        let otherTypingUsers = typingUserIds.filter { $0 != currentUserId }

        guard !otherTypingUsers.isEmpty else {
            typingIndicatorText = ""
            return
        }

        // Fetch user profiles for typing users
        var displayNames: [String] = []
        for userId in otherTypingUsers {
            // For one-on-one chats, use the already-loaded otherUser for optimization
            if !self.conversation.isGroupChat, let otherUser = self.otherUser, userId == otherUser.id {
                displayNames.append(otherUser.displayName)
                continue
            }

            // Check cache first
            if let cachedProfile = typingUserProfiles[userId] {
                displayNames.append(cachedProfile.displayName)
            } else {
                // Fetch and cache the profile
                do {
                    let profile = try await UserService.shared.fetchUser(userId: userId)
                    typingUserProfiles[userId] = profile
                    displayNames.append(profile.displayName)
                } catch {
                    // If fetch fails, try again on next typing event
                    // Skip this user for now rather than showing "Someone"
                    continue
                }
            }
        }

        // Format based on count
        // If we couldn't fetch any names, show generic indicator while loading
        if displayNames.isEmpty && !otherTypingUsers.isEmpty {
            typingIndicatorText = "typing..."
        } else {
            typingIndicatorText = formatTypingIndicatorText(displayNames: displayNames)
        }
    }

    /// Formats typing indicator text based on number of typers
    private func formatTypingIndicatorText(displayNames: [String]) -> String {
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

    /// Gets draft for this conversation if one exists
    private func getDraft() -> MessageDraft? {
        guard let conversationId = conversation.id else { return nil }
        return viewModel.getDraft(for: conversationId)
    }
}

#Preview {
    List {
        ConversationRowView(
            conversation: Conversation(
                id: "1",
                participantIds: ["user1", "user2"],
                lastMessage: "Hey, how are you doing today?",
                lastMessageTime: Date().addingTimeInterval(-3600),
                isGroupChat: false,
                groupName: nil
            ),
            viewModel: ConversationsViewModel()
        )
    }
}
