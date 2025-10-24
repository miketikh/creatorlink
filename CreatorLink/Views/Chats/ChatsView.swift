//
//  ChatsView.swift
//  CreatorLink
//
//  Main view for displaying conversation list
//  Note: User avatars displayed by ConversationRowView support both
//  Google profile photos and generated avatars (UI Avatars API)
//

import SwiftUI

struct ChatsView: View {
    @State private var viewModel = ConversationsViewModel()
    @State private var showingNewConversation = false
    @State private var showNewGroupSheet = false
    @State private var selectedConversation: Conversation?
    @State private var scrollPositions: [String: String] = [:] // conversationId -> messageId
    @State private var navigationCoordinator = NavigationCoordinator.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar (only show when conversations exist)
                if !viewModel.conversations.isEmpty {
                    FilterBarView(viewModel: viewModel)
                }

                // Main content
                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading conversations...")
                    } else if viewModel.conversations.isEmpty {
                        emptyStateView
                    } else {
                        conversationListView
                    }
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingNewConversation = true
                        } label: {
                            Label("New Message", systemImage: "message")
                        }

                        Button {
                            showNewGroupSheet = true
                        } label: {
                            Label("New Group", systemImage: "person.2.fill")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingNewConversation) {
                NewConversationView(onConversationCreated: { conversation in
                    showingNewConversation = false
                    selectedConversation = conversation
                })
            }
            .sheet(isPresented: $showNewGroupSheet) {
                NewGroupConversationView()
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatDetailView(
                    conversation: conversation,
                    savedScrollPosition: scrollPositions[conversation.id ?? ""],
                    onScrollPositionChanged: { messageId in
                        if let conversationId = conversation.id {
                            scrollPositions[conversationId] = messageId
                        }
                    }
                )
            }
            .task {
                await viewModel.loadConversations()
            }
            .refreshable {
                await viewModel.refresh()
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
            .onChange(of: navigationCoordinator.deepLinkConversationId) { oldValue, newValue in
                handleDeepLink(conversationId: newValue)
            }
        }
    }

    // MARK: - Swipe Actions

    private enum SwipeActionType {
        case urgent
        case resolved
    }

    private func handleSwipeAction(_ action: SwipeActionType, for conversation: Conversation) {
        guard let conversationId = conversation.id else { return }

        // Provide haptic feedback
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)

        Task {
            switch action {
            case .urgent:
                await viewModel.markConversationAsUrgent(conversationId: conversationId)
            case .resolved:
                await viewModel.markConversationAsResolved(conversationId: conversationId)
            }
        }
    }

    // MARK: - Deep Link Handling

    /// Handle deep link navigation to a specific conversation
    private func handleDeepLink(conversationId: String?) {
        guard let conversationId = conversationId else { return }

        // Clear any saved scroll position for this conversation - we want to scroll to bottom
        scrollPositions.removeValue(forKey: conversationId)

        // First, try to find the conversation in the current list
        if let conversation = viewModel.conversations.first(where: { $0.id == conversationId }) {
            selectedConversation = conversation
            navigationCoordinator.clearDeepLink()
        } else {
            // Conversation not in current list - fetch it
            Task {
                do {
                    if let conversation = try await ConversationService.shared.fetchConversation(conversationId: conversationId) {
                        selectedConversation = conversation
                        navigationCoordinator.clearDeepLink()
                    } else {
                        viewModel.errorMessage = "Unable to open conversation. You may not have access to it."
                        navigationCoordinator.clearDeepLink()
                    }
                } catch {
                    viewModel.errorMessage = "Failed to open conversation: \(error.localizedDescription)"
                    navigationCoordinator.clearDeepLink()
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Conversations Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the compose button to start a new chat")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingNewConversation = true
            } label: {
                Label("Start a Conversation", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }

    private var conversationListView: some View {
        List(viewModel.filteredConversations) { conversation in
            Button {
                selectedConversation = conversation
            } label: {
                ConversationRowView(conversation: conversation, viewModel: viewModel)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    handleSwipeAction(.urgent, for: conversation)
                } label: {
                    Label("Urgent", systemImage: "flame.fill")
                }
                .tint(.red)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    handleSwipeAction(.resolved, for: conversation)
                } label: {
                    Label("Resolved", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
        }
        .listStyle(.plain)
        .animation(.easeInOut, value: viewModel.selectedCategoryFilters)
        .animation(.easeInOut, value: viewModel.selectedStatusFilters)
    }
}

#Preview {
    ChatsView()
}
