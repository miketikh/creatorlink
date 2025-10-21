//
//  ChatDetailView.swift
//  CreatorLink
//
//  Main chat interface showing message history and input field
//

import SwiftUI
import FirebaseAuth

struct ChatDetailView: View {
    let conversation: Conversation

    @State private var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var otherUser: UserProfile?
    @FocusState private var isInputFocused: Bool

    init(conversation: Conversation) {
        print("🔵 [ChatDetailView] Initializing with conversation ID: \(conversation.id ?? "nil")")
        print("🔵 [ChatDetailView] Conversation participantIds: \(conversation.participantIds)")

        // Ensure conversation has a valid ID
        guard let conversationId = conversation.id, !conversationId.isEmpty else {
            print("❌ [ChatDetailView] CRITICAL: Conversation ID is nil or empty! This will cause a crash.")
            print("❌ [ChatDetailView] Creating ViewModel with fallback empty string, but this needs investigation")
            self.conversation = conversation
            _viewModel = State(initialValue: ChatViewModel(conversationId: ""))
            return
        }

        self.conversation = conversation
        _viewModel = State(initialValue: ChatViewModel(conversationId: conversationId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            messagesScrollView

            // Input area
            messageInputArea
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
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

                    Text(navigationTitle)
                        .font(.headline)
                }
            }
        }
        .task {
            await loadData()
        }
        .onAppear {
            Task {
                await viewModel.markMessagesAsRead()
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
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView("Loading messages...")
                            .padding()
                    } else if viewModel.messages.isEmpty {
                        emptyMessagesView
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: viewModel.isFromCurrentUser(message)
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                if newCount > oldCount, let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
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

    // MARK: - Methods

    private func loadData() async {
        print("🔵 [ChatDetailView] loadData() started")
        await viewModel.loadMessages()
        print("🔵 [ChatDetailView] viewModel.loadMessages() completed")

        if !conversation.isGroupChat {
            print("🔵 [ChatDetailView] Loading other user...")
            await loadOtherUser()
            print("🔵 [ChatDetailView] loadOtherUser() completed")
        }
        print("✅ [ChatDetailView] loadData() completed")
    }

    private func loadOtherUser() async {
        guard let currentUserId = AuthService.shared.currentUser?.uid,
              let otherUserId = conversation.participantIds.first(where: { $0 != currentUserId }) else {
            return
        }

        otherUser = try? await UserService.shared.fetchUser(userId: otherUserId)
    }

    private func sendMessage() async {
        let text = messageText
        messageText = ""

        await viewModel.sendMessage(text: text)

        // Optionally refocus the input field
        isInputFocused = true
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
