//
//  Message.swift
//  CreatorLink
//
//  Data model for messages
//

import Foundation

struct Message: Identifiable, Codable {
    let id: String                      // Firestore document ID
    let conversationId: String
    let senderId: String
    let text: String
    let timestamp: Date
    let status: MessageStatus
    let readBy: [String: Date]          // Map of userId to timestamp when read
    let imageUrl: String?               // Optional image URL (for Phase 6)
    let metadata: [String: String]?     // Optional metadata for AI features (Phase 8)

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId
        case senderId
        case text
        case timestamp
        case status
        case readBy
        case imageUrl
        case metadata
    }
}
