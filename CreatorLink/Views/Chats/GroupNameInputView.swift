//
//  GroupNameInputView.swift
//  CreatorLink
//
//  View for entering group name and optional image URL
//

import SwiftUI
import FirebaseAuth

struct GroupNameInputView: View {
    let selectedUserIds: Set<String>
    let onGroupCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var groupName: String = ""
    @State private var groupImageUrl: String = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showImagePreview = false
    @State private var participantNames: [String] = []

    private let maxGroupNameLength = 35

    var body: some View {
        NavigationStack {
            Form {
                // Group name section
                Section {
                    TextField("Group name (optional)", text: $groupName)
                        .onChange(of: groupName) { oldValue, newValue in
                            if newValue.count > maxGroupNameLength {
                                groupName = String(newValue.prefix(maxGroupNameLength))
                            }
                        }

                    HStack {
                        Spacer()
                        Text("\(groupName.count)/\(maxGroupNameLength) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Group Name")
                } footer: {
                    Text("Enter a custom name or leave blank to auto-generate from participant names")
                }

                // Group image section
                Section {
                    TextField("Image URL (optional)", text: $groupImageUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !groupImageUrl.isEmpty {
                        Button {
                            showImagePreview.toggle()
                        } label: {
                            Label(showImagePreview ? "Hide Preview" : "Preview Image", systemImage: showImagePreview ? "eye.slash" : "eye")
                        }

                        if showImagePreview {
                            if let url = URL(string: groupImageUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(height: 200)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 200)
                                            .cornerRadius(8)
                                    case .failure:
                                        VStack(spacing: 8) {
                                            Image(systemName: "exclamationmark.triangle")
                                                .font(.largeTitle)
                                                .foregroundColor(.red)
                                            Text("Failed to load image")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(height: 200)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Group Image")
                } footer: {
                    Text("Provide an image URL for the group avatar, or leave blank to use a default")
                }

                // Participants section
                Section {
                    ForEach(participantNames, id: \.self) { name in
                        Text(name)
                    }
                } header: {
                    Text("Selected Participants (\(selectedUserIds.count))")
                }
            }
            .navigationTitle("Group Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await createGroup()
                        }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isCreating)
                }
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
            .task {
                await loadParticipantNames()
            }
        }
    }

    // MARK: - Methods

    private func loadParticipantNames() async {
        var names: [String] = []

        for userId in selectedUserIds {
            do {
                let user = try await UserService.shared.fetchUser(userId: userId)
                names.append(user.displayName)
            } catch {
                // If we can't fetch a user, just skip them in the display
                continue
            }
        }

        await MainActor.run {
            participantNames = names.sorted()
        }
    }

    private func createGroup() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            await MainActor.run {
                errorMessage = "No user logged in"
            }
            return
        }

        await MainActor.run {
            isCreating = true
            errorMessage = nil
        }

        // Validate image URL if provided
        if !groupImageUrl.isEmpty && !isValidUrl(groupImageUrl) {
            await MainActor.run {
                errorMessage = "Please enter a valid image URL starting with http:// or https://"
                isCreating = false
            }
            return
        }

        do {
            // Determine final group name
            let finalGroupName: String?
            if groupName.trimmingCharacters(in: .whitespaces).isEmpty {
                // Auto-generate name from participants
                finalGroupName = await generateAutoName()
            } else {
                finalGroupName = groupName.trimmingCharacters(in: .whitespaces)
            }

            // Add current user to participant list
            var allParticipants = Array(selectedUserIds)
            allParticipants.append(currentUserId)

            // Validate we have at least 3 participants total
            guard allParticipants.count >= 3 else {
                await MainActor.run {
                    errorMessage = "Group chats require at least 3 participants (including you)"
                    isCreating = false
                }
                return
            }

            // Create the conversation
            let imageUrl = groupImageUrl.isEmpty ? nil : groupImageUrl
            _ = try await ConversationService.shared.createConversation(
                participantIds: allParticipants,
                currentUserId: currentUserId,
                groupName: finalGroupName,
                groupImageUrl: imageUrl
            )

            // Success - dismiss both views
            await MainActor.run {
                isCreating = false
                onGroupCreated()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }

    private func generateAutoName() async -> String {
        // Take first 3 participant names and join them
        let names = participantNames.prefix(3)
        var autoName = names.joined(separator: ", ")

        // Truncate if too long
        if autoName.count > maxGroupNameLength {
            autoName = String(autoName.prefix(maxGroupNameLength - 3)) + "..."
        }

        return autoName.isEmpty ? "Group Chat" : autoName
    }

    private func isValidUrl(_ string: String) -> Bool {
        let urlPattern = "^https?://.*"
        let urlPredicate = NSPredicate(format: "SELF MATCHES %@", urlPattern)
        return urlPredicate.evaluate(with: string)
    }
}

#Preview {
    GroupNameInputView(selectedUserIds: ["user1", "user2", "user3"], onGroupCreated: {})
}
