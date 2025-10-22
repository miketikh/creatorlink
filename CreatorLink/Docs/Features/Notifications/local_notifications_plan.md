# Local Notifications Implementation Plan (No APNs Required)

## Project Context

CreatorLink is a **local test iOS messaging app** built with Swift/SwiftUI and Firebase backend. This plan implements notifications using **local notifications** triggered by Firestore listeners, avoiding the need for:
- ❌ APNs authentication certificates
- ❌ Paid Apple Developer account ($99/year)
- ❌ Firebase Cloud Functions
- ❌ FCM token management

## What This Approach Provides

### ✅ Works For:
- **Foreground**: App is actively being used - show in-app banners
- **Background**: App sent to background (home button) - show notification banners for ~30 seconds
- **Local testing**: Perfect for simulator and local device testing
- **MVP requirements**: Demonstrates notification UI/UX

### ❌ Limitations:
- **Terminated app**: After app is force-quit or suspended by iOS, listeners stop working
- **Extended background**: After ~30 seconds in background, iOS suspends the app
- **Production use**: Real apps need remote push notifications for reliability

**For your use case (local testing, MVP demo)**: This approach is **perfect** and much simpler!

## How It Works

```
User A sends message
    ↓
Firestore write
    ↓
Firestore listener on User B's device (still active in background)
    ↓
Trigger local notification
    ↓
User B sees notification banner
```

## Implementation Phases

### Phase 1: Request Notification Permissions (30 minutes)

#### 1.1 Create NotificationManager Service
**Location**: Create `CreatorLink/Services/NotificationManager.swift`

**Purpose**: Centralize notification permissions and local notification creation

**Implementation**:
```swift
import UserNotifications

@Observable
class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    // Request permission from user
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            print("Notification permission granted: \(granted)")
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    // Check current permission status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}
```

#### 1.2 Update AppDelegate
**Location**: `CreatorLink/CreatorLinkApp.swift` (AppDelegate class)

**Add**: Set notification center delegate

**Implementation**:
```swift
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        AuthService.shared.ensureInitialized()
        return true
    }
}

// Add notification delegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // Handle notification when app is in FOREGROUND
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {

        // Show banner, sound, and badge even when app is open
        return [.banner, .sound, .badge]
    }

    // Handle notification TAP
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {

        let userInfo = response.notification.request.content.userInfo

        // Extract conversationId from notification payload
        if let conversationId = userInfo["conversationId"] as? String {
            // Navigate to conversation (implement in Phase 3)
            print("User tapped notification for conversation: \(conversationId)")
        }
    }
}
```

#### 1.3 Request Permission After Sign-In
**Location**: `CreatorLink/Services/AuthService.swift`

**Add**: Request permission after successful authentication

**Pattern**:
```swift
// After successful sign-in, request notification permission
Task {
    await NotificationManager.shared.requestPermission()
}
```

**Alternative**: Request in `ContentRootView.onAppear()` after user is authenticated

### Phase 2: Trigger Local Notifications from Firestore Listener (1-2 hours)

#### 2.1 Add Notification Method to NotificationManager
**Location**: `CreatorLink/Services/NotificationManager.swift`

**Add Method**:
```swift
// Create and schedule a local notification for a new message
func showMessageNotification(
    conversationId: String,
    senderName: String,
    messageText: String,
    isGroupChat: Bool = false
) {
    let content = UNMutableNotificationContent()

    // Set notification content
    content.title = senderName
    content.body = messageText
    content.sound = .default

    // Add badge (increment by 1)
    content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

    // Add custom data for deep linking
    content.userInfo = [
        "conversationId": conversationId,
        "isGroupChat": isGroupChat
    ]

    // Create trigger (deliver immediately)
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

    // Create request with unique identifier
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: trigger
    )

    // Schedule notification
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Failed to schedule notification: \(error)")
        }
    }
}
```

#### 2.2 Update Global Message Listener
**Location**: `CreatorLink/CreatorLinkApp.swift` (ContentRootView)

**Modification**: Add local notification trigger in `setupGlobalMessageDeliveryListener`

**Current code** (around line 113-153):
```swift
private func setupGlobalMessageDeliveryListener(userId: String) {
    messageDeliveryListener?.remove()

    messageDeliveryListener = Firestore.firestore()
        .collection("messages")
        .whereField("participantIds", arrayContains: userId)
        .addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else {
                return
            }

            for change in snapshot.documentChanges {
                guard change.type == .added || change.type == .modified else { continue }

                do {
                    let message = try change.document.data(as: Message.self)

                    // Only mark as delivered if from someone else
                    guard message.senderId != userId,
                          message.status == .sent,
                          let messageId = message.id
                    else { continue }

                    // Mark as delivered
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
```

**Updated code** (add notification trigger):
```swift
private func setupGlobalMessageDeliveryListener(userId: String) {
    messageDeliveryListener?.remove()

    messageDeliveryListener = Firestore.firestore()
        .collection("messages")
        .whereField("participantIds", arrayContains: userId)
        .addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else {
                return
            }

            for change in snapshot.documentChanges {
                // Only trigger notification for NEW messages (not modified)
                guard change.type == .added else { continue }

                do {
                    let message = try change.document.data(as: Message.self)

                    // Only process messages from others
                    guard message.senderId != userId,
                          let messageId = message.id
                    else { continue }

                    // Mark as delivered
                    Task {
                        do {
                            try await MessageService.shared.updateMessageStatus(messageId: messageId, status: .delivered)

                            // TRIGGER LOCAL NOTIFICATION
                            await self.triggerNotificationForMessage(message, userId: userId)
                        } catch {
                        }
                    }
                } catch {
                }
            }
        }
}

// NEW METHOD: Trigger notification for incoming message
private func triggerNotificationForMessage(_ message: Message, userId: String) async {
    // Don't show notification if user is actively viewing this conversation
    // (You can add logic here to check current screen)

    // Fetch sender info
    do {
        let sender = try await UserService.shared.fetchUser(userId: message.senderId)
        let senderName = sender?.displayName ?? "Someone"

        // Fetch conversation to check if group chat
        let conversation = try await ConversationService.shared.fetchConversation(conversationId: message.conversationId)
        let isGroupChat = conversation?.isGroupChat ?? false

        // Trigger local notification
        NotificationManager.shared.showMessageNotification(
            conversationId: message.conversationId,
            senderName: senderName,
            messageText: message.text,
            isGroupChat: isGroupChat
        )
    } catch {
        print("Failed to fetch sender info: \(error)")
    }
}
```

### Phase 3: Deep Linking (Navigate to Conversation on Tap) (1 hour)

#### 3.1 Create NavigationCoordinator
**Location**: Create `CreatorLink/Services/NavigationCoordinator.swift`

**Purpose**: Handle navigation from notification taps

**Implementation**:
```swift
import Foundation

@Observable
class NavigationCoordinator {
    static let shared = NavigationCoordinator()

    // Conversation ID to deep link to
    var deepLinkConversationId: String?

    private init() {}

    // Called when user taps a notification
    func handleNotificationTap(conversationId: String) {
        print("Deep linking to conversation: \(conversationId)")
        self.deepLinkConversationId = conversationId
    }

    // Clear deep link after navigation
    func clearDeepLink() {
        self.deepLinkConversationId = nil
    }
}
```

#### 3.2 Wire Notification Tap Handler
**Location**: `CreatorLink/CreatorLinkApp.swift` (AppDelegate extension)

**Update**: Implement notification tap in delegate method (already added in Phase 1)

**Implementation**:
```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse) async {

    let userInfo = response.notification.request.content.userInfo

    if let conversationId = userInfo["conversationId"] as? String {
        // Trigger deep link navigation
        await MainActor.run {
            NavigationCoordinator.shared.handleNotificationTap(conversationId: conversationId)
        }
    }
}
```

#### 3.3 Update ChatsView to Handle Deep Links
**Location**: `CreatorLink/Views/Chats/ChatsView.swift` (or your main chats list view)

**Add**: Listen for deep link changes

**Pattern**:
```swift
@State private var navigationCoordinator = NavigationCoordinator.shared

var body: some View {
    // ... existing NavigationStack/List code
    .onChange(of: navigationCoordinator.deepLinkConversationId) { oldValue, newValue in
        if let conversationId = newValue {
            // Navigate to ChatDetailView
            // Implementation depends on your navigation setup
            // Example: push to detail view or set selected conversation

            // Clear deep link after handling
            navigationCoordinator.clearDeepLink()
        }
    }
}
```

### Phase 4: Badge Management (30 minutes)

#### 4.1 Add Badge Update Method
**Location**: `CreatorLink/Services/NotificationManager.swift`

**Add Method**:
```swift
// Update app badge count
func updateBadgeCount(_ count: Int) {
    UNUserNotificationCenter.current().setBadgeCount(count) { error in
        if let error = error {
            print("Failed to set badge count: \(error)")
        }
    }
}

// Clear badge
func clearBadge() {
    updateBadgeCount(0)
}
```

#### 4.2 Update Badge on App Launch
**Location**: `CreatorLink/CreatorLinkApp.swift` (ContentRootView)

**Add**: Reset badge when user opens app

**Pattern**:
```swift
.onAppear {
    if let userId = authService.currentUser?.uid {
        PresenceService.shared.setupPresence(userId: userId)
        setupGlobalMessageDeliveryListener(userId: userId)

        // Clear badge when app opens
        NotificationManager.shared.clearBadge()
    }
}
```

#### 4.3 Update Badge When Reading Messages
**Location**: `CreatorLink/Views/Chats/ChatDetailView.swift` (or wherever messages are marked as read)

**Add**: Decrement badge after marking messages as read

**Pattern**:
```swift
// After marking messages as read
let currentBadge = UIApplication.shared.applicationIconBadgeNumber
let newBadge = max(0, currentBadge - unreadCount)
NotificationManager.shared.updateBadgeCount(newBadge)
```

### Phase 5: Optimize for App States (1 hour)

#### 5.1 Don't Notify When Conversation Is Open
**Location**: `CreatorLink/CreatorLinkApp.swift` (triggerNotificationForMessage method)

**Add**: Check if user is actively viewing the conversation

**Pattern**:
```swift
private func triggerNotificationForMessage(_ message: Message, userId: String) async {
    // Check if user is currently viewing this conversation
    // You can use an environment object or coordinator to track current conversation
    // if CurrentConversationTracker.shared.activeConversationId == message.conversationId {
    //     return // Don't show notification
    // }

    // ... rest of notification code
}
```

#### 5.2 Handle Scene Phase Changes
**Location**: `CreatorLink/CreatorLinkApp.swift` (handleScenePhaseChange method)

**Add**: Clear badge when app becomes active

**Pattern**:
```swift
private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
    guard let userId = AuthService.shared.currentUser?.uid else { return }

    switch newPhase {
    case .active:
        PresenceService.shared.cancelOfflineTimer()
        PresenceService.shared.setOnline(userId: userId)

        // Clear badge when app becomes active
        NotificationManager.shared.clearBadge()

    case .inactive:
        break

    case .background:
        PresenceService.shared.setOffline(userId: userId, delay: 30)

    @unknown default:
        break
    }
}
```

## Testing Strategy

### Test Scenario 1: Foreground Notification
1. Open app and navigate to ChatsView
2. From another device/simulator, send a message
3. **Expected**: Banner appears at top of screen with sender name and message
4. Tap banner → should navigate to conversation

### Test Scenario 2: Background Notification
1. Open app, then press home button (send to background)
2. From another device/simulator, send a message within 30 seconds
3. **Expected**: Notification banner appears on lock screen/notification center
4. Tap notification → app opens and navigates to conversation

### Test Scenario 3: Badge Count
1. Background the app
2. Send 3 messages from another device
3. **Expected**: App icon shows badge "3"
4. Open app → badge clears
5. Open conversation → badge updates

### Test Scenario 4: Group Chat
1. Create group with 3+ users
2. User A sends message
3. **Expected**: Users B and C both see notifications with sender name

### Test Scenario 5: Don't Notify When Viewing
1. Open ChatDetailView for a conversation
2. Receive message in that conversation
3. **Expected**: No notification appears (user is already looking at it)

### Limitations to Test
1. Background app for 60+ seconds → send message → **No notification** (iOS suspended the app)
2. Force quit app → send message → **No notification** (app not running)
3. These are expected limitations of local notifications

## Files Summary

### Files to Create
1. `CreatorLink/Services/NotificationManager.swift` - Local notification handling
2. `CreatorLink/Services/NavigationCoordinator.swift` - Deep link navigation

### Files to Modify
1. `CreatorLink/CreatorLinkApp.swift`
   - Add `UNUserNotificationCenterDelegate` to AppDelegate
   - Add `triggerNotificationForMessage` method
   - Update `setupGlobalMessageDeliveryListener`
   - Clear badge in scene phase changes
2. `CreatorLink/Services/AuthService.swift` - Request permissions after sign-in
3. `CreatorLink/Views/Chats/ChatsView.swift` - Handle deep link navigation
4. `CreatorLink/Views/Chats/ChatDetailView.swift` - Update badge when reading messages

### No Changes Required
- ❌ Firebase Console (no FCM setup needed)
- ❌ Info.plist (no remote notification background mode needed)
- ❌ Xcode project settings (no new packages needed)
- ❌ Cloud Functions (no backend code needed)

## Advantages of This Approach

1. **No External Dependencies**
   - No APNs certificates
   - No paid Apple Developer account
   - No Cloud Functions deployment
   - No server-side code

2. **Perfect for Testing**
   - Works in simulator
   - Works on local devices
   - Easy to debug
   - No network delays

3. **Quick Implementation**
   - ~3-4 hours total
   - No Firebase Console setup
   - No backend complexity

4. **Meets MVP Requirements**
   - Foreground notifications ✅
   - Background notifications ✅ (for ~30 seconds)
   - Badge management ✅
   - Deep linking ✅

## Timeline Estimate

- **Phase 1** (Permissions): 30 minutes
- **Phase 2** (Trigger Notifications): 1-2 hours
- **Phase 3** (Deep Linking): 1 hour
- **Phase 4** (Badge Management): 30 minutes
- **Phase 5** (Optimization): 1 hour

**Total**: ~3-4 hours

## When to Upgrade to Remote Push

You should implement full remote push notifications (APNs + FCM) when:
- You need notifications for terminated apps
- You need notifications after 30+ seconds in background
- You're ready to deploy to TestFlight or App Store
- You have a paid Apple Developer account
- You want production-quality reliability

For now, local notifications are **perfect for your use case**!

## Success Criteria

Local notifications are complete when:

- ✅ Users receive notification banners when app is in foreground
- ✅ Users receive notification banners when app is backgrounded (within ~30 seconds)
- ✅ Tapping notification opens the app to the correct conversation
- ✅ Badge count shows unread messages
- ✅ Group chat notifications show sender name
- ✅ Notifications don't appear when user is viewing the conversation
- ✅ Works reliably in simulator and on device for testing

## Next Steps

Ready to implement? Start with Phase 1 and work through sequentially. Each phase builds on the previous one and can be tested independently.

The full remote push notification plan is still available in `push_notifications_plan.md` for when you're ready to upgrade!
