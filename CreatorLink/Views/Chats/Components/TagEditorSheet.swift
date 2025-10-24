//
//  TagEditorSheet.swift
//  CreatorLink
//
//  Modal sheet for editing all conversation tags with full control
//

import SwiftUI

struct TagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TagEditorViewModel

    let onSave: () -> Void

    init(conversation: Conversation, userId: String, onSave: @escaping () -> Void = {}) {
        self._viewModel = State(initialValue: TagEditorViewModel(conversation: conversation, userId: userId))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                // Category Tags Section
                Section {
                    ForEach([ConversationTag.business, .collaboration, .social, .fan], id: \.self) { tag in
                        Button {
                            viewModel.toggleCategory(tag)
                        } label: {
                            HStack {
                                Text(tag.emoji)
                                    .font(.title3)
                                Text(tag.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.selectedCategories.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .accessibilityLabel("Tag as \(tag.displayName)")
                    }
                } header: {
                    Text("CATEGORY")
                } footer: {
                    Text("Select up to 2 categories for this conversation")
                }

                // Status Tags Section
                Section {
                    ForEach([StatusTag.urgent, .needsResponse, .awaitingReply, .resolved], id: \.self) { tag in
                        Button {
                            // Toggle status (single selection or deselect)
                            if viewModel.selectedStatus == tag {
                                viewModel.setStatus(nil)
                            } else {
                                viewModel.setStatus(tag)
                            }
                        } label: {
                            HStack {
                                Text(tag.emoji)
                                    .font(.title3)
                                Text(tag.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.selectedStatus == tag {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .accessibilityLabel("Mark as \(tag.displayName)")
                    }
                } header: {
                    Text("STATUS")
                } footer: {
                    Text("Select one status for this conversation (optional)")
                }

                // AI Suggestion Section
                if let suggestion = viewModel.aiSuggestion {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(suggestion.category.emoji)
                                    .font(.title3)
                                Text("AI suggested: \(suggestion.category.displayName)")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(Int(suggestion.confidence * 100))% confident")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if viewModel.isDifferentFromAI {
                                Button {
                                    viewModel.acceptAISuggestion()
                                } label: {
                                    Text("Accept AI Suggestion")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.borderless)
                            }

                            Text("AI analyzes message content to suggest relevant tags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("AI SUGGESTION")
                    }
                }

                // Override Toggle Section
                Section {
                    Toggle(isOn: $viewModel.userOverride) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Don't auto-tag this conversation")
                                .font(.subheadline)
                            Text("Prevent AI from automatically updating tags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel tag editing")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            do {
                                try await viewModel.saveTags()
                                onSave()
                                dismiss()
                            } catch {
                                // Error is shown in alert
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Save tag changes")
                }
            }
            .disabled(viewModel.isLoading)
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
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
    }
}

#Preview {
    TagEditorSheet(
        conversation: Conversation(
            id: "1",
            participantIds: ["user1", "user2"],
            lastMessage: "Test message",
            lastMessageTime: Date(),
            isGroupChat: false,
            groupName: nil,
            primaryCategory: .business,
            tagMetadata: Conversation.TagMetadata(
                aiSuggestedCategory: .business,
                aiConfidenceScore: 0.85,
                userOverrideCategory: false,
                userOverrideStatus: false
            ),
            tagsByUser: [
                "user1": Conversation.UserTagData(
                    categoryTags: [.business],
                    statusTags: [.urgent]
                )
            ]
        ),
        userId: "user1"
    )
}
