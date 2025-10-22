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
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

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
            print("[NotificationDelegate] User tapped notification for conversation: \(conversationId)")
            // TODO: Navigate to conversation - implement in Phase 3
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
            PresenceService.shared.cancelOfflineTimer()
            PresenceService.shared.setOnline(userId: userId)

        case .inactive:
            // App is temporarily inactive (e.g., receiving a phone call)
            // Don't change presence yet
            break

        case .background:
            // App entered background - set user offline after 30 second grace period
            PresenceService.shared.setOffline(userId: userId, delay: 30)

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

                // Process new/modified messages
                for change in snapshot.documentChanges {
                    guard change.type == .added || change.type == .modified else { continue }

                    do {
                        let message = try change.document.data(as: Message.self)

                        // Only mark as delivered if:
                        // 1. Message is from someone else (not current user)
                        // 2. Message status is currently "sent"
                        // 3. Message hasn't been delivered yet
                        guard message.senderId != userId,
                              message.status == .sent,
                              let messageId = message.id
                        else { continue }

                        // Mark as delivered in background
                        Task {
                            do {
                                try await MessageService.shared.updateMessageStatus(messageId: messageId, status: .delivered)
                            } catch {
                            }
                        }
                    } catch {
                    }
                }
            }
    }
}
