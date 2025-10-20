//
//  CreatorLinkApp.swift
//  CreatorLink
//
//  Created by gauntlet on 10/20/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // Initialize auth service after Firebase is configured
        AuthService.shared.ensureInitialized()

        return true
    }
}

@main
struct CreatorLinkApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentRootView()
        }
    }
}

struct ContentRootView: View {
    @State private var authService = AuthService.shared

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
        } else {
            // User is not signed in - show auth view
            AuthView()
        }
    }
}
