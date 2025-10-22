# Push Notifications Implementation Plan

## Project Context

CreatorLink is an iOS messaging app built with Swift/SwiftUI and Firebase backend. The app currently implements:
- Real-time messaging via Firestore listeners
- Message status tracking (sending → sent → delivered → read)
- Offline support with local persistence
- Group chat functionality
- User presence (online/offline status)

**Gap**: Push notifications are required for the rubric but not yet implemented. Users need to receive notifications for new messages when:
- App is in the foreground (show in-app banner)
- App is in the background (show notification banner)
- App is terminated (wake app and show notification)

## Architecture Overview

### Current Setup
- **Backend**: Firebase (Firestore, Auth)
- **Frontend**: Swift, SwiftUI, SwiftData
- **Auth**: Firebase Auth with Google Sign-In
- **App Structure**: AppDelegate pattern with `@UIApplicationDelegateAdaptor`
- **Message Flow**: Local optimistic UI → Firestore write → Real-time listeners

### What Push Notifications Add
Push notifications will use **Firebase Cloud Messaging (FCM)** to:
1. Send notification payloads when new messages are created
2. Wake the app in background to sync messages
3. Display banners to users even when app is closed
4. Deep link users to specific conversations when tapped

## Implementation Phases

### Phase 1: FCM Setup & Configuration (2-3 hours)

#### 1.1 Firebase Console Setup
**Location**: Firebase Console (web)

**Steps**:
1. Upload APNs authentication key or certificate to Firebase Console
   - Go to Project Settings → Cloud Messaging → iOS app configuration
   - Upload APNs Auth Key (.p8 file) OR APNs Certificate (.p12 file)
   - Recommended: Use APNs Auth Key (token-based) for modern apps
2. Enable Firebase Cloud Messaging API in Google Cloud Console
3. Verify iOS app bundle ID matches Xcode project

#### 1.2 Add FCM Package Dependencies
**Location**: Xcode project settings

**Steps**:
1. Add Firebase Messaging SPM package
   - File → Add Package Dependencies
   - Add `https://github.com/firebase/firebase-ios-sdk`
   - Select `FirebaseMessaging` module (likely already have FirebaseAuth, FirebaseFirestore)
2. Import in `CreatorLinkApp.swift`: `import FirebaseMessaging`

#### 1.3 Update Info.plist
**Location**: `CreatorLink/Info.plist`

**Additions**:
```xml
<!-- Disable method swizzling for manual token management -->
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>

<!-- Background modes for remote notifications -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

**Rationale**: Disabling swizzling gives explicit control over APNs/FCM token handling, which is recommended for SwiftUI apps and better debugging.

### Phase 2: Client-Side Token Management (3-4 hours)

#### 2.1 Create NotificationService
**Location**: Create new file `CreatorLink/Services/NotificationService.swift`

**Purpose**: Centralize all FCM token and notification handling logic

**Key Methods**:
```swift
class NotificationService {
    static let shared = NotificationService()

    // Request notification permissions from user
    func requestPermissions() async -> Bool

    // Retrieve and upload FCM token to Firestore
    func registerForPushNotifications() async

    // Store token in Firestore user document
    func uploadFCMToken(_ token: String, userId: String) async

    // Handle token refresh (called by FCM delegate)
    func handleTokenRefresh(_ token: String) async
}
```

**Best Practice Pattern**:
- Request permissions on first launch or after sign-in (not immediately at app launch)
- Store FCM tokens in Firestore `users/{userId}` document under field `fcmTokens: [String]` (array to support multiple devices)
- Always upload token after successful auth

#### 2.2 Extend AppDelegate with FCM Delegates
**Location**: `CreatorLink/CreatorLinkApp.swift` (AppDelegate class)

**Implementations Required**:

1. **UNUserNotificationCenterDelegate** (for handling notifications)
   - `userNotificationCenter(_:willPresent:)` - Foreground notifications
   - `userNotificationCenter(_:didReceive:)` - User tapped notification

2. **MessagingDelegate** (for FCM token updates)
   - `messaging(_:didReceiveRegistrationToken:)` - Token refresh callback

**Code Pattern**:
```swift
extension AppDelegate: UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // Set FCM delegates
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Register for remote notifications
        application.registerForRemoteNotifications()

        return true
    }

    // Handle APNs token (required when swizzling disabled)
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // FCM token refresh
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task {
            await NotificationService.shared.handleTokenRefresh(token)
        }
    }

    // Foreground notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        // Show banner, sound, and badge even when app is open
        return [.banner, .sound, .badge]
    }

    // Notification tap handler
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        // Extract conversationId from payload and navigate to chat
        if let conversationId = userInfo["conversationId"] as? String {
            await navigateToConversation(conversationId)
        }
    }
}
```

#### 2.3 Update AuthService
**Location**: `CreatorLink/Services/AuthService.swift`

**Modification**: After successful sign-in, register for push notifications

**Pattern**:
```swift
// In sign-in success handler
Task {
    await NotificationService.shared.registerForPushNotifications()
}
```

#### 2.4 Update User Model
**Location**: Firestore `users` collection schema

**Add Field**:
- `fcmTokens: [String]` - Array of FCM tokens (supports multi-device)

**Migration**: Update `UserService.swift` to include `fcmTokens` field when creating/updating users

### Phase 3: Backend Notification Sending (4-5 hours)

#### 3.1 Create Cloud Function for Message Notifications
**Location**: Create Firebase Cloud Functions project (separate Node.js/TypeScript project)

**Function**: `onMessageCreated`

**Trigger**: Firestore trigger on `messages/{messageId}` onCreate

**Logic**:
1. Read message document to get `conversationId`, `senderId`, `text`, `participantIds`
2. Query `users` collection to get FCM tokens for all participants (except sender)
3. Fetch sender's display name and photo URL for notification
4. For group chats: fetch conversation name
5. Build FCM payload with:
   - **Notification**: Title, body, badge, sound
   - **Data**: `conversationId`, `messageId`, `senderId` (for deep linking)
6. Send via FCM Admin SDK to recipient tokens
7. Handle token errors (invalid/expired tokens) and remove from Firestore

**Code Pattern** (TypeScript):
```typescript
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

export const onMessageCreated = functions.firestore
  .document("messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const messageId = context.params.messageId;

    // Get recipient tokens (exclude sender)
    const recipientIds = message.participantIds.filter(id => id !== message.senderId);
    const tokens = await getTokensForUsers(recipientIds);

    // Get sender info
    const sender = await admin.firestore().collection("users").doc(message.senderId).get();
    const senderName = sender.data()?.displayName || "Someone";

    // Build notification payload
    const payload = {
      notification: {
        title: senderName,
        body: message.text || "Sent an image",
        sound: "default",
        badge: "1"
      },
      data: {
        conversationId: message.conversationId,
        messageId: messageId,
        senderId: message.senderId
      }
    };

    // Send to all recipient tokens
    if (tokens.length > 0) {
      await admin.messaging().sendMulticast({
        tokens: tokens,
        ...payload
      });
    }
  });
```

#### 3.2 Deploy Cloud Functions
**Location**: Firebase Cloud Functions

**Steps**:
1. Initialize Cloud Functions in project: `firebase init functions`
2. Install dependencies: `npm install firebase-admin firebase-functions`
3. Write function (see above pattern)
4. Deploy: `firebase deploy --only functions`
5. Monitor logs: `firebase functions:log`

**Environment**:
- Runtime: Node.js 18 or 20
- Region: Choose closest to users (e.g., `us-central1`)

#### 3.3 Optimize for Group Chats
**Location**: Same Cloud Function

**Optimization**: For group chats with many participants, batch token sends in groups of 500 (FCM limit)

**Pattern**:
```typescript
// Split tokens into batches of 500
const tokenBatches = chunkArray(tokens, 500);

for (const batch of tokenBatches) {
  await admin.messaging().sendMulticast({
    tokens: batch,
    ...payload
  });
}
```

### Phase 4: Deep Linking & Navigation (2-3 hours)

#### 4.1 Create NavigationCoordinator
**Location**: Create `CreatorLink/Services/NavigationCoordinator.swift`

**Purpose**: Handle deep linking from notification taps to specific conversations

**Pattern** (SwiftUI):
Use `@AppStorage` or environment object to track navigation state:

```swift
@Observable
class NavigationCoordinator {
    static let shared = NavigationCoordinator()

    var deepLinkConversationId: String?

    func handleNotificationTap(conversationId: String) {
        self.deepLinkConversationId = conversationId
    }
}
```

#### 4.2 Update ContentRootView
**Location**: `CreatorLink/CreatorLinkApp.swift` (ContentRootView)

**Modification**: Listen for deep link changes and navigate to chat

**Pattern**:
```swift
@State private var navigationCoordinator = NavigationCoordinator.shared

var body: some View {
    // ... existing TabView
    .onChange(of: navigationCoordinator.deepLinkConversationId) { oldValue, newValue in
        if let conversationId = newValue {
            // Navigate to ChatDetailView with conversationId
            // Implementation depends on navigation pattern (NavigationStack, etc.)
        }
    }
}
```

#### 4.3 Wire Notification Tap to Coordinator
**Location**: `CreatorLinkApp.swift` AppDelegate extension

**Modification**:
```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse) async {
    let userInfo = response.notification.request.content.userInfo

    if let conversationId = userInfo["conversationId"] as? String {
        NavigationCoordinator.shared.handleNotificationTap(conversationId: conversationId)
    }
}
```

### Phase 5: Badge Management (1-2 hours)

#### 5.1 Track Unread Count
**Location**: `CreatorLink/Services/ConversationService.swift`

**Add Method**:
```swift
func getUnreadMessageCount(userId: String) async -> Int {
    // Query messages where user is participant and message is unread
    let snapshot = try? await db.collection("messages")
        .whereField("participantIds", arrayContains: userId)
        .whereField("readBy.\(userId)", isEqualTo: NSNull())
        .getDocuments()

    return snapshot?.documents.count ?? 0
}
```

#### 5.2 Update Badge on App Launch/Message Received
**Location**: `CreatorLinkApp.swift`

**Pattern**:
```swift
func updateBadgeCount() async {
    guard let userId = AuthService.shared.currentUser?.uid else { return }

    let unreadCount = await ConversationService.shared.getUnreadMessageCount(userId: userId)

    await MainActor.run {
        UNUserNotificationCenter.current().setBadgeCount(unreadCount)
    }
}
```

**Call Locations**:
- App launch (in `onAppear` of ContentRootView)
- After marking messages as read (in ChatDetailView)
- In foreground notification handler (to update badge immediately)

### Phase 6: Testing & Validation (2-3 hours)

#### 6.1 Test Scenarios

**Foreground Notifications**:
1. Open app to ChatsView
2. Send message from another simulator/device
3. Verify banner appears at top with sender name and message preview
4. Tap banner → should navigate to conversation

**Background Notifications**:
1. Send app to background (home button)
2. Send message from another device
3. Verify notification banner appears on lock screen/notification center
4. Tap notification → app launches and opens conversation

**Terminated App Notifications**:
1. Force quit app (swipe up from app switcher)
2. Send message from another device
3. Verify notification appears
4. Tap notification → app launches from scratch and opens conversation

**Group Chat Notifications**:
1. Create group with 3+ users
2. User A sends message
3. Verify Users B and C both receive notifications
4. Verify notification shows group name (if set) or participant names

**Badge Counts**:
1. Receive 5 messages while app is closed
2. Verify badge shows "5" on app icon
3. Open app and mark messages as read
4. Verify badge updates to "0"

**Token Refresh**:
1. Sign out and sign in with different user
2. Verify new FCM token is uploaded
3. Send message → verify notification received

#### 6.2 Debugging Tools

**Xcode Console Logs**:
- Log FCM token on app launch: `print("FCM Token: \(token)")`
- Log notification payloads in delegate methods
- Log navigation events for deep linking

**Firebase Console**:
- Cloud Messaging → Send test notification to specific token
- Test notification payload structure before deploying functions
- Monitor Cloud Functions logs for errors

**Notification Composer** (Firebase Console):
- Send manual push notifications to test devices
- Useful for testing without triggering Cloud Function

#### 6.3 Common Issues & Solutions

**Issue**: Notifications not appearing
- Check APNs certificate/key is uploaded to Firebase Console
- Verify `application.registerForRemoteNotifications()` is called
- Ensure FCM token is successfully uploaded to Firestore
- Check Cloud Function logs for send errors

**Issue**: App crashes on notification tap
- Verify deep link conversation ID exists in Firestore
- Add nil checks in navigation logic
- Test with invalid/deleted conversation IDs

**Issue**: Notifications appear but badge doesn't update
- Ensure `UNUserNotificationCenter.setBadgeCount()` is called
- Check that unread count query is correct
- Verify badge permissions are granted

**Issue**: Duplicate notifications
- Check if multiple FCM tokens exist for same user
- Ensure old tokens are removed on sign-out
- Verify Cloud Function isn't being triggered multiple times

## Locations Summary

### Files to Create
1. `CreatorLink/Services/NotificationService.swift` - FCM token management
2. `CreatorLink/Services/NavigationCoordinator.swift` - Deep linking coordinator
3. Firebase Cloud Functions project (separate repository or `/functions` folder)
   - `functions/src/index.ts` - Message notification trigger

### Files to Modify
1. `CreatorLink/CreatorLinkApp.swift` - Add delegates, register for notifications
2. `CreatorLink/Services/AuthService.swift` - Register for push on sign-in
3. `CreatorLink/Info.plist` - Add background modes and Firebase config
4. `CreatorLink/Models/User.swift` (if exists) - Add `fcmTokens` field
5. `CreatorLink/Services/UserService.swift` - Update user creation/update logic
6. Xcode project settings - Add FirebaseMessaging SPM package

### Firestore Schema Changes
- `users/{userId}`:
  - Add field: `fcmTokens: [String]`

## Best Practices

### Token Management
- Store tokens as array to support multiple devices per user
- Remove invalid tokens when FCM returns error codes (404, 410)
- Refresh tokens on app launch and whenever FCM calls delegate
- Clear tokens on sign-out for privacy

### Notification Payloads
- Keep notification body under 2KB for reliability
- Always include `data` field for deep linking
- Use `content-available: true` for silent background updates
- Set `priority: high` for time-sensitive messages

### Performance
- Batch FCM sends for group chats (max 500 tokens per call)
- Use Firestore indexing on `participantIds` for fast token queries
- Cache sender names/photos to reduce Firestore reads in Cloud Function

### Privacy & Security
- Only send notifications to authorized participants
- Don't include sensitive message content in notification title/body for group chats
- Validate conversation access before deep linking
- Use Firestore Security Rules to protect `fcmTokens` field (user can only write their own)

### User Experience
- Request notification permissions contextually (after first message sent/received)
- Show explanation dialog before system permission prompt
- Allow users to disable notifications per-conversation (future enhancement)
- Respect system notification settings (DND, Focus modes)

## Timeline Estimate

- **Phase 1** (FCM Setup): 2-3 hours
- **Phase 2** (Client Token Management): 3-4 hours
- **Phase 3** (Cloud Functions): 4-5 hours
- **Phase 4** (Deep Linking): 2-3 hours
- **Phase 5** (Badge Management): 1-2 hours
- **Phase 6** (Testing): 2-3 hours

**Total**: 14-20 hours

**Recommended Schedule**: Implement over 2-3 days, with Phase 6 testing spread throughout.

## Success Criteria

Push notifications are complete when:

- ✅ Users receive notifications for new messages in all app states (foreground, background, terminated)
- ✅ Tapping notification opens the app to the correct conversation
- ✅ Badge count accurately reflects unread messages
- ✅ Group chat notifications include sender name and work for all participants
- ✅ Notifications work reliably across app restarts and user sign-out/sign-in
- ✅ No duplicate notifications or missing notifications in test scenarios
- ✅ FCM tokens are properly managed (refreshed, uploaded, cleaned up)
- ✅ Cloud Function handles errors gracefully (invalid tokens, missing data)

## Notes for Engineers

- **iOS 18 Compatibility**: All patterns above work with iOS 18. UNUserNotificationCenter API is stable.
- **SwiftUI Gotchas**: Since the app uses `@UIApplicationDelegateAdaptor`, ensure delegates are set in `didFinishLaunchingWithOptions`, not in SwiftUI lifecycle methods.
- **Testing Without Physical Device**: Simulators do NOT support push notifications. You MUST test on a real iOS device or use Firebase Console's notification composer to validate token generation.
- **APNs Requirements**: You need an Apple Developer account to create APNs keys. Sandbox (development) and production environments use different APNs endpoints.
- **Cloud Functions Local Testing**: Use Firebase Emulator Suite to test Cloud Functions locally before deploying (`firebase emulators:start`).
