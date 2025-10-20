//
//  Conversation.swift
//  CreatorLink
//
//  Data model for conversations
//

import Foundation

struct Conversation: Identifiable, Codable {
    let id: String                  // Firestore document ID
    let participantIds: [String]    // Array of user IDs
    let lastMessage: String
    let lastMessageTime: Date
    let isGroupChat: Bool
    let groupName: String?          // Optional group name for group chats

    enum CodingKeys: String, CodingKey {
        case id
        case participantIds
        case lastMessage
        case lastMessageTime
        case isGroupChat
        case groupName
    }
}
