//
//  NewGroupConversationView.swift
//  CreatorLink
//
//  View for selecting multiple participants to create a group conversation
//

import SwiftUI
import FirebaseAuth

struct NewGroupConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUserIds: Set<String> = []
    @State private var users: [UserProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showGroupNameInput = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading users...")
                } else if users.isEmpty {
                    emptyStateView
                } else {
                    userListView
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") {
                        showGroupNameInput = true
                    }
                    .disabled(selectedUserIds.count < 2)
                }
            }
            .searchable(text: $searchText, prompt: "Search users")
            .overlay(alignment: .bottom) {
                if !selectedUserIds.isEmpty {
                    selectionCountBanner
                }
            }
            .task {
                await fetchUsers()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .navigationDestination(isPresented: $showGroupNameInput) {
                GroupNameInputView(selectedUserIds: selectedUserIds, onGroupCreated: {
                    dismiss()
                })
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

            Text("There are no other users available to add to a group")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }

    private var userListView: some View {
        List(filteredUsers) { user in
            SelectableUserRow(
                user: user,
                isSelected: selectedUserIds.contains(user.id)
            ) {
                toggleUserSelection(user)
            }
        }
        .listStyle(.plain)
    }

    private var selectionCountBanner: some View {
        HStack {
            Text("\(selectedUserIds.count) selected")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(Color.blue)
        .cornerRadius(0)
    }

    // MARK: - Computed Properties

    private var filteredUsers: [UserProfile] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { user in
                user.displayName.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Methods

    private func fetchUsers() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            errorMessage = "No user logged in"
            isLoading = false
            return
        }

        do {
            let allUsers = try await UserService.shared.fetchAllUsers()
            // Filter out current user
            await MainActor.run {
                users = allUsers.filter { $0.id != currentUserId }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func toggleUserSelection(_ user: UserProfile) {
        if selectedUserIds.contains(user.id) {
            selectedUserIds.remove(user.id)
        } else {
            selectedUserIds.insert(user.id)
        }
    }
}

// MARK: - SelectableUserRow

struct SelectableUserRow: View {
    let user: UserProfile
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile photo
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

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
}

#Preview {
    NewGroupConversationView()
}
