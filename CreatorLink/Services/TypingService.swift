//
//  TypingService.swift
//  CreatorLink
//
//  Service for managing typing indicators using Firebase Realtime Database
//

import Foundation
import FirebaseDatabase
import Observation

@Observable
@MainActor
class TypingService {
    static let shared = TypingService()

    private var database: DatabaseReference {
        #if DEBUG
        return Database.database(url: "http://127.0.0.1:9000?ns=creatorlink-c160a").reference()
        #else
        return Database.database().reference()
        #endif
    }
    private var typingTimers: [String: Timer] = [:]
    private var onDisconnectRefs: [String: DatabaseReference] = [:]

    private init() {}

    // MARK: - Public Methods

    /// Sets typing state for a user in a conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: The user who is typing
    ///   - isTyping: Whether the user is typing
    func setTyping(conversationId: String, userId: String, isTyping: Bool) {
        let typingRef = database.child("typing").child(conversationId).child(userId)

        if isTyping {
            // Set typing indicator
            let typingData: [String: Any] = [
                "isTyping": true,
                "timestamp": ServerValue.timestamp()
            ]

            typingRef.setValue(typingData)

            // Set up onDisconnect to clear typing state
            typingRef.onDisconnectRemoveValue()
            onDisconnectRefs["\(conversationId)_\(userId)"] = typingRef

            // Cancel existing timer and create new one to clear after 3 seconds
            typingTimers["\(conversationId)_\(userId)"]?.invalidate()
            typingTimers["\(conversationId)_\(userId)"] = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.clearTyping(conversationId: conversationId, userId: userId)
                }
            }
        } else {
            clearTyping(conversationId: conversationId, userId: userId)
        }
    }

    /// Clears typing state for a user in a conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: The user whose typing state to clear
    func clearTyping(conversationId: String, userId: String) {
        let typingRef = database.child("typing").child(conversationId).child(userId)
        typingRef.removeValue()

        // Cancel timer
        let key = "\(conversationId)_\(userId)"
        typingTimers[key]?.invalidate()
        typingTimers[key] = nil
        onDisconnectRefs[key] = nil
    }

    /// Listens to typing indicators for a conversation
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - currentUserId: The current user's ID (to exclude from results)
    ///   - completion: Closure called with array of typing user IDs
    /// - Returns: DatabaseHandle for cleanup
    func listenToTyping(conversationId: String, currentUserId: String, completion: @escaping ([String]) -> Void) -> DatabaseHandle {
        let typingRef = database.child("typing").child(conversationId)

        return typingRef.observe(.value) { snapshot in
            MainActor.assumeIsolated {
                var typingUserIds: [String] = []

                guard let typingData = snapshot.value as? [String: Any] else {
                    completion([])
                    return
                }

                let now = Date().timeIntervalSince1970 * 1000 // Convert to milliseconds

                for (userId, data) in typingData {
                    // Skip current user
                    if userId == currentUserId {
                        continue
                    }

                    // Check if data is valid
                    guard let userData = data as? [String: Any],
                          let isTyping = userData["isTyping"] as? Bool,
                          let timestamp = userData["timestamp"] as? Double else {
                        continue
                    }

                    // Only include if typing is true and timestamp is recent (within 5 seconds)
                    let timeDiff = now - timestamp
                    if isTyping && timeDiff < 5000 {
                        typingUserIds.append(userId)
                    }
                }

                completion(typingUserIds)
            }
        }
    }

    /// Removes a typing listener
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - handle: The database handle to remove
    func removeTypingListener(conversationId: String, handle: DatabaseHandle) {
        let typingRef = database.child("typing").child(conversationId)
        typingRef.removeObserver(withHandle: handle)
    }
}
