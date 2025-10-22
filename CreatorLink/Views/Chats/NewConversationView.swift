//
//  NewConversationView.swift
//  CreatorLink
//
//  View for starting a new conversation by selecting a user
//

import SwiftUI
import FirebaseAuth
import FirebaseDatabase

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = NewConversationViewModel()
    @State private var searchText = ""
    @State private var isCreatingConversation = false

    let onConversationCreated: (Conversation) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading users...")
                } else if filteredUsers.isEmpty {
                    emptyStateView
                } else {
                    userListView
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search users")
            .task {
                await viewModel.loadUsers()
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
            .overlay {
                if isCreatingConversation {
                    ProgressView("Creating conversation...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Users Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("There are no other users to start a conversation with")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }

    private var userListView: some View {
        List(filteredUsers) { user in
            Button {
                Task {
                    await createConversation(with: user)
                }
            } label: {
                UserRowView(user: user)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Computed Properties

    private var filteredUsers: [UserProfile] {
        if searchText.isEmpty {
            return viewModel.users
        } else {
            return viewModel.users.filter { user in
                user.displayName.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Methods

    private func createConversation(with user: UserProfile) async {
        isCreatingConversation = true
        do {
            let conversation = try await viewModel.createConversation(with: user.id)
            isCreatingConversation = false
            onConversationCreated(conversation)
        } catch {
            isCreatingConversation = false
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - UserRowView

struct UserRowView: View {
    let user: UserProfile
    @State private var isOnline = false
    @State private var presenceHandle: DatabaseHandle?

    var body: some View {
        HStack(spacing: 12) {
            // Profile photo
            // Supports both Google profile photos and generated avatars (UI Avatars API)
            if let photoURL = user.photoURL, let url = URL(string: photoURL) {
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

            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Online indicator (real-time)
            if isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            setupPresenceListener()
        }
        .onDisappear {
            cleanupPresenceListener()
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

    private var initials: String {
        let components = user.displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else {
            return String(user.displayName.prefix(1)).uppercased()
        }
    }

    private func setupPresenceListener() {
        presenceHandle = PresenceService.shared.listenToPresence(userId: user.id) { [self] online, _ in
            Task { @MainActor in
                self.isOnline = online
            }
        }
    }

    private func cleanupPresenceListener() {
        if let handle = presenceHandle {
            PresenceService.shared.removePresenceListener(userId: user.id, handle: handle)
            presenceHandle = nil
        }
    }
}

// MARK: - NewConversationViewModel

@Observable
@MainActor
class NewConversationViewModel {
    var users: [UserProfile] = []
    var isLoading = false
    var errorMessage: String?

    private let userService = UserService.shared
    private let conversationService = ConversationService.shared
    private let authService = AuthService.shared

    func loadUsers() async {
        guard let currentUserId = authService.currentUser?.uid else {
            errorMessage = "No user logged in"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let allUsers = try await userService.fetchAllUsers()
            // Filter out current user
            users = allUsers.filter { $0.id != currentUserId }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func createConversation(with userId: String) async throws -> Conversation {
        guard let currentUserId = authService.currentUser?.uid else {
            throw ConversationError.invalidData
        }

        let participantIds = [currentUserId, userId].sorted()

        // Check if conversation already exists
        if let existingConversation = try await conversationService.findExistingConversation(participantIds: participantIds, currentUserId: currentUserId) {
            return existingConversation
        }

        // Create new conversation
        return try await conversationService.createConversation(participantIds: participantIds, currentUserId: currentUserId)
    }
}

#Preview {
    NewConversationView { _ in }
}
