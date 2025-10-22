# Group Messaging Implementation Tasks

## Context

This document provides step-by-step implementation tasks for adding group messaging functionality to CreatorLink, a Swift/SwiftUI iOS messaging app. Group messaging allows multiple users (3+) to participate in a single conversation thread, extending the existing one-on-one chat functionality.

**What this provides:**
- Create group conversations with 3+ participants
- Visual distinction between group and one-on-one chats with custom avatars
- Group-aware typing indicators showing who is typing
- Custom group image upload or URL input
- Message attribution showing who sent each message in groups
- Proper read receipt handling for multiple users
- Group management (add/remove participants, edit group details)
- Group information screen showing all participants

**Key architectural notes:**
- Data models already support groups (isGroupChat, groupName fields exist)
- Services (MessageService, ConversationService) are group-compatible
- Implementation focuses on UI/UX and missing group-specific features
- Uses existing Firebase infrastructure (Firestore + Realtime Database)

This implementation is broken into 10 phases following the group messaging plan. Each phase builds on the previous and can be tested independently.

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

## Phase 7: Read Receipts for Groups

**Estimated Time:** 2-3 days

This phase adapts read receipt display for multiple readers in group conversations.

### PR 7.1: Update Message Status Display for Groups

**Goal:** Show read count instead of simple checkmarks for group messages.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift`
- [ ] Locate existing message status indicator (checkmarks for delivered/read)
- [ ] Add new parameters to initializer:
  - `isGroupChat: Bool` - Whether this is a group conversation
  - `readCount: Int?` - Number of participants who read the message
  - `deliveredCount: Int?` - Number of participants who received the message
  - `totalParticipants: Int?` - Total number of participants (excluding sender)
- [ ] Update status indicator logic:
  - **If one-on-one**: Keep existing checkmarks (✓ or ✓✓)
  - **If group**: Show "✓✓ X" where X is read count
  - Only show for messages from current user (others don't see their own read stats)
- [ ] Style the read count:
  - Small font (10-12pt)
  - Secondary color
  - Positioned near checkmarks
- [ ] Make status indicator tappable (for details in next PR)
- [ ] Add `@Binding var showReadDetails: Bool?` for tap handling

**What to Test:**
1. Send message in one-on-one chat
2. Verify existing checkmark behavior works (✓ for delivered, ✓✓ for read)
3. Send message in group chat
4. Verify status shows "✓✓ 0" initially (no reads yet)
5. Have one person read the message
6. Verify status updates to "✓✓ 1"
7. Have more people read
8. Verify count increments correctly
9. Verify status only shows for your own messages (not others')
10. Test with various group sizes (3, 5, 10 members)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift` - Update status indicator for group read counts

**Notes:**
- Read count calculation needs to query message.readBy dictionary
- Exclude sender from count (sender doesn't "read" their own message)
- Real-time updates should reflect when more people read
- Consider showing "✓✓ 3 of 5" for clarity (optional)

---

### PR 7.2: Add Read Count Calculation to ChatViewModel

**Goal:** Add logic to calculate and track read counts for messages.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift`
- [ ] Add method `calculateReadCount(message: Message, currentUserId: String) -> Int`
  - Access message.readBy dictionary (if exists)
  - Count entries excluding currentUserId
  - Return count
- [ ] Add method `calculateDeliveredCount(message: Message, currentUserId: String) -> Int`
  - Determine delivered based on message status
  - For groups, may need to track per-user delivery (future enhancement)
  - For now, return simplified count
- [ ] Add method `getTotalParticipantCount(conversation: Conversation, currentUserId: String) -> Int`
  - Return conversation.participantIds.count - 1 (excluding current user)
- [ ] Consider caching read counts to avoid repeated calculations
- [ ] Ensure real-time updates trigger recalculation

**What to Test:**
1. Create test message with readBy dictionary
2. Call calculateReadCount and verify correct count
3. Test with various readBy states (0 reads, partial reads, all reads)
4. Verify currentUserId is excluded from count
5. Test performance with large groups (20+ participants)
6. Verify caching works correctly (if implemented)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift` - Add read count calculation methods

**Notes:**
- message.readBy is a dictionary: [userId: timestamp]
- Excluding sender is important for accurate count
- Real-time listener should update readBy when users read messages
- Consider performance: calculating for every message in long conversations

---

### PR 7.3: Create MessageReadDetailsView Sheet

**Goal:** Build a sheet showing detailed read/delivered status for each participant.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/MessageReadDetailsView.swift`
- [ ] Import SwiftUI
- [ ] Create `MessageReadDetailsView` struct conforming to View
- [ ] Add initializer accepting:
  - `message: Message` - The message to show details for
  - `participants: [UserProfile]` - List of group participants
- [ ] Add `@State private var readStatuses: [String: ReadStatus]` for tracking
- [ ] Define enum `ReadStatus`: case read(Date), delivered, sent, unread
- [ ] Implement view body:
  - NavigationStack with title "Message Info"
  - List divided into sections:
    - **Read by (X)**: Users who read the message with timestamp
    - **Delivered to (X)**: Users who received but haven't read
    - **Not delivered (X)**: Users who haven't received (if applicable)
  - Each row shows: avatar, name, status text, timestamp
- [ ] Implement `loadReadStatuses() async` method
  - For each participant, determine status from message.readBy
  - Update readStatuses dictionary
- [ ] Sort sections:
  - Most recent reads at top
  - Alphabetically within sections
- [ ] Add `.task` modifier to load statuses on appear

**What to Test:**
1. Send message in group
2. Tap message status indicator
3. Verify MessageReadDetailsView appears
4. Initially, verify all users in "Not delivered" or "Delivered to"
5. Have one user read the message
6. Verify their name moves to "Read by" section with timestamp
7. Have more users read
8. Verify list updates in real-time
9. Verify timestamps are accurate and formatted nicely (e.g., "10:30 AM")
10. Test with large group (10+ members)
11. Verify scrolling and performance are good

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/MessageReadDetailsView.swift` - NEW: Read receipt details sheet

**Notes:**
- Real-time updates are important - users may be reading while viewing details
- Timestamps should be relative or absolute based on recency
- Consider accessibility: VoiceOver should announce status changes
- Privacy consideration: some users may not want detailed read tracking (note for future)

---

### PR 7.4: Wire Up Read Details Tap in ChatDetailView

**Goal:** Enable tapping message status to view detailed read receipts.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift`
- [ ] Add `@State private var selectedMessageForDetails: Message?` for sheet presentation
- [ ] Update MessageBubbleView rendering to:
  - Pass calculated read/delivered counts
  - Pass onTapStatusIndicator closure
- [ ] Implement tap handler:
  - Set `selectedMessageForDetails` to tapped message
  - This triggers sheet presentation
- [ ] Add `.sheet(item: $selectedMessageForDetails)` presenting MessageReadDetailsView
- [ ] Pass message and participant profiles to sheet
- [ ] Ensure only messages from current user are tappable (others don't see read details)

**What to Test:**
1. Send message in group chat
2. Tap the status indicator (✓✓ X)
3. Verify MessageReadDetailsView appears
4. Verify correct read/delivered status shown
5. Dismiss sheet and verify returns to chat
6. Try tapping status on message from another user
7. Verify nothing happens (or sheet doesn't appear)
8. Test with multiple messages
9. Verify correct details for each message
10. Test real-time updates - have users read while viewing details

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` - Wire up read details tap gesture

**Notes:**
- Only sender should see read details (privacy and UX)
- Sheet presentation is better than navigation for details view
- Ensure tap target is large enough
- Consider haptic feedback on tap

---

### PR 7.5: Update Last Message Status in ConversationRowView

**Goal:** Show read count in conversation list for group chats.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ConversationRowView.swift`
- [ ] Locate last message status indicator
- [ ] Add conditional rendering based on `conversation.isGroupChat`:
  - **If one-on-one**: Keep existing checkmarks
  - **If group**: Show "✓✓ X" where X is count from lastMessageStatus
- [ ] Add `@State private var readCount: Int?` if needed for calculation
- [ ] Implement `calculateLastMessageReadCount() async` if not available
  - May need to fetch last message to get readBy data
  - Or store read count in conversation document (denormalized)
- [ ] Update when new messages are read
- [ ] Ensure status only shows for messages from current user

**What to Test:**
1. View conversation list
2. Send message in group chat
3. Verify last message preview shows "You: {message}"
4. Verify status shows "✓✓ 0" initially
5. Have group members read the message
6. Verify status updates to "✓✓ 1", "✓✓ 2", etc.
7. Compare with one-on-one chats
8. Verify one-on-one still shows simple checkmarks
9. Test with messages from others
10. Verify status doesn't show (only for your messages)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ConversationRowView.swift` - Update last message status for groups

**Notes:**
- May require denormalizing read count to conversation document for efficiency
- Alternatively, fetch last message to calculate count (less efficient)
- Real-time updates ensure count stays current
- Consider showing "Read by all" when everyone has read

---

## Phase 8: Unread Badge Optimization

**Estimated Time:** 1 day

This phase fine-tunes unread badge logic for group conversations to ensure accurate counts.

### PR 8.1: Verify and Test Unread Logic for Groups

**Goal:** Ensure unread message counting works correctly for group conversations.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ConversationRowView.swift`
- [ ] Locate unread count calculation logic
- [ ] Review how unread messages are counted
- [ ] Verify logic works for both one-on-one and group chats:
  - Count messages where senderId != currentUserId
  - Count messages where currentUserId is not in readBy dictionary
- [ ] Add test scenarios for edge cases:
  - High-traffic groups with rapid messages
  - Messages from multiple senders
  - Marking messages as read
- [ ] Consider showing "5+ unread" for large counts instead of exact number
- [ ] Implement `getUnreadCount(conversation: Conversation, currentUserId: String) -> Int`
  - Query messages where read status indicates unread by current user
  - Return count
- [ ] Ensure badge updates in real-time as new messages arrive
- [ ] Test badge clearing when conversation is opened

**What to Test:**
1. Join group chat with existing unread messages
2. Verify unread badge shows correct count
3. Send 5 rapid messages from another device
4. Verify badge increments to 5
5. Open conversation
6. Verify badge clears immediately or after messages marked read
7. Leave conversation open and receive new message
8. Verify badge doesn't increment (conversation is active)
9. Background app and receive messages
10. Verify badge shows on app icon and conversation row
11. Test with 50+ unread messages
12. Verify display shows "50+" or handles large numbers gracefully
13. Test with multiple group chats having unread messages
14. Verify total app badge is sum of all unread

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ConversationRowView.swift` - Verify and optimize unread count logic
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ConversationsViewModel.swift` - Update unread queries if needed

**Notes:**
- Unread logic should already work if implemented correctly for one-on-one
- Groups amplify edge cases due to multiple senders
- Real-time updates are critical for user trust
- Consider performance: querying unread counts for many conversations
- Badge clearing should happen immediately when conversation opens

---

### PR 8.2: Optimize Unread Count Queries

**Goal:** Improve performance of unread count calculations for groups.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ConversationsViewModel.swift`
- [ ] Review how unread counts are calculated
- [ ] Consider optimization strategies:
  - Denormalize unread count to conversation document
  - Use Firestore aggregation queries (if available)
  - Cache unread counts locally
  - Update incrementally rather than recalculating each time
- [ ] Implement efficient unread counting:
  - Option 1: Store `unreadCounts: [userId: Int]` in conversation document
  - Option 2: Use Firestore count() query (iOS 15+)
  - Option 3: Client-side tracking with real-time listener
- [ ] Ensure unread count updates when:
  - New message arrives
  - Message is marked as read
  - User joins/leaves group
- [ ] Test performance with 20+ conversations

**What to Test:**
1. Open app with many conversations (20+)
2. Verify conversation list loads quickly
3. Verify unread badges appear without delay
4. Monitor Firestore read operations
5. Verify queries are efficient (not fetching all messages)
6. Receive new message in multiple conversations
7. Verify badges update in real-time
8. Mark messages as read in one conversation
9. Verify badge updates without affecting others
10. Test with slow network connection
11. Verify degraded experience is acceptable

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ConversationsViewModel.swift` - Optimize unread count queries
- Potentially `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/MessageService.swift` - Update message read logic

**Notes:**
- Firestore reads cost money - optimize for minimal queries
- Denormalization requires updating multiple documents (tradeoff)
- Real-time listeners are efficient but require careful management
- Test with production-like data volumes
- Consider using Firestore count() aggregation if available

---

## Phase 9: Group-Specific Notifications

**Estimated Time:** 2-3 days

This phase customizes notification behavior for group messages, building on existing notification infrastructure.

### PR 9.1: Update Notification Text for Group Messages

**Goal:** Include sender name in group message notifications.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/NotificationManager.swift`
- [ ] Locate the method that creates message notifications
- [ ] Update notification title/body format for groups:
  - **One-on-one**: Title = sender name, Body = message text
  - **Group**: Title = group name, Body = "{Sender}: {message text}"
  - Or: Title = "{Sender} in {Group Name}", Body = message text
- [ ] Add `groupName` parameter to notification method
- [ ] Implement formatting logic based on `isGroupChat` flag
- [ ] Ensure text truncation works properly for long names/messages
- [ ] Test both notification styles to determine best UX

**What to Test:**
1. Receive message in one-on-one chat
2. Verify notification shows: "{Sender}" → "{Message}"
3. Receive message in group chat
4. Verify notification shows: "{Group Name}" → "{Sender}: {Message}"
5. Test with long group names
6. Verify truncation doesn't cut off critical info
7. Test with long sender names
8. Verify formatting remains clear
9. Receive rapid messages from multiple senders in same group
10. Verify notifications are distinct and clear

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/NotificationManager.swift` - Update notification formatting for groups

**Notes:**
- Including sender name in group notifications is essential for context
- Format should match conventions from WhatsApp, iMessage, etc.
- Consider truncation strategy: prioritize sender name over message text
- Test on lock screen and notification center (different layouts)

---

### PR 9.2: Add Notification Muting for Groups

**Goal:** Allow users to mute notifications for specific groups.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Conversation.swift`
- [ ] Add optional field `var isMuted: Bool?` to Conversation model
- [ ] Update CodingKeys and initializer
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift`
- [ ] Add method `toggleMute(conversationId: String, isMuted: Bool) async throws`
  - Update Firestore document with isMuted value
  - Store per-user preference (may need user-specific subcollection)
- [ ] Alternative: Store mute preferences in user document or UserDefaults
  - `mutedConversations: [conversationId]` array
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift`
- [ ] Add "Mute Notifications" toggle switch in settings section
- [ ] Wire up toggle to call ConversationService.toggleMute()
- [ ] Update notification trigger logic to check mute status before showing notification

**What to Test:**
1. Open GroupInfoView
2. Locate "Mute Notifications" toggle
3. Enable mute
4. Have someone send message in that group
5. Verify no notification appears
6. Verify message still appears in app when opened
7. Disable mute
8. Receive another message
9. Verify notification appears normally
10. Test mute persistence across app restarts
11. Test with multiple groups - ensure mute is per-group

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Conversation.swift` - Add isMuted field
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift` - Add mute toggle method
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift` - Add mute toggle UI
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/NotificationManager.swift` - Check mute status before showing notification

**Notes:**
- Mute is per-user preference, not global to conversation
- Consider mute duration options: forever, 1 hour, 8 hours, 1 week
- Badge counts may still update for muted groups (decision needed)
- Visual indicator in conversation list for muted groups (moon icon)

---

### PR 9.3: Optimize Notification Grouping for Groups

**Goal:** Group multiple rapid notifications from the same group.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/NotificationManager.swift`
- [ ] Update notification identifier strategy:
  - Currently: unique identifier for each notification
  - Change to: use conversationId as identifier for group notifications
  - This causes new notifications to replace old ones from same group
- [ ] Add notification grouping using `threadIdentifier`:
  - Set `content.threadIdentifier = conversationId`
  - iOS will group notifications from same thread
- [ ] Update notification summary:
  - When multiple notifications from same group, show: "{Group Name} (3 messages)"
- [ ] Test notification stacking and grouping behavior
- [ ] Consider using `summaryArgument` for better summaries

**What to Test:**
1. Receive 5 rapid messages in same group
2. Verify notifications are grouped by conversation
3. Verify summary shows message count
4. Tap grouped notification
5. Verify opens to correct conversation
6. Receive messages from multiple groups
7. Verify each group has separate notification thread
8. Test expanding notification group
9. Verify individual messages are accessible
10. Test on different iOS versions (behavior may vary)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/NotificationManager.swift` - Add notification grouping logic

**Notes:**
- iOS notification grouping is automatic with threadIdentifier
- Grouping improves UX in high-traffic groups
- Test on iOS 15+ for best results
- Consider different strategies for one-on-one vs groups
- Summary text should be clear and informative

---

## Phase 10: Polish and Edge Cases

**Estimated Time:** 3-5 days

This final phase addresses remaining edge cases, improves error handling, and ensures production readiness.

### PR 10.1: Add Loading States and Error Handling

**Goal:** Improve UX during group operations with proper loading indicators and error messages.

**Tasks:**
- [ ] Review all group-related views for loading states
- [ ] Add loading spinners or skeletons for:
  - Group creation (while creating conversation)
  - Participant list loading (while fetching profiles)
  - Adding participants (while processing adds)
  - Removing participants (while processing removal)
  - Updating group details (while saving)
- [ ] Implement error alerts for:
  - Failed group creation
  - Failed participant add/remove
  - Network errors during operations
  - Permission/authorization errors
- [ ] Add user-friendly error messages (not raw error descriptions)
- [ ] Implement retry mechanisms where appropriate
- [ ] Add optimistic UI updates where possible
  - Show participant as added immediately, rollback if fails
  - Update group name immediately, revert if fails

**What to Test:**
1. Disconnect network and attempt group creation
2. Verify loading state appears
3. Verify error alert shows with helpful message
4. Retry operation after reconnecting
5. Test failed participant addition
6. Verify proper error handling
7. Test rapid operations (create, add, remove in quick succession)
8. Verify no race conditions or UI glitches
9. Test with slow network (simulate with Network Link Conditioner)
10. Verify loading states appear and disappear appropriately

**Files Changed:**
- Multiple view files: NewGroupConversationView, GroupNameInputView, GroupInfoView, AddParticipantsView
- All ViewModels: Add loading and error state properties

**Notes:**
- Good loading states build user trust
- Error messages should suggest solutions, not just state problems
- Optimistic UI improves perceived performance
- Consider haptic feedback for errors
- Test on slow networks to identify all loading scenarios

---

### PR 10.2: Handle Edge Cases and Concurrent Operations

**Goal:** Ensure app handles edge cases gracefully without crashing or data corruption.

**Tasks:**
- [ ] Document and test edge cases:
  - **Creating group with only 2 members**: Should it convert to group or stay one-on-one?
  - **Adding third person to existing one-on-one**: Convert to group or create new conversation?
  - **Last person leaving group**: Delete conversation or keep history?
  - **Removed while viewing group**: Navigate back gracefully
  - **Group deleted while viewing**: Show error and navigate back
  - **Concurrent edits to group name**: Last write wins (Firestore default)
  - **Concurrent add/remove of same user**: Handle with proper checks
- [ ] Implement handling for each edge case:
  - Add validation checks
  - Add navigation guards
  - Add data consistency checks
  - Add user-facing messages where needed
- [ ] Add defensive programming:
  - Null checks for optional data
  - Array bounds checking
  - Fallback values for missing data
- [ ] Test concurrent operations:
  - Two admins editing group name simultaneously
  - Two admins adding/removing participants simultaneously
  - User leaving while admin removes them

**What to Test:**
1. Create group with exactly 2 selected participants
2. Verify behavior (3 total including current user)
3. Have admin remove you while viewing GroupInfoView
4. Verify you're navigated back gracefully with message
5. Be last person and leave group
6. Verify conversation handling (decide: delete or archive)
7. Two devices: simultaneously edit group name
8. Verify last write wins and both see final result
9. Two devices: simultaneously add same user
10. Verify user added only once, no errors
11. Network interruption during operations
12. Verify retry logic or appropriate error messages

**Files Changed:**
- All group-related services and views
- Add validation and edge case handling throughout

**Notes:**
- Edge cases often cause bugs in production
- Concurrent operations are common in multiplayer apps
- Firestore's eventual consistency requires careful handling
- Document decisions (delete vs archive, convert vs create new)
- Test with multiple devices simultaneously

---

### PR 10.3: Add Empty States and Placeholder Content

**Goal:** Improve UX when there's no data or content to display.

**Tasks:**
- [ ] Add empty state for no group chats:
  - In ChatsView, if no groups exist, show placeholder
  - Message: "No group chats yet"
  - Call-to-action button: "Create your first group"
- [ ] Add empty state for no participants available:
  - In AddParticipantsView, if all users are already members
  - Message: "Everyone is already in this group"
  - Suggestion: "Invite more people to join [App Name]"
- [ ] Add empty state for group with no messages:
  - In ChatDetailView for new groups
  - Message: "Group created! Say hello to everyone."
  - Friendly illustration or icon
- [ ] Add placeholder while loading:
  - Skeleton screens for participant lists
  - Placeholder avatars during load
- [ ] Ensure all empty states are friendly and helpful

**What to Test:**
1. New user with no conversations
2. Verify empty state appears with helpful message
3. Create first group
4. Verify empty state disappears
5. Open group with all users already added
6. Verify AddParticipantsView shows appropriate message
7. Create new group and open it immediately
8. Verify empty state shows in message area
9. Send first message
10. Verify empty state is replaced by message

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatsView.swift` - Add empty state for no groups
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/AddParticipantsView.swift` - Add empty state for no available users
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` - Add empty state for new groups

**Notes:**
- Empty states are opportunities for onboarding
- Friendly tone encourages users to take action
- Consider illustrations or animations for polish
- Empty states should match app's design language

---

### PR 10.4: Accessibility Audit

**Goal:** Ensure all group messaging features are accessible to users with disabilities.

**Tasks:**
- [ ] Test with VoiceOver enabled:
  - Navigate through group creation flow
  - Verify all buttons and fields are labeled
  - Verify selections are announced
  - Verify group info screen is navigable
- [ ] Add accessibility labels where missing:
  - GroupAvatarView: "Group avatar for {groupName}"
  - ParticipantRowView: "{Name}, {online status}"
  - Message status indicators: "Read by {count} people"
  - Typing indicators: "{Names} typing"
- [ ] Test with Dynamic Type (large text sizes):
  - Verify layouts don't break with large text
  - Ensure truncation works properly
  - Verify avatars scale appropriately
- [ ] Add accessibility hints for complex interactions:
  - "Double tap to view group details"
  - "Double tap to view read receipts"
- [ ] Test with Voice Control:
  - Verify all interactive elements are controllable
- [ ] Test with Reduce Motion enabled:
  - Ensure animations can be disabled
  - Provide alternative transitions

**What to Test:**
1. Enable VoiceOver in iOS Settings
2. Navigate to ChatsView
3. Create new group using VoiceOver
4. Verify all steps are accessible
5. Open existing group chat
6. Verify messages and sender names are announced
7. Open GroupInfoView
8. Verify participant list is navigable
9. Enable largest Dynamic Type size
10. Review all group UIs
11. Verify text doesn't overflow or get cut off
12. Enable Reduce Motion
13. Verify animations are simplified or removed

**Files Changed:**
- All group-related views - add accessibility modifiers

**Notes:**
- Accessibility is not optional - required for App Store
- VoiceOver testing reveals many usability issues
- Dynamic Type support improves UX for everyone
- Consider accessibility from the start, not as afterthought
- Reference Apple's Human Interface Guidelines for best practices

---

### PR 10.5: Performance Testing and Optimization

**Goal:** Ensure smooth performance with various group sizes and activity levels.

**Tasks:**
- [ ] Test with different group sizes:
  - Small groups (3-5 members)
  - Medium groups (10-15 members)
  - Large groups (20-50 members)
- [ ] Measure and optimize:
  - Conversation list scroll performance
  - Chat detail view scroll performance with message attribution
  - GroupInfoView participant list performance
  - Avatar loading performance
- [ ] Identify bottlenecks:
  - Excessive Firestore queries
  - Repeated profile photo fetches
  - Unnecessary view re-renders
- [ ] Implement optimizations:
  - Profile caching
  - Avatar image caching
  - Lazy loading for long participant lists
  - Pagination for message history
- [ ] Use Instruments to profile:
  - Time Profiler for CPU usage
  - Allocations for memory leaks
  - Network for Firestore query efficiency
- [ ] Set performance targets:
  - 60fps scrolling in conversation list
  - < 1 second to open group chat
  - < 500ms to load participant list

**What to Test:**
1. Create group with 30 members
2. Send 100+ messages
3. Scroll through conversation list
4. Verify smooth 60fps scrolling
5. Open large group chat
6. Scroll through message history
7. Verify no lag or stuttering
8. Monitor memory usage over time
9. Verify no memory leaks
10. Check Firestore query counts
11. Verify efficient querying (no excessive reads)
12. Test on older device (iPhone SE, iPhone 11)
13. Verify acceptable performance on lower-end hardware

**Files Changed:**
- Multiple files - add performance optimizations throughout
- Potentially add caching layers in services

**Notes:**
- Performance matters more as data grows
- Profile on actual devices, not just simulator
- Test on oldest supported iOS version and device
- Consider pagination for very large groups
- Monitor Firestore costs - excessive queries cost money

---

### PR 10.6: Analytics and Monitoring

**Goal:** Add analytics events to track group messaging usage and identify issues.

**Tasks:**
- [ ] Identify key metrics to track:
  - Group creation count
  - Average group size
  - Messages sent in groups vs one-on-one
  - Participant additions/removals
  - Groups created per user
- [ ] Add analytics events (Firebase Analytics or similar):
  - `group_created` - When user creates group
  - `group_joined` - When user added to group
  - `group_left` - When user leaves group
  - `participant_added` - When member added
  - `participant_removed` - When member removed
  - `group_message_sent` - When message sent in group
  - `group_info_viewed` - When user views group details
- [ ] Add event parameters:
  - `group_size` - Number of participants
  - `group_has_custom_image` - Boolean
  - `group_has_custom_name` - Boolean
- [ ] Add error tracking:
  - Track failed group operations
  - Track Firestore errors
  - Track permission errors
- [ ] Set up monitoring:
  - Track app crashes related to groups
  - Monitor Firestore usage and costs
  - Set up alerts for unusual patterns

**What to Test:**
1. Create group and verify analytics event fires
2. Check Firebase Analytics dashboard
3. Verify event parameters are captured correctly
4. Add participant and verify event
5. Test all tracked actions
6. Verify events appear in analytics
7. Cause error (network failure) and verify error tracking
8. Review error logs to ensure proper tracking

**Files Changed:**
- All group-related views and services - add analytics calls
- Create `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/AnalyticsService.swift` if doesn't exist

**Notes:**
- Analytics inform feature improvements and priorities
- Track both successes and failures
- Privacy: don't log personal data (names, messages)
- Consider user consent for analytics (GDPR/CCPA)
- Use analytics to validate assumptions about usage

---

### PR 10.7: Documentation and Code Comments

**Goal:** Document group messaging implementation for future developers.

**Tasks:**
- [ ] Update README (if exists) with group messaging features
- [ ] Add inline code comments for complex logic:
  - Smart grouping algorithm in message attribution
  - Avatar priority logic in GroupAvatarView
  - Read count calculation logic
  - Participant management in ConversationService
- [ ] Document architecture decisions:
  - Why hybrid avatar approach (custom → composite → placeholder)
  - Why smart grouping for message attribution
  - Why 2-minute time gap for sender info
  - Why separate add/remove vs single update method
- [ ] Add header comments to new files:
  - Purpose of the file
  - Key components/methods
  - Related files
- [ ] Document known limitations:
  - No role-based permissions (admin/member)
  - No @mentions
  - No message threading
- [ ] Create troubleshooting guide:
  - Common issues and solutions
  - Firebase setup requirements
  - Security rules needed

**What to Test:**
1. Review all new files
2. Verify header comments are present and accurate
3. Review complex methods
4. Verify inline comments explain non-obvious logic
5. Read through documentation
6. Verify it's understandable by someone unfamiliar with codebase
7. Test following documentation to implement a feature
8. Verify documentation is accurate and helpful

**Files Changed:**
- All new and modified files - add comments
- Create `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Docs/Features/Groups/implementation_notes.md` (optional)
- Update main README or developer docs

**Notes:**
- Future you will thank you for documentation
- Comments should explain WHY, not just WHAT
- Keep documentation up to date as code changes
- Good documentation reduces onboarding time for new developers
- Consider creating diagrams for complex flows (group creation, participant management)

---

## Testing Matrix

### Comprehensive Test Scenarios

After completing all phases, run through these end-to-end test scenarios:

#### Scenario 1: Create and Use First Group
1. New user signs in
2. Tap "New Group" button
3. Select 3 participants
4. Enter group name "Team Chat"
5. Enter custom image URL
6. Create group
7. Verify group appears at top of conversation list with custom avatar
8. Send first message
9. Verify message appears
10. Have another member reply
11. Verify reply shows sender name and avatar
12. Tap group header
13. Verify GroupInfoView opens with all details

#### Scenario 2: Multi-Device Group Messaging
1. User A creates group with Users B and C
2. User A sends message "Hello team"
3. On User B's device, verify notification appears with sender name
4. User B opens group and replies
5. On User A's device, verify message appears with User B's name/avatar
6. User C sends message
7. Verify all users see message with correct attribution
8. Users B and C type simultaneously
9. On User A's device, verify typing indicator shows "User B and User C are typing..."

#### Scenario 3: Group Management
1. Open existing group
2. Tap header to open GroupInfoView
3. Tap "Edit" on group name
4. Change to "Updated Team"
5. Verify name updates throughout app
6. Tap "Add Participants"
7. Add User D
8. Verify User D appears in participant list
9. Verify system message (if implemented): "User D joined the group"
10. Long-press User D
11. Select "Remove from Group"
12. Confirm removal
13. Verify User D removed from list
14. On User D's device, verify group no longer appears

#### Scenario 4: Read Receipts in Groups
1. User A sends message in group
2. Initially shows "✓✓ 0" (no reads)
3. User B reads message
4. Status updates to "✓✓ 1"
5. User A taps status indicator
6. Verify MessageReadDetailsView shows User B in "Read by" section
7. User C reads message
8. Verify details update to show both User B and User C
9. Verify timestamps are accurate

#### Scenario 5: Group Avatars
1. Create group without custom image
2. With 3-4 members, verify composite avatar (2x2 grid)
3. Open GroupInfoView
4. Add image URL
5. Verify custom image replaces composite
6. Remove all text from image URL field
7. Verify fallback to composite or placeholder
8. Create group with 10 members and no custom image
9. Verify placeholder avatar with group initial

#### Scenario 6: Edge Cases
1. Create group with only 2 selected participants (3 total including you)
2. Verify group is created (minimum size)
3. Have admin remove you while viewing group
4. Verify graceful navigation back with message
5. Be last person in group and leave
6. Verify conversation handling (delete or archive)
7. Attempt to add participant already in group
8. Verify appropriate error or prevention
9. Edit group name to exceed 35 characters
10. Verify truncation or validation

#### Scenario 7: Performance Testing
1. Create group with 20 members
2. Send 100+ messages in group
3. Scroll conversation list
4. Verify smooth 60fps scrolling
5. Open large group chat
6. Scroll message history
7. Verify no lag
8. Open GroupInfoView
9. Scroll participant list
10. Verify smooth performance
11. Test on older device (iPhone SE)
12. Verify acceptable performance

---

## Files Summary

### New Files Created

| File Path | Purpose |
|-----------|---------|
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/NewGroupConversationView.swift` | Multi-select participant picker for group creation |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupNameInputView.swift` | Group name and image URL input screen |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/GroupAvatarView.swift` | Reusable group avatar with priority logic |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/CompositeAvatarView.swift` | 2x2 grid composite avatar component |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/MessageSenderHeaderView.swift` | Sender name label above messages |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift` | Group information and management screen |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/ParticipantRowView.swift` | Participant list row component |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/AddParticipantsView.swift` | Add participants to existing group screen |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/MessageReadDetailsView.swift` | Read receipt details sheet |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/GroupInfoViewModel.swift` | Business logic for group information screen |

### Files Modified

| File Path | Changes |
|-----------|---------|
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Conversation.swift` | Add groupImageUrl and isMuted fields |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift` | Add group creation params, participant management, group detail updates |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatsView.swift` | Add "New Group" button and navigation |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ConversationRowView.swift` | Add group avatars, sender name in preview, read counts |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` | Add group header, message attribution, typing indicators, read details |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift` | Add sender name/avatar, group read counts |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/TypingIndicatorView.swift` | Enhanced display for multiple typers |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift` | Add sender caching, smart grouping logic, read count calculation |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/MessageService.swift` | Update participant change handling |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/NotificationManager.swift` | Add group notification formatting, muting, grouping |

---

## Success Criteria

Group messaging implementation is complete when all of the following are verified:

- [ ] Users can create groups with 3+ participants
- [ ] Users can set custom group name and image URL
- [ ] Auto-generated group names work when no custom name provided
- [ ] Group avatars display correctly (custom → composite → placeholder)
- [ ] Composite avatars show 2-4 participant photos in grid
- [ ] Group chats are visually distinct from one-on-one chats
- [ ] Message attribution shows sender name and avatar in groups
- [ ] Smart grouping hides redundant sender info for consecutive messages
- [ ] Typing indicators show multiple users elegantly
- [ ] Group header shows participant count and is tappable
- [ ] GroupInfoView displays all participants with online status
- [ ] Users can edit group name and image URL
- [ ] Users can add participants to existing groups
- [ ] Users can remove participants from groups
- [ ] Users can leave groups
- [ ] Read receipts show count for group messages
- [ ] Tapping read status shows detailed read/delivered info
- [ ] Unread badges work correctly for groups
- [ ] Group notifications include sender name
- [ ] Users can mute specific groups
- [ ] All features work smoothly on various device sizes
- [ ] Performance is acceptable with 20+ member groups
- [ ] Accessibility (VoiceOver, Dynamic Type) works throughout
- [ ] Edge cases are handled gracefully

---

## Timeline Estimate

**Assuming one developer working full-time:**

- Phase 1 (Group Creation UI): 3-5 days
- Phase 2 (Group Avatar Display): 2-3 days
- Phase 3 (Message Attribution): 3-4 days
- Phase 4 (Enhanced Typing): 1-2 days
- Phase 5 (Group Info Screen): 3-4 days
- Phase 6 (Add/Remove Participants): 2-3 days
- Phase 7 (Read Receipts): 2-3 days
- Phase 8 (Unread Badge Optimization): 1 day
- Phase 9 (Notifications): 2-3 days
- Phase 10 (Polish & Edge Cases): 3-5 days

**Total: 22-36 days (4-7 weeks)**

**Phased Rollout Option:**
- MVP (Phases 1-4): 9-14 days → Release usable group messaging
- Management (Phases 5-6): 5-7 days → Add group controls
- Polish (Phases 7-10): 8-15 days → Refine UX and edge cases

---

## Additional Notes

### Firebase Security Rules

Ensure Firestore security rules allow group operations:

```javascript
// Conversations collection
match /conversations/{conversationId} {
  // Allow create if creator is in participant list and minimum 2 participants
  allow create: if request.auth.uid in request.resource.data.participantIds
                && request.resource.data.participantIds.size() >= 2;

  // Allow read if user is participant
  allow read: if request.auth.uid in resource.data.participantIds;

  // Allow update if user is participant (for group name, image, participants)
  allow update: if request.auth.uid in resource.data.participantIds;
}

// Messages collection
match /messages/{messageId} {
  // Allow create if sender is in participant list
  allow create: if request.auth.uid == request.resource.data.senderId
                && request.auth.uid in request.resource.data.participantIds;

  // Allow read if user is in participant list
  allow read: if request.auth.uid in resource.data.participantIds;

  // Allow update for read receipts
  allow update: if request.auth.uid in resource.data.participantIds;
}
```

### Future Enhancements (Out of Scope)

1. Group roles (admin, moderator, member)
2. @Mentions
3. Message threading/replies
4. Photo upload (vs URL input)
5. Group description
6. Pinned messages
7. Group invite links
8. Broadcast mode
9. Polls
10. File sharing beyond images
11. Message reactions
12. Message forwarding

---

**Document Version:** 1.0
**Last Updated:** 2025-10-22
**Status:** Ready for Implementation
**Feature:** Group Messaging Core Functionality
