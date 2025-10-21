//
//  Message.swift
//  CreatorLink
//
//  Data model for messages
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    @DocumentID var id: String?         // Firestore document ID (managed by @DocumentID)
    let conversationId: String
    let senderId: String
    let participantIds: [String]        // Denormalized for security rules
    let text: String
    let timestamp: Date
    let status: MessageStatus
    let readBy: [String: Date]          // Map of userId to timestamp when read
    let imageUrl: String?               // Optional image URL (for Phase 6)
    let metadata: [String: String]?     // Optional metadata for AI features (Phase 8)

    // Custom initializer for manual construction
    init(id: String? = nil, conversationId: String, senderId: String, participantIds: [String], text: String, timestamp: Date, status: MessageStatus, readBy: [String: Date], imageUrl: String?, metadata: [String: String]?) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.participantIds = participantIds
        self.text = text
        self.timestamp = timestamp
        self.status = status
        self.readBy = readBy
        self.imageUrl = imageUrl
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case id  // Required for @DocumentID to work!
        case conversationId
        case senderId
        case participantIds
        case text
        case timestamp
        case status
        case readBy
        case imageUrl
        case metadata
    }
}
