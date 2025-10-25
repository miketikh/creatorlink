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
    @Binding var userLeftGroup: Bool
    let onDismiss: () -> Void

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
    @State private var aiEnabled = false

    init(conversation: Conversation, userLeftGroup: Binding<Bool>, onDismiss: @escaping () -> Void) {
        self.initialConversation = conversation
        self._userLeftGroup = userLeftGroup
        self.onDismiss = onDismiss
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

                // AI Assistant Section
                aiAssistantSection

                // Participants Section
                participantsSection

                // Actions Section
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Group Info")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Saving...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            }
        }
        .task {
            await viewModel.loadParticipants()
            setupConversationListener()

            // Initialize AI enabled state from conversation
            aiEnabled = conversation.aiEnabled ?? false

            // Track analytics
            AnalyticsService.shared.trackGroupInfoViewed(groupSize: conversation.participantIds.count)
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
            } else {
                Text("An unexpected error occurred. Please try again.")
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

    private var aiAssistantSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI ASSISTANT")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { aiEnabled },
                    set: { newValue in
                        Task {
                            await toggleAI(enabled: newValue)
                        }
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable AI Assistant")
                                .font(.body)
                            if aiEnabled {
                                Text("AI will help answer frequently asked questions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )

                if aiEnabled, let config = conversation.aiConfig {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("FAQ Detection:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(config.faqDetectionEnabled ? "Enabled" : "Disabled")
                                .font(.caption)
                                .foregroundColor(config.faqDetectionEnabled ? .green : .secondary)
                        }

                        HStack {
                            Text("Similarity Threshold:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(config.minimumSimilarity * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let humanParticipantCount = viewModel.participants.filter { $0.id != AIConstants.AI_USER_ID }.count
            let hasAI = viewModel.participants.contains { $0.id == AIConstants.AI_USER_ID }

            Text(hasAI ? "\(humanParticipantCount) MEMBERS + AI" : "\(humanParticipantCount) MEMBERS")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)

            if viewModel.isLoading && viewModel.participants.isEmpty {
                // Skeleton loading state
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        ParticipantSkeletonRow()
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            } else {
                // Sort participants: humans first, then AI last
                let sortedParticipants = viewModel.participants.sorted { p1, p2 in
                    let p1IsAI = p1.id == AIConstants.AI_USER_ID
                    let p2IsAI = p2.id == AIConstants.AI_USER_ID
                    if p1IsAI == p2IsAI { return false } // Keep original order for same type
                    return !p1IsAI && p2IsAI // Humans before AI
                }

                VStack(spacing: 0) {
                    ForEach(sortedParticipants) { participant in
                        let currentUserId = UserService.shared.currentUserId ?? ""
                        let isCurrentUser = participant.id == currentUserId

                        VStack(spacing: 0) {
                            ParticipantRowView(
                                participant: participant,
                                showOnlineStatus: true,
                                isCurrentUser: isCurrentUser
                            )
                            .contextMenu {
                                let isAIUser = participant.id == AIConstants.AI_USER_ID

                                if !isCurrentUser && !isAIUser {
                                    Button(role: .destructive) {
                                        participantToRemove = participant
                                        showRemoveConfirmation = true
                                    } label: {
                                        Label("Remove from Group", systemImage: "person.badge.minus")
                                    }
                                } else if isAIUser {
                                    Button {
                                        // Do nothing - just show info
                                    } label: {
                                        Label("Use AI toggle to remove AI", systemImage: "info.circle")
                                    }
                                    .disabled(true)
                                }
                            }

                            if participant.id != sortedParticipants.last?.id {
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
              let userId = UserService.shared.currentUserId else {
            return
        }

        do {
            try await viewModel.leaveGroup(conversationId: conversationId, userId: userId)

            // Set the binding to trigger navigation back to conversations list
            userLeftGroup = true

            onDismiss()
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

            // Track analytics
            AnalyticsService.shared.trackGroupNotificationsMuted(isMuted: isMuted)
        } catch {
            viewModel.errorMessage = "Failed to update notification settings"
        }
    }

    private func toggleAI(enabled: Bool) async {
        guard let conversationId = conversation.id else { return }

        // Store the previous state in case we need to revert
        let previousState = aiEnabled

        // Optimistically update UI
        aiEnabled = enabled

        do {
            try await viewModel.toggleAI(conversation: conversation, enabled: enabled)

            // Track analytics
            AnalyticsService.shared.trackEvent(
                enabled ? "ai_enabled" : "ai_disabled",
                parameters: ["conversation_id": conversationId]
            )
        } catch {
            // Revert on error
            aiEnabled = previousState
            // Error is shown via viewModel.errorMessage
        }
    }

    private func setupConversationListener() {
        guard let conversationId = conversation.id else {
            return
        }

        // Listen to this specific conversation for updates
        conversationListener = ConversationService.shared.db
            .collection("conversations")
            .document(conversationId)
            .addSnapshotListener { [self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        // Check if this is a permission error (expected after leaving group)
                        let errorDescription = error.localizedDescription
                        if errorDescription.contains("permission") || errorDescription.contains("Permission") {
                            // This is expected when user leaves - don't show error to user
                            return
                        }
                        return
                    }

                    // Handle conversation deleted
                    guard let snapshot = snapshot, snapshot.exists else {
                        self.viewModel.errorMessage = "This group has been deleted."
                        self.onDismiss()
                        return
                    }

                    if let updatedConversation = try? snapshot.data(as: Conversation.self) {
                        // Check if current user was removed from the group
                        if let currentUserId = UserService.shared.currentUserId {
                            let isStillInGroup = updatedConversation.participantIds.contains(currentUserId)

                            if !isStillInGroup {
                                // User is no longer in the group (either left or was removed)
                                // Set the binding to trigger navigation
                                self.userLeftGroup = true
                                self.onDismiss()
                                return
                            }
                        }

                        self.conversation = updatedConversation

                        // Update aiEnabled state when conversation updates
                        self.aiEnabled = updatedConversation.aiEnabled ?? false
                    }
                }
            }
    }
}

// MARK: - Skeleton Loading Components

struct ParticipantSkeletonRow: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar skeleton
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
                .shimmer(isAnimating: isAnimating)

            // Name skeleton
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 14)
                    .shimmer(isAnimating: isAnimating)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 12)
                    .shimmer(isAnimating: isAnimating)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

extension View {
    func shimmer(isAnimating: Bool) -> some View {
        self.overlay(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.white.opacity(0.3),
                    Color.clear
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: isAnimating ? 200 : -200)
            .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
        )
        .clipped()
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var userLeftGroup = false

        var body: some View {
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
                    ),
                    userLeftGroup: $userLeftGroup,
                    onDismiss: {}
                )
            }
        }
    }

    return PreviewWrapper()
}
