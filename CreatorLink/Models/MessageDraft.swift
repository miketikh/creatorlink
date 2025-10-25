//
//  MessageDraft.swift
//  CreatorLink
//
//  Data model for AI-generated draft responses
//  Simple schema with just the essentials for functionality
//

import Foundation
import FirebaseFirestore

/// AI-generated draft message for a conversation
/// Stored in conversations/{conversationId}/drafts/{userId} subcollection
struct MessageDraft: Identifiable, Codable, Hashable {
    @DocumentID var id: String?     // Firestore document ID (userId)
    let conversationId: String      // Parent conversation
    let userId: String              // Who the draft is for (the recipient)
    let text: String                // Draft message text
    let category: ConversationTag   // Conversation category
    let generatedAt: Date           // When draft was first generated
    let updatedAt: Date             // When draft was last updated
    let userTouched: Bool?          // User manually edited draft (prevents auto-updates)

    // Custom initializer for manual construction
    init(
        id: String? = nil,
        conversationId: String,
        userId: String,
        text: String,
        category: ConversationTag,
        generatedAt: Date,
        updatedAt: Date,
        userTouched: Bool? = false
    ) {
        self.id = id
        self.conversationId = conversationId
        self.userId = userId
        self.text = text
        self.category = category
        self.generatedAt = generatedAt
        self.updatedAt = updatedAt
        self.userTouched = userTouched
    }

    enum CodingKeys: String, CodingKey {
        case id  // Required for @DocumentID to work
        case conversationId
        case userId
        case text
        case category
        case generatedAt
        case updatedAt
        case userTouched
    }

    // MARK: - Computed Properties

    /// Preview text (first 50 characters)
    var previewText: String {
        if text.count > 50 {
            return String(text.prefix(50)) + "..."
        }
        return text
    }
}
