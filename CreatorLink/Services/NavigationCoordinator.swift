//
//  NavigationCoordinator.swift
//  CreatorLink
//
//  Service for managing deep link navigation from notifications
//

import Foundation

@Observable
class NavigationCoordinator {
    static let shared = NavigationCoordinator()

    /// The conversation ID to navigate to when a notification is tapped
    var deepLinkConversationId: String?

    /// The conversation ID currently being viewed by the user
    var activeConversationId: String?

    private init() {}

    // MARK: - Deep Link Navigation

    /// Handles notification tap by setting the deep link conversation ID
    func handleNotificationTap(conversationId: String) {
        deepLinkConversationId = conversationId
    }

    /// Clears the deep link after navigation completes
    func clearDeepLink() {
        deepLinkConversationId = nil
    }

    // MARK: - Active Conversation Tracking

    /// Sets the currently active conversation
    func setActiveConversation(_ conversationId: String?) {
        activeConversationId = conversationId
    }
}
