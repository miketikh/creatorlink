//
//  AIConstants.swift
//  CreatorLink
//
//  Centralized constants for AI assistant features
//

import Foundation

/// Constants for AI assistant integration
///
/// The AI user is a special system user that participates in conversations when AI features are enabled.
/// The AI user ID must match what the Python AI service and Cloud Functions use when creating AI-generated messages.
/// The AI user must exist in Firestore before being added to conversations.
struct AIConstants {
    /// The unique user ID for the AI assistant (must match across all systems)
    static let AI_USER_ID = "ai-assistant"

    /// Display name shown in the UI for AI messages
    static let AI_DISPLAY_NAME = "AI Assistant"

    /// Email address for the AI user profile
    static let AI_EMAIL = "ai@creatorlink.app"

    /// Photo URL for the AI user avatar (uses UI Avatars API with indigo background)
    static let AI_PHOTO_URL = "https://ui-avatars.com/api/?name=AI&background=6366f1&color=fff"
}
