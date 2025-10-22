# Group Messaging Implementation Tasks: Phases 4-6

## Context

This document covers **Phases 4-6** of the group messaging implementation for CreatorLink. These phases focus on enhancing the group chat experience with improved typing indicators, comprehensive group information management, and participant management features.

**What these phases provide:**
- **Phase 4:** Enhanced typing indicators displaying multiple simultaneous typers intelligently
- **Phase 5:** Group information screen for viewing and editing group details
- **Phase 6:** Adding and removing participants from existing groups

**Prerequisites:**
- Phases 1-3 must be completed first:
  - Phase 1: Group creation UI with multi-select and custom naming/images
  - Phase 2: Group avatar display with composite/placeholder support
  - Phase 3: Message attribution showing sender names/avatars in groups

**Architecture notes:**
- Uses existing Firebase infrastructure (Firestore + Realtime Database)
- TypingService already returns array of typing user IDs
- ConversationService has updateGroupName() method
- Services are group-compatible; focus is on UI/UX refinement

---

## Instructions for AI Agent

When implementing these tasks:
1. **Work sequentially** - Complete Phase 4 before Phase 5, etc.
2. **Test after each PR** - Follow the "What to Test" instructions thoroughly
3. **Use existing patterns** - Reference similar components and services
4. **Preserve existing functionality** - Don't break one-on-one chat features
5. **Follow Swift/SwiftUI conventions** - Use @Observable for view models, async/await for operations

**File path conventions:**
- Services: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/`
- Views: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/`
- ViewModels: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/`
- Components: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/`

---

## Phase 4: Enhanced Typing Indicators for Groups

**Estimated Time:** 1-2 days

This phase improves typing indicator UX when multiple users are typing simultaneously.

### PR 4.1: Update Typing Indicator Formatting Logic

**Goal:** Enhance typing indicator to intelligently display multiple typers.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift`
- [ ] Locate typing-related code (may be in TypingService or ChatViewModel)
- [ ] Add method `formatTypingIndicatorText(typingUserIds: [String], currentUserId: String) -> String`
  - Filter out current user from typing list
  - Fetch display names for all typing users
  - Implement formatting rules:
    - **0 typers**: Return empty string (hide indicator)
    - **1 typer**: Return "{Name} is typing..."
    - **2 typers**: Return "{Name1} and {Name2} are typing..."
    - **3+ typers**: Return "{Name1}, {Name2}, and X others are typing..."
  - Handle missing names gracefully (fallback to "Someone")
- [ ] Add helper `shouldShowTypingIndicator(typingUsers: [String]) -> Bool`
  - Return true if typingUsers array is not empty
- [ ] Consider adding `getTypingUserAvatars(typingUserIds: [String]) -> [String]`
  - Fetch up to 3 avatar URLs for visual indicator
  - Return array of photo URLs

**What to Test:**
1. Manually test formatting function with various inputs:
   - Empty array: verify returns ""
   - One user: verify "Alice is typing..."
   - Two users: verify "Alice and Bob are typing..."
   - Three users: verify "Alice, Bob, and 1 other are typing..."
   - Five users: verify "Alice, Bob, and 3 others are typing..."
2. Test with missing user profiles
3. Test with very long user names
4. Verify grammatically correct pluralization

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift` - Add typing indicator formatting logic

**Notes:**
- Proper pluralization matters for polish ("is" vs "are")
- Showing 2 names explicitly helps users know who's typing
- "X others" for 3+ keeps text compact
- Consider performance if many users typing simultaneously

---

### PR 4.2: Update TypingIndicatorView with Enhanced Display

**Goal:** Update the typing indicator UI to show formatted text and optional avatars.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/TypingIndicatorView.swift`
- [ ] Review current implementation (likely shows basic text)
- [ ] Add parameters to initializer:
  - `typingUserNames: [String]` or `formattedText: String`
  - `typingUserAvatars: [String]?` (optional, for avatar display)
  - `isGroupChat: Bool` (to determine whether to show enhanced version)
- [ ] Update view body:
  - If `isGroupChat`, show enhanced layout:
    - HStack with small avatar thumbnails (if avatars provided)
    - Formatted typing text
    - Typing animation (three dots)
  - If not group chat, keep simple existing display
- [ ] Style avatars:
  - Small size (20-24pt)
  - Circular
  - Overlapping if multiple avatars
  - Max 3 avatars shown
- [ ] Ensure animation continues to work
- [ ] Add proper spacing and padding
- [ ] Consider background color/blur for visibility over messages

**What to Test:**
1. Open group chat
2. Have one person type from another device
3. Verify indicator shows "{Name} is typing..."
4. Have second person start typing
5. Verify indicator updates to "{Name1} and {Name2} are typing..."
6. Have third person start typing
7. Verify indicator shows "{Name1}, {Name2}, and 1 other are typing..."
8. Verify avatars display correctly (if implemented)
9. Stop all typing
10. Verify indicator disappears smoothly
11. Test rapid typing start/stop from multiple users
12. Open one-on-one chat and verify existing typing indicator still works

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/TypingIndicatorView.swift` - Enhance typing indicator UI

**Notes:**
- Typing state changes frequently - ensure smooth animations
- Overlapping avatars give visual hint of multiple typers
- Background blur/color helps typing indicator stand out
- Keep consistent with message bubble styling

---

### PR 4.3: Wire Up Enhanced Typing Indicators in ChatDetailView

**Goal:** Connect the enhanced typing logic to the chat view.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift`
- [ ] Locate existing typing indicator implementation
- [ ] Update to use new formatting logic:
  - Fetch typing user IDs from TypingService
  - Pass to `viewModel.formatTypingIndicatorText()`
  - Get formatted text
  - Optional: fetch typing user avatars
  - Pass formatted text and avatars to TypingIndicatorView
- [ ] Ensure real-time updates work correctly
- [ ] Add `isGroupChat` parameter based on conversation
- [ ] Test that indicator appears/disappears smoothly
- [ ] Verify indicator doesn't push input field off screen

**What to Test:**
1. Open group chat on Device A
2. Start typing on Device B
3. Verify indicator appears on Device A with correct text
4. Start typing on Device C while B is still typing
5. Verify indicator updates to show both names
6. Stop typing on Device B
7. Verify indicator updates to show only Device C
8. Stop all typing
9. Verify indicator disappears
10. Test with 5+ simultaneous typers
11. Verify UI doesn't break or overflow
12. Test performance - should be smooth with no lag

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` - Wire up enhanced typing indicators

**Notes:**
- Real-time updates should be debounced to avoid flicker
- Consider accessibility: VoiceOver should announce typers
- Typing state in Firebase RTDB expires after 5 seconds automatically
- Test with slow network to ensure degraded experience is acceptable

---

## Phase 5: Group Information Screen

**Estimated Time:** 3-4 days

This phase adds a dedicated screen to view and manage group details, accessible by tapping the group header.

### PR 5.1: Create GroupInfoViewModel

**Goal:** Build the view model to handle group information business logic.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/GroupInfoViewModel.swift`
- [ ] Import Foundation, Combine, and Firebase frameworks
- [ ] Create `@Observable class GroupInfoViewModel`
- [ ] Add properties:
  - `var participants: [UserProfile] = []` - List of group members
  - `var groupName: String` - Editable group name
  - `var groupImageUrl: String` - Editable group image URL
  - `var isLoading = false` - Loading state
  - `var errorMessage: String?` - Error display
- [ ] Add initializer accepting `conversation: Conversation`
- [ ] Implement `loadParticipants() async` method
  - Fetch UserProfile for each participantId
  - Update participants array
  - Handle errors
- [ ] Implement `updateGroupName(conversationId: String, newName: String) async throws` method
  - Validate name (max 35 characters, not empty)
  - Call ConversationService to update
  - Handle errors
- [ ] Implement `updateGroupImage(conversationId: String, newImageUrl: String) async throws` method
  - Validate URL format
  - Call ConversationService to update
  - Handle errors
- [ ] Implement `leaveGroup(conversationId: String, userId: String) async throws` method
  - Will be implemented in Phase 6 with add/remove logic
  - For now, add TODO comment

**What to Test:**
1. Create GroupInfoViewModel with test conversation
2. Call loadParticipants() and verify profiles are fetched
3. Test updateGroupName with valid name
4. Verify name update succeeds
5. Test updateGroupName with invalid name (too long, empty)
6. Verify validation errors
7. Test updateGroupImage with valid URL
8. Verify image update succeeds
9. Test updateGroupImage with invalid URL
10. Verify validation errors

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/GroupInfoViewModel.swift` - NEW: Group info business logic

**Notes:**
- Follow existing view model patterns in the codebase
- Error handling should be user-friendly
- Consider caching participant data to avoid repeated fetches
- Async methods should update isLoading state appropriately

---

### PR 5.2: Create ParticipantRowView Component

**Goal:** Build a reusable list row component for displaying group participants.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/ParticipantRowView.swift`
- [ ] Import SwiftUI
- [ ] Create `ParticipantRowView` struct conforming to View
- [ ] Add initializer accepting:
  - `participant: UserProfile` - User to display
  - `showOnlineStatus: Bool = true` - Whether to show online indicator
  - `isCurrentUser: Bool = false` - Whether this is the current user
- [ ] Implement view body:
  - HStack containing:
    - User avatar (AsyncImage, 40-50pt)
    - VStack with:
      - Display name (bold if current user)
      - Online status indicator (green dot + "Online" or "Last seen: X")
      - Optional: "You" label if isCurrentUser
  - Chevron icon on trailing edge (for navigation)
- [ ] Add proper spacing and padding
- [ ] Style online indicator with green circle or text
- [ ] Support tap gesture (will be wired up in parent view)

**What to Test:**
1. Preview component with test user data
2. Test with online user - verify green indicator
3. Test with offline user - verify "Last seen" text
4. Test with current user - verify "You" label appears
5. Test with long display names - verify truncation
6. Test with missing avatar - verify placeholder shows
7. Test different sizes and layouts

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/ParticipantRowView.swift` - NEW: Participant list row component

**Notes:**
- Follow existing user list item patterns
- Online status uses existing PresenceService data
- Consider adding role indicator (admin, member) in future
- Ensure tap targets are large enough (min 44pt)

---

### PR 5.3: Create GroupInfoView Screen

**Goal:** Build the main group information screen with editable details and participant list.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift`
- [ ] Import SwiftUI
- [ ] Create `GroupInfoView` struct conforming to View
- [ ] Add initializer accepting `conversation: Conversation` parameter
- [ ] Add `@StateObject private var viewModel: GroupInfoViewModel`
- [ ] Add `@State private var isEditingName = false` for edit mode
- [ ] Add `@State private var isEditingImage = false` for edit mode
- [ ] Add `@State private var showLeaveConfirmation = false` for alert
- [ ] Add `@State private var imagePreviewUrl: String?` for preview
- [ ] Add `@Environment(\.dismiss) var dismiss` for navigation
- [ ] Implement view body with ScrollView containing:
  - **Header Section**:
    - Large group avatar (120pt, centered)
    - Tap gesture to preview/edit image
    - If isEditingImage, show TextField for URL input
  - **Group Name Section**:
    - Display group name
    - Edit button → shows TextField when tapped
    - Save/Cancel buttons in edit mode
  - **Participants Section**:
    - Section header: "X MEMBERS"
    - List of participants using ParticipantRowView
    - Each participant tappable to view profile or message directly
  - **Actions Section**:
    - "Add Participants" button (will be implemented Phase 6)
    - "Leave Group" button (destructive style)
- [ ] Implement `saveGroupName() async` method
  - Call viewModel.updateGroupName()
  - Show error if fails
  - Exit edit mode on success
- [ ] Implement `saveGroupImage() async` method
  - Validate URL
  - Call viewModel.updateGroupImage()
  - Show error if fails
  - Exit edit mode on success
- [ ] Implement `leaveGroupTapped()` method
  - Show confirmation alert
  - On confirm, call viewModel.leaveGroup() (TODO in Phase 6)
  - Dismiss view on success
- [ ] Add `.task` modifier to load participants on appear

**What to Test:**
1. Open group chat and tap header
2. Verify GroupInfoView appears
3. Verify group avatar displays correctly (custom, composite, or placeholder)
4. Verify group name shows correctly
5. Tap "Edit" on group name
6. Change name and tap "Save"
7. Verify name updates in header and conversation list
8. Tap group avatar
9. Enter new image URL
10. Verify preview shows the new image
11. Save and verify avatar updates throughout app
12. Scroll through participant list
13. Verify all members displayed with correct online status
14. Verify current user shows "You" indicator
15. Tap "Leave Group" button
16. Verify confirmation alert appears
17. Cancel and verify nothing happens
18. Test edit validation (empty name, too long, invalid URL)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift` - NEW: Group information and settings screen

**Notes:**
- Use Form or List for clean iOS-style layout
- Editing should feel natural (inline editing preferred)
- Confirmation alert for destructive actions is essential
- Consider photo picker integration for uploading images (future)
- Real-time updates: if someone else edits group, should reflect immediately

---

### PR 5.4: Make Chat Header Tappable to Open GroupInfoView

**Goal:** Enable navigation from chat header to group info screen.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift`
- [ ] Locate the header/toolbar area with group name and avatar
- [ ] Add `@State private var showGroupInfo = false` for sheet presentation
- [ ] Add `.onTapGesture` modifier to header area (only for group chats)
- [ ] In tap handler, set `showGroupInfo = true`
- [ ] Add `.sheet(isPresented: $showGroupInfo)` modifier presenting GroupInfoView
- [ ] Pass conversation to GroupInfoView
- [ ] Ensure one-on-one chats don't have tappable header (or navigate to user profile instead)
- [ ] Add visual hint that header is tappable (subtle chevron or highlight on press)

**What to Test:**
1. Open group chat
2. Tap the header (group name/avatar area)
3. Verify GroupInfoView sheet appears
4. Verify correct group information displayed
5. Dismiss sheet and verify returns to chat
6. Open one-on-one chat
7. Verify header is not tappable (or navigates to user profile)
8. Test on different device sizes
9. Verify tap target is large enough
10. Test rapid tapping - should not open multiple sheets

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` - Make group header tappable

**Notes:**
- Sheet presentation is better than navigation push for info screens
- Consider haptic feedback on tap for better UX
- Ensure sheet dismisses properly when leaving group (Phase 6)
- One-on-one chats could navigate to user profile (optional enhancement)

---

### PR 5.5: Update ConversationService with Group Edit Methods

**Goal:** Add service methods for updating group name and image URL.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift`
- [ ] Locate existing `updateGroupName()` method (mentioned in plan as already implemented)
- [ ] Review and enhance if needed:
  - Ensure it validates name length (max 35 characters)
  - Ensure it handles errors properly
  - Ensure it updates Firestore document
- [ ] Add new method `updateGroupImageUrl(conversationId: String, imageUrl: String?) async throws`
  - Validate URL format if not nil
  - Update Firestore document field `groupImageUrl`
  - Handle errors with proper error types
- [ ] Add validation helper `validateImageUrl(_ url: String?) -> Bool`
  - Return true if nil (allowing removal)
  - Return true if starts with "http://" or "https://"
  - Return false otherwise
- [ ] Consider adding method `updateGroupDetails(conversationId: String, name: String?, imageUrl: String?) async throws`
  - Update multiple fields in single transaction
  - More efficient than separate updates

**What to Test:**
1. Call updateGroupName with valid name
2. Verify Firestore document updates
3. Call updateGroupName with invalid name (too long)
4. Verify error is thrown
5. Call updateGroupImageUrl with valid URL
6. Verify Firestore document updates
7. Call updateGroupImageUrl with nil
8. Verify field is cleared in Firestore
9. Call updateGroupImageUrl with invalid URL
10. Verify error is thrown
11. Test concurrent updates from multiple devices
12. Verify last write wins (expected Firestore behavior)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift` - Add group image update method and enhance existing methods

**Notes:**
- Firestore security rules must allow participants to update group details
- Consider adding audit log (who changed what when) in future
- URL validation should be basic - image loading handles broken URLs gracefully
- Batch updates reduce Firestore write operations

---

## Phase 6: Add/Remove Participants

**Estimated Time:** 2-3 days

This phase enables managing group membership after creation, including adding new members and removing existing ones.

### PR 6.1: Add Participant Management Methods to ConversationService

**Goal:** Implement service methods for adding and removing group participants.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift`
- [ ] Implement `addParticipant(conversationId: String, userId: String, currentUserId: String) async throws`
  - Validate currentUserId is in the group (authorization check)
  - Fetch conversation document
  - Check if userId is already in participantIds
  - If not, append to participantIds array
  - Update Firestore document with new participantIds
  - Handle errors appropriately
- [ ] Implement `removeParticipant(conversationId: String, userId: String, currentUserId: String) async throws`
  - Validate currentUserId is in the group
  - Prevent removing oneself (must use leaveGroup instead)
  - Fetch conversation document
  - Remove userId from participantIds array
  - Update Firestore document
  - Handle errors
- [ ] Implement `leaveGroup(conversationId: String, userId: String) async throws`
  - Remove userId from participantIds
  - If participantIds becomes empty, optionally delete conversation
  - Update Firestore document
  - Handle errors
- [ ] Optional: Add method `createSystemMessage(conversationId: String, text: String) async throws`
  - Create system message like "{Name} joined the group" or "{Name} left the group"
  - Use special message type or sender ID (e.g., "system")
  - Store in messages collection

**What to Test:**
1. Call addParticipant with valid user
2. Verify user is added to participantIds array in Firestore
3. Attempt to add user already in group
4. Verify no duplicate is created
5. Call removeParticipant with valid user
6. Verify user is removed from participantIds
7. Attempt to remove yourself using removeParticipant
8. Verify error is thrown (must use leaveGroup)
9. Call leaveGroup as a participant
10. Verify you are removed from group
11. Test with last person leaving
12. Verify conversation handling (delete or keep)
13. Test authorization - ensure non-participants cannot modify

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift` - Add participant management methods

**Notes:**
- Firestore security rules must enforce participant authorization
- System messages improve UX by showing membership changes
- Consider atomicity - use Firestore transactions if needed
- Handle edge case: concurrent add/remove operations
- Validate user exists before adding to group

---

### PR 6.2: Update MessageService to Handle Participant Changes

**Goal:** Ensure messages are properly filtered when participants change.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/MessageService.swift`
- [ ] Review existing message queries
- [ ] Verify queries use `participantIds` array for filtering
- [ ] Ensure real-time listeners update when participant list changes
- [ ] Consider: When participant is removed, do they keep message history?
  - Current implementation likely keeps history (messages already synced)
  - New messages should not appear (not in participantIds)
- [ ] Optional: Add method to update message participantIds if needed
  - May be required if messages need to reflect current participant list
  - Bulk update could be expensive - evaluate necessity
- [ ] Test listener behavior when removed from group

**What to Test:**
1. Join a group and verify you see all messages
2. Have another user remove you from group
3. Verify you stop receiving new messages
4. Verify you can still see old messages (if that's desired behavior)
5. Attempt to send message after being removed
6. Verify error or prevention mechanism works
7. Add user back to group
8. Verify they start receiving messages again
9. Test with multiple concurrent participants being added/removed

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/MessageService.swift` - Verify and update message filtering for participant changes

**Notes:**
- Decision needed: Should removed users lose access to message history?
- Current Firestore structure likely allows historical access (messages already synced locally)
- Preventing new message access is priority
- Security rules should enforce participantIds check for reading messages
- Consider implications for privacy and data retention

---

### PR 6.3: Create AddParticipantsView Screen

**Goal:** Build UI for selecting and adding new participants to existing group.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/AddParticipantsView.swift`
- [ ] Import SwiftUI
- [ ] Create `AddParticipantsView` struct conforming to View
- [ ] Add initializer accepting:
  - `conversation: Conversation` - The group to add participants to
  - `existingParticipantIds: [String]` - Current members to filter out
- [ ] Add `@State private var selectedUserIds: Set<String>` for selections
- [ ] Add `@State private var availableUsers: [UserProfile]` for user list
- [ ] Add `@State private var isLoading = true` for loading state
- [ ] Add `@State private var isAdding = false` for add operation state
- [ ] Add `@Environment(\.dismiss) var dismiss` for navigation
- [ ] Implement view body:
  - NavigationStack with title "Add Participants"
  - Loading spinner while fetching users
  - List of available users (filtered to exclude existing participants)
  - Checkboxes for multi-select
  - Selection count in toolbar
  - "Add" button in toolbar (disabled if none selected)
- [ ] Implement `fetchAvailableUsers() async` method
  - Fetch all users
  - Filter out users already in existingParticipantIds
  - Update availableUsers array
- [ ] Implement `addSelectedParticipants() async` method
  - For each selected user, call `ConversationService.shared.addParticipant()`
  - Show error if any fail
  - Dismiss view on success
  - Optional: Create system message for each added user
- [ ] Add `.task` modifier to load users on appear

**What to Test:**
1. Open GroupInfoView and tap "Add Participants"
2. Verify AddParticipantsView appears
3. Verify only users NOT in group are shown
4. Select multiple users
5. Verify selection count updates
6. Tap "Add" button
7. Verify users are added to group
8. Verify system messages appear (if implemented)
9. Return to GroupInfoView
10. Verify participant list now includes new members
11. Test with no available users (everyone already in group)
12. Verify appropriate empty state or message
13. Test adding users while another admin adds different users
14. Verify concurrent adds work correctly

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/AddParticipantsView.swift` - NEW: Add participants selection screen

**Notes:**
- Similar to NewGroupConversationView but filters existing members
- Consider search functionality for large user lists
- System messages help communicate membership changes
- Error handling for failed adds is important
- Consider limiting group size (e.g., max 50 members)

---

### PR 6.4: Wire Up Add Participants Flow in GroupInfoView

**Goal:** Enable adding participants from the group info screen.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift`
- [ ] Locate the "Add Participants" button section
- [ ] Add `@State private var showAddParticipants = false` for sheet presentation
- [ ] Wire up button tap to set `showAddParticipants = true`
- [ ] Add `.sheet(isPresented: $showAddParticipants)` presenting AddParticipantsView
- [ ] Pass conversation and current participantIds to AddParticipantsView
- [ ] Ensure participant list refreshes after adding new members
- [ ] Add visual feedback during add operation

**What to Test:**
1. Open GroupInfoView
2. Tap "Add Participants" button
3. Verify AddParticipantsView appears
4. Add one or more users
5. Dismiss sheet
6. Verify GroupInfoView participant list updates immediately
7. Verify new members appear with correct online status
8. Send message in group
9. Verify new members receive the message
10. Test on another device as new member
11. Verify they can see and participate in conversation

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift` - Wire up add participants flow

**Notes:**
- Real-time updates should reflect new participants immediately
- Consider showing a success message when participants are added
- New members should see group details and participant list
- Ensure smooth navigation flow (sheet within sheet)

---

### PR 6.5: Implement Remove Participant and Leave Group

**Goal:** Add functionality to remove participants and leave groups.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift`
- [ ] Update ParticipantRowView tap action or add context menu:
  - On long-press, show context menu with options:
    - "View Profile" (navigate to user profile if exists)
    - "Message Directly" (create/open one-on-one conversation)
    - "Remove from Group" (only if not current user, red/destructive)
- [ ] Implement `removeParticipant(userId: String) async` method
  - Show confirmation alert
  - Call `ConversationService.shared.removeParticipant()`
  - Update participant list
  - Show error if fails
  - Optional: Create system message "{Name} was removed"
- [ ] Update "Leave Group" button implementation in GroupInfoViewModel
  - Call `ConversationService.shared.leaveGroup()`
  - Dismiss GroupInfoView
  - Dismiss ChatDetailView (navigate back to ChatsView)
  - Remove conversation from local list
  - Optional: Create system message "{Name} left the group"
- [ ] Handle edge cases:
  - Last person leaving - decide whether to delete conversation
  - Being removed while viewing group
  - Concurrent removals

**What to Test:**
1. Open GroupInfoView as group member
2. Long-press another participant
3. Verify context menu appears with options
4. Tap "Remove from Group"
5. Verify confirmation alert appears
6. Confirm removal
7. Verify participant is removed from list
8. Verify removed user stops receiving messages
9. On removed user's device, verify group conversation disappears or becomes read-only
10. Tap "Leave Group" button
11. Verify confirmation alert appears
12. Confirm leaving
13. Verify you return to ChatsView
14. Verify group conversation no longer appears in your list
15. On another device in group, verify you no longer appear in participant list
16. Test as last person - verify conversation handling

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift` - Add remove participant and leave group functionality
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/GroupInfoViewModel.swift` - Implement leave group logic

**Notes:**
- Confirmation alerts are critical for destructive actions
- Navigation after leaving group should be smooth (pop back to ChatsView)
- Consider permissions: only admins can remove others (if role system exists)
- Real-time updates: removed users should see immediate effect
- System messages help group understand membership changes
- Handle re-joining: can removed users be added back? (answer: yes, via add flow)

---

## Next Steps

After completing Phases 4-6:
- **Phase 7:** Read Receipts for Groups - Adapt read receipt display for multiple readers
- **Phase 8:** Unread Badge Optimization - Fine-tune unread logic for group conversations
- **Phase 9:** Group-Specific Notifications - Customize notification behavior for groups
- **Phase 10:** Polish and Edge Cases - Handle remaining edge cases and improve UX

Refer to the main `groups_tasks.md` document for complete implementation details of all phases.

---

**Document Version:** 1.0
**Date:** 2025-10-22
**Phases Covered:** 4-6 (Enhanced Typing, Group Info, Participant Management)
**Prerequisites:** Phases 1-3 must be completed first
