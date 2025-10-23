//
//  CreatorLinkApp.swift
//  CreatorLink
//
//  Created by gauntlet on 10/20/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        #if DEBUG
        // Connect to Firebase Local Emulator Suite
        // Connect Auth to emulator
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)

        // Connect Firestore to emulator
        let settings = Firestore.firestore().settings
        settings.host = "127.0.0.1:8080"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings

        // Connect Realtime Database to emulator
        Database.database(url: "http://127.0.0.1:9000?ns=creatorlink-c160a")
        #endif

        // Initialize auth service after Firebase is configured
        AuthService.shared.ensureInitialized()

        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        return true
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Called when a notification is delivered while the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when the user taps on a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Extract conversationId from notification payload
        if let conversationId = userInfo["conversationId"] as? String {
            // Navigate to conversation using NavigationCoordinator
            Task { @MainActor in
                NavigationCoordinator.shared.handleNotificationTap(conversationId: conversationId)
            }
        }

        completionHandler()
    }
}

@main
struct CreatorLinkApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentRootView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    // MARK: - App Lifecycle Handling

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        guard let userId = AuthService.shared.currentUser?.uid else { return }

        switch newPhase {
        case .active:
            // App entered foreground - set user online
            // Clear badge, resume notification suppression for active conversation
            PresenceService.shared.cancelOfflineTimer()
            PresenceService.shared.setOnline(userId: userId)
            NotificationManager.shared.clearBadge()

        case .inactive:
            // App is temporarily inactive (e.g., receiving a phone call)
            // No action needed - temporary state
            break

        case .background:
            // App entered background - set user offline after 30 second grace period
            // Clear active conversation so notifications will show for new messages
            PresenceService.shared.setOffline(userId: userId, delay: 30)
            NavigationCoordinator.shared.setActiveConversation(nil)

        @unknown default:
            break
        }
    }
}

struct ContentRootView: View {
    @State private var authService = AuthService.shared
    @State private var messageDeliveryListener: ListenerRegistration?

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // User is signed in - show main app
                TabView {
                    ChatsView()
                        .tabItem {
                            Label("Chats", systemImage: "bubble.left.and.bubble.right.fill")
                        }

                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                }
                .onAppear {
                    // Setup presence when user is authenticated and app appears
                    if let userId = authService.currentUser?.uid {
                        PresenceService.shared.setupPresence(userId: userId)
                        setupGlobalMessageDeliveryListener(userId: userId)
                        // Clear badge when app launches
                        NotificationManager.shared.clearBadge()
                    }
                }
                .onDisappear {
                    // Clean up global listener when app goes away
                    messageDeliveryListener?.remove()
                    messageDeliveryListener = nil
                }
            } else {
                // User is not signed in - show auth view
                AuthView()
                    .onAppear {
                        // Clean up listener if user signs out
                        messageDeliveryListener?.remove()
                        messageDeliveryListener = nil
                    }
            }
        }
    }

    // MARK: - Global Message Delivery Listener

    /// Sets up a global listener that marks messages as "delivered" when they arrive
    /// This runs app-wide, even when specific chat views aren't open
    private func setupGlobalMessageDeliveryListener(userId: String) {
        // Remove existing listener if any
        messageDeliveryListener?.remove()

        // Listen to all messages where current user is a participant
        messageDeliveryListener = Firestore.firestore()
            .collection("messages")
            .whereField("participantIds", arrayContains: userId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    return
                }

                // Process new messages (only .added to avoid duplicate notifications)
                for change in snapshot.documentChanges {
                    guard change.type == .added else { continue }

                    do {
                        let message = try change.document.data(as: Message.self)

                        // Only process messages from others (not current user)
                        guard message.senderId != userId,
                              message.status == .sent,
                              let messageId = message.id
                        else { continue }

                        // Mark as delivered and trigger notification in background
                        Task {
                            do {
                                try await MessageService.shared.updateMessageStatus(messageId: messageId, status: .delivered)
                                // Trigger notification after successful delivery update
                                await self.triggerNotificationForMessage(message, userId: userId)
                            } catch {
                                // Silently handle errors
                            }
                        }
                    } catch {
                        // Silently handle decoding errors
                    }
                }
            }
    }

    // MARK: - Notification Triggering

    /// Trigger a local notification for an incoming message
    /// - Parameters:
    ///   - message: The message that was received
    ///   - userId: The current user's ID
    private func triggerNotificationForMessage(_ message: Message, userId: String) async {
        // Suppress notification if user is actively viewing this conversation
        if NavigationCoordinator.shared.activeConversationId == message.conversationId {
            return
        }

        do {
            // Fetch conversation to determine if it's a group chat and check mute status
            let conversation = try await ConversationService.shared.fetchConversation(conversationId: message.conversationId)

            guard let conversation = conversation else {
                return
            }

            // Check if conversation is muted by current user
            if let mutedBy = conversation.mutedBy, mutedBy.contains(userId) {
                // Conversation is muted - don't show notification
                return
            }

            // Fetch sender information
            let sender = try await UserService.shared.fetchUser(userId: message.senderId)
            let senderName = sender.displayName ?? "Someone"

            let isGroupChat = conversation.isGroupChat
            let groupName = conversation.groupName

            // Trigger the notification
            NotificationManager.shared.showMessageNotification(
                conversationId: message.conversationId,
                senderName: senderName,
                messageText: message.text,
                isGroupChat: isGroupChat,
                groupName: groupName
            )
        } catch {
            // Silently handle errors
        }
    }
}
