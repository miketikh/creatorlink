//
//  NotificationManager.swift
//  CreatorLink
//
//  Service layer for managing local notifications and notification permissions
//

import Foundation
import UserNotifications

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
            print("[NotificationManager] Permission request result: \(granted ? "Granted" : "Denied")")
            return granted
        } catch {
            print("[NotificationManager] Permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Check the current notification permission status
    /// - Returns: The current authorization status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
