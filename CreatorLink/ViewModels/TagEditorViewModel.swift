//
//  TagEditorViewModel.swift
//  CreatorLink
//
//  ViewModel for managing tag editor state
//

import Foundation
import Observation

@Observable
@MainActor
class TagEditorViewModel {
    var selectedCategories: Set<ConversationTag>
    var selectedStatus: StatusTag?
    var userOverride: Bool
    var isLoading = false
    var errorMessage: String?

    private let conversationId: String
    private let userId: String
    private let taggingService = TaggingService.shared
    private let initialConversation: Conversation

    init(conversation: Conversation, userId: String) {
        self.conversationId = conversation.id ?? ""
        self.userId = userId
        self.initialConversation = conversation
        self.userOverride = conversation.tagMetadata?.userOverrideStatus ?? false

        // Load current tags for this user
        let currentTags = taggingService.getEffectiveTags(conversation: conversation, userId: userId)
        self.selectedCategories = Set(currentTags.categories)
        self.selectedStatus = currentTags.statuses.first
    }

    /// Toggles a category tag (add if not present, remove if present)
    func toggleCategory(_ tag: ConversationTag) {
        if selectedCategories.contains(tag) {
            selectedCategories.remove(tag)
        } else {
            // Limit to max 2 categories
            if selectedCategories.count >= 2 {
                // Remove oldest (first) category
                if let firstTag = selectedCategories.first {
                    selectedCategories.remove(firstTag)
                }
            }
            selectedCategories.insert(tag)
        }
    }

    /// Sets the status tag (single selection)
    func setStatus(_ tag: StatusTag?) {
        selectedStatus = tag
    }

    /// Saves tags to Firestore
    func saveTags() async throws {
        isLoading = true
        errorMessage = nil

        do {
            // Update category tags
            let categoryArray = Array(selectedCategories)
            try await taggingService.updateCategoryTags(
                conversationId: conversationId,
                userId: userId,
                tags: categoryArray
            )

            // Update status tags
            var statusArray: [StatusTag] = []
            if let status = selectedStatus {
                statusArray = [status]
            }
            try await taggingService.updateStatusTags(
                conversationId: conversationId,
                userId: userId,
                tags: statusArray
            )

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Accepts AI suggestion and updates tags
    func acceptAISuggestion() {
        guard let metadata = initialConversation.tagMetadata,
              let aiSuggested = metadata.aiSuggestedCategory else {
            return
        }

        // Set AI suggested category
        selectedCategories = [aiSuggested]
        userOverride = false
    }

    /// Returns AI suggestion info if available
    var aiSuggestion: (category: ConversationTag, confidence: Double)? {
        guard let metadata = initialConversation.tagMetadata,
              let aiSuggested = metadata.aiSuggestedCategory,
              let confidence = metadata.aiConfidenceScore else {
            return nil
        }
        return (aiSuggested, confidence)
    }

    /// Checks if current selection differs from AI suggestion
    var isDifferentFromAI: Bool {
        guard let suggestion = aiSuggestion else {
            return false
        }
        return !selectedCategories.contains(suggestion.category)
    }
}
