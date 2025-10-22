# Local Notifications Implementation Tasks

## Context

This document provides step-by-step implementation tasks for adding local notifications to CreatorLink, a Swift/SwiftUI iOS messaging app. The approach uses **local notifications triggered by Firestore listeners** rather than remote push notifications (APNs), making it perfect for local testing and MVP demos without requiring paid Apple Developer accounts or server-side infrastructure.

**What this provides:**
- Notification banners when app is in foreground
- Notification banners when app is backgrounded (works for ~30 seconds)
- Deep linking to conversations when tapping notifications
- Badge count management for unread messages
- Works reliably in simulator and on device for testing

**Known limitations:**
- Does not work after app is force-quit or terminated
- Background notifications stop working after ~30 seconds when iOS suspends the app
- Not suitable for production use (would need remote push notifications)

This implementation is broken into 5 phases that build on each other. Each phase can be tested independently before moving to the next.

---

## Instructions for AI Agent

When implementing these tasks:
1. **Work sequentially** - Complete Phase 1 before Phase 2, etc.
2. **Test after each PR** - Follow the "What to Test" instructions to verify functionality
3. **Use existing patterns** - Reference similar service files (AuthService, PresenceService) for code style
4. **Preserve existing functionality** - Don't break current message delivery or status updates
5. **Follow Swift/SwiftUI conventions** - Use @Observable for services, async/await for asynchronous operations

**File path conventions:**
- Services: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/`
- Views: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/`
- Models: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/`

---

## Phase 1: Request Notification Permissions

**Estimated Time:** 30 minutes

This phase sets up the foundation for notifications by requesting user permission and configuring the notification center delegate.

### PR 1.1: Create NotificationManager Service

**Goal:** Create a centralized service for managing notification permissions and local notification creation.

**Tasks:**
- [x] Create new file `NotificationManager.swift` in Services directory
- [x] Import `UserNotifications` framework
- [x] Create `@Observable class NotificationManager` with shared singleton
- [x] Implement `requestPermission() async -> Bool` method
  - Request authorization with options: `.alert`, `.sound`, `.badge`
  - Return granted status
  - Print permission result for debugging
- [x] Implement `checkPermissionStatus() async -> UNAuthorizationStatus` method
  - Fetch current notification settings
  - Return authorization status

**What to Test:**
1. Build the app to verify no compilation errors
2. Add a temporary button that calls `await NotificationManager.shared.requestPermission()`
3. Run app and tap button
4. Verify iOS permission dialog appears asking for notification access
5. Check Xcode console logs to confirm permission status is printed

**Files Changed:**
- `CreatorLink/Services/NotificationManager.swift` - NEW: Core notification management service

**Notes:**
- Use singleton pattern (`static let shared`) consistent with other services (AuthService, PresenceService)
- Permission only needs to be requested once - iOS remembers the user's choice
- Follow existing service patterns for structure and style

---

### PR 1.2: Configure Notification Delegate

**Goal:** Set up the AppDelegate to handle foreground notifications and notification taps.

**Tasks:**
- [x] Open `CreatorLinkApp.swift` and locate the `AppDelegate` class
- [x] In `application(_:didFinishLaunchingWithOptions:)`, add notification delegate setup
  - After `FirebaseApp.configure()`, add: `UNUserNotificationCenter.current().delegate = self`
- [x] Create extension `extension AppDelegate: UNUserNotificationCenterDelegate`
- [x] Implement `userNotificationCenter(_:willPresent:)` delegate method
  - Return `[.banner, .sound, .badge]` to show notifications even when app is open
  - This enables foreground notifications
- [x] Implement `userNotificationCenter(_:didReceive:)` delegate method
  - Extract `conversationId` from `userInfo` dictionary
  - Print conversationId for debugging (deep linking will be implemented in Phase 3)
  - Add TODO comment: "Navigate to conversation - implement in Phase 3"

**What to Test:**
1. Build the app to verify no compilation errors
2. Verify app launches successfully
3. Check that `UNUserNotificationCenter.current().delegate` is set during app launch
4. No visual changes yet - this is infrastructure setup

**Files Changed:**
- `CreatorLink/CreatorLinkApp.swift` - Add UNUserNotificationCenterDelegate conformance and delegate methods to AppDelegate class

**Notes:**
- The delegate MUST be set in `didFinishLaunchingWithOptions` before any notifications are received
- Returning `[.banner, .sound, .badge]` ensures notifications appear even when app is in foreground
- The tap handler will be fully implemented in Phase 3 - for now just print the conversationId

---

### PR 1.3: Request Permission After Sign-In

**Goal:** Automatically request notification permission after user successfully signs in.

**Tasks:**
- [x] Open `CreatorLink/Services/AuthService.swift`
- [x] Locate the `signInWithGoogle()` method (around line 52-100)
- [x] After successful Firebase sign-in (after `Auth.auth().signIn(with: credential)`), add permission request
  - Create a `Task { }` block
  - Call `await NotificationManager.shared.requestPermission()`
  - Don't await the task - let it run in background
- [ ] Alternative implementation: Add permission request in `ContentRootView.onAppear()`
  - After `setupGlobalMessageDeliveryListener` call
  - Check if permission already granted before requesting
  - Only request once per app install

**What to Test:**
1. Sign out if currently signed in
2. Sign in with Google account
3. Immediately after sign-in, verify iOS shows notification permission dialog
4. Grant permission
5. On subsequent sign-ins, dialog should NOT appear again (iOS remembers)
6. Check app settings (iOS Settings > CreatorLink > Notifications) to verify permission is granted

**Files Changed:**
- `CreatorLink/Services/AuthService.swift` - Add notification permission request after successful sign-in
- OR `CreatorLink/CreatorLinkApp.swift` - Add permission request in ContentRootView.onAppear (alternative approach)

**Notes:**
- Best UX: Request permission after sign-in when user understands app context
- Don't block sign-in flow - permission request runs asynchronously
- iOS automatically prevents duplicate permission dialogs
- User can always change permission in iOS Settings

---

## Phase 2: Trigger Local Notifications from Firestore Listener

**Estimated Time:** 1-2 hours

This phase integrates notification triggers into the existing message delivery listener, so users receive notification banners when messages arrive.

### PR 2.1: Add Notification Creation Method

**Goal:** Add method to NotificationManager that creates and schedules local notifications for incoming messages.

**Tasks:**
- [ ] Open `CreatorLink/Services/NotificationManager.swift`
- [ ] Add new method `showMessageNotification(conversationId:senderName:messageText:isGroupChat:)`
- [ ] Create `UNMutableNotificationContent` object
  - Set `content.title` to sender name
  - Set `content.body` to message text
  - Set `content.sound` to `.default`
- [ ] Implement badge increment logic
  - Get current badge: `UIApplication.shared.applicationIconBadgeNumber`
  - Set `content.badge` to current badge + 1 (wrapped in NSNumber)
- [ ] Add custom data for deep linking
  - Set `content.userInfo` dictionary with `conversationId` and `isGroupChat`
- [ ] Create notification trigger
  - Use `UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)` for immediate delivery
- [ ] Create notification request
  - Use `UUID().uuidString` as unique identifier
  - Combine content and trigger
- [ ] Schedule notification
  - Call `UNUserNotificationCenter.current().add(request)`
  - Handle errors in completion handler

**What to Test:**
1. Build to verify no compilation errors
2. Add temporary test button that calls: `NotificationManager.shared.showMessageNotification(conversationId: "test123", senderName: "Test User", messageText: "Hello!", isGroupChat: false)`
3. Tap button while app is in foreground
4. Verify notification banner appears at top of screen
5. Tap notification and check console for conversationId
6. Check app icon badge shows "1"

**Files Changed:**
- `CreatorLink/Services/NotificationManager.swift` - Add showMessageNotification method

**Notes:**
- timeInterval of 0.1 seconds ensures nearly immediate delivery
- userInfo dictionary enables deep linking in Phase 3
- Each notification needs unique identifier to prevent duplicate issues
- Badge management will be refined in Phase 4

---

### PR 2.2: Integrate Notification Trigger into Message Listener

**Goal:** Modify the existing global message delivery listener to trigger local notifications when new messages arrive from other users.

**Tasks:**
- [ ] Open `CreatorLink/CreatorLinkApp.swift`
- [ ] Locate `setupGlobalMessageDeliveryListener(userId:)` method in ContentRootView
- [ ] Modify the snapshot listener to only trigger notifications for `.added` messages
  - Change `guard change.type == .added || change.type == .modified` to only `.added`
  - This prevents notifications for message status updates
- [ ] After `updateMessageStatus` call in the Task block, add notification trigger
  - Call new helper method: `await self.triggerNotificationForMessage(message, userId: userId)`
- [ ] Create new private method `triggerNotificationForMessage(_ message: Message, userId: String) async`
  - Fetch sender info using `UserService.shared.fetchUser(userId: message.senderId)`
  - Extract sender's display name (fallback to "Someone" if nil)
  - Fetch conversation using `ConversationService.shared.fetchConversation(conversationId: message.conversationId)`
  - Determine if group chat from conversation
  - Call `NotificationManager.shared.showMessageNotification` with all parameters
  - Wrap in do-catch and print errors
- [ ] Add TODO comment for Phase 5: "Check if user is actively viewing this conversation"

**What to Test:**
1. Open app on Device A or Simulator 1
2. Sign in as User A
3. Open app on Device B or Simulator 2
4. Sign in as User B
5. From Device B, send message to User A
6. On Device A (foreground), verify:
   - Notification banner appears with sender name and message
   - Tapping banner prints conversationId to console
   - App badge increments
7. Repeat test with Device A backgrounded (home button):
   - Send message from Device B within 30 seconds
   - Notification banner should appear on lock screen
   - Tapping notification opens app

**Files Changed:**
- `CreatorLink/CreatorLinkApp.swift` - Modify setupGlobalMessageDeliveryListener and add triggerNotificationForMessage method

**Notes:**
- Only trigger for `.added` messages to avoid duplicate notifications
- Fetch user/conversation info asynchronously - don't block listener
- Error handling is critical - don't crash if fetch fails
- Don't notify for own messages (already filtered by `senderId != userId`)
- Phase 5 will add logic to suppress notifications when conversation is already open

---

## Phase 3: Deep Linking (Navigate to Conversation on Tap)

**Estimated Time:** 1 hour

This phase implements navigation to the specific conversation when a user taps a notification.

### PR 3.1: Create NavigationCoordinator

**Goal:** Create a shared coordinator to manage deep link navigation from notifications.

**Tasks:**
- [ ] Create new file `NavigationCoordinator.swift` in Services directory
- [ ] Import Foundation
- [ ] Create `@Observable class NavigationCoordinator` with shared singleton
- [ ] Add property `var deepLinkConversationId: String?` for tracking deep link target
- [ ] Implement `handleNotificationTap(conversationId:)` method
  - Set `deepLinkConversationId` to provided conversationId
  - Print debug message with conversationId
- [ ] Implement `clearDeepLink()` method
  - Set `deepLinkConversationId` back to nil
  - Called after navigation completes

**What to Test:**
1. Build to verify no compilation errors
2. Add temporary test code that calls `NavigationCoordinator.shared.handleNotificationTap(conversationId: "test123")`
3. Verify conversationId is stored and printed
4. Call `clearDeepLink()` and verify property is cleared

**Files Changed:**
- `CreatorLink/Services/NavigationCoordinator.swift` - NEW: Deep link navigation coordinator

**Notes:**
- Use @Observable to enable SwiftUI views to react to property changes
- Simple state machine: set conversationId on tap, clear after navigation
- Singleton ensures single source of truth for navigation state

---

### PR 3.2: Wire Up Notification Tap Handler

**Goal:** Connect notification taps to the NavigationCoordinator so deep links are triggered.

**Tasks:**
- [ ] Open `CreatorLink/CreatorLinkApp.swift`
- [ ] Locate `userNotificationCenter(_:didReceive:)` delegate method in AppDelegate extension
- [ ] Replace TODO comment with actual implementation
  - Extract conversationId from `userInfo["conversationId"]`
  - Use `await MainActor.run { }` to ensure UI updates on main thread
  - Call `NavigationCoordinator.shared.handleNotificationTap(conversationId: conversationId)`
- [ ] Add error handling for missing conversationId

**What to Test:**
1. Send a message while app is backgrounded
2. Tap the notification
3. Check console logs to verify conversationId is printed
4. Verify NavigationCoordinator.shared.deepLinkConversationId is set
5. No visual navigation yet - that's in next PR

**Files Changed:**
- `CreatorLink/CreatorLinkApp.swift` - Implement notification tap handling in AppDelegate extension

**Notes:**
- Must use MainActor.run since notification callbacks happen on background thread
- Graceful degradation if conversationId is missing from userInfo
- Next PR connects this to actual navigation

---

### PR 3.3: Implement Deep Link Navigation in ChatsView

**Goal:** Listen for deep link changes and navigate to the target conversation.

**Tasks:**
- [ ] Open `CreatorLink/Views/Chats/ChatsView.swift`
- [ ] Add state property: `@State private var navigationCoordinator = NavigationCoordinator.shared`
- [ ] Add `.onChange(of: navigationCoordinator.deepLinkConversationId)` modifier to NavigationStack
  - Check if `newValue` is not nil
  - Find conversation in `viewModel.conversations` that matches conversationId
  - Set `selectedConversation` to found conversation
  - Call `navigationCoordinator.clearDeepLink()` after setting navigation
- [ ] Handle case where conversation isn't in current list
  - Fetch conversation using `ConversationService.shared.fetchConversation(conversationId:)`
  - Add to selected conversation if found
  - Show error if conversation doesn't exist or user doesn't have access

**What to Test:**
1. Open app and view ChatsView
2. Background the app (home button)
3. Send message from another device/account
4. Tap notification on lock screen
5. Verify:
   - App opens to ChatsView
   - ChatDetailView automatically opens for the conversation
   - Can see the new message
   - Badge count updates appropriately
6. Test with multiple conversations to ensure correct one opens
7. Test tapping notification for conversation not in current list

**Files Changed:**
- `CreatorLink/Views/Chats/ChatsView.swift` - Add deep link navigation logic

**Notes:**
- NavigationStack with navigationDestination(item:) makes this straightforward
- Setting selectedConversation triggers navigation automatically
- Clear deep link immediately after handling to prevent re-navigation
- May need to refresh conversation list if target conversation is new

---

## Phase 4: Badge Management

**Estimated Time:** 30 minutes

This phase adds proper badge count management to track unread messages.

### PR 4.1: Add Badge Management Methods

**Goal:** Add methods to NotificationManager for updating and clearing badge counts.

**Tasks:**
- [ ] Open `CreatorLink/Services/NotificationManager.swift`
- [ ] Add method `updateBadgeCount(_ count: Int)`
  - Call `UNUserNotificationCenter.current().setBadgeCount(count)`
  - Handle errors in completion handler
  - Print success/failure for debugging
- [ ] Add method `clearBadge()`
  - Call `updateBadgeCount(0)`
  - Convenience method for resetting badge

**What to Test:**
1. Add test button that calls `NotificationManager.shared.updateBadgeCount(5)`
2. Tap button and verify app icon shows badge "5"
3. Call `NotificationManager.shared.clearBadge()`
4. Verify badge is removed from app icon
5. Test with various values (0, 1, 10, 100)

**Files Changed:**
- `CreatorLink/Services/NotificationManager.swift` - Add badge management methods

**Notes:**
- iOS 16+ uses setBadgeCount instead of deprecated applicationIconBadgeNumber setter
- Badge count is app-wide, not per-conversation
- Zero clears the badge completely

---

### PR 4.2: Clear Badge on App Launch and Activation

**Goal:** Automatically clear badge when user opens the app or brings it to foreground.

**Tasks:**
- [ ] Open `CreatorLink/CreatorLinkApp.swift`
- [ ] Locate `ContentRootView.onAppear` block
- [ ] After `setupGlobalMessageDeliveryListener` call, add badge clear
  - Call `NotificationManager.shared.clearBadge()`
- [ ] Locate `handleScenePhaseChange` method
- [ ] In the `.active` case, add badge clear
  - After `setOnline` call, add `NotificationManager.shared.clearBadge()`
  - This handles returning from background

**What to Test:**
1. Receive multiple messages while app is backgrounded
2. Verify badge count increases (should show number of messages)
3. Tap app icon to launch app (don't tap notification)
4. Verify badge clears when app becomes active
5. Background app again and receive more messages
6. Tap notification to open
7. Verify badge clears

**Files Changed:**
- `CreatorLink/CreatorLinkApp.swift` - Add badge clearing in onAppear and handleScenePhaseChange

**Notes:**
- Clear badge both on initial app launch (onAppear) and when returning from background (.active)
- This provides good UX - badge indicates "you have new messages", cleared when user sees app
- More granular badge management (per conversation) will be in next PR

---

### PR 4.3: Update Badge When Reading Messages

**Goal:** Decrement badge count when user reads messages in a conversation.

**Tasks:**
- [ ] Open `CreatorLink/Views/Chats/ChatDetailView.swift`
- [ ] Locate the view's `onAppear` or message marking logic
- [ ] When messages are marked as read (status changes to `.read`):
  - Count how many messages were just marked read
  - Get current badge: `UIApplication.shared.applicationIconBadgeNumber`
  - Calculate new badge: `max(0, currentBadge - unreadCount)`
  - Call `NotificationManager.shared.updateBadgeCount(newBadge)`
- [ ] Alternative: Implement in MessageService when updateMessageStatus is called with `.read`

**What to Test:**
1. Receive 5 messages in Conversation A while app backgrounded
2. Verify badge shows "5"
3. Open app to ChatsView - badge clears (from Phase 4.2)
4. Receive 3 more messages in Conversation B while on ChatsView
5. Badge should show "3" (from foreground notification)
6. Open Conversation B
7. Verify messages marked as read
8. Badge should clear or decrement
9. Test with multiple conversations and mixed read/unread states

**Files Changed:**
- `CreatorLink/Views/Chats/ChatDetailView.swift` - Add badge decrement when marking messages as read
- OR `CreatorLink/Services/MessageService.swift` - Alternative: centralize badge logic in service

**Notes:**
- Use `max(0, ...)` to prevent negative badge counts
- May need to track unread count per conversation for accurate decrements
- Current implementation (PR 4.2) clears entire badge on app open - this is acceptable for MVP
- More granular tracking would require unread message counting infrastructure

---

## Phase 5: Optimize for App States

**Estimated Time:** 1 hour

This phase adds smart behavior to suppress notifications when they're not needed.

### PR 5.1: Track Active Conversation

**Goal:** Create a mechanism to track which conversation is currently being viewed.

**Tasks:**
- [ ] Open `CreatorLink/Services/NavigationCoordinator.swift`
- [ ] Add property `var activeConversationId: String?`
- [ ] Add method `setActiveConversation(_ conversationId: String?)`
  - Set activeConversationId to provided value
  - Print debug message for tracking
- [ ] Open `CreatorLink/Views/Chats/ChatDetailView.swift`
- [ ] Add `onAppear` modifier to view body
  - Call `NavigationCoordinator.shared.setActiveConversation(conversation.id)`
- [ ] Add `onDisappear` modifier to view body
  - Call `NavigationCoordinator.shared.setActiveConversation(nil)`

**What to Test:**
1. Open a conversation in ChatDetailView
2. Check console logs to verify activeConversationId is set
3. Navigate back to ChatsView
4. Verify activeConversationId is cleared (nil)
5. Open different conversation
6. Verify activeConversationId updates correctly

**Files Changed:**
- `CreatorLink/Services/NavigationCoordinator.swift` - Add active conversation tracking
- `CreatorLink/Views/Chats/ChatDetailView.swift` - Report active conversation on appear/disappear

**Notes:**
- Simple state tracking - no complex logic needed
- onAppear/onDisappear provide reliable lifecycle hooks
- This enables smart notification suppression in next PR

---

### PR 5.2: Don't Notify When Conversation Is Open

**Goal:** Suppress notifications for messages in the conversation the user is actively viewing.

**Tasks:**
- [ ] Open `CreatorLink/CreatorLinkApp.swift`
- [ ] Locate `triggerNotificationForMessage` method
- [ ] At the beginning of the method, add conversation check:
  - Check if `NavigationCoordinator.shared.activeConversationId == message.conversationId`
  - If true, return early without creating notification
  - Add print statement for debugging: "Suppressing notification - user is viewing this conversation"
- [ ] Keep the message delivery status update (shouldn't be affected)

**What to Test:**
1. Open ChatDetailView for Conversation A
2. From another device, send message to Conversation A
3. Verify:
   - Message appears in chat immediately (Firestore listener works)
   - NO notification banner appears (suppressed)
   - Badge does not increment
4. Navigate back to ChatsView (close ChatDetailView)
5. Send another message from other device
6. Verify:
   - Notification banner DOES appear (conversation not active)
   - Badge increments
7. Test with multiple conversations to ensure filtering works correctly

**Files Changed:**
- `CreatorLink/CreatorLinkApp.swift` - Add active conversation check in triggerNotificationForMessage

**Notes:**
- Check conversation BEFORE fetching user/conversation data to save resources
- This significantly improves UX - no annoying notifications while chatting
- Message still gets delivered and marked as read - only notification is suppressed

---

### PR 5.3: Handle App State Transitions

**Goal:** Ensure notification behavior is correct across all app state transitions.

**Tasks:**
- [ ] Open `CreatorLink/CreatorLinkApp.swift`
- [ ] Review `handleScenePhaseChange` method
- [ ] Verify existing badge clear in `.active` case (added in Phase 4.2)
- [ ] Consider clearing active conversation when app backgrounds
  - In `.background` case, add: `NavigationCoordinator.shared.setActiveConversation(nil)`
  - Ensures notifications work if user backgrounds mid-conversation
- [ ] Add comments documenting notification behavior in each scene phase:
  - `.active`: Clear badge, resume notification suppression for active conversation
  - `.inactive`: No action needed (temporary state)
  - `.background`: Clear active conversation, notifications will show for new messages

**What to Test:**
1. Open conversation and verify notifications suppressed
2. Press home button to background app
3. Send message from another device within 30 seconds
4. Verify notification appears (active conversation cleared)
5. Tap notification to open app
6. Verify conversation opens correctly
7. Background app again and retest
8. Force quit app and verify no notifications (expected limitation)

**Files Changed:**
- `CreatorLink/CreatorLinkApp.swift` - Enhance scene phase handling for notifications

**Notes:**
- iOS lifecycle management is complex - document behavior clearly
- Clearing activeConversation on background ensures consistent notification behavior
- 30-second background window is iOS limitation, not a bug
- After force quit, Firestore listeners stop completely (expected)

---

## Testing Matrix

### Comprehensive Test Scenarios

After completing all phases, run through these test scenarios to verify complete functionality:

#### Scenario 1: Foreground Notifications
1. Sign in to app on two devices (Device A and Device B)
2. On Device A, navigate to ChatsView (don't open any conversation)
3. On Device B, send message to Device A
4. **Expected:**
   - Notification banner appears at top of Device A screen
   - Banner shows sender name and message preview
   - Notification sound plays
   - Badge increments by 1
5. Tap notification banner
6. **Expected:**
   - ChatDetailView opens to correct conversation
   - New message is visible
   - Badge count updates

#### Scenario 2: Background Notifications
1. Open app on Device A
2. Press home button to background the app (do NOT force quit)
3. Within 30 seconds, send message from Device B
4. **Expected:**
   - Notification appears on lock screen / notification center
   - Shows sender name and message
   - Badge increments
5. Tap notification
6. **Expected:**
   - App opens
   - Navigates directly to conversation
   - Message is visible

#### Scenario 3: Notification Suppression (Active Conversation)
1. Open ChatDetailView for Conversation A on Device A
2. Send message from Device B to Conversation A
3. **Expected:**
   - Message appears in chat immediately
   - NO notification banner appears (suppressed)
   - No notification sound
   - Badge does NOT increment
4. Navigate back to ChatsView
5. Send another message from Device B
6. **Expected:**
   - Notification banner appears (no longer suppressed)
   - Badge increments

#### Scenario 4: Badge Management
1. Completely close app on Device A
2. Send 5 messages from Device B
3. Open app on Device A (tap app icon, not notification)
4. **Expected:**
   - App icon shows badge "5"
   - Badge clears when app opens
5. From ChatsView, receive 3 more messages
6. **Expected:**
   - Badge shows "3"
7. Open conversation
8. **Expected:**
   - Messages marked as read
   - Badge clears or decrements

#### Scenario 5: Group Chat Notifications
1. Create group conversation with 3+ users (User A, User B, User C)
2. User B sends message
3. **Expected:**
   - User A and User C both receive notifications
   - Notification shows "User B" as sender (not just group name)
   - Message preview is accurate
4. User A opens conversation and sends reply
5. **Expected:**
   - User A does NOT see notification for own message
   - User B and User C receive notification showing "User A" sent message

#### Scenario 6: Multiple Conversations
1. Have 3 active conversations (A, B, C) on Device A
2. Background the app
3. Receive message in Conversation A
4. Receive message in Conversation B
5. Receive message in Conversation C
6. **Expected:**
   - 3 separate notifications appear
   - Each shows correct sender and message
   - Badge shows "3"
7. Tap notification for Conversation B
8. **Expected:**
   - App opens to Conversation B specifically
   - Messages in A and C remain unread

#### Scenario 7: Known Limitations
1. Force quit app on Device A (swipe up in app switcher)
2. Send message from Device B
3. **Expected:**
   - NO notification appears (app not running - expected limitation)
4. Open app manually
5. **Expected:**
   - Message appears in conversation (Firestore sync works)
   - No retroactive notification
6. Background app for 60+ seconds
7. Send message from Device B after 60 seconds
8. **Expected:**
   - NO notification (iOS suspended app - expected limitation)
9. Bring app to foreground
10. **Expected:**
    - Message appears (Firestore resumes listening)

#### Scenario 8: Permission Denied
1. Fresh app install
2. Sign in for first time
3. When permission dialog appears, tap "Don't Allow"
4. Send message from another device
5. **Expected:**
   - No notifications appear (permission denied)
   - Messages still appear in app when opened
6. Go to iOS Settings > CreatorLink > Notifications
7. Enable notifications
8. Send message again
9. **Expected:**
   - Notifications now appear

---

## Files Summary

### New Files Created

| File Path | Purpose | Phase |
|-----------|---------|-------|
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/NotificationManager.swift` | Core notification service - handles permission requests, creates local notifications, manages badge counts | 1, 2, 4 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/NavigationCoordinator.swift` | Navigation coordinator - manages deep linking from notifications and tracks active conversation | 3, 5 |

### Files Modified

| File Path | Changes | Phase |
|-----------|---------|-------|
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/CreatorLinkApp.swift` | - Add UNUserNotificationCenterDelegate to AppDelegate<br>- Implement foreground notification presentation<br>- Implement notification tap handling<br>- Add triggerNotificationForMessage method<br>- Update setupGlobalMessageDeliveryListener to trigger notifications<br>- Clear badge on app activation<br>- Clear active conversation on background | 1, 2, 3, 4, 5 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/AuthService.swift` | Add notification permission request after successful Google sign-in | 1 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatsView.swift` | Add deep link navigation logic to handle notification taps and navigate to correct conversation | 3 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` | - Track active conversation (onAppear/onDisappear)<br>- Update badge when messages are marked as read | 4, 5 |

### No Changes Required

- Firebase Console configuration (no FCM setup needed)
- Info.plist (no remote notification background mode needed)
- Xcode project settings (no new packages/capabilities needed)
- Cloud Functions (no backend code needed)
- Any model files (Message, Conversation, UserProfile unchanged)

---

## Success Criteria

Local notifications implementation is complete when all of the following are verified:

- [ ] Users receive notification banners when app is in foreground
- [ ] Users receive notification banners when app is backgrounded (within ~30 seconds)
- [ ] Notification shows sender name and message preview
- [ ] Notification sound plays
- [ ] Tapping notification opens app and navigates to correct conversation
- [ ] Badge count shows number of unread messages
- [ ] Badge clears when app becomes active
- [ ] Group chat notifications show individual sender name
- [ ] No notifications appear when user is actively viewing the conversation
- [ ] Works reliably in simulator and on physical device
- [ ] Deep linking works from both foreground and background notifications
- [ ] Multiple simultaneous notifications are handled correctly
- [ ] App doesn't crash if permission is denied

---

## Common Issues and Solutions

### Issue: Notifications not appearing in foreground
**Solution:** Verify `userNotificationCenter(_:willPresent:)` returns `[.banner, .sound, .badge]`

### Issue: Notification tap doesn't navigate to conversation
**Solution:** Check that conversationId is correctly passed in userInfo dictionary and NavigationCoordinator is properly wired

### Issue: Badge count incorrect
**Solution:** Verify badge is being incremented in showMessageNotification and cleared in appropriate lifecycle methods

### Issue: Getting notifications for own messages
**Solution:** Ensure `message.senderId != userId` check is in place in setupGlobalMessageDeliveryListener

### Issue: No notifications after 30 seconds in background
**Solution:** This is expected iOS behavior for background apps without push notifications - not a bug

### Issue: Duplicate notifications
**Solution:** Verify listener only triggers for `.added` messages, not `.modified`

### Issue: Notifications appearing when viewing conversation
**Solution:** Check that activeConversationId is correctly tracked and compared in triggerNotificationForMessage

---

## Next Steps

After completing all phases:

1. **Test thoroughly** using the Testing Matrix above
2. **Gather feedback** from users on notification behavior
3. **Consider upgrading to remote push notifications** when:
   - Ready to deploy to TestFlight or App Store
   - Need notifications for terminated apps
   - Have paid Apple Developer account ($99/year)
   - Reference `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Docs/push_notifications_plan.md` for full remote push implementation

---

## Estimated Timeline

- **Phase 1** (Permissions): 30 minutes
- **Phase 2** (Trigger Notifications): 1-2 hours
- **Phase 3** (Deep Linking): 1 hour
- **Phase 4** (Badge Management): 30 minutes
- **Phase 5** (Optimization): 1 hour

**Total Implementation Time:** 3-4 hours

**Testing Time:** 1-2 hours for comprehensive testing across all scenarios

---

## Additional Resources

- [Apple UserNotifications Documentation](https://developer.apple.com/documentation/usernotifications)
- [Local and Remote Notification Programming Guide](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/)
- [UNUserNotificationCenter Reference](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-21
**Status:** Ready for Implementation
