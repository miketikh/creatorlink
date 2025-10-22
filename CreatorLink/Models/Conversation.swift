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
    let unreadCounts: [String: Int]? // Denormalized unread count per user (userId: count)

    // Custom initializer for manual construction
    init(id: String? = nil, participantIds: [String], lastMessage: String, lastMessageTime: Date, isGroupChat: Bool, groupName: String?, groupImageUrl: String? = nil, lastMessageSenderId: String? = nil, lastMessageStatus: MessageStatus? = nil, unreadCounts: [String: Int]? = nil) {
        self.id = id
        self.participantIds = participantIds
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.isGroupChat = isGroupChat
        self.groupName = groupName
        self.groupImageUrl = groupImageUrl
        self.lastMessageSenderId = lastMessageSenderId
        self.lastMessageStatus = lastMessageStatus
        self.unreadCounts = unreadCounts
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
        case unreadCounts
    }

    // Hashable conformance - include ALL properties that affect UI rendering (per ios_dev_notes.md)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(participantIds)
        hasher.combine(lastMessage)
        hasher.combine(lastMessageTime)
        hasher.combine(isGroupChat)
        hasher.combine(groupName)
        hasher.combine(groupImageUrl)
        hasher.combine(lastMessageSenderId)
        hasher.combine(lastMessageStatus)
        // Note: unreadCounts is intentionally excluded from hash since it changes frequently
        // and we want real-time updates via the listener to trigger UI updates
    }

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        // Compare unreadCounts to ensure UI updates when counts change
        let unreadCountsEqual: Bool
        if let lhsCounts = lhs.unreadCounts, let rhsCounts = rhs.unreadCounts {
            unreadCountsEqual = lhsCounts == rhsCounts
        } else {
            unreadCountsEqual = lhs.unreadCounts == nil && rhs.unreadCounts == nil
        }

        return lhs.id == rhs.id &&
               lhs.participantIds == rhs.participantIds &&
               lhs.lastMessage == rhs.lastMessage &&
               lhs.lastMessageTime == rhs.lastMessageTime &&
               lhs.isGroupChat == rhs.isGroupChat &&
               lhs.groupName == rhs.groupName &&
               lhs.groupImageUrl == rhs.groupImageUrl &&
               lhs.lastMessageSenderId == rhs.lastMessageSenderId &&
               lhs.lastMessageStatus == rhs.lastMessageStatus &&
               unreadCountsEqual
    }
}
