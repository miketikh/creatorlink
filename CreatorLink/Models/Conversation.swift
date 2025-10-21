//
//  Conversation.swift
//  CreatorLink
//
//  Data model for conversations
//

import Foundation
import FirebaseFirestore

struct Conversation: Identifiable, Codable, Hashable {
    @DocumentID var id: String?     // Firestore document ID (managed by @DocumentID)
    let participantIds: [String]    // Array of user IDs
    let lastMessage: String
    let lastMessageTime: Date
    let isGroupChat: Bool
    let groupName: String?          // Optional group name for group chats

    // Custom initializer for manual construction
    init(id: String? = nil, participantIds: [String], lastMessage: String, lastMessageTime: Date, isGroupChat: Bool, groupName: String?) {
        self.id = id
        self.participantIds = participantIds
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.isGroupChat = isGroupChat
        self.groupName = groupName
    }

    enum CodingKeys: String, CodingKey {
        case id  // Required for @DocumentID to work!
        case participantIds
        case lastMessage
        case lastMessageTime
        case isGroupChat
        case groupName
    }

    // Hashable conformance - include properties that affect UI rendering
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(lastMessage)
        hasher.combine(lastMessageTime)
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.lastMessage == rhs.lastMessage &&
               lhs.lastMessageTime == rhs.lastMessageTime
    }
}
