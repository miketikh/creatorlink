//
//  PresenceService.swift
//  CreatorLink
//
//  Service for managing user presence and online/offline status
//

import Foundation
import FirebaseAuth
import FirebaseDatabase
import FirebaseFirestore

@Observable
class PresenceService {
    static let shared = PresenceService()

    private var rtdb: DatabaseReference {
        #if DEBUG
        return Database.database(url: "http://127.0.0.1:9000?ns=creatorlink-c160a").reference()
        #else
        return Database.database().reference()
        #endif
    }
    private let firestore = Firestore.firestore()
    private var offlineTimer: Timer?

    private init() {}

    // MARK: - Presence Management

    /// Sets up presence for the current user
    func setupPresence(userId: String) {
        // Set online in RTDB with onDisconnect handler
        let presenceRef = rtdb.child("presence").child(userId)

        // Set online status
        presenceRef.child("isOnline").setValue(true)
        presenceRef.child("lastSeen").setValue(ServerValue.timestamp())

        // Set offline status on disconnect
        presenceRef.child("isOnline").onDisconnectSetValue(false)
        presenceRef.child("lastSeen").onDisconnectSetValue(ServerValue.timestamp())

        // Also update Firestore user document
        Task {
            try? await UserService.shared.updateOnlineStatus(userId: userId, isOnline: true)
        }
    }

    /// Sets user as online
    func setOnline(userId: String) {
        // Cancel any pending offline timer
        offlineTimer?.invalidate()
        offlineTimer = nil

        let presenceRef = rtdb.child("presence").child(userId)
        presenceRef.child("isOnline").setValue(true)
        presenceRef.child("lastSeen").setValue(ServerValue.timestamp())

        // Update Firestore
        Task {
            try? await UserService.shared.updateOnlineStatus(userId: userId, isOnline: true)
        }
    }

    /// Sets user as offline with optional delay (grace period)
    func setOffline(userId: String, delay: TimeInterval = 0) {
        // Cancel any existing timer
        offlineTimer?.invalidate()

        if delay > 0 {
            // Schedule offline update after delay
            offlineTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.performSetOffline(userId: userId)
            }
        } else {
            // Immediately set offline
            performSetOffline(userId: userId)
        }
    }

    private func performSetOffline(userId: String) {
        let presenceRef = rtdb.child("presence").child(userId)
        presenceRef.child("isOnline").setValue(false)
        presenceRef.child("lastSeen").setValue(ServerValue.timestamp())

        // Update Firestore
        Task {
            try? await UserService.shared.updateOnlineStatus(userId: userId, isOnline: false)
        }
    }

    /// Cancels pending offline timer (used when app returns to foreground)
    func cancelOfflineTimer() {
        offlineTimer?.invalidate()
        offlineTimer = nil
    }

    /// Listens to presence updates for a user
    func listenToPresence(userId: String, completion: @escaping (Bool, Date?) -> Void) -> DatabaseHandle {
        let presenceRef = rtdb.child("presence").child(userId)

        return presenceRef.observe(.value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                completion(false, nil)
                return
            }

            let isOnline = value["isOnline"] as? Bool ?? false

            // Convert timestamp to Date
            var lastSeen: Date?
            if let timestamp = value["lastSeen"] as? TimeInterval {
                lastSeen = Date(timeIntervalSince1970: timestamp / 1000)
            }

            completion(isOnline, lastSeen)
        }
    }

    /// Removes presence listener
    func removePresenceListener(userId: String, handle: DatabaseHandle) {
        let presenceRef = rtdb.child("presence").child(userId)
        presenceRef.removeObserver(withHandle: handle)
    }
}
