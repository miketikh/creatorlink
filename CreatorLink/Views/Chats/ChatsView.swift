//
//  ChatsView.swift
//  CreatorLink
//
//  Main view for displaying conversation list
//

import SwiftUI

struct ChatsView: View {
    @State private var viewModel = ConversationsViewModel()
    @State private var showingNewConversation = false
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading conversations...")
                } else if viewModel.conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationListView
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewConversation = true
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
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatDetailView(conversation: conversation)
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
        List(viewModel.conversations) { conversation in
            NavigationLink(destination: ChatDetailView(conversation: conversation)) {
                ConversationRowView(conversation: conversation, viewModel: viewModel)
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    ChatsView()
}
