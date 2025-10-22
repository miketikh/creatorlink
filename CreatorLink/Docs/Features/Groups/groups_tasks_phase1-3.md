# Group Messaging Implementation Tasks (Phases 1-3)

## Overview

This document contains the implementation tasks for **Phases 1-3** of the group messaging feature. These phases establish the core foundation for group conversations:

- **Phase 1**: Group Creation UI - Allow users to create group conversations
- **Phase 2**: Group Avatar Display - Visual distinction for group chats with custom avatars
- **Phase 3**: Message Attribution - Show who sent each message in group conversations

These three phases deliver a complete, usable group messaging MVP. Users can create groups, see them visually distinguished in the conversation list, and identify who sent each message.

**Context**: This is part of the larger group messaging implementation documented in `groups_plan.md` and `groups_tasks.md`. For complete feature details, refer to those documents.

---

## Instructions for AI Agent

When implementing these tasks:
1. **Work sequentially** - Complete Phase 1 before Phase 2, etc.
2. **Test after each PR** - Follow the "What to Test" instructions to verify functionality
3. **Use existing patterns** - Reference similar service files (AuthService, MessageService) for code style
4. **Preserve existing functionality** - Don't break current one-on-one chat features
5. **Follow Swift/SwiftUI conventions** - Use @Observable for services, async/await for asynchronous operations

**File path conventions:**
- Services: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/`
- Views: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/`
- Models: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/`
- Components: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/`

---

## Phase 1: Group Creation UI

**Estimated Time:** 3-5 days

This phase enables users to create group conversations with multiple participants, including optional custom group naming and image URL input.

### PR 1.1: Add groupImageUrl Field to Data Model

**Goal:** Extend the Conversation model to support custom group images.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Conversation.swift`
- [ ] Add new optional field `let groupImageUrl: String?` after the `groupName` field
- [ ] Update the custom initializer to include `groupImageUrl: String? = nil` parameter
- [ ] Add `groupImageUrl` to the `CodingKeys` enum
- [ ] Update hash function if groupImageUrl affects UI rendering (likely not needed)
- [ ] Update equality operator if groupImageUrl affects comparison (likely not needed)

**What to Test:**
1. Build the app to verify no compilation errors
2. Verify existing conversations still load correctly
3. Check that Firestore sync doesn't break (backwards compatible)
4. Create a test conversation and verify groupImageUrl field can be nil

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Conversation.swift` - Add groupImageUrl field

**Notes:**
- This is a backwards-compatible addition - existing conversations without this field will have nil values
- The field will store either custom image URLs or UI Avatars API placeholder URLs
- Follow existing pattern for optional fields like groupName

---

### PR 1.2: Update ConversationService for Group Creation

**Goal:** Enhance the conversation creation service to accept optional group name and image URL.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift`
- [ ] Locate the `createConversation(participantIds:currentUserId:)` method
- [ ] Add two optional parameters: `groupName: String? = nil` and `groupImageUrl: String? = nil`
- [ ] Update the `conversationData` dictionary to include `groupImageUrl` field
  - Use `groupImageUrl ?? NSNull()` to handle nil values properly
- [ ] Update the returned Conversation object to include groupImageUrl parameter
- [ ] Add validation: if participantIds.count >= 3, ensure isGroupChat is true
- [ ] Add helper method `generateGroupPlaceholderUrl(groupName: String) -> String`
  - Use UI Avatars API: `https://ui-avatars.com/api/?name={firstLetter}&background=random`
  - Extract first letter from group name
  - Return formatted URL string

**What to Test:**
1. Create a conversation with 2 participants (one-on-one) - verify groupImageUrl is nil
2. Create a conversation with 3+ participants without custom image - verify placeholder URL generated
3. Create a conversation with 3+ participants with custom URL - verify custom URL saved
4. Verify conversations appear in Firestore with correct groupImageUrl field
5. Test with empty group name - should still generate placeholder

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift` - Update createConversation method and add placeholder generation

**Notes:**
- UI Avatars API is already used for user profile placeholders - follow same pattern
- Validate that custom URLs are properly formatted (basic URL validation)
- Placeholder generation should be deterministic based on group name
- Document the priority order: custom image → auto-generated placeholder

---

### PR 1.3: Create Multi-Select User List View

**Goal:** Build the first step of group creation - selecting multiple participants.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/NewGroupConversationView.swift`
- [ ] Import SwiftUI and Firebase frameworks
- [ ] Create `NewGroupConversationView` struct conforming to View
- [ ] Add `@State private var selectedUserIds: Set<String>` to track selections
- [ ] Add `@State private var users: [UserProfile]` for available users
- [ ] Add `@State private var isLoading = true` for loading state
- [ ] Add `@Environment(\.dismiss) var dismiss` for navigation
- [ ] Implement view body with:
  - NavigationStack with title "New Group"
  - Loading spinner while fetching users
  - List of users with custom row view showing checkbox
  - Selection indicator showing count: "X selected" in toolbar
  - "Next" button in toolbar (disabled if < 2 selected)
- [ ] Create helper view `SelectableUserRow(user:isSelected:)` component
  - Display user avatar, name, and checkmark when selected
  - Tap gesture to toggle selection
- [ ] Implement `fetchUsers() async` method
  - Fetch all users except current user using UserService
  - Update users array on main thread
- [ ] Implement `nextTapped()` method
  - Navigate to GroupNameInputView with selectedUserIds
- [ ] Add `.onAppear` to trigger user fetching

**What to Test:**
1. Open NewGroupConversationView from ChatsView
2. Verify all users (except current user) are displayed
3. Tap users to select/deselect them
4. Verify checkmarks appear for selected users
5. Verify selection count updates in toolbar
6. Verify "Next" button is disabled with 0-1 selections
7. Verify "Next" button is enabled with 2+ selections
8. Tap "Next" and verify navigation occurs (will fail until next PR)
9. Test with 10+ users to ensure scrolling works

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/NewGroupConversationView.swift` - NEW: Multi-select participant picker

**Notes:**
- Use Set<String> for selectedUserIds to prevent duplicates and enable efficient lookups
- Follow existing user list patterns from NewConversationView.swift
- Consider search functionality if user list is long (optional for MVP)
- Ensure proper loading states and error handling

---

### PR 1.4: Create Group Name and Image Input View

**Goal:** Build the second step of group creation - entering group name and optional image URL.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupNameInputView.swift`
- [ ] Import SwiftUI
- [ ] Create `GroupNameInputView` struct conforming to View
- [ ] Add initializer accepting `selectedUserIds: Set<String>` parameter
- [ ] Add `@State private var groupName: String = ""` for text input
- [ ] Add `@State private var groupImageUrl: String = ""` for image URL input
- [ ] Add `@State private var isCreating = false` for loading state
- [ ] Add `@State private var errorMessage: String?` for error display
- [ ] Add `@State private var showImagePreview = false` for preview toggle
- [ ] Add `@Environment(\.dismiss) var dismiss` for navigation
- [ ] Implement view body with:
  - NavigationStack with title "Group Details"
  - Form containing:
    - Section with TextField for group name (placeholder: "Group name (optional)")
    - Character limit indicator: "X/35 characters"
    - Section with TextField for image URL (placeholder: "Image URL (optional)")
    - "Preview Image" button (if URL is not empty)
    - Preview of image using AsyncImage (if showImagePreview)
    - Section showing selected participants (read-only, names only)
  - Toolbar with "Create" button (shows loading spinner if isCreating)
- [ ] Implement `createGroup() async` method
  - Validate group name length (max 35 characters)
  - Validate image URL format if provided (basic URL check)
  - Generate auto-name if groupName is empty: join first 3 participant display names
  - Add current user ID to participant list
  - Call `ConversationService.shared.createConversation()` with all parameters
  - Navigate back to ChatsView on success
  - Show error alert on failure
- [ ] Add `.onSubmit` to TextField for keyboard "done" button
- [ ] Add validation helper `isValidUrl(_ string: String) -> Bool`

**What to Test:**
1. Navigate from NewGroupConversationView with 2+ selected users
2. Leave group name empty and tap "Create"
3. Verify auto-generated name appears in conversation list (e.g., "Alice, Bob, Charlie")
4. Enter custom group name "Team Chat" and create
5. Verify custom name appears in conversation list
6. Test character limit - verify can't exceed 35 characters
7. Enter valid image URL and preview it
8. Verify preview shows the image correctly
9. Enter invalid URL and verify validation error
10. Create group with custom image URL
11. Verify group appears with custom image in conversation list
12. Test with very long auto-generated names (10+ participants)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupNameInputView.swift` - NEW: Group naming and image input screen

**Notes:**
- Auto-generated names should be comma-separated, e.g., "Alice, Bob, Charlie"
- Truncate auto-names if they exceed 35 characters
- Image URL validation should be basic (starts with http/https)
- Preview is helpful but optional - users can see result after creation
- Consider adding photo picker for uploading images (future enhancement)

---

### PR 1.5: Wire Up Group Creation Flow in ChatsView

**Goal:** Add "New Group" button to ChatsView and connect the entire creation flow.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatsView.swift`
- [ ] Locate the toolbar containing "New Message" button
- [ ] Add `@State private var showNewGroupSheet = false` for sheet presentation
- [ ] Add second toolbar button "New Group" with group icon (or "+" with badge)
- [ ] Add `.sheet(isPresented: $showNewGroupSheet)` modifier presenting NewGroupConversationView
- [ ] Ensure both "New Message" and "New Group" buttons are visible and distinct
- [ ] Consider UI: either two separate buttons or menu with options
- [ ] Optional: Add SF Symbol icons for clarity (person.2.fill for group)

**What to Test:**
1. Open ChatsView
2. Verify both "New Message" and "New Group" buttons are visible
3. Tap "New Group" button
4. Verify NewGroupConversationView sheet appears
5. Select 2+ users and tap "Next"
6. Verify GroupNameInputView appears
7. Enter group name and optional image URL
8. Tap "Create"
9. Verify sheet dismisses
10. Verify new group conversation appears at top of conversation list
11. Tap the group conversation
12. Verify ChatDetailView opens correctly
13. Send a message and verify it works
14. Create multiple groups and verify all appear correctly

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatsView.swift` - Add "New Group" button and sheet presentation

**Notes:**
- Consider using a Menu for "New Message" vs "New Group" to save toolbar space
- Icons help users understand the difference between one-on-one and group creation
- Ensure navigation stack properly handles going back through the flow
- Test with both simulator and physical device to ensure tap targets are reasonable

---

## Phase 2: Group Avatar Display

**Estimated Time:** 2-3 days

This phase adds visual distinction for group chats through custom avatars following the priority: custom image → composite → placeholder.

### PR 2.1: Create GroupAvatarView Component

**Goal:** Build a reusable component that displays group avatars with priority logic.

**Tasks:**
- [ ] Create new directory `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/` if it doesn't exist
- [ ] Create new file `GroupAvatarView.swift` in Components directory
- [ ] Import SwiftUI
- [ ] Create `GroupAvatarView` struct conforming to View
- [ ] Add initializer accepting parameters:
  - `groupImageUrl: String?` - Custom group image URL
  - `participantIds: [String]` - Array of participant IDs
  - `size: CGFloat` - Avatar size in points
- [ ] Add `@State private var participantPhotos: [String]` for loaded profile URLs
- [ ] Add `@State private var groupName: String?` for placeholder generation
- [ ] Implement priority logic in body:
  - **Priority 1**: If groupImageUrl exists, show AsyncImage with custom URL
  - **Priority 2**: If 3-4 participants, show CompositeAvatarView (next PR)
  - **Priority 3**: Otherwise, show placeholder using UI Avatars API
- [ ] Implement `fetchParticipantPhotos() async` method
  - Fetch up to 4 participant profiles using UserService
  - Extract photoURL from each profile
  - Update participantPhotos array
- [ ] Implement placeholder generation
  - If groupName available, use first letter
  - Otherwise use "G" for "Group"
  - Use UI Avatars API: `https://ui-avatars.com/api/?name={letter}&background=random&size={size}`
- [ ] Add `.onAppear` to trigger photo fetching
- [ ] Style with rounded corners, border, and proper sizing

**What to Test:**
1. Test with custom groupImageUrl - verify custom image displays
2. Test with invalid/broken groupImageUrl - verify fallback to composite/placeholder
3. Test with nil groupImageUrl and 3 participants - verify composite preview (will be implemented in next PR)
4. Test with nil groupImageUrl and 5+ participants - verify placeholder displays
5. Test with various sizes (30pt, 50pt, 100pt) - verify scales correctly
6. Test loading states - verify smooth transitions
7. Test with missing participant photos - verify graceful degradation

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/GroupAvatarView.swift` - NEW: Group avatar component with priority logic

**Notes:**
- AsyncImage handles loading and error states automatically
- Cache participant photos to avoid repeated fetches (consider using UserService cache)
- Ensure component is performant for list views with many groups
- Follow existing avatar styling patterns from user profile displays

---

### PR 2.2: Create CompositeAvatarView Component

**Goal:** Build a 2x2 grid layout showing 2-4 participant profile photos.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/CompositeAvatarView.swift`
- [ ] Import SwiftUI
- [ ] Create `CompositeAvatarView` struct conforming to View
- [ ] Add initializer accepting:
  - `photoUrls: [String]` - Array of up to 4 participant photo URLs
  - `size: CGFloat` - Total avatar size in points
- [ ] Implement grid layout logic:
  - If 2 photos: vertical 1x2 layout
  - If 3 photos: 2 top, 1 bottom center
  - If 4 photos: 2x2 grid
- [ ] Calculate individual photo size: `size / 2` for each cell
- [ ] Use LazyVGrid or custom HStack/VStack for layout
- [ ] For each photo, render AsyncImage with:
  - Aspect ratio .fill
  - Frame size of size/2
  - Clip shape (rounded corners on outer edges, sharp edges on inner edges)
  - Placeholder showing loading spinner or initials
- [ ] Add outer border and corner radius to entire composite
- [ ] Handle missing/broken image URLs gracefully

**What to Test:**
1. Test with 2 photos - verify vertical layout
2. Test with 3 photos - verify 2 top, 1 bottom center
3. Test with 4 photos - verify 2x2 grid
4. Test with various sizes (50pt, 80pt, 120pt) - verify proportions correct
5. Test with missing image URLs - verify placeholders appear
6. Test with slow loading images - verify loading states
7. Compare visually to other apps (WhatsApp, iMessage) for reference

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/CompositeAvatarView.swift` - NEW: Composite avatar grid component

**Notes:**
- Sharp edges on inner grid dividers, rounded corners only on outer edges
- Ensure grid gaps/spacing is minimal for tight composite look
- Consider using .clipShape with custom shape for precise corner control
- Performance: ensure smooth scrolling in conversation list

---

### PR 2.3: Integrate Group Avatars in ConversationRowView

**Goal:** Update conversation list to show group avatars instead of single user photos for group chats.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ConversationRowView.swift`
- [ ] Locate the existing profile photo display code (likely AsyncImage showing single user)
- [ ] Add conditional rendering based on `conversation.isGroupChat`:
  - **If group chat**: Show GroupAvatarView with conversation's groupImageUrl and participantIds
  - **If one-on-one**: Keep existing single user photo display
- [ ] Pass appropriate size parameter (likely 50-60pt for list rows)
- [ ] Ensure alignment and spacing matches existing design
- [ ] Update any related state variables needed for avatar loading
- [ ] Test that participant count logic works (3+ users show properly)

**What to Test:**
1. View conversation list with mix of one-on-one and group chats
2. Verify one-on-one chats still show single user photo
3. Verify group chats show appropriate avatar type:
   - Groups with custom image show custom image
   - Groups with 3-4 members (no custom image) show composite
   - Groups with 5+ members (no custom image) show placeholder
4. Verify avatars align properly with conversation names
5. Scroll through long list - verify smooth performance
6. Test with missing/broken image URLs - verify graceful fallback
7. Verify loading states don't cause layout shifts

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ConversationRowView.swift` - Add conditional group avatar rendering

**Notes:**
- Keep existing one-on-one logic unchanged to avoid breaking current functionality
- Group avatars may load async - ensure placeholder shows immediately
- Consider caching avatar components to improve scroll performance
- Match existing visual style (shadows, borders, spacing)

---

### PR 2.4: Update Chat Header with Group Avatar and Participant Count

**Goal:** Show group avatar and member count in the ChatDetailView header.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift`
- [ ] Locate the toolbar/header area (likely in `.toolbar` or `.navigationBarTitle`)
- [ ] Find where conversation/user name is displayed
- [ ] Add conditional rendering for group vs one-on-one:
  - **If group chat**: Show GroupAvatarView + group name + participant count
  - **If one-on-one**: Keep existing user photo + name
- [ ] Implement participant count display
  - Format: "· 5 members" or "5" with person icon
  - Place next to or below group name
  - Use subtle color (secondary text)
- [ ] Add `@State private var participantCount: Int` to track count
- [ ] Update count in `onAppear` or from conversation data
- [ ] Ensure header layout works on different device sizes
- [ ] Make header tappable (will navigate to GroupInfoView in Phase 5)

**What to Test:**
1. Open a group chat
2. Verify group avatar appears in header (custom, composite, or placeholder)
3. Verify group name displays correctly
4. Verify participant count shows correctly (e.g., "· 5 members")
5. Open different sized groups (3, 5, 10 members) - verify count updates
6. Open a one-on-one chat
7. Verify existing user photo + name still works
8. Test on different device sizes (iPhone SE, iPhone Pro Max, iPad)
9. Verify header doesn't overlap with safe areas
10. Tap header - verify it's tappable (nothing happens yet, just ensure tap registers)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` - Update header with group avatar and participant count

**Notes:**
- Header should be visually distinct from message area
- Participant count helps users quickly identify group size
- Tappable header will open GroupInfoView (Phase 5)
- Consider animation when avatar loads to avoid jarring appearance
- Match existing header height and padding

---

## Phase 3: Message Attribution in Groups

**Estimated Time:** 3-4 days

This phase adds sender identification to group messages so users know who sent each message.

### PR 3.1: Create MessageSenderHeaderView Component

**Goal:** Build a reusable component showing sender name above message bubbles.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/MessageSenderHeaderView.swift`
- [ ] Import SwiftUI
- [ ] Create `MessageSenderHeaderView` struct conforming to View
- [ ] Add initializer accepting:
  - `senderName: String` - Display name of message sender
  - `alignment: Alignment` - Leading (for others' messages) or trailing (shouldn't be used for current user)
- [ ] Implement view body:
  - Text showing sender name
  - Small font size (12-14pt)
  - Secondary or tertiary color
  - Proper horizontal alignment
  - Small padding
- [ ] Add conditional display logic (will be controlled by parent)
- [ ] Style to match message bubble alignment

**What to Test:**
1. Preview component in Xcode preview
2. Test with various name lengths (short, medium, long)
3. Test with leading alignment (for others' messages)
4. Verify text size and color are readable but subtle
5. Verify spacing doesn't push message bubbles too far apart

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/MessageSenderHeaderView.swift` - NEW: Sender name label component

**Notes:**
- This header only appears for messages from others, not current user
- Keep design minimal to avoid cluttering the chat
- Will be conditionally shown based on smart grouping logic (next PR)
- Follow existing text styling patterns in the app

---

### PR 3.2: Extend ChatViewModel with Sender Info Caching

**Goal:** Add logic to fetch and cache sender information for efficient message attribution.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift` (or create if doesn't exist)
- [ ] Add `@Published var senderProfiles: [String: UserProfile] = [:]` dictionary for caching
- [ ] Implement method `fetchSenderProfile(userId: String) async -> UserProfile?`
  - Check if profile exists in cache
  - If cached, return immediately
  - If not cached, fetch using `UserService.shared.fetchUser(userId:)`
  - Store in cache and return
  - Handle errors gracefully
- [ ] Implement method `getSenderName(userId: String) -> String`
  - Look up in cache
  - Return displayName if found
  - Return "Someone" as fallback
- [ ] Implement method `getSenderPhotoUrl(userId: String) -> String?`
  - Look up in cache
  - Return photoURL if found
  - Return nil as fallback
- [ ] Add helper `shouldShowSenderInfo(currentMessage: Message, previousMessage: Message?, currentUserId: String) -> Bool`
  - Return false if message is from current user
  - Return true if no previous message
  - Return true if previous sender is different
  - Return true if time gap > 2 minutes
  - Return false otherwise (smart grouping)

**What to Test:**
1. Open group chat with messages from multiple senders
2. Verify sender profiles are fetched and cached
3. Send rapid messages from same sender
4. Verify caching prevents repeated fetches (check network calls)
5. Test with missing/deleted users
6. Verify fallback names appear correctly
7. Test time gap logic - messages 3 minutes apart should show sender name

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift` - Add sender info caching and helper methods

**Notes:**
- Cache is essential for performance in large groups
- 2-minute time gap is a good balance (configurable if needed)
- Consider pre-fetching all group participants on chat open
- Memory management: consider clearing cache when leaving chat

---

### PR 3.3: Update MessageBubbleView with Sender Attribution

**Goal:** Show sender name and avatar for group messages using smart grouping logic.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift`
- [ ] Add new parameters to initializer:
  - `isGroupChat: Bool` - Whether this is a group conversation
  - `showSenderInfo: Bool` - Whether to show sender name/avatar (from smart grouping)
  - `senderName: String?` - Display name of sender
  - `senderPhotoUrl: String?` - Avatar URL of sender
  - `isCurrentUser: Bool` - Whether message is from current user
- [ ] Update view body structure:
  - Add outer VStack containing all message components
  - If `showSenderInfo && isGroupChat && !isCurrentUser`:
    - Show MessageSenderHeaderView at top
  - Add HStack containing:
    - If message from others in group, show small avatar (30pt) on left
    - Existing message bubble content
  - Ensure proper spacing and alignment
- [ ] Style avatar:
  - Circular, 30pt diameter
  - Aligned to bottom of message bubble
  - Only visible for group messages from others
- [ ] Update bubble alignment to account for avatar width
- [ ] Add padding/spacing so consecutive messages from same sender look grouped

**What to Test:**
1. Open group chat with multiple senders
2. Verify sender name appears when sender changes
3. Verify sender avatar appears on left for others' messages
4. Send consecutive messages from same sender within 2 minutes
5. Verify only first message shows sender name (smart grouping)
6. Wait 2+ minutes and send another message
7. Verify sender name reappears due to time gap
8. Open one-on-one chat
9. Verify no sender names or avatars appear (isGroupChat = false)
10. Verify current user's messages don't show their own name/avatar
11. Test with various message lengths and types

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift` - Add sender name and avatar for group messages

**Notes:**
- Avatar should be small and subtle - not competing with message content
- Smart grouping reduces visual clutter while maintaining clarity
- Current user's messages should never show attribution (they know they sent it)
- Ensure layout doesn't break with long names or missing avatars

---

### PR 3.4: Wire Up Message Attribution in ChatDetailView

**Goal:** Connect the message attribution components to the chat message list.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift`
- [ ] Locate the message list rendering (likely ForEach over messages)
- [ ] Add `@StateObject private var viewModel = ChatViewModel()` if not exists
- [ ] Pre-fetch all participant profiles in `onAppear`:
  - For each participantId in conversation, call `viewModel.fetchSenderProfile(userId:)`
  - This ensures sender info is cached before rendering
- [ ] Update message rendering loop to:
  - Determine `showSenderInfo` using `viewModel.shouldShowSenderInfo(currentMessage:previousMessage:currentUserId:)`
  - Fetch sender name using `viewModel.getSenderName(userId: message.senderId)`
  - Fetch sender photo using `viewModel.getSenderPhotoUrl(userId: message.senderId)`
  - Pass all new parameters to MessageBubbleView
- [ ] Ensure message list updates when new messages arrive
- [ ] Handle edge cases:
  - First message in conversation
  - Messages after long gaps
  - Rapid messages from multiple senders

**What to Test:**
1. Open group chat with existing messages
2. Verify sender names appear at appropriate times (first message, after sender change, after time gap)
3. Verify avatars align properly with message bubbles
4. Scroll through chat history
5. Verify smart grouping works correctly throughout history
6. Send new message from another device/user
7. Verify new message appears with correct attribution
8. Send multiple messages rapidly from different users
9. Verify attribution updates correctly in real-time
10. Test with 5+ participants sending messages
11. Verify performance remains smooth with many messages

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` - Wire up message attribution to message list

**Notes:**
- Pre-fetching profiles prevents loading flicker
- Consider scrolling impact - attribution should not cause layout shifts
- Real-time updates must maintain smart grouping logic
- Test with both new and existing conversations

---

### PR 3.5: Update Last Message Preview in ConversationRowView

**Goal:** Show sender name in last message preview for group chats.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ConversationRowView.swift`
- [ ] Locate the last message preview text
- [ ] Add conditional formatting based on `conversation.isGroupChat`:
  - **If group chat**: Prefix with sender name: "Alice: Hello everyone"
  - **If one-on-one**: Keep existing format (just message text)
- [ ] Add `@State private var lastMessageSenderName: String?` to track sender
- [ ] Implement `fetchLastMessageSender() async` method
  - Use conversation.lastMessageSenderId to fetch sender profile
  - Extract display name
  - Update state variable
- [ ] Add `.onAppear` or `.task` to trigger fetch
- [ ] Handle edge cases:
  - Current user sent last message: use "You" instead of name
  - Missing sender profile: show message without prefix
  - Empty message or no messages yet
- [ ] Ensure text truncates properly if sender name + message is too long

**What to Test:**
1. View conversation list with multiple group chats
2. Verify last message shows format: "Alice: Message text"
3. Send message in group from current user
4. Verify last message shows: "You: Message text"
5. Test with very long sender names
6. Verify truncation works correctly
7. Test with empty messages or missing sender data
8. Open one-on-one chat and send message
9. Verify no sender prefix appears (not a group)
10. Compare with other apps (WhatsApp, Telegram) for UX reference

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ConversationRowView.swift` - Add sender name to last message preview for groups

**Notes:**
- "You:" for current user is more natural than showing your own name
- Truncation should favor showing message content over full sender name
- Consider caching sender names to avoid repeated fetches
- This small detail significantly improves group chat UX

---

## Summary

After completing these three phases, users will be able to:

1. **Create group conversations** with multiple participants, optional custom names, and custom image URLs
2. **Visually distinguish** group chats from one-on-one chats in the conversation list through custom avatars
3. **Identify message senders** in group conversations through smart attribution with names and avatars

These phases establish the foundation for a complete group messaging experience. The remaining phases (4-10) build on this foundation with enhanced features like typing indicators, group management, read receipts, and polish.

**Next Steps:** After completing Phase 3, proceed to Phase 4 (Enhanced Typing Indicators) in the complete `groups_tasks.md` document.
