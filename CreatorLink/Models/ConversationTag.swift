//
//  ConversationTag.swift
//  CreatorLink
//
//  Enum representing conversation category tags
//

import Foundation

enum ConversationTag: String, Codable, Hashable {
    case business       // Business-related conversations
    case collaboration  // Collaboration and project work
    case social         // Social and casual conversations
    case fan            // Fan interactions and community

    /// Emoji representation for UI display
    var emoji: String {
        switch self {
        case .business: return "💼"
        case .collaboration: return "🤝"
        case .social: return "💬"
        case .fan: return "⭐"
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .business: return "Business"
        case .collaboration: return "Collaboration"
        case .social: return "Social"
        case .fan: return "Fan"
        }
    }
}
