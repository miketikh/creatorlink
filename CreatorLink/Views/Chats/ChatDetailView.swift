//
//  ChatDetailView.swift
//  CreatorLink
//
//  Main chat interface showing message history and input field
//

import SwiftUI
import FirebaseAuth
import FirebaseDatabase

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
    @FocusState private var isInputFocused: Bool

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
            if !viewModel.typingUserNames.isEmpty {
                TypingIndicatorView(typingUserNames: viewModel.typingUserNames)
            }

            // Input area
            messageInputArea
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    // Profile photo
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

                    // Name and online status
                    VStack(alignment: .leading, spacing: 2) {
                        Text(navigationTitle)
                            .font(.headline)

                        // Show online status or last seen
                        if !conversation.isGroupChat {
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
                }
            }
        }
        .onAppear {
            // Set view as active to prevent auto-delivery race condition
            viewModel.isViewActive = true
            // Also mark messages as read when view appears (handles navigation back)
            Task {
                await viewModel.markMessagesAsRead()
            }
        }
        .onDisappear {
            // Save scroll position before leaving
            onScrollPositionChanged(scrollPosition)

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
                            VStack(spacing: 4) {
                                // Show date separator if this is a new day
                                if shouldShowDateSeparator(at: index) {
                                    DateSeparatorView(date: message.timestamp)
                                }

                                MessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: viewModel.isFromCurrentUser(message),
                                    showTimestamp: shouldShowTimestamp(at: index)
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

                // Scroll to saved position or bottom AFTER messages load
                if let savedPos = savedScrollPosition {
                    proxy.scrollTo(savedPos, anchor: .top)
                } else if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }

                // Mark messages as read after initial load
                await viewModel.markMessagesAsRead()
            }
            .overlay(alignment: .bottomTrailing) {
                scrollToBottomButton
            }
        }
    }

    private var emptyMessagesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No messages yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Send a message to start the conversation")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scrollToBottomButton: some View {
        Group {
            if !isNearBottom {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if let lastMessage = viewModel.messages.last {
                            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
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
