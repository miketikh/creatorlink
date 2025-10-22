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
                Text(displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .fontWeight(unreadCount > 0 ? .bold : .semibold)

                // Show typing indicator or last message
                if isOtherUserTyping {
                    Text(typingIndicatorText.isEmpty ? "typing..." : typingIndicatorText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
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
                Text(formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)

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

    // MARK: - Methods

    private func loadOtherUser() async {
        if !conversation.isGroupChat {
            otherUser = await viewModel.getOtherParticipant(in: conversation)

            // Start listening to presence for the other user
            if let otherUserId = otherUser?.id {
                listenToPresence(userId: otherUserId)
            }
        } else {
            // For group chats, load the last message sender name
            await fetchLastMessageSender()
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

                // For group chats, format the typing indicator with names
                if self.conversation.isGroupChat && !typingUserIds.isEmpty {
                    await self.updateTypingIndicatorText(typingUserIds: typingUserIds, currentUserId: currentUserId)
                } else {
                    // For one-on-one chats, keep it simple
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
                    // Silently fail - use fallback name
                    displayNames.append("Someone")
                }
            }
        }

        // Format based on count
        typingIndicatorText = formatTypingIndicatorText(displayNames: displayNames)
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
