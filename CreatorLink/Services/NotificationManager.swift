//
//  NotificationManager.swift
//  CreatorLink
//
//  Service layer for managing local notifications and notification permissions
//

import Foundation
import UserNotifications
import UIKit

@Observable
class NotificationManager {
    static let shared = NotificationManager()

    private init() {
        // Private initializer for singleton pattern
    }

    // MARK: - Permission Management

    /// Request notification permission from the user
    /// - Returns: Boolean indicating whether permission was granted
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            return false
        }
    }

    /// Check the current notification permission status
    /// - Returns: The current authorization status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Notification Creation

    /// Show a local notification for an incoming message
    /// - Parameters:
    ///   - conversationId: The ID of the conversation where the message was received
    ///   - senderName: The display name of the message sender
    ///   - messageText: The text content of the message
    ///   - isGroupChat: Whether this is a group conversation
    ///   - groupName: The name of the group (required if isGroupChat is true)
    func showMessageNotification(conversationId: String, senderName: String, messageText: String, isGroupChat: Bool, groupName: String? = nil) {
        // Create notification content
        let content = UNMutableNotificationContent()

        // Format notification based on conversation type
        if isGroupChat, let groupName = groupName {
            // Group chat: Title = group name, Body = "{Sender}: {message text}"
            content.title = groupName
            content.body = "\(senderName): \(messageText)"

            // Set thread identifier for grouping - all notifications from same conversation will group together
            content.threadIdentifier = conversationId

            // Set summary argument for better notification grouping summary
            content.summaryArgument = groupName
        } else {
            // One-on-one: Title = sender name, Body = message text
            content.title = senderName
            content.body = messageText

            // Set thread identifier for one-on-one chats as well
            content.threadIdentifier = conversationId
        }

        content.sound = .default

        // Increment badge count
        let currentBadge = UIApplication.shared.applicationIconBadgeNumber
        content.badge = NSNumber(value: currentBadge + 1)

        // Add custom data for deep linking
        content.userInfo = [
            "conversationId": conversationId,
            "isGroupChat": isGroupChat
        ]

        // Create trigger for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

        // Create notification request
        // Use conversationId as base for identifier so notifications from same conversation replace/group together
        let identifier = isGroupChat ? "group-\(conversationId)-\(UUID().uuidString)" : "chat-\(conversationId)-\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            // Silently handle errors
        }
    }

    // MARK: - Badge Management

    /// Update the app icon badge count
    /// - Parameter count: The new badge count (use 0 to clear the badge)
    func updateBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            // Silently handle errors
        }
    }

    /// Clear the app icon badge
    func clearBadge() {
        updateBadgeCount(0)
    }
}
