# Phase 3: Message States & Real-time Features

**Timeline:** Day 2 Afternoon
**Deadline:** Day 2, 6pm
**Duration:** ~6 hours

## Phase Overview

Enhance the messaging experience with full message lifecycle management, real-time presence indicators, typing notifications, and read receipts. This phase adds the polish that makes the app feel professional and responsive. By the end of this phase, users will see when messages are sent, delivered, and read, know when others are online or typing, and see accurate "last seen" timestamps.

## Dependencies

- Phase 2 must be complete (basic messaging working)
- Real-time listeners infrastructure from Phase 2

## Success Criteria

- Message status indicators visible: sending → sent → delivered → read
- Read receipts update when recipient opens conversation
- Typing indicator appears when user is typing
- Online/offline status visible in conversation list and chat view
- "Last seen" timestamp shows for offline users
- Visual indicators are clear and non-intrusive
- All features work smoothly in real-time across two simulators

---

## Task 1: Implement Message Status Flow

**Description:** Build the complete message status lifecycle from sending through read, with Firestore updates and UI indicators.

**Implementation Details:**
- Extend MessageService with status update methods
- Implement automatic status progression: sending → sent → delivered → read
- Update message status in Firestore when each state is reached
- Display status indicators in message bubbles (only for sent messages)

**Status Definitions:**
- **sending:** Message created locally, not yet confirmed by Firestore
- **sent:** Message successfully written to Firestore
- **delivered:** Message received on recipient's device (app opened/active)
- **read:** Recipient has opened the conversation containing the message

**Status Update Triggers:**
- sending → sent: After successful Firestore write (in MessageService.sendMessage)
- sent → delivered: When recipient's app fetches the message (real-time listener fires)
- delivered → read: When recipient opens/is viewing the conversation (ChatDetailView appears)

**Technical Implementation:**
- Add updateMessageStatus(messageId: String, status: MessageStatus) to MessageService
- In MessageService.sendMessage, update status to "sent" after Firestore write succeeds
- In ChatViewModel, mark all delivered messages as "read" when view appears
- In ChatViewModel real-time listener, mark incoming messages as "delivered" automatically

**Firestore Updates:**
- Update message document's status field
- Use Firestore transaction or batch for consistency
- Handle concurrent status updates gracefully

**Files Modified:**
- Services/MessageService.swift
- ViewModels/ChatViewModel.swift
- Models/Message.swift (ensure status field exists)

**Dependencies:** Phase 2 (Task 1: MessageService)

---

## Task 2: Add Status Indicators to Message Bubbles

**Description:** Display visual status indicators in sent message bubbles showing current message state.

**Implementation Details:**
- Modify MessageBubbleView to show status icons for sent messages only (not received messages)
- Use SF Symbols for status icons
- Position indicator next to or below timestamp
- Apply appropriate color coding for each status

**Status Icons (SF Symbols):**
- **sending:** clock icon or spinner (gray)
- **sent:** single checkmark (gray) - "checkmark"
- **delivered:** double checkmark (gray) - "checkmark.checkmark"
- **read:** double checkmark (blue) - "checkmark.checkmark" with blue color

**UI Layout:**
- Show icon next to timestamp in small size (10-12pt)
- Only display for messages from current user (sent messages)
- Icon should be subtle and not dominate the UI
- Consider animation when status changes

**Technical Notes:**
- Use Image(systemName:) for SF Symbols
- Add animation when status updates (.animation modifier)
- Consider using ProgressView for "sending" state
- Ensure icon is legible against bubble background

**Files Modified:**
- Views/Chats/MessageBubbleView.swift

**Dependencies:** Task 1

---

## Task 3: Implement Read Receipts

**Description:** Track and display when messages have been read by recipients using Firestore's readBy map field.

**Implementation Details:**
- When user opens/views a conversation, mark all unread messages as read
- Update message.readBy field in Firestore with current user ID and timestamp
- For group chats, track which participants have read each message
- Display read status appropriately (1-on-1 vs. group)

**Read Receipt Logic:**
- In ChatViewModel, implement markMessagesAsRead() method
- Call markMessagesAsRead() when ChatDetailView appears
- Update all messages with status "delivered" to status "read"
- Add current user ID and timestamp to message.readBy map in Firestore

**Group Chat Considerations:**
- readBy is a map: [userId: timestamp]
- Show "Read by 2/3" or similar for group chats
- Allow tapping to see who has read the message
- Don't show read receipts for messages sent by current user in groups

**Technical Implementation:**
- Use Firestore FieldValue.serverTimestamp() for read timestamp
- Batch update multiple messages at once for efficiency
- Only update messages that haven't been read by current user yet

**Privacy Considerations:**
- Read receipts cannot be disabled in MVP (feature for future)
- Users should be aware that senders can see when they've read messages

**Files Modified:**
- Services/MessageService.swift (add markAsRead method)
- ViewModels/ChatViewModel.swift
- Models/Message.swift (ensure readBy field exists)

**Dependencies:** Task 1

---

## Task 4: Implement Online/Offline Presence

**Description:** Track and display user online status using Firestore presence system with onDisconnect handlers.

**Implementation Details:**
- Use Firestore Realtime Database (not Firestore) for presence due to onDisconnect support
- When user signs in or app becomes active, set isOnline to true
- Use Firebase Realtime Database onDisconnect() to set isOnline to false when user disconnects
- Update lastSeen timestamp when user goes offline
- Listen to presence updates for users in conversation list and chat views

**Presence System Architecture:**
- Store presence data in Firebase Realtime Database (rtdb) at /presence/{userId}
- Mirror isOnline status to Firestore user document for querying
- Update presence when app state changes (foreground, background, terminated)

**Implementation Steps:**
1. Enable Firebase Realtime Database in Firebase Console
2. Add Firebase Database package to Xcode project (if not already added)
3. Create PresenceService.swift for presence management
4. Set online status on app launch and foreground
5. Set offline status with onDisconnect handler
6. Update lastSeen timestamp when going offline

**Technical Details:**
- Use Database.database().reference() for RTDB access
- Set presence at /presence/{userId}/isOnline and /presence/{userId}/lastSeen
- Use .onDisconnectSetValue() to handle disconnection gracefully
- Sync isOnline to Firestore user document for easy querying

**Edge Cases:**
- Handle app termination (onDisconnect covers this)
- Handle network loss and reconnection
- Handle multiple devices (same user on multiple devices)

**Files Created:**
- Services/PresenceService.swift

**Files Modified:**
- Services/UserService.swift (add presence methods if needed)
- CreatorLinkApp.swift (setup presence on app lifecycle changes)

**Dependencies:** Phase 1 (Firebase setup), Phase 2 (UserService)

---

## Task 5: Display Online Status Indicators

**Description:** Show online/offline status indicators in the UI wherever user presence is relevant.

**Implementation Details:**
- Add online status indicator to ConversationRowView (green dot if online)
- Add online status indicator to ChatDetailView navigation bar
- Show "last seen" timestamp for offline users instead of online indicator
- Update indicators in real-time as presence changes

**UI Indicators:**
- Online: small green circle (8-10pt diameter) next to profile photo
- Offline: no indicator, but show "Last seen X time ago" in secondary text
- Position indicator at bottom-right of profile photo (overlay)

**Last Seen Formatting:**
- "Active now" if online
- "Last seen 5m ago" if recently offline
- "Last seen yesterday" if offline for 1-2 days
- "Last seen 3 days ago" if offline longer
- Use RelativeDateTimeFormatter for automatic formatting

**Technical Implementation:**
- Listen to presence changes in ConversationsViewModel and ChatViewModel
- Fetch presence data for relevant users
- Update UI reactively when presence changes
- Cache presence data to reduce reads

**Files Modified:**
- Views/Chats/ConversationRowView.swift
- Views/Chats/ChatDetailView.swift
- ViewModels/ConversationsViewModel.swift
- ViewModels/ChatViewModel.swift

**Dependencies:** Task 4

---

## Task 6: Implement Typing Indicators

**Description:** Show real-time typing indicators when users are composing messages, without persisting typing state to Firestore.

**Implementation Details:**
- Use Firebase Realtime Database (RTDB) for ephemeral typing state
- When user types in text field, set typing indicator in RTDB
- Clear typing indicator after 3 seconds of inactivity or when message is sent
- Display "User is typing..." below conversation or in chat view
- Multiple users typing: "User A and User B are typing..."

**Typing State Storage:**
- Store in RTDB at /typing/{conversationId}/{userId}
- Value: { isTyping: true, timestamp: serverTimestamp }
- Use .onDisconnectRemove() to clear typing state on disconnect
- Automatically expire typing state after 5 seconds (handle in listener)

**Client-side Logic:**
- Debounce typing updates (only send after 500ms of typing activity)
- Clear typing state after 3 seconds of no typing
- Clear typing state when message is sent
- Don't show typing indicator for current user (only for others)

**UI Display:**
- Show typing indicator below last message or in input area
- Use animated ellipsis "..." for visual feedback
- Keep indicator subtle and non-intrusive
- For groups, show up to 3 users typing, then "Multiple people are typing..."

**Technical Implementation:**
- Create TypingService.swift for managing typing state
- In ChatViewModel, call setTyping(true) when user types
- Use Timer or Combine debouncing for clearing typing state
- Listen to typing state in real-time and update UI

**Performance Considerations:**
- Debounce updates to avoid excessive RTDB writes
- Use short TTL for typing state (3-5 seconds)
- Don't persist typing state permanently

**Files Created:**
- Services/TypingService.swift

**Files Modified:**
- ViewModels/ChatViewModel.swift
- Views/Chats/ChatDetailView.swift

**Dependencies:** Task 4 (uses RTDB infrastructure)

---

## Task 7: Add Typing Indicator UI Component

**Description:** Create visual typing indicator component that displays when other users are typing.

**Implementation Details:**
- Create TypingIndicatorView.swift as a reusable component
- Display user names (or "User") and "is typing..." text
- Add animated ellipsis using animation
- Position below message list or above input field
- Hide when no one is typing

**UI Design:**
- Small gray text: "John is typing..."
- Animated ellipsis that fades in/out
- Italic or regular font
- Subtle appearance (shouldn't distract from messages)

**Animation:**
- Three dots that animate in sequence
- Fade in/out animation for smooth appearance
- Consider using ProgressView with custom styling

**Multi-user Handling:**
- Single user: "John is typing..."
- Two users: "John and Jane are typing..."
- Three+ users: "John, Jane, and 2 others are typing..."

**Technical Implementation:**
- Accept array of user IDs/names as parameter
- Use @State for animation control
- Use .transition() for smooth appearance/disappearance
- Position above keyboard in ChatDetailView

**Files Created:**
- Views/Chats/TypingIndicatorView.swift

**Dependencies:** Task 6

---

## Task 8: Update App Lifecycle Handling for Presence

**Description:** Ensure presence and typing states update correctly as app moves between foreground, background, and terminated states.

**Implementation Details:**
- Listen to app lifecycle events using SwiftUI lifecycle or NotificationCenter
- Update presence when app enters foreground (set online)
- Update presence when app enters background (set offline after delay)
- Clear typing state when app backgrounds
- Handle app termination gracefully (onDisconnect handles this)

**Lifecycle Events to Handle:**
- scenePhase changes: .active, .inactive, .background
- App launches: set user online
- App backgrounds: set user offline after 30 second grace period
- App terminates: rely on onDisconnect handlers

**Implementation Approach:**
- In CreatorLinkApp, use .onChange(of: scenePhase)
- Call PresenceService methods for each state change
- Clear typing indicators on background
- Resume presence on foreground

**Grace Period for Background:**
- Don't immediately set offline when app backgrounds
- Wait 30 seconds before marking offline (user might be switching apps briefly)
- Cancel offline timer if app returns to foreground
- This prevents flickering online/offline status

**Technical Notes:**
- Use DispatchQueue.main.asyncAfter for delayed offline updates
- Store timer reference to cancel if app returns to foreground
- Ensure presence updates happen on main thread

**Files Modified:**
- CreatorLinkApp.swift
- Services/PresenceService.swift

**Dependencies:** Task 4

---

## Task 9: Implement Message Delivery Detection

**Description:** Automatically mark messages as "delivered" when received on recipient's device.

**Implementation Details:**
- In ChatViewModel, when real-time listener receives new messages, mark them as delivered
- Only mark as delivered if message status is currently "sent"
- Don't mark as delivered if user sent the message (only for received messages)
- Batch update delivered status for multiple messages

**Delivery Detection Logic:**
- Real-time listener fires when new message arrives
- Check if message is from another user (senderId != currentUserId)
- Check if message status is "sent" (not already delivered/read)
- Update status to "delivered" in Firestore
- Sender will see status change via their own real-time listener

**Technical Implementation:**
- In ChatViewModel.listenToMessages completion handler
- Filter new messages where status == "sent" and senderId != currentUserId
- Call MessageService.updateMessageStatus for each message
- Consider batching updates if multiple messages arrive simultaneously

**Edge Cases:**
- Message arrives when chat view is not visible (still mark as delivered)
- Multiple devices: each device independently marks as delivered
- Already delivered: skip update to avoid unnecessary writes

**Files Modified:**
- ViewModels/ChatViewModel.swift
- Services/MessageService.swift

**Dependencies:** Task 1

---

## Task 10: Add Timestamps and Time Grouping

**Description:** Display timestamps on messages with smart grouping to reduce clutter while maintaining temporal context.

**Implementation Details:**
- Group messages by time periods (e.g., "Today", "Yesterday", specific dates)
- Show full timestamp only for first message in a time group
- Show abbreviated timestamp (just time) for messages within 5 minutes of previous
- Display date separators between different days

**Time Grouping Logic:**
- Messages sent within 1 minute: no timestamp (already shown on previous)
- Messages sent within 5 minutes: show time only (e.g., "2:30 PM")
- Messages sent different days: show date separator (e.g., "Today", "Yesterday", "March 15")
- First message in conversation: always show full timestamp

**Date Separator UI:**
- Centered gray text between messages
- Small capsule background (light gray)
- Text: "Today", "Yesterday", or formatted date
- Visible spacing above and below

**Timestamp Formatting:**
- Today: show time only (e.g., "2:30 PM")
- Yesterday: "Yesterday" with optional time
- This week: day name (e.g., "Monday")
- Older: full date (e.g., "March 15, 2025")
- Use DateFormatter with appropriate styles

**Technical Implementation:**
- Create helper function to determine time grouping
- Add date separator view component
- Modify message list to include separators
- Calculate grouping in ChatViewModel or view logic

**Files Created:**
- Views/Chats/DateSeparatorView.swift (optional)

**Files Modified:**
- Views/Chats/ChatDetailView.swift
- Views/Chats/MessageBubbleView.swift

**Dependencies:** Phase 2 (message display)

---

## Task 11: Enhance Conversation Row with Status Preview

**Description:** Show message status and online status in conversation list rows for quick scanning.

**Implementation Details:**
- Display message status icon next to last message preview (if user is sender)
- Show online indicator on profile photo
- Display unread message count badge (will implement read tracking)
- Show typing indicator if other user is typing

**Conversation Row Enhancements:**
- If last message is from current user, show status icon (sent/delivered/read checkmarks)
- If other user is online, show green dot on profile photo
- If other user is typing, show "typing..." instead of last message preview
- If there are unread messages, show count badge (blue circle with number)

**Layout Adjustments:**
- Status icon next to last message text (small, gray)
- Online indicator overlaid on bottom-right of profile photo
- Unread badge on right side next to timestamp
- Typing text in italic gray

**Technical Implementation:**
- Extend ConversationRowView to accept status and presence data
- Listen to typing state for conversations in ConversationsViewModel
- Calculate unread count based on messages not in current user's readBy map
- Use appropriate icons and colors

**Files Modified:**
- Views/Chats/ConversationRowView.swift
- ViewModels/ConversationsViewModel.swift

**Dependencies:** Task 2, Task 5, Task 6

---

## Task 12: Implement Unread Message Tracking

**Description:** Track which messages are unread and display unread count in conversation list.

**Implementation Details:**
- Count messages in conversation where current user is NOT in readBy map
- Display unread count as badge on conversation row
- Clear unread count when user opens conversation (readBy is updated)
- Show unread indicator in conversation list

**Unread Count Logic:**
- Query messages where conversationId matches AND current userId NOT IN readBy
- Count resulting messages
- Store count in Conversation model or calculate on-demand
- Update count when messages are marked as read

**UI Display:**
- Blue circle badge with white text on right side of conversation row
- Badge size: 20pt diameter for 1-2 digits, expand for 3+ digits
- Show "99+" if count exceeds 99
- Bold conversation name if there are unread messages

**Performance Optimization:**
- Cache unread counts to avoid repeated Firestore queries
- Update counts via real-time listeners instead of polling
- Consider storing unread count in conversation document for efficiency

**Technical Implementation:**
- Add unreadCount field to Conversation model (calculated or stored)
- In ConversationsViewModel, fetch/calculate unread counts
- Update unread count when messages are read
- Display badge in ConversationRowView conditionally

**Files Modified:**
- Models/Conversation.swift
- Services/ConversationService.swift
- ViewModels/ConversationsViewModel.swift
- Views/Chats/ConversationRowView.swift

**Dependencies:** Task 3 (read receipts)

---

## Task 13: Add Loading and Error States

**Description:** Implement comprehensive loading and error states for all real-time features to handle edge cases gracefully.

**Implementation Details:**
- Show loading indicators while fetching initial data
- Display error messages when Firestore operations fail
- Handle network connectivity issues
- Provide retry mechanisms for failed operations
- Show empty states when no data is available

**Loading States to Implement:**
- Conversation list loading: skeleton views or progress indicator
- Message list loading: spinner in center of screen
- Message sending: spinner on send button or in message bubble
- Profile photo loading: placeholder image or progress view

**Error States to Handle:**
- Network connection lost: banner or alert with retry option
- Firestore permission denied: show meaningful error message
- Message send failure: show retry button on message
- Presence update failure: silently retry in background

**Empty States:**
- No conversations: "Start a conversation" with new chat button
- No messages in conversation: "Send your first message" prompt
- No users to chat with: "No users available"

**UI Components:**
- Error banner at top of screen (red background, white text)
- Retry button for failed actions
- Loading spinner using ProgressView
- Skeleton views for loading states (optional)

**Technical Implementation:**
- Add @Published error and loading properties to ViewModels
- Display error alerts or banners based on error state
- Implement retry logic in services
- Use .overlay or .alert for error displays

**Files Modified:**
- ViewModels/ConversationsViewModel.swift
- ViewModels/ChatViewModel.swift
- Views/Chats/ChatsView.swift
- Views/Chats/ChatDetailView.swift
- Services/* (add error handling)

**Dependencies:** Phase 2 (existing ViewModels and Views)

---

## Task 14: Comprehensive Testing of Real-time Features

**Description:** Test all Phase 3 features across two simulators to ensure reliable real-time synchronization.

**Testing Setup:**
- Two iOS simulators side-by-side
- Sign in as different users
- Open same conversation on both devices

**Test Scenarios:**

**Scenario 1: Message Status Flow**
- User A sends message to User B
- Verify status on User A's device: sending → sent (after Firestore write)
- User B's app receives message via real-time listener
- Verify status updates to "delivered" on User A's device
- User B opens conversation (if not already open)
- Verify status updates to "read" (blue double checkmark) on User A's device
- Verify timing: each transition should happen within 1-2 seconds

**Scenario 2: Typing Indicators**
- User A opens conversation with User B
- User A starts typing in text field
- Verify "User A is typing..." appears on User B's device within 1 second
- User A stops typing for 3 seconds
- Verify typing indicator disappears on User B's device
- User A sends message
- Verify typing indicator disappears immediately on User B's device

**Scenario 3: Online/Offline Presence**
- User A is active in app
- Verify green dot appears on User A's profile in User B's conversation list
- User A closes/terminates app
- Verify green dot disappears on User B's side within 5-10 seconds
- Verify "Last seen X time ago" appears on User B's side
- User A reopens app
- Verify green dot reappears on User B's side

**Scenario 4: Read Receipts**
- User A sends multiple messages to User B while User B's app is closed
- User B opens app but doesn't open conversation yet
- Verify messages show "delivered" status on User A's side
- User B opens conversation
- Verify all messages show "read" status (blue checkmarks) on User A's side
- Check that readBy map in Firestore contains User B's ID

**Scenario 5: Unread Counts**
- User A sends 5 messages to User B
- User B is on conversation list (not in chat)
- Verify conversation row shows unread badge with "5"
- User B opens conversation
- Verify badge disappears from conversation list
- User B returns to conversation list
- Verify no unread badge (all messages marked read)

**Scenario 6: App Lifecycle**
- User A is online and chatting
- Put app in background (swipe up on simulator)
- Verify User A appears offline on User B's side after 30 seconds
- Bring User A's app back to foreground
- Verify User A appears online again on User B's side

**Scenario 7: Edge Cases**
- Send message while offline (should queue, test in Phase 4)
- Receive message while app is in background
- Multiple users typing simultaneously in group (prepare for Phase 5)
- Rapid status changes (send many messages quickly)

**Performance Verification:**
- All status updates appear within 1-2 seconds
- Typing indicators are responsive (< 1 second delay)
- Presence changes are timely (< 10 seconds)
- UI remains smooth and responsive
- No console errors or warnings

**Firestore Verification:**
- Check message documents in Firestore console
- Verify status field updates correctly
- Verify readBy map is populated
- Check user documents for presence data
- Verify RTDB has typing and presence data

**Dependencies:** All tasks in Phase 3

---

## Phase 3 Completion Checklist

Before moving to Phase 4, verify:
- [x] Message status flow implemented (sending → sent → delivered → read)
- [x] Status indicators visible in message bubbles
- [x] Read receipts working (messages marked as read when conversation opened)
- [x] Online/offline presence tracking functional
- [x] Presence indicators displayed in conversation list and chat view
- [x] "Last seen" timestamps shown for offline users
- [x] Typing indicators working in real-time
- [x] Typing indicator UI appears/disappears correctly
- [x] App lifecycle handling for presence updates
- [x] Message delivery detection automatic
- [x] Timestamps and time grouping implemented
- [x] Conversation row shows status preview
- [x] Unread message count displayed and accurate
- [x] Loading and error states handled gracefully
- [ ] All features tested across two simulators
- [ ] No performance issues or excessive Firestore reads

---

## Deliverables

By the end of Phase 3, you should have:
1. Complete message status lifecycle with visual indicators
2. Real-time typing indicators
3. Online/offline presence system
4. Read receipts and unread tracking
5. Polished UI with proper loading and error states
6. Professional-feeling messaging experience

---

## Known Limitations (To Address in Later Phases)

- No offline message persistence - Phase 4
- No offline queue management - Phase 4
- No group chat support for presence/typing - Phase 5 (will extend)
- No retry mechanism for failed presence updates - Phase 4

---

## Notes for Next Phase

Phase 4 will add crucial reliability features:
- SwiftData local persistence
- Offline message queue
- Auto-retry for failed messages
- Sync strategy for conflicting data
- App lifecycle persistence

Ensure Phase 3 features work reliably in online scenarios before tackling offline complexity in Phase 4.
