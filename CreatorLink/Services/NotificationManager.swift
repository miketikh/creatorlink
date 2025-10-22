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
    func showMessageNotification(conversationId: String, senderName: String, messageText: String, isGroupChat: Bool) {
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = senderName
        content.body = messageText
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

        // Create notification request with unique identifier
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
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
