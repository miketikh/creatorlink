//
//  GroupInfoView.swift
//  CreatorLink
//
//  Group information and settings screen
//

import SwiftUI
import FirebaseFirestore

struct GroupInfoView: View {
    let initialConversation: Conversation

    @State private var viewModel: GroupInfoViewModel
    @State private var isEditingName = false
    @State private var isEditingImage = false
    @State private var showLeaveConfirmation = false
    @State private var editedGroupName = ""
    @State private var editedImageUrl = ""
    @State private var imagePreviewUrl: String?
    @State private var conversation: Conversation
    @State private var conversationListener: ListenerRegistration?
    @State private var showAddParticipants = false
    @State private var participantToRemove: UserProfile?
    @State private var showRemoveConfirmation = false
    @Environment(\.dismiss) var dismiss

    init(conversation: Conversation) {
        self.initialConversation = conversation
        _conversation = State(initialValue: conversation)
        _viewModel = State(initialValue: GroupInfoViewModel(conversation: conversation))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section - Group Avatar
                groupAvatarSection

                // Group Name Section
                groupNameSection

                // Group Image Section
                groupImageSection

                // Participants Section
                participantsSection

                // Actions Section
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Group Info")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadParticipants()
            setupConversationListener()
        }
        .onDisappear {
            conversationListener?.remove()
            conversationListener = nil
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
        .alert("Leave Group", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task {
                    await leaveGroupTapped()
                }
            }
        } message: {
            Text("Are you sure you want to leave this group? You will no longer receive messages from this group.")
        }
        .sheet(isPresented: $showAddParticipants) {
            AddParticipantsView(
                conversation: conversation,
                existingParticipantIds: conversation.participantIds
            )
        }
        .onChange(of: conversation.participantIds) { _, _ in
            // Reload participants when participant list changes
            Task {
                await viewModel.loadParticipants()
            }
        }
        .alert("Remove Participant", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {
                participantToRemove = nil
            }
            Button("Remove", role: .destructive) {
                Task {
                    await removeParticipantConfirmed()
                }
            }
        } message: {
            if let participant = participantToRemove {
                Text("Are you sure you want to remove \(participant.displayName) from this group?")
            }
        }
    }

    // MARK: - Subviews

    private var groupAvatarSection: some View {
        VStack(spacing: 12) {
            // Large group avatar
            GroupAvatarView(
                groupImageUrl: imagePreviewUrl ?? conversation.groupImageUrl ?? "",
                participantIds: conversation.participantIds,
                size: 120
            )
            .onTapGesture {
                isEditingImage.toggle()
            }

            Text("Tap to edit photo")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var groupNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Group Name")
                    .font(.headline)
                Spacer()
                if !isEditingName {
                    Button("Edit") {
                        editedGroupName = conversation.groupName ?? "Group Chat"
                        isEditingName = true
                    }
                    .font(.subheadline)
                }
            }

            if isEditingName {
                VStack(spacing: 8) {
                    TextField("Group Name", text: $editedGroupName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            isEditingName = false
                            editedGroupName = ""
                        }
                        .foregroundColor(.secondary)

                        Spacer()

                        Button("Save") {
                            Task {
                                await saveGroupName()
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(editedGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .font(.subheadline)
                }
            } else {
                Text(conversation.groupName ?? "Group Chat")
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }

    private var groupImageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Group Image URL")
                    .font(.headline)
                Spacer()
                if !isEditingImage {
                    Button("Edit") {
                        editedImageUrl = conversation.groupImageUrl ?? ""
                        isEditingImage = true
                    }
                    .font(.subheadline)
                }
            }

            if isEditingImage {
                VStack(spacing: 8) {
                    TextField("https://example.com/image.jpg", text: $editedImageUrl)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .onChange(of: editedImageUrl) { _, newValue in
                            // Live preview of the image URL
                            if !newValue.isEmpty {
                                imagePreviewUrl = newValue
                            } else {
                                imagePreviewUrl = nil
                            }
                        }

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            isEditingImage = false
                            editedImageUrl = ""
                            imagePreviewUrl = nil
                        }
                        .foregroundColor(.secondary)

                        Spacer()

                        Button("Save") {
                            Task {
                                await saveGroupImage()
                            }
                        }
                        .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
            } else {
                if let groupImageUrl = conversation.groupImageUrl, !groupImageUrl.isEmpty {
                    Text(groupImageUrl)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                } else {
                    Text("No custom image set")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
    }

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(viewModel.participants.count) MEMBERS")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.participants) { participant in
                        let currentUserId = UserService.shared.currentUserId ?? ""
                        let isCurrentUser = participant.id == currentUserId

                        VStack(spacing: 0) {
                            ParticipantRowView(
                                participant: participant,
                                showOnlineStatus: true,
                                isCurrentUser: isCurrentUser
                            )
                            .contextMenu {
                                if !isCurrentUser {
                                    Button(role: .destructive) {
                                        participantToRemove = participant
                                        showRemoveConfirmation = true
                                    } label: {
                                        Label("Remove from Group", systemImage: "person.badge.minus")
                                    }
                                }
                            }

                            if participant.id != viewModel.participants.last?.id {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 16) {
            // Mute Notifications Toggle
            VStack(alignment: .leading, spacing: 12) {
                Text("NOTIFICATIONS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)

                Toggle(isOn: Binding(
                    get: {
                        guard let mutedBy = conversation.mutedBy,
                              let currentUserId = UserService.shared.currentUserId else {
                            return false
                        }
                        return mutedBy.contains(currentUserId)
                    },
                    set: { newValue in
                        Task {
                            await toggleMuteNotifications(isMuted: newValue)
                        }
                    }
                )) {
                    HStack {
                        Image(systemName: "bell.slash.fill")
                            .foregroundColor(.secondary)
                        Text("Mute Notifications")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            }

            // Add Participants button
            Button {
                showAddParticipants = true
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Add Participants")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            // Leave Group button
            Button {
                showLeaveConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Leave Group")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Methods

    private func saveGroupName() async {
        guard let conversationId = conversation.id else { return }

        do {
            try await viewModel.updateGroupName(
                conversationId: conversationId,
                newName: editedGroupName
            )
            isEditingName = false
            editedGroupName = ""
        } catch {
            // Error is shown via viewModel.errorMessage
        }
    }

    private func saveGroupImage() async {
        guard let conversationId = conversation.id else { return }

        do {
            try await viewModel.updateGroupImage(
                conversationId: conversationId,
                newImageUrl: editedImageUrl
            )
            isEditingImage = false
            editedImageUrl = ""
            imagePreviewUrl = nil
        } catch {
            // Error is shown via viewModel.errorMessage
        }
    }

    private func leaveGroupTapped() async {
        guard let conversationId = conversation.id,
              let userId = UserService.shared.currentUserId else { return }

        do {
            try await viewModel.leaveGroup(conversationId: conversationId, userId: userId)
            dismiss()
        } catch {
            // Error is shown via viewModel.errorMessage
        }
    }

    private func removeParticipantConfirmed() async {
        guard let conversationId = conversation.id,
              let userId = participantToRemove?.id,
              let currentUserId = UserService.shared.currentUserId else {
            participantToRemove = nil
            return
        }

        do {
            try await viewModel.removeParticipant(
                conversationId: conversationId,
                userId: userId,
                currentUserId: currentUserId
            )
            participantToRemove = nil
        } catch {
            // Error is shown via viewModel.errorMessage
            participantToRemove = nil
        }
    }

    private func toggleMuteNotifications(isMuted: Bool) async {
        guard let conversationId = conversation.id,
              let userId = UserService.shared.currentUserId else { return }

        do {
            try await ConversationService.shared.toggleMute(
                conversationId: conversationId,
                userId: userId,
                isMuted: isMuted
            )
        } catch {
            viewModel.errorMessage = "Failed to update notification settings"
        }
    }

    private func setupConversationListener() {
        guard let conversationId = conversation.id else { return }

        // Listen to this specific conversation for updates
        conversationListener = ConversationService.shared.db
            .collection("conversations")
            .document(conversationId)
            .addSnapshotListener { [self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        return
                    }

                    guard let snapshot = snapshot, snapshot.exists else {
                        return
                    }

                    if let updatedConversation = try? snapshot.data(as: Conversation.self) {
                        self.conversation = updatedConversation
                    }
                }
            }
    }
}

#Preview {
    NavigationStack {
        GroupInfoView(
            conversation: Conversation(
                id: "preview",
                participantIds: ["user1", "user2", "user3"],
                lastMessage: "Hello!",
                lastMessageTime: Date(),
                isGroupChat: true,
                groupName: "Team Chat",
                groupImageUrl: "https://ui-avatars.com/api/?name=T&background=random"
            )
        )
    }
}
