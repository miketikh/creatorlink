# Phase 5: Group Chat Support

**Timeline:** Day 3 Morning - Day 3 Afternoon
**Deadline:** Day 3, 2pm
**Duration:** ~4 hours

## Phase Overview

Extend the messaging infrastructure to support group conversations with 3-10 participants. Build upon the existing 1-on-1 messaging foundation to handle multi-participant scenarios, including group-specific UI elements, per-member delivery tracking, read receipts from multiple users, and group typing indicators. By the end of this phase, users should be able to create group chats, send messages to multiple participants, and see rich status information for each group member.

## Dependencies

- Phase 1 complete (Firebase, Auth, Basic UI)
- Phase 2 complete (Core messaging infrastructure)
- Phase 3 complete (Message states, real-time features)
- Phase 4 complete (Offline persistence)

## Success Criteria

- Users can create group conversations with 3-10 participants
- Messages sent to groups are delivered to all participants
- Read receipts show which members have read each message
- Typing indicators show multiple users typing
- Group member list is visible and accurate
- Delivery tracking per member (who has received the message)
- Group metadata (optional name) is supported
- Message attribution shows sender name/photo in group context
- All group features work offline with proper sync
- Group conversations appear correctly in conversation list

---

## Task 1: Extend Group Chat Data Models

**Description:** Enhance existing data models to fully support group chat metadata, member management, and per-participant tracking.

**Implementation Details:**
- Update Conversation model to include group-specific fields
- Add member roles and permissions (for future expansion)
- Extend Message model to better handle group attribution
- Add group metadata fields (creation date, created by, member count)
- Ensure SwiftData models support group scenarios

**Conversation Model Enhancements:**
- groupName: String? (optional custom name, defaults to participant names)
- groupPhotoURL: String? (optional group avatar)
- createdBy: String (userId who created the group)
- createdAt: Date (when group was created)
- memberCount: Int (redundant with participantIds.count, but useful for queries)
- Ensure isGroupChat is properly set based on participantIds.count > 2

**Message Model Enhancements:**
- Ensure sender attribution is clear in UI layer
- readBy map should accommodate multiple participants
- deliveredTo array to track which participants have received the message

**Technical Notes:**
- Backward compatibility with 1-on-1 chats (isGroupChat = false)
- participantIds array should remain the primary source of group membership
- Validate group size constraints (3-10 participants) in service layer
- Consider adding admin/member role field for future features

**Files Modified:**
- Models/Conversation.swift
- Models/Message.swift
- Persistence/ConversationModel.swift (SwiftData)
- Persistence/MessageModel.swift (SwiftData)

**Dependencies:** Phase 1 (Task 10: Data Models), Phase 4 (Task 2: SwiftData Models)

---

## Task 2: Create GroupService for Group Management

**Description:** Build dedicated service layer for group-specific operations including creation, member management, and metadata updates.

**Implementation Details:**
- Create GroupService.swift to handle all group-related operations
- Implement group creation with multiple participants
- Implement member add/remove operations (for future use)
- Implement group metadata updates (name, photo)
- Validate group size and permissions
- Integrate with existing ConversationService and MessageService

**Core Methods:**
- createGroup(name: String?, participantIds: [String]) -> async throws Conversation
- fetchGroupMembers(conversationId: String) -> async throws [User]
- updateGroupName(conversationId: String, name: String) -> async throws
- updateGroupPhoto(conversationId: String, photoURL: String) -> async throws
- addMember(conversationId: String, userId: String) -> async throws (future)
- removeMember(conversationId: String, userId: String) -> async throws (future)

**Group Creation Logic:**
- Validate minimum participants (3) and maximum (10)
- Check that all participant IDs exist in users collection
- Create conversation document with isGroupChat = true
- If no name provided, generate default name from participant names
- Set createdBy to current user ID
- Set initial metadata (createdAt, memberCount)

**Technical Implementation:**
- Use Firestore batch writes to create conversation and update participant data atomically
- Save group to SwiftData immediately for offline support
- Validate that current user is in participantIds array
- Handle duplicate participant IDs gracefully

**Error Handling:**
- Too few participants (< 3)
- Too many participants (> 10)
- Invalid participant IDs
- Permission errors
- Network failures (queue for offline sync)

**Files Created:**
- Services/GroupService.swift

**Dependencies:** Phase 2 (ConversationService), Phase 4 (PersistenceService)

---

## Task 3: Implement Group Creation UI

**Description:** Build user interface for creating group conversations with member selection and optional group naming.

**Implementation Details:**
- Create GroupCreationView.swift as a multi-step flow
- Step 1: Select members from user list (multi-select)
- Step 2: Set group name (optional)
- Display selected members with ability to remove before creation
- Validate minimum participant count (3 including creator)
- Navigate to new group chat after creation

**UI Requirements:**

**Step 1 - Member Selection:**
- Search bar for filtering users
- List of all users with checkboxes/toggle for selection
- Show selected count at top ("3 of 10 selected")
- Disable users already in conversation (optional)
- Exclude current user from selection (auto-added)
- Continue button enabled when 2+ users selected (3 including creator)

**Step 2 - Group Name (Optional):**
- Text field for group name (optional, max 50 characters)
- Preview of default name if no custom name provided
- Create button to finalize group
- Back button to return to member selection

**Member Selection UI:**
- User rows with profile photo, name, and checkbox
- Multi-select capability (tap row to toggle selection)
- Visual indicator for selected users (checkmark, blue background)
- Search filters list in real-time

**Navigation Flow:**
1. User taps "New Group" button in ChatsView
2. GroupCreationView appears as full screen or sheet
3. User selects members (minimum 2, maximum 9 plus creator = 10 total)
4. User taps "Continue" or "Next"
5. Optional: User enters group name
6. User taps "Create"
7. Group is created via GroupService
8. Navigate to new group chat (ChatDetailView)

**Technical Implementation:**
- Use @State for selected user IDs array
- Use @State for group name text
- Validate selections before enabling Create button
- Show loading indicator during group creation
- Handle creation errors with alert
- Dismiss view and navigate on success

**Files Created:**
- Views/Groups/GroupCreationView.swift
- Views/Groups/MemberSelectionView.swift (optional sub-component)

**Files Modified:**
- Views/Chats/ChatsView.swift (add "New Group" button option)

**Dependencies:** Task 2

---

## Task 4: Update ChatDetailView for Group Context

**Description:** Modify the chat detail view to properly display group conversations with sender attribution and group-specific UI elements.

**Implementation Details:**
- Show group name or participant names in navigation title
- Display sender name/photo for each message (not just received messages)
- Add group info button in navigation bar (tap to view members)
- Adjust message bubble layout to include sender attribution
- Handle group-specific empty states

**Navigation Bar Updates:**
- Title: Group name or "Group Chat" if no name set
- Subtitle: Member count (e.g., "5 members")
- Right button: Info icon (SF Symbol "info.circle") to view group details
- Tap navigation bar to view group info (optional)

**Message Display Changes:**
- For group messages, always show sender name above or below bubble
- Show sender profile photo next to message bubble (especially for received messages)
- Sender photo appears on left for received, name appears above/below bubble
- Current user's messages don't show sender name (obvious it's from them)
- Group messages by sender to reduce repetition (show name only for first in sequence)

**Message Attribution Layout:**
- Received messages: Profile photo (left) → Message bubble → Show sender name above bubble
- Sent messages: No sender info needed (aligned right as usual)
- Consecutive messages from same sender: Only show name on first message

**Technical Implementation:**
- Check conversation.isGroupChat to determine display mode
- Fetch sender User profile for each message to get displayName and photoURL
- Cache user profiles to avoid redundant fetches
- Modify MessageBubbleView or create GroupMessageBubbleView
- Add sender info component above/beside message bubble

**Files Modified:**
- Views/Chats/ChatDetailView.swift
- Views/Chats/MessageBubbleView.swift (add sender attribution)

**Files Created:**
- Views/Chats/SenderAttributionView.swift (optional component for name/photo)

**Dependencies:** Task 1, Phase 2 (ChatDetailView)

---

## Task 5: Create Group Info View

**Description:** Build a dedicated view for displaying group details, member list, and group settings.

**Implementation Details:**
- Create GroupInfoView.swift to show group metadata and members
- Display group name (editable by creator)
- Display group photo placeholder (future: allow upload)
- Show list of all group members with profile photos and names
- Show online/offline status for each member
- Add leave group button for current user
- Add settings/actions (mute, notifications - future)

**UI Layout:**

**Header Section:**
- Group photo (large, centered) or placeholder
- Group name (tappable to edit if user is creator)
- Member count subtitle
- Created date or "Created by [name]"

**Members Section:**
- Section header: "Members (X)"
- List of member rows with profile photo, name, online status
- Current user highlighted or marked ("You")
- Show admin badge if applicable (future)

**Actions Section:**
- "Leave Group" button (destructive red)
- "Mute Notifications" toggle (future)
- "Report Group" option (future)

**Technical Requirements:**
- Fetch User profiles for all participantIds
- Listen to presence updates for members
- Only allow group name editing if current user is creator
- Confirm before leaving group (alert)
- Update conversation after leaving (remove self from participantIds)

**Navigation:**
- Presented as sheet or pushed onto navigation stack from ChatDetailView
- Dismiss returns to chat view
- If user leaves group, navigate back to ChatsView

**Files Created:**
- Views/Groups/GroupInfoView.swift
- Views/Groups/GroupMemberRowView.swift (optional component)

**Dependencies:** Task 4, Phase 3 (presence system)

---

## Task 6: Implement Group Message Delivery Tracking

**Description:** Track message delivery to each group member individually, showing who has received the message.

**Implementation Details:**
- Extend message model to track deliveredTo array (userIds)
- When group member's app receives message, add their ID to deliveredTo
- Update MessageService to handle group delivery tracking
- Display delivery status in UI (e.g., "Delivered to 3/5")
- Sync delivery status to Firestore and SwiftData

**Delivery Tracking Logic:**
- When message is created, deliveredTo is empty array
- When recipient's real-time listener fires, add recipient's userId to deliveredTo
- Update Firestore message document with updated deliveredTo array
- Sender sees delivery status update in real-time

**Firestore Update:**
- Use Firestore arrayUnion to add userId to deliveredTo atomically
- Avoid race conditions with multiple recipients updating simultaneously
- Update message status to "delivered" only when all participants have received it

**UI Display:**
- For group messages, show "Delivered to X/Y" instead of simple checkmark
- Tap on delivery status to see list of who has/hasn't received
- In message bubble or below timestamp
- Different indicator if partially delivered vs. fully delivered

**Technical Implementation:**
- Add deliveredTo field to Message model (array of strings)
- Update MessageService.markAsDelivered to accept userId parameter
- In ChatViewModel, mark messages as delivered with current user's ID
- Update MessageBubbleView to show group delivery status
- Create modal or sheet to show detailed delivery list on tap

**Files Modified:**
- Models/Message.swift
- Persistence/MessageModel.swift
- Services/MessageService.swift
- ViewModels/ChatViewModel.swift
- Views/Chats/MessageBubbleView.swift

**Dependencies:** Task 1, Phase 3 (Task 9: Delivery Detection)

---

## Task 7: Implement Group Read Receipts

**Description:** Extend read receipt functionality to track which group members have read each message, with UI showing read status per member.

**Implementation Details:**
- Leverage existing readBy map field (already supports multiple users)
- When group member opens conversation, add their ID and timestamp to readBy
- Display read status showing how many members have read
- Allow tapping read status to see detailed list of who has read
- Update sender's UI in real-time as members read messages

**Read Receipt Logic:**
- readBy map: [userId: timestamp]
- When user opens group chat, mark all unread messages with their userId
- Use Firestore map merge to add user's read timestamp
- Update message status to "read" when at least one person (besides sender) has read it

**UI Display Options:**

**Option 1 - Summary:**
- "Read by 2" or "Read by 2/5" below message
- Blue checkmarks when at least one person has read
- Gray checkmarks when delivered but not read

**Option 2 - Avatars:**
- Show small profile photos of users who have read
- Max 3 avatars, then "+X more"
- Overlapping avatar stack for compact display

**Detailed Read Receipt View:**
- Modal/sheet that appears on tap of read status
- List of all participants with read status
- Show "Read at [time]" or "Delivered" or "Not delivered"
- Sort by read time (most recent first)

**Technical Implementation:**
- Existing readBy map already supports multiple users
- Update markMessagesAsRead to use map merge in Firestore
- Create ReadReceiptDetailView component
- Calculate read count from readBy map keys
- Show read receipt detail on tap

**Files Created:**
- Views/Chats/ReadReceiptDetailView.swift

**Files Modified:**
- Services/MessageService.swift (ensure map merge works)
- ViewModels/ChatViewModel.swift
- Views/Chats/MessageBubbleView.swift (add read receipt tap gesture)

**Dependencies:** Task 6, Phase 3 (Task 3: Read Receipts)

---

## Task 8: Implement Group Typing Indicators

**Description:** Show typing indicators for multiple group members simultaneously, with proper UI to handle multiple concurrent typists.

**Implementation Details:**
- Extend existing typing indicator system to handle multiple users
- Display typing indicator showing up to 3 names, then "and X others"
- Use same RTDB structure at /typing/{conversationId}/{userId}
- Handle multiple simultaneous typists gracefully
- Clear typing state properly for group members

**Typing State in Groups:**
- Structure: /typing/{conversationId}/{userId} = { isTyping: true, timestamp: serverTimestamp }
- Listen to all children under /typing/{conversationId}
- Filter out current user from typing list
- Update UI when any member starts/stops typing

**UI Display Logic:**
- No one typing: hide indicator
- 1 person typing: "Alice is typing..."
- 2 people typing: "Alice and Bob are typing..."
- 3 people typing: "Alice, Bob, and Charlie are typing..."
- 4+ people typing: "Alice, Bob, and 2 others are typing..."

**Technical Implementation:**
- Extend TypingService to handle group typing queries
- Listen to all typing states under conversation path
- Maintain array of currently typing user IDs
- Fetch user display names for typing users
- Update TypingIndicatorView to accept multiple names
- Debounce updates to avoid flickering with multiple typists

**Performance Considerations:**
- Limit displayed names to 3 for readability
- Cache user display names to avoid repeated fetches
- Throttle UI updates if many users typing simultaneously
- Clear stale typing states (>5 seconds old)

**Files Modified:**
- Services/TypingService.swift
- ViewModels/ChatViewModel.swift
- Views/Chats/TypingIndicatorView.swift
- Views/Chats/ChatDetailView.swift

**Dependencies:** Phase 3 (Task 6: Typing Indicators)

---

## Task 9: Update Conversation List for Groups

**Description:** Modify conversation list UI to properly display group conversations with group-specific information and styling.

**Implementation Details:**
- Show group name or member names in conversation row
- Display group photo or stacked member photos
- Show member count subtitle
- Display last message with sender name for group messages
- Handle group-specific status indicators (delivery to multiple members)

**Conversation Row Updates:**

**Group Photo Display:**
- If group has custom photo: show that photo
- If no custom photo: show grid of member profile photos (2x2 or 3x3)
- Fallback: generic group icon (SF Symbol "person.3.fill")

**Title Display:**
- If group has name: show group name
- If no name: show first 2-3 member names ("Alice, Bob, Charlie")
- Truncate long names with ellipsis

**Subtitle Display:**
- Show member count: "5 members"
- If typing: "Alice is typing..." (same logic as individual chats)

**Last Message Display:**
- For group messages, prepend sender name: "Alice: Hey everyone!"
- If message is from current user: "You: Message text"
- Truncate message text appropriately

**Status Indicators:**
- Show unread count badge if applicable
- Show sent/delivered/read status if last message is from current user
- Consider showing partial delivery status (e.g., "Delivered to 3/5")

**Technical Implementation:**
- Update ConversationRowView to detect group conversations
- Conditionally render group-specific UI elements
- Fetch group member info for display
- Generate composite group photo if needed (use AsyncImage or custom view)
- Handle long group names and member lists gracefully

**Files Modified:**
- Views/Chats/ConversationRowView.swift

**Files Created:**
- Views/Common/GroupAvatarView.swift (optional component for group photos)

**Dependencies:** Task 1, Phase 2 (Task 5: ConversationRowView)

---

## Task 10: Implement Group Member Presence

**Description:** Extend presence system to show online/offline status for all group members in group info view.

**Implementation Details:**
- Fetch presence data for all group members
- Display online status in group info view member list
- Update presence in real-time as members go online/offline
- Show aggregate presence info in chat view (e.g., "3 online")
- Handle presence efficiently for large groups

**Presence Display Locations:**

**Group Info View:**
- Each member row shows green dot if online
- Show "last seen" timestamp if offline
- Update in real-time as presence changes

**Chat Detail View (optional):**
- Navigation bar subtitle: "3 of 5 members online"
- Or: "Alice, Bob online"
- Only show if space permits and enhances UX

**Technical Implementation:**
- Use existing PresenceService to query member presence
- Listen to presence updates for all participantIds
- Update UI reactively when presence changes
- Cache presence data to reduce reads
- Batch presence queries to avoid N+1 query problem

**Performance Optimization:**
- Don't fetch presence for all members if group is large (>10)
- Consider pagination or limiting to "active" members
- Use Firestore query to fetch multiple user presence documents in one request
- Update presence only when GroupInfoView is visible

**Files Modified:**
- Views/Groups/GroupInfoView.swift
- ViewModels/ChatViewModel.swift (if showing aggregate presence)
- Services/PresenceService.swift (add batch query if needed)

**Dependencies:** Task 5, Phase 3 (Task 4: Online/Offline Presence)

---

## Task 11: Handle Group Message Notifications

**Description:** Ensure push notifications work correctly for group messages, with proper attribution and context.

**Implementation Details:**
- Update FCM message payload to include group context
- Show sender name in notification for group messages
- Include group name in notification
- Handle notification tap to navigate to correct group chat
- Ensure notification permissions are properly requested

**Notification Payload for Groups:**
- Title: "[Group Name]" or "Group Chat"
- Body: "[Sender Name]: Message text"
- Data: conversationId, senderId, isGroupChat flag
- Badge count: unread message count across all conversations

**Notification Display:**
- Example: "Family Group" / "Alice: Hey everyone!"
- Example: "Project Team" / "Bob: Meeting at 3pm"
- For long messages, truncate with ellipsis

**Notification Handling:**
- When user taps notification, open app to specific group chat
- Use conversationId from notification data to navigate
- Mark messages as read when conversation is opened

**Technical Notes:**
- Firebase Cloud Messaging handles notification delivery
- Cloud Functions (Phase 8+) will send notifications on new message
- For MVP, focus on foreground/background notification display
- Deep linking handled in app delegate or SwiftUI lifecycle

**Files Modified:**
- CreatorLinkApp.swift (notification handling)
- AppDelegate.swift (if using UIKit AppDelegate for notifications)

**Files Created:**
- Services/NotificationService.swift (if not already exists)

**Dependencies:** Phase 1 (FCM setup), Task 2

**Note:** Full notification implementation may be deferred to Phase 6 if time is limited. Focus on UI and messaging logic first.

---

## Task 12: Add Group Message Offline Support

**Description:** Ensure group messages work seamlessly offline, with proper queuing and sync for multi-participant scenarios.

**Implementation Details:**
- Extend offline message queue to handle group messages
- Queue group messages for each participant
- Sync group messages to Firestore when online
- Handle delivery tracking for offline group messages
- Ensure group creation works offline

**Offline Group Messaging Flow:**
1. User sends message in group while offline
2. Message saved to SwiftData with isPendingUpload = true
3. Message appears in UI immediately (optimistic)
4. When online, SyncService uploads message to Firestore
5. Firestore triggers real-time listeners for all group members
6. Delivery tracking updates as members receive message

**Offline Group Creation:**
- User creates group while offline
- Group conversation saved to SwiftData with temporary ID
- When online, group is created in Firestore
- Firestore generates real conversation ID
- Update local group with Firestore ID
- Sync pending messages in that group

**Technical Implementation:**
- Existing MessageQueue should handle group messages automatically
- Ensure SyncService correctly uploads group messages to Firestore
- Verify deliveredTo and readBy tracking works after sync
- Test group creation offline and subsequent sync

**Edge Cases:**
- Group created offline, member added online (conflict resolution)
- Message sent offline to group that was deleted online
- Multiple group members sending messages simultaneously offline

**Testing Scenarios:**
- Create group offline, send messages, go online → verify sync
- Send group message offline, go online → verify all members receive
- Create group online, send messages offline → verify delivery tracking

**Files Modified:**
- Services/SyncService.swift (ensure group support)
- Services/MessageQueue.swift (if group-specific logic needed)
- Services/GroupService.swift (offline group creation)

**Dependencies:** Task 2, Phase 4 (Task 9: Message Queue Management)

---

## Task 13: Implement Group Search and Filtering

**Description:** Add ability to search and filter group conversations in the conversation list for easier navigation.

**Implementation Details:**
- Add search bar to ChatsView that filters both 1-on-1 and group conversations
- Filter groups by group name, member names, or last message content
- Highlight group conversations in search results
- Provide filter options (All, 1-on-1, Groups)

**Search Functionality:**
- Search bar appears at top of ChatsView
- Real-time filtering as user types
- Search matches: group name, participant names, last message text
- Case-insensitive search

**Filter Options:**
- Segmented control or tabs: "All" | "Direct" | "Groups"
- Default: All conversations
- Direct: Only 1-on-1 conversations (isGroupChat = false)
- Groups: Only group conversations (isGroupChat = true)

**UI Implementation:**
- Use .searchable modifier in SwiftUI
- Filter conversations array based on search text
- Show "No results" empty state if search yields nothing
- Clear search on filter change

**Technical Implementation:**
- Add @State searchText in ConversationsViewModel or ChatsView
- Implement filtering logic: check group name, participant names, last message
- Use .filter on conversations array
- Consider debouncing search for performance with large lists

**Files Modified:**
- Views/Chats/ChatsView.swift
- ViewModels/ConversationsViewModel.swift

**Dependencies:** Task 9, Phase 2 (Task 4: ChatsView)

---

## Task 14: Comprehensive Group Chat Testing

**Description:** Thoroughly test group chat functionality across multiple simulators to ensure all features work correctly in multi-user scenarios.

**Testing Setup:**
- Three iOS simulators (User A, User B, User C)
- All signed in as different users
- Network connectivity control for offline testing

**Test Scenarios:**

**Scenario 1: Group Creation**
1. User A creates group with Users B and C
2. Verify group appears in conversation list for all three users
3. Verify group name displays correctly
4. Verify member count is accurate (3 members)
5. Check Firestore console for conversation document

**Scenario 2: Group Messaging**
1. User A sends message in group
2. Verify message appears immediately on User A's device (optimistic UI)
3. Verify message appears on Users B and C's devices within 2 seconds
4. Verify sender name/photo displays correctly for B and C
5. User B sends reply
6. Verify all three users see the reply with correct attribution

**Scenario 3: Message Delivery Tracking**
1. User A sends message in group
2. Verify deliveredTo updates as B and C receive message
3. User A sees "Delivered to 2/3" or similar indicator
4. Tap delivery status to see detailed list
5. Verify B and C appear in delivered list

**Scenario 4: Group Read Receipts**
1. User A sends message in group
2. User B opens group chat (message should be marked read)
3. Verify User A sees read receipt for User B
4. User C opens group chat
5. Verify User A sees read receipts for both B and C
6. Verify "Read by 2" or similar indicator

**Scenario 5: Group Typing Indicators**
1. User A opens group chat
2. User B starts typing
3. Verify "User B is typing..." appears on User A's device
4. User C also starts typing
5. Verify "User B and User C are typing..." appears on User A's device
6. User B stops typing
7. Verify only "User C is typing..." appears

**Scenario 6: Group Info View**
1. Open group chat on User A's device
2. Tap group info button
3. Verify member list shows all 3 members
4. Verify online status indicators for each member
5. User B goes offline
6. Verify User B shows as offline in member list on User A's device

**Scenario 7: Offline Group Messaging**
1. User A goes offline
2. User A sends message in group
3. Verify message appears in UI (optimistic)
4. Verify message has pending indicator
5. User A comes online
6. Verify message syncs to Firestore
7. Verify Users B and C receive the message

**Scenario 8: Offline Group Creation**
1. User A goes offline
2. User A creates new group with Users B and C
3. Send message in group
4. Force quit and reopen app (still offline)
5. Verify group and message persist
6. Go online
7. Verify group syncs to Firestore
8. Verify Users B and C see the group and message

**Scenario 9: Multiple Groups**
1. Create multiple groups with different member combinations
2. Send messages in each group
3. Verify messages go to correct groups
4. Verify conversation list shows all groups correctly
5. Verify no message crossover between groups

**Scenario 10: Group Presence**
1. Open GroupInfoView for a group
2. Verify online status for all members
3. User B closes app
4. Verify User B shows as offline within 10 seconds
5. User B reopens app
6. Verify User B shows as online again

**Scenario 11: Large Group (8-10 members)**
1. Create group with 8-10 members (if possible with available test accounts)
2. Send messages and verify delivery to all members
3. Verify UI handles many members gracefully (no overflow)
4. Verify typing indicators work with multiple typists

**Verification Points:**
- All group messages delivered to all participants
- Read receipts accurate for all members
- Typing indicators show correctly for multiple users
- Group info displays accurate member list and status
- Offline functionality works for groups
- No data loss or corruption
- UI is clear and not cluttered with group info
- Performance is acceptable (no lag)
- Firestore documents structured correctly

**Performance Checks:**
- Group message delivery time < 2 seconds
- UI remains responsive with multiple group chats
- Presence updates timely for all members
- No excessive Firestore reads/writes
- App doesn't crash with large groups

**Dependencies:** All tasks in Phase 5

---

## Phase 5 Completion Checklist

Before moving to Phase 6, verify:
- [ ] Data models extended for group chat support
- [ ] GroupService implemented with creation and management methods
- [ ] Group creation UI functional (member selection + naming)
- [ ] ChatDetailView displays groups correctly with sender attribution
- [ ] GroupInfoView shows member list and group details
- [ ] Group message delivery tracked per member
- [ ] Group read receipts working (shows which members have read)
- [ ] Group typing indicators handle multiple simultaneous typists
- [ ] Conversation list displays groups with proper UI
- [ ] Group member presence visible in GroupInfoView
- [ ] Group notifications structured correctly (even if not fully implemented)
- [ ] Group messages work offline with proper sync
- [ ] Group search and filtering functional
- [ ] Comprehensive testing passed with 3+ simulators
- [ ] All group features stable and bug-free

---

## Deliverables

By the end of Phase 5, you should have:
1. Fully functional group chat with 3-10 participants
2. Group-specific UI elements (sender attribution, member list)
3. Per-member delivery and read tracking
4. Group typing indicators for multiple users
5. Group info view with member management
6. Offline support for all group features
7. Professional group messaging experience

---

## Known Limitations and Future Enhancements

- No group admin/member roles (all members have equal permissions)
- Cannot add/remove members after group creation
- No group photo upload (only placeholder)
- No group settings (mute, notifications)
- Group size limited to 10 participants (could be increased)
- No message reactions or threads within groups
- No @mentions for specific group members

---

## Notes for Next Phase

Phase 6 will add media support and polish:
- Image sending and receiving
- Image upload to Firebase Storage
- Image display in messages (thumbnails, full view)
- Push notification implementation (foreground and background)
- UI polish and animations
- Loading states and error handling refinements

The group chat infrastructure built in Phase 5 will seamlessly support image messages, as the Message model already includes imageUrl field. Focus will be on media handling, storage, and UI presentation.
