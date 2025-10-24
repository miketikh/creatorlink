//
//  TaggingService.swift
//  CreatorLink
//
//  Dedicated service for conversation tagging operations
//  Separates tag management concerns from ConversationService
//

import Foundation
import FirebaseFirestore

@Observable
class TaggingService {
    static let shared = TaggingService()

    private let db = FirestoreService.shared.db
    private let conversationsCollection = FirestoreService.shared.conversationsCollection
    private let conversationService = ConversationService.shared

    private init() {}

    // MARK: - Tag CRUD Operations

    /// Updates category tags for a user in a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    ///   - tags: Array of category tags to set
    func updateCategoryTags(conversationId: String, userId: String, tags: [ConversationTag]) async throws {
        // Validate category tags
        guard validateCategoryTags(tags) else {
            throw ConversationError.tooManyTags
        }

        do {
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists else {
                throw ConversationError.invalidData
            }

            // Update only the categoryTags field within tagsByUser[userId]
            // This preserves other fields like statusTags
            let updateData: [String: Any] = [
                "tagsByUser.\(userId).categoryTags": tags.map { $0.rawValue }
            ]

            // Update Firestore
            try await docRef.updateData(updateData)
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    /// Updates status tags for a user in a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    ///   - tags: Array of status tags to set
    func updateStatusTags(conversationId: String, userId: String, tags: [StatusTag]) async throws {
        do {
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists else {
                throw ConversationError.invalidData
            }

            // Get existing conversation to read current tagMetadata
            let conversation = try document.data(as: Conversation.self)

            // Sanitize status tags before saving
            let sanitizedTags = sanitizeStatusTags(tags)

            // Update only the statusTags field within tagsByUser[userId]
            // This preserves other fields like categoryTags
            var updateData: [String: Any] = [
                "tagsByUser.\(userId).statusTags": sanitizedTags.map { $0.rawValue }
            ]

            // Update tagMetadata with complete object to avoid decode errors
            // Read existing metadata or create default
            var metadataDict: [String: Any] = [
                "userOverrideCategory": conversation.tagMetadata?.userOverrideCategory ?? false,
                "userOverrideStatus": true  // Set to true when user manually updates status
            ]

            // Preserve existing AI fields if present
            if let aiSuggestedCategory = conversation.tagMetadata?.aiSuggestedCategory {
                metadataDict["aiSuggestedCategory"] = aiSuggestedCategory.rawValue
            }
            if let aiConfidenceScore = conversation.tagMetadata?.aiConfidenceScore {
                metadataDict["aiConfidenceScore"] = aiConfidenceScore
            }
            if let lastAIAnalysisTime = conversation.tagMetadata?.lastAIAnalysisTime {
                metadataDict["lastAIAnalysisTime"] = Timestamp(date: lastAIAnalysisTime)
            }

            updateData["tagMetadata"] = metadataDict

            // Update Firestore
            try await docRef.updateData(updateData)
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    /// Updates the denormalized primary category for efficient filtering
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - category: The primary category (or nil to clear)
    func updatePrimaryCategory(conversationId: String, category: ConversationTag?) async throws {
        do {
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists else {
                throw ConversationError.invalidData
            }

            var updateData: [String: Any] = [:]
            if let category = category {
                updateData["primaryCategory"] = category.rawValue
            } else {
                updateData["primaryCategory"] = FieldValue.delete()
            }

            // Update Firestore
            try await docRef.updateData(updateData)
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    /// Updates AI metadata for tag suggestions
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - metadata: The tag metadata to set
    func updateTagMetadata(conversationId: String, metadata: Conversation.TagMetadata) async throws {
        do {
            let docRef = conversationsCollection.document(conversationId)
            let document = try await docRef.getDocument()

            guard document.exists else {
                throw ConversationError.invalidData
            }

            var metadataDict: [String: Any] = [
                "userOverrideCategory": metadata.userOverrideCategory,
                "userOverrideStatus": metadata.userOverrideStatus
            ]

            if let aiSuggestedCategory = metadata.aiSuggestedCategory {
                metadataDict["aiSuggestedCategory"] = aiSuggestedCategory.rawValue
            }
            if let aiConfidenceScore = metadata.aiConfidenceScore {
                metadataDict["aiConfidenceScore"] = aiConfidenceScore
            }
            if let lastAIAnalysisTime = metadata.lastAIAnalysisTime {
                metadataDict["lastAIAnalysisTime"] = Timestamp(date: lastAIAnalysisTime)
            }

            let updateData: [String: Any] = [
                "tagMetadata": metadataDict
            ]

            // Update Firestore
            try await docRef.updateData(updateData)
        } catch let error as ConversationError {
            throw error
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    // MARK: - Quick Tag Operations

    /// Marks a conversation as urgent for a user
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    func markAsUrgent(conversationId: String, userId: String) async throws {
        // Fetch current conversation
        guard let conversation = try await conversationService.fetchConversation(conversationId: conversationId) else {
            throw ConversationError.invalidData
        }

        // Get current status tags for this user
        var currentStatusTags: [StatusTag] = []
        if let tagsByUser = conversation.tagsByUser,
           let userTagData = tagsByUser[userId],
           let statusTags = userTagData.statusTags {
            currentStatusTags = statusTags
        }

        // Add Urgent if not already present
        if !currentStatusTags.contains(.urgent) {
            currentStatusTags.append(.urgent)
        }

        // Update status tags
        try await updateStatusTags(conversationId: conversationId, userId: userId, tags: currentStatusTags)
    }

    /// Marks a conversation as resolved for a user (removes Urgent and NeedsResponse)
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    func markAsResolved(conversationId: String, userId: String) async throws {
        // Fetch current conversation
        guard let conversation = try await conversationService.fetchConversation(conversationId: conversationId) else {
            throw ConversationError.invalidData
        }

        // Get current status tags for this user
        var currentStatusTags: [StatusTag] = []
        if let tagsByUser = conversation.tagsByUser,
           let userTagData = tagsByUser[userId],
           let statusTags = userTagData.statusTags {
            currentStatusTags = statusTags
        }

        // Remove conflicting tags and add Resolved
        currentStatusTags.removeAll { $0 == .urgent || $0 == .needsResponse }
        if !currentStatusTags.contains(.resolved) {
            currentStatusTags.append(.resolved)
        }

        // Update status tags
        try await updateStatusTags(conversationId: conversationId, userId: userId, tags: currentStatusTags)
    }

    /// Marks a conversation as needing response for a user
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    func markAsNeedsResponse(conversationId: String, userId: String) async throws {
        // Fetch current conversation
        guard let conversation = try await conversationService.fetchConversation(conversationId: conversationId) else {
            throw ConversationError.invalidData
        }

        // Get current status tags for this user
        var currentStatusTags: [StatusTag] = []
        if let tagsByUser = conversation.tagsByUser,
           let userTagData = tagsByUser[userId],
           let statusTags = userTagData.statusTags {
            currentStatusTags = statusTags
        }

        // Add NeedsResponse if not already present
        if !currentStatusTags.contains(.needsResponse) {
            currentStatusTags.append(.needsResponse)
        }

        // Update status tags
        try await updateStatusTags(conversationId: conversationId, userId: userId, tags: currentStatusTags)
    }

    /// Removes urgent flag from a conversation for a user
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    func removeUrgent(conversationId: String, userId: String) async throws {
        // Fetch current conversation
        guard let conversation = try await conversationService.fetchConversation(conversationId: conversationId) else {
            throw ConversationError.invalidData
        }

        // Get current status tags for this user
        var currentStatusTags: [StatusTag] = []
        if let tagsByUser = conversation.tagsByUser,
           let userTagData = tagsByUser[userId],
           let statusTags = userTagData.statusTags {
            currentStatusTags = statusTags
        }

        // Remove Urgent
        currentStatusTags.removeAll { $0 == .urgent }

        // Update status tags
        try await updateStatusTags(conversationId: conversationId, userId: userId, tags: currentStatusTags)
    }

    // MARK: - Batch Operations

    /// Updates category tags for multiple conversations at once
    /// - Parameters:
    ///   - conversationIds: Array of conversation IDs to update (max 500)
    ///   - userId: The ID of the user
    ///   - tags: Array of category tags to set
    func batchUpdateCategoryTags(conversationIds: [String], userId: String, tags: [ConversationTag]) async throws {
        // Validate inputs
        guard !conversationIds.isEmpty else {
            throw ConversationError.invalidData
        }

        guard conversationIds.count <= 500 else {
            throw ConversationError.invalidData
        }

        // Validate category tags
        guard validateCategoryTags(tags) else {
            throw ConversationError.tooManyTags
        }

        do {
            // Create Firestore batch
            let batch = db.batch()

            // Add update operations for each conversation
            for conversationId in conversationIds {
                let docRef = conversationsCollection.document(conversationId)
                // Update only the categoryTags field to preserve other fields like statusTags
                batch.updateData([
                    "tagsByUser.\(userId).categoryTags": tags.map { $0.rawValue }
                ], forDocument: docRef)
            }

            // Commit batch atomically
            try await batch.commit()
        } catch {
            throw ConversationError.updateFailed(error)
        }
    }

    // MARK: - Tag Helpers

    /// Synchronizes primary category from user tags (auto-update primaryCategory field)
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - userId: The ID of the user
    func syncPrimaryCategoryFromTags(conversationId: String, userId: String) async throws {
        guard let conversation = try await conversationService.fetchConversation(conversationId: conversationId) else {
            throw ConversationError.invalidData
        }

        // Determine primary category based on AI suggestion or user's first category tag
        var primaryCategory: ConversationTag?

        // Check if user has overridden category
        if let metadata = conversation.tagMetadata, !metadata.userOverrideCategory,
           let aiSuggested = metadata.aiSuggestedCategory {
            primaryCategory = aiSuggested
        } else if let tagsByUser = conversation.tagsByUser,
                  let userTagData = tagsByUser[userId],
                  let categoryTags = userTagData.categoryTags,
                  let firstTag = categoryTags.first {
            primaryCategory = firstTag
        }

        // Update primary category
        try await updatePrimaryCategory(conversationId: conversationId, category: primaryCategory)
    }

    /// Gets effective tags for a user (considering both user-specific and conversation-level tags)
    /// - Parameters:
    ///   - conversation: The conversation
    ///   - userId: The user ID
    /// - Returns: Tuple of category and status tags
    func getEffectiveTags(conversation: Conversation, userId: String) -> (categories: [ConversationTag], statuses: [StatusTag]) {
        guard let tagsByUser = conversation.tagsByUser,
              let userTagData = tagsByUser[userId] else {
            // If no user-specific tags, fall back to conversation-level category tags
            return (categories: conversation.categoryTags ?? [], statuses: [])
        }

        let categories = userTagData.categoryTags ?? conversation.categoryTags ?? []
        let statuses = userTagData.statusTags ?? []

        return (categories: categories, statuses: statuses)
    }

    // MARK: - Validation Helpers

    /// Validates category tags array
    /// - Parameter tags: Array of category tags
    /// - Returns: True if valid (max 2 tags), false otherwise
    private func validateCategoryTags(_ tags: [ConversationTag]) -> Bool {
        return tags.count <= 2
    }

    /// Validates status tags array and throws if invalid
    /// - Parameter tags: Array of status tags
    /// - Throws: ConversationError.tagConflict if tags conflict
    private func validateStatusTags(_ tags: [StatusTag]) throws {
        // Check for conflicting tags: Resolved should not coexist with Urgent or NeedsResponse
        let hasResolved = tags.contains(.resolved)
        let hasUrgent = tags.contains(.urgent)
        let hasNeedsResponse = tags.contains(.needsResponse)

        if hasResolved && (hasUrgent || hasNeedsResponse) {
            throw ConversationError.tagConflict
        }
    }

    /// Sanitizes status tags by removing conflicts and duplicates
    /// - Parameter tags: Array of status tags to sanitize
    /// - Returns: Sanitized array following business rules
    private func sanitizeStatusTags(_ tags: [StatusTag]) -> [StatusTag] {
        var sanitized = tags

        // Remove duplicates
        sanitized = Array(Set(sanitized))

        // Business rule: If Resolved is present, remove Urgent and NeedsResponse
        if sanitized.contains(.resolved) {
            sanitized.removeAll { $0 == .urgent || $0 == .needsResponse }
        }

        // Business rule: If Urgent is present, ensure NeedsResponse is also present
        if sanitized.contains(.urgent) && !sanitized.contains(.needsResponse) {
            sanitized.append(.needsResponse)
        }

        return sanitized
    }
}
