//
//  ChatDetailView.swift
//  CreatorLink
//
//  Main chat interface showing message history and input field
//  Note: User avatars support both Google profile photos and
//  generated avatars (UI Avatars API)
//

import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import UIKit

struct ChatDetailView: View {
    let initialConversation: Conversation
    let savedScrollPosition: String?
    let onScrollPositionChanged: (String?) -> Void

    @State private var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var otherUser: UserProfile?
    @State private var isOnline = false
    @State private var lastSeen: Date?
    @State private var presenceHandle: DatabaseHandle?
    @State private var scrollPosition: String? = nil
    @State private var isNearBottom: Bool = true
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var unreadMessagesCount: Int = 0
    @State private var showGroupInfo = false
    @State private var selectedMessageForDetails: Message?
    @State private var userLeftGroup = false
    @State private var showLeftGroupConfirmation = false
    @State private var highlightedMessageId: String?
    @State private var faqScrollError: String?
    @State private var showFAQError = false
    @State private var isLoadingFAQReference = false
    @State private var showTagEditor = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // Computed property to get the live conversation from ViewModel
    private var conversation: Conversation {
        viewModel.conversation ?? initialConversation
    }

    init(conversation: Conversation, savedScrollPosition: String? = nil, onScrollPositionChanged: @escaping (String?) -> Void = { _ in }) {
        // Ensure conversation has a valid ID
        guard let conversationId = conversation.id, !conversationId.isEmpty else {
            self.initialConversation = conversation
            self.savedScrollPosition = savedScrollPosition
            self.onScrollPositionChanged = onScrollPositionChanged
            _viewModel = State(initialValue: ChatViewModel(conversationId: ""))
            _scrollPosition = State(initialValue: savedScrollPosition)
            return
        }

        self.initialConversation = conversation
        self.savedScrollPosition = savedScrollPosition
        self.onScrollPositionChanged = onScrollPositionChanged
        _viewModel = State(initialValue: ChatViewModel(conversationId: conversationId))
        _scrollPosition = State(initialValue: savedScrollPosition)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            messagesScrollView

            // Typing indicator (positioned above input)
            if !viewModel.typingUserIds.isEmpty {
                let currentUserId = AuthService.shared.currentUser?.uid ?? ""
                let formattedText = viewModel.formatTypingIndicatorText(
                    typingUserIds: viewModel.typingUserIds,
                    currentUserId: currentUserId
                )
                let avatars = viewModel.getTypingUserAvatars(typingUserIds: viewModel.typingUserIds)

                if !formattedText.isEmpty {
                    TypingIndicatorView(
                        typingUserNames: viewModel.typingUserNames,
                        typingUserAvatars: avatars,
                        isGroupChat: conversation.isGroupChat,
                        formattedText: formattedText
                    )
                }
            }

            // Input area
            messageInputArea
        }
        .overlay {
            // Loading indicator for FAQ reference fetching
            if isLoadingFAQReference {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showTagEditor = true
                } label: {
                    Image(systemName: "tag")
                        .font(.body)
                }
                .accessibilityLabel("Edit conversation tags")
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    // Profile photo or group avatar
                    if conversation.isGroupChat {
                        // Show group avatar for group chats
                        GroupAvatarView(
                            groupImageUrl: conversation.groupImageUrl,
                            participantIds: conversation.participantIds,
                            size: 30
                        )
                    } else {
                        // Show user photo for one-on-one chats
                        // Supports both Google profile photos and generated avatars (UI Avatars API)
                        if let photoURL = otherUser?.photoURL, let url = URL(string: photoURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                            }
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                        }
                    }

                    // Name, status/participant count, and tags
                    VStack(alignment: .leading, spacing: 2) {
                        Text(navigationTitle)
                            .font(.headline)

                        // Tag badges (if any tags exist for current user)
                        if let currentUserId = AuthService.shared.currentUser?.uid, hasAnyTags {
                            ConversationTagsView(conversation: conversation, userId: currentUserId)
                                .id(conversation.tagsByUser?[currentUserId]) // Force re-render when tags change
                        }

                        if conversation.isGroupChat {
                            // Show participant count for groups
                            Text("\(conversation.participantIds.count) members")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            // Show online status or last seen for one-on-one
                            if isOnline {
                                Text("Active now")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else if let lastSeen = lastSeen {
                                Text(formattedLastSeen(lastSeen))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Chevron icon for group chats to indicate tappability
                    if conversation.isGroupChat {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if conversation.isGroupChat {
                        showGroupInfo = true
                    }
                }
            }
        }
        .onChange(of: viewModel.messages) { oldMessages, newMessages in
            // When new messages arrive while conversation is open
            guard let currentUserId = AuthService.shared.currentUser?.uid else { return }

            // Find new messages from OTHER users (not your own)
            let oldIds = Set(oldMessages.map { $0.id })
            let newMessagesFromOthers = newMessages.filter { message in
                guard let messageId = message.id else { return false }
                return !oldIds.contains(messageId) && message.senderId != currentUserId
            }

            if !newMessagesFromOthers.isEmpty {
                // Auto-mark as read immediately (standard chat app behavior)
                Task {
                    await viewModel.markMessagesAsRead()
                }

                // Auto-scroll to bottom if user is already at bottom
                if isNearBottom, let lastMessage = newMessages.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                } else {
                    // User is scrolled up - increment by count of new messages from others
                    unreadMessagesCount += newMessagesFromOthers.count
                }
            }
        }
        .onAppear {
            // Set view as active to prevent auto-delivery race condition
            viewModel.isViewActive = true
            // Track active conversation for notification suppression
            if let conversationId = conversation.id {
                NavigationCoordinator.shared.setActiveConversation(conversationId)
            }
            // Also mark messages as read when view appears (handles navigation back)
            Task {
                await markMessagesAsReadAndUpdateBadge()
            }
        }
        .onDisappear {
            // Save scroll position before leaving
            onScrollPositionChanged(scrollPosition)

            // Clear active conversation tracking
            NavigationCoordinator.shared.setActiveConversation(nil)

            // Set view as inactive so auto-delivery can run for background messages
            viewModel.isViewActive = false
            viewModel.cleanup()

            // Clean up presence listener
            if let otherUserId = otherUser?.id, let handle = presenceHandle {
                PresenceService.shared.removePresenceListener(userId: otherUserId, handle: handle)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showGroupInfo) {
            NavigationStack {
                GroupInfoView(conversation: conversation, userLeftGroup: $userLeftGroup) {
                    showGroupInfo = false
                }
            }
        }
        .onChange(of: userLeftGroup) { _, didLeave in
            if didLeave {
                // User left the group - show confirmation first
                showGroupInfo = false
                showLeftGroupConfirmation = true
            }
        }
        .alert("Group Left", isPresented: $showLeftGroupConfirmation) {
            Button("OK") {
                showLeftGroupConfirmation = false
                // Dismiss the view after user acknowledges the alert
                dismiss()
            }
        } message: {
            Text("You have left the group")
        }
        .alert("Message Not Found", isPresented: $showFAQError) {
            Button("OK") { }
        } message: {
            Text(faqScrollError ?? "The referenced message could not be found.")
        }
        .sheet(item: $selectedMessageForDetails) { message in
            // Get participant profiles for the message
            let participantProfiles = conversation.participantIds.compactMap { userId in
                viewModel.senderProfiles[userId]
            }
            MessageReadDetailsView(message: message, participants: participantProfiles)
        }
        .sheet(isPresented: $showTagEditor) {
            if let currentUserId = AuthService.shared.currentUser?.uid {
                TagEditorSheet(conversation: conversation, userId: currentUserId)
            }
        }
    }

    // MARK: - Subviews

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            let _ = {
                // Capture the proxy for use in scroll-to-bottom button
                DispatchQueue.main.async {
                    self.scrollProxy = proxy
                }
            }()

            ScrollView {
                LazyVStack(spacing: 4) {
                    if viewModel.isLoading {
                        ProgressView("Loading messages...")
                            .padding()
                    } else if viewModel.messages.isEmpty {
                        emptyMessagesView
                    } else {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let previousMessage = index > 0 ? viewModel.messages[index - 1] : nil
                            let nextMessage = index < viewModel.messages.count - 1 ? viewModel.messages[index + 1] : nil
                            let currentUserId = AuthService.shared.currentUser?.uid ?? ""
                            let showSenderInfo = viewModel.shouldShowSenderInfo(
                                currentMessage: message,
                                previousMessage: previousMessage,
                                currentUserId: currentUserId
                            )
                            let showSenderAvatar = viewModel.shouldShowSenderAvatar(
                                currentMessage: message,
                                nextMessage: nextMessage,
                                currentUserId: currentUserId
                            )
                            let senderName = viewModel.getSenderName(userId: message.senderId)
                            let senderPhotoUrl = viewModel.getSenderPhotoUrl(userId: message.senderId)

                            // Calculate read counts for group messages from current user
                            let readCount = (conversation.isGroupChat && viewModel.isFromCurrentUser(message))
                                ? viewModel.calculateReadCount(message: message, currentUserId: currentUserId)
                                : nil
                            let deliveredCount = (conversation.isGroupChat && viewModel.isFromCurrentUser(message))
                                ? viewModel.calculateDeliveredCount(message: message, currentUserId: currentUserId)
                                : nil
                            let totalParticipants = conversation.isGroupChat
                                ? viewModel.getTotalParticipantCount(conversation: conversation, currentUserId: currentUserId)
                                : nil

                            VStack(spacing: 4) {
                                // Show date separator if this is a new day
                                if shouldShowDateSeparator(at: index) {
                                    DateSeparatorView(date: message.timestamp)
                                }

                                MessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: viewModel.isFromCurrentUser(message),
                                    showTimestamp: shouldShowTimestamp(at: index),
                                    isGroupChat: conversation.isGroupChat,
                                    showSenderInfo: showSenderInfo,
                                    showSenderAvatar: showSenderAvatar,
                                    senderName: senderName,
                                    senderPhotoUrl: senderPhotoUrl,
                                    readCount: readCount,
                                    deliveredCount: deliveredCount,
                                    totalParticipants: totalParticipants,
                                    onTapStatusIndicator: {
                                        // Only allow tapping for group messages from current user
                                        if conversation.isGroupChat && viewModel.isFromCurrentUser(message) {
                                            selectedMessageForDetails = message
                                        }
                                    },
                                    onTapFAQReference: { messageId in
                                        Task {
                                            await scrollToMessage(messageId: messageId)
                                        }
                                    }
                                )
                            }
                            .id(message.id)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: VisibleMessagePreferenceKey.self,
                                        value: [VisibleMessage(
                                            id: message.id ?? "",
                                            minY: geometry.frame(in: .named("scrollView")).minY
                                        )]
                                    )
                                }
                            )
                            .background(
                                highlightedMessageId == message.id ?
                                    Color.yellow.opacity(0.3) : Color.clear
                            )
                            .animation(.easeInOut(duration: 0.3), value: highlightedMessageId)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .coordinateSpace(name: "scrollView")
            .onScrollGeometryChange(for: Bool.self) { geometry in
                // Calculate if we're near the bottom (within 200 points)
                let contentHeight = geometry.contentSize.height
                let scrollOffset = geometry.contentOffset.y
                let containerHeight = geometry.containerSize.height
                let distanceFromBottom = contentHeight - (scrollOffset + containerHeight)

                // Consider "near bottom" if within 200 points or if content fits in view
                return distanceFromBottom < 200 || contentHeight <= containerHeight
            } action: { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isNearBottom = newValue
                }
                // Reset unread counter when user scrolls to bottom
                if newValue && !oldValue {
                    unreadMessagesCount = 0
                }
            }
            .onPreferenceChange(VisibleMessagePreferenceKey.self) { messages in
                // Find the message closest to the top (smallest positive minY)
                if let topMessage = messages
                    .filter({ $0.minY >= 0 && $0.minY < 200 })
                    .min(by: { $0.minY < $1.minY }) {
                    scrollPosition = topMessage.id
                }
            }
            .task {
                await loadData()

                // Pre-fetch all participant profiles for group chats
                if conversation.isGroupChat {
                    for participantId in conversation.participantIds {
                        _ = await viewModel.fetchSenderProfile(userId: participantId)
                    }
                }

                // Scroll to saved position or bottom AFTER messages load
                if let savedPos = savedScrollPosition {
                    proxy.scrollTo(savedPos, anchor: .top)
                } else if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }

                // Mark messages as read after initial load
                await markMessagesAsReadAndUpdateBadge()
            }
            .overlay(alignment: .bottomTrailing) {
                scrollToBottomButton
            }
        }
    }

    private var emptyMessagesView: some View {
        VStack(spacing: 16) {
            Image(systemName: conversation.isGroupChat ? "person.3" : "message")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No messages yet")
                .font(.headline)
                .foregroundColor(.secondary)

            if conversation.isGroupChat {
                Text("Group created! Say hello to everyone.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text("Send a message to start the conversation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scrollToBottomButton: some View {
        Group {
            if !isNearBottom {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // Reset unread counter when scrolling to bottom
                        unreadMessagesCount = 0
                        if let lastMessage = viewModel.messages.last {
                            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                        // Badge showing unread count
                        if unreadMessagesCount > 0 {
                            Text("\(unreadMessagesCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var messageInputArea: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .onChange(of: messageText) { oldValue, newValue in
                        // Trigger typing indicator when text changes
                        let isTyping = !newValue.isEmpty
                        viewModel.handleTypingChange(isTyping: isTyping)
                    }

                Button {
                    Task {
                        await sendMessage()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSendMessage ? .blue : .gray)
                }
                .disabled(!canSendMessage)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Computed Properties

    private var navigationTitle: String {
        if conversation.isGroupChat {
            return conversation.groupName ?? "Group Chat"
        } else {
            return otherUser?.displayName ?? "Chat"
        }
    }

    private var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSending
    }

    private var hasAnyTags: Bool {
        guard let userId = AuthService.shared.currentUser?.uid else { return false }
        let tags = TaggingService.shared.getEffectiveTags(conversation: conversation, userId: userId)
        return !tags.categories.isEmpty || !tags.statuses.isEmpty
    }

    // MARK: - Helper Methods for Timestamp Grouping

    /// Determines if a date separator should be shown before this message
    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index < viewModel.messages.count else { return false }

        // Always show for first message
        if index == 0 {
            return true
        }

        let currentMessage = viewModel.messages[index]
        let previousMessage = viewModel.messages[index - 1]

        // Show separator if messages are on different days
        return !Calendar.current.isDate(currentMessage.timestamp, inSameDayAs: previousMessage.timestamp)
    }

    /// Determines if timestamp should be shown for this message
    private func shouldShowTimestamp(at index: Int) -> Bool {
        // Always show timestamp and status for every message (like WhatsApp)
        // The timestamp is small and unobtrusive, and users want to see
        // the status indicator on each message they send
        return true
    }

    // MARK: - Methods

    private func markMessagesAsReadAndUpdateBadge() async {
        guard let currentUserId = AuthService.shared.currentUser?.uid else { return }

        // Count unread messages before marking them as read
        let unreadMessages = viewModel.messages.filter { message in
            message.senderId != currentUserId &&
            message.readBy[currentUserId] == nil
        }
        let unreadCount = unreadMessages.count

        // Mark messages as read
        await viewModel.markMessagesAsRead()

        // Update badge count if there were unread messages
        if unreadCount > 0 {
            let currentBadge = UIApplication.shared.applicationIconBadgeNumber
            let newBadge = max(0, currentBadge - unreadCount)
            NotificationManager.shared.updateBadgeCount(newBadge)
        }
    }

    private func loadData() async {
        await viewModel.loadMessages()

        if !conversation.isGroupChat {
            await loadOtherUser()
        }
    }

    private func loadOtherUser() async {
        guard let currentUserId = AuthService.shared.currentUser?.uid,
              let otherUserId = conversation.participantIds.first(where: { $0 != currentUserId }) else {
            return
        }

        otherUser = try? await UserService.shared.fetchUser(userId: otherUserId)

        // Start listening to presence for the other user
        listenToPresence(userId: otherUserId)
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

    private func scrollToMessage(messageId: String) async {
        // Set loading state
        await MainActor.run {
            isLoadingFAQReference = true
        }

        // First check if message is in current loaded messages
        if viewModel.messages.contains(where: { $0.id == messageId }) {
            // Message already loaded - scroll immediately
            await MainActor.run {
                isLoadingFAQReference = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollProxy?.scrollTo(messageId, anchor: .center)
                }
                highlightedMessageId = messageId
            }
        } else {
            // Message not loaded - fetch it
            if let _ = await viewModel.fetchMessageById(messageId: messageId) {
                await MainActor.run {
                    isLoadingFAQReference = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollProxy?.scrollTo(messageId, anchor: .center)
                    }
                    highlightedMessageId = messageId
                }
            } else {
                // Message not found - show error
                await MainActor.run {
                    isLoadingFAQReference = false
                    faqScrollError = "The referenced message could not be found. It may have been deleted."
                    showFAQError = true
                }
                return
            }
        }

        // Clear highlight after delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        await MainActor.run {
            highlightedMessageId = nil
        }
    }

    private func sendMessage() async {
        let text = messageText
        messageText = ""

        await viewModel.sendMessage(text: text)

        // Scroll to bottom to show the new message
        if let lastMessage = viewModel.messages.last {
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }

        // Optionally refocus the input field
        isInputFocused = true
    }
}

// Preference key for tracking visible messages
struct VisibleMessage: Equatable {
    let id: String
    let minY: CGFloat
}

struct VisibleMessagePreferenceKey: PreferenceKey {
    static var defaultValue: [VisibleMessage] = []

    static func reduce(value: inout [VisibleMessage], nextValue: () -> [VisibleMessage]) {
        value.append(contentsOf: nextValue())
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(
            conversation: Conversation(
                id: "preview",
                participantIds: ["user1", "user2"],
                lastMessage: "Hello!",
                lastMessageTime: Date(),
                isGroupChat: false,
                groupName: nil
            )
        )
    }
}
