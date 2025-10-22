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
    let groupImageUrl: String?      // Optional custom image URL for group chats
    let lastMessageSenderId: String? // ID of user who sent the last message
    let lastMessageStatus: MessageStatus? // Status of the last message

    // Custom initializer for manual construction
    init(id: String? = nil, participantIds: [String], lastMessage: String, lastMessageTime: Date, isGroupChat: Bool, groupName: String?, groupImageUrl: String? = nil, lastMessageSenderId: String? = nil, lastMessageStatus: MessageStatus? = nil) {
        self.id = id
        self.participantIds = participantIds
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.isGroupChat = isGroupChat
        self.groupName = groupName
        self.groupImageUrl = groupImageUrl
        self.lastMessageSenderId = lastMessageSenderId
        self.lastMessageStatus = lastMessageStatus
    }

    enum CodingKeys: String, CodingKey {
        case id  // Required for @DocumentID to work!
        case participantIds
        case lastMessage
        case lastMessageTime
        case isGroupChat
        case groupName
        case groupImageUrl
        case lastMessageSenderId
        case lastMessageStatus
    }

    // Hashable conformance - include ALL properties that affect UI rendering (per ios_dev_notes.md)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(lastMessage)
        hasher.combine(lastMessageTime)
        hasher.combine(lastMessageSenderId)
        hasher.combine(lastMessageStatus)
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.lastMessage == rhs.lastMessage &&
               lhs.lastMessageTime == rhs.lastMessageTime &&
               lhs.lastMessageSenderId == rhs.lastMessageSenderId &&
               lhs.lastMessageStatus == rhs.lastMessageStatus
    }
}
