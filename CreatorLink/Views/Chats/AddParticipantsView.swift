//
//  AddParticipantsView.swift
//  CreatorLink
//
//  Screen for selecting and adding new participants to an existing group
//

import SwiftUI

struct AddParticipantsView: View {
    let conversation: Conversation
    let existingParticipantIds: [String]

    @State private var selectedUserIds: Set<String> = []
    @State private var availableUsers: [UserProfile] = []
    @State private var isLoading = true
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var showError = false
    @Environment(\.dismiss) var dismiss

    private let userService = UserService.shared
    private let conversationService = ConversationService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading users...")
                } else if availableUsers.isEmpty {
                    emptyStateView
                } else {
                    userListView
                }
            }
            .navigationTitle("Add Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addSelectedParticipants()
                        }
                    }
                    .disabled(selectedUserIds.isEmpty || isAdding)
                    .fontWeight(.semibold)
                }
            }
            .task {
                await fetchAvailableUsers()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay {
                if isAdding {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ProgressView("Adding participants...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Users Available")
                .font(.headline)

            Text("All users are already in this group.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var userListView: some View {
        VStack(spacing: 0) {
            // Selection count header
            if !selectedUserIds.isEmpty {
                HStack {
                    Text("\(selectedUserIds.count) selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Clear") {
                        selectedUserIds.removeAll()
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))
            }

            // User list
            List(availableUsers) { user in
                Button {
                    toggleSelection(for: user.id)
                } label: {
                    HStack(spacing: 12) {
                        // User avatar
                        AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)

                                Text(user.displayName.prefix(1).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())

                        // User info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(.body)
                                .foregroundColor(.primary)

                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Checkbox
                        Image(systemName: selectedUserIds.contains(user.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(selectedUserIds.contains(user.id) ? .blue : .gray)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Methods

    /// Fetches all users and filters out existing participants
    private func fetchAvailableUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            let allUsers = try await userService.fetchAllUsers()

            // Filter out users already in the group and the current user
            let currentUserId = userService.currentUserId ?? ""
            availableUsers = allUsers.filter { user in
                !existingParticipantIds.contains(user.id) && user.id != currentUserId
            }

            isLoading = false
        } catch {
            errorMessage = "Failed to load users: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }

    /// Toggles selection for a user
    /// - Parameter userId: The ID of the user to toggle
    private func toggleSelection(for userId: String) {
        if selectedUserIds.contains(userId) {
            selectedUserIds.remove(userId)
        } else {
            selectedUserIds.insert(userId)
        }
    }

    /// Adds selected participants to the group
    private func addSelectedParticipants() async {
        guard let conversationId = conversation.id,
              let currentUserId = userService.currentUserId else {
            return
        }

        isAdding = true
        errorMessage = nil

        var successCount = 0
        var failedUsers: [String] = []

        // Add each selected user
        for userId in selectedUserIds {
            do {
                try await conversationService.addParticipant(
                    conversationId: conversationId,
                    userId: userId,
                    currentUserId: currentUserId
                )
                successCount += 1
            } catch {
                // Track failed additions
                if let user = availableUsers.first(where: { $0.id == userId }) {
                    failedUsers.append(user.displayName)
                }
            }
        }

        isAdding = false

        // Show error if any failed
        if !failedUsers.isEmpty {
            errorMessage = "Failed to add: \(failedUsers.joined(separator: ", "))"
            showError = true
        }

        // Dismiss if at least one succeeded
        if successCount > 0 {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        AddParticipantsView(
            conversation: Conversation(
                id: "preview",
                participantIds: ["user1", "user2"],
                lastMessage: "Hello",
                lastMessageTime: Date(),
                isGroupChat: true,
                groupName: "Team Chat",
                groupImageUrl: nil
            ),
            existingParticipantIds: ["user1", "user2"]
        )
    }
}
