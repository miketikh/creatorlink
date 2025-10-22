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
}
