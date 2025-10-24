//
//  StatusTag.swift
//  CreatorLink
//
//  Enum representing conversation status tags
//

import Foundation

enum StatusTag: String, Codable, Hashable {
    case urgent         // Urgent messages requiring immediate attention
    case needsResponse  // Awaiting user response
    case awaitingReply  // Awaiting reply from others
    case resolved       // Conversation resolved

    /// Emoji representation for UI display
    var emoji: String {
        switch self {
        case .urgent: return "🔥"
        case .needsResponse: return "❓"
        case .awaitingReply: return "⏰"
        case .resolved: return "✅"
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .urgent: return "Urgent"
        case .needsResponse: return "Needs Response"
        case .awaitingReply: return "Awaiting Reply"
        case .resolved: return "Resolved"
        }
    }
}
