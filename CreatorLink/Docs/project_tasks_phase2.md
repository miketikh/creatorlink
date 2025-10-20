# Phase 2: Core Messaging Infrastructure

**Timeline:** Day 1 Afternoon - Day 2 Morning
**Deadline:** Day 2, 10am
**Duration:** ~8 hours

## Phase Overview

Build the core messaging infrastructure that enables real-time text communication between users. This phase focuses on creating conversations, sending messages, receiving messages via Firestore real-time listeners, and implementing optimistic UI updates. By the end of this phase, two users should be able to chat in real-time with instant message delivery.

## Dependencies

- Phase 1 must be complete (authentication working, Firebase configured)
- User must be signed in to access messaging features

## Success Criteria

- User A can send a text message to User B
- User B receives the message instantly via real-time listener
- Messages appear immediately in sender's UI (optimistic update)
- Messages display in chronological order
- Conversation list shows all active conversations
- Can tap a conversation to view message thread
- Basic message UI with sender/receiver styling

---

## Task 1: Create MessageService

**Description:** Build the service layer for all message-related Firebase operations including sending, fetching, and real-time listening.

**Implementation Details:**
- Create MessageService.swift in Services folder
- Implement method: sendMessage(conversationId: String, text: String, senderId: String) -> async throws Message
- Implement method: fetchMessages(conversationId: String) -> async throws [Message]
- Implement method: listenToMessages(conversationId: String, completion: @escaping ([Message]) -> Void) -> ListenerRegistration
- Implement method: updateMessageStatus(messageId: String, status: MessageStatus) -> async throws
- Use Firestore batch writes for atomic operations when needed

**Firestore Operations:**
- Write message document to "messages" collection
- Query messages by conversationId, ordered by timestamp descending
- Set up snapshot listener for real-time updates
- Return listener registration for cleanup

**Technical Notes:**
- Use Firestore .addDocument() for auto-generated message IDs
- Messages should be written with status "sending" initially
- Use .whereField("conversationId", isEqualTo: conversationId) for queries
- Use .order(by: "timestamp", descending: false) for chronological order
- Real-time listener should use .addSnapshotListener for live updates

**Error Handling:**
- Network failures during message send
- Permission errors (user not in conversation)
- Firestore quota limits
- Invalid message data

**Files Created:**
- Services/MessageService.swift

**Dependencies:** Phase 1 (Task 10: Data Models)

---

## Task 2: Create ConversationService

**Description:** Build the service layer for conversation creation, fetching, and management.

**Implementation Details:**
- Create ConversationService.swift in Services folder
- Implement method: createConversation(participantIds: [String]) -> async throws Conversation
- Implement method: fetchConversations(userId: String) -> async throws [Conversation]
- Implement method: listenToConversations(userId: String, completion: @escaping ([Conversation]) -> Void) -> ListenerRegistration
- Implement method: updateLastMessage(conversationId: String, text: String, timestamp: Date) -> async throws
- Implement method: findExistingConversation(participantIds: [String]) -> async throws Conversation?

**Conversation Logic:**
- Before creating a new conversation, check if one already exists with same participants
- For 1-on-1 conversations, use sorted participantIds to ensure uniqueness
- Update conversation's lastMessage and lastMessageTime when messages are sent
- Set isGroupChat based on participant count (>2 = group)

**Technical Notes:**
- Use Firestore .whereField("participantIds", arrayContains: userId) to find user's conversations
- Sort conversations by lastMessageTime descending
- Real-time listener should update conversation list automatically
- Consider caching conversations locally to reduce Firestore reads

**Files Created:**
- Services/ConversationService.swift

**Dependencies:** Phase 1 (Task 10: Data Models)

---

## Task 3: Create ViewModels for Chats

**Description:** Build view models to manage state and business logic for chat-related views, following MVVM pattern.

**Implementation Details:**
- Create ViewModels folder in Xcode project
- Create ConversationsViewModel.swift for managing conversation list
- Create ChatViewModel.swift for managing individual chat threads
- Use @Observable macro or @ObservableObject protocol for SwiftUI reactivity
- Each ViewModel should hold references to required services (MessageService, ConversationService, UserService)

**ConversationsViewModel Responsibilities:**
- Load all conversations for current user
- Listen to real-time conversation updates
- Track loading state
- Handle errors
- Provide sorted conversation list to UI
- Create new conversations

**ChatViewModel Responsibilities:**
- Load messages for specific conversation
- Listen to real-time message updates
- Send new messages with optimistic updates
- Track typing state (will enhance in Phase 3)
- Handle message status updates
- Manage message send queue

**Technical Notes:**
- ViewModels should be created per-view (not singletons)
- Clean up Firestore listeners in deinit
- Use @Published or @Observable for properties that trigger UI updates
- Handle async operations on MainActor for UI updates

**Files Created:**
- ViewModels/ConversationsViewModel.swift
- ViewModels/ChatViewModel.swift

**Dependencies:** Task 1, Task 2

---

## Task 4: Implement ChatsView (Conversation List)

**Description:** Build the conversation list view showing all active chats for the current user.

**Implementation Details:**
- Update ChatsView.swift (created in Phase 1)
- Display list of conversations using SwiftUI List
- Each row shows: other user's profile photo, name, last message preview, timestamp
- Show loading state while conversations are being fetched
- Show empty state if no conversations exist
- Add navigation to create new chat (+ button in navigation bar)
- Tap on conversation navigates to ChatDetailView

**UI Requirements:**
- Profile photo on left (circular, 50pt diameter)
- User name in bold at top
- Last message preview in gray below name (truncate to 2 lines max)
- Timestamp on right side (formatted as "10m ago", "Yesterday", etc.)
- Unread indicator if applicable (will enhance in Phase 3)
- Pull-to-refresh to reload conversations

**List Behavior:**
- Sort by lastMessageTime descending (most recent first)
- Use NavigationStack for hierarchical navigation
- Swipe actions for future features (delete, mute, etc.)

**Technical Notes:**
- Use ConversationsViewModel for data
- Use AsyncImage for loading profile photos
- Format timestamps using RelativeDateTimeFormatter
- Handle empty state with helpful message
- Use .refreshable for pull-to-refresh

**Files Modified:**
- Views/Chats/ChatsView.swift

**Dependencies:** Task 3

---

## Task 5: Create ConversationRowView

**Description:** Build reusable row component for displaying conversation previews in the list.

**Implementation Details:**
- Create ConversationRowView.swift as a separate component
- Accept Conversation model as parameter
- Accept User model for the other participant (1-on-1) or group info (group chat)
- Display profile photo, name, last message, and timestamp
- Handle both 1-on-1 and group chat display differently
- For groups, show group name or "Group Chat" if no name set

**UI Layout:**
- HStack with spacing
- Profile photo: 50x50 AsyncImage, circular clip shape
- VStack with name and message preview
- Spacer to push timestamp to right
- Timestamp in smaller, gray text

**Technical Requirements:**
- Extract participant info from conversation (fetch user profile)
- Format last message time using relative formatting
- Truncate long messages with "..." ellipsis
- Handle nil photoURL gracefully (show initials or placeholder icon)

**Files Created:**
- Views/Chats/ConversationRowView.swift

**Dependencies:** Task 4

---

## Task 6: Create NewConversationView

**Description:** Build UI for starting a new conversation by selecting a user to chat with.

**Implementation Details:**
- Create NewConversationView.swift as a sheet presentation
- Display list of all users (fetch from Firestore "users" collection)
- Search bar to filter users by name
- Exclude current user from list
- Exclude users with existing conversations (or show "Open Chat" instead)
- Tap user to create conversation and navigate to chat

**UI Requirements:**
- Search bar at top for filtering users
- List of users with profile photo and name
- Loading state while fetching users
- Empty state if no users found
- Close button to dismiss sheet

**Conversation Creation Flow:**
1. User taps + button in ChatsView navigation bar
2. NewConversationView appears as sheet
3. User searches/browses user list
4. User taps a user to chat with
5. Check if conversation already exists
6. If exists, navigate to existing conversation
7. If not, create new conversation and navigate to chat view

**Technical Notes:**
- Fetch all users from Firestore "users" collection
- Use ConversationService.findExistingConversation to check for duplicates
- Dismiss sheet after creating conversation
- Navigate to ChatDetailView with new conversation

**Files Created:**
- Views/Chats/NewConversationView.swift

**Dependencies:** Task 2, Task 4

---

## Task 7: Implement ChatDetailView (Message Thread)

**Description:** Build the main chat interface showing message history and input field for sending messages.

**Implementation Details:**
- Create ChatDetailView.swift
- Display messages in a scrollable list (ScrollView with VStack or List)
- Messages ordered chronologically (oldest at top)
- Different styling for sent vs. received messages
- Message input field at bottom with send button
- Navigation title shows other user's name (or group name)
- Show user's profile photo in navigation bar

**UI Layout:**
- Navigation bar: back button, user name, profile photo
- Message list: ScrollView/List with messages
- Bottom input area: TextField + Send Button (HStack pinned to bottom)
- Messages should auto-scroll to bottom when new message arrives
- Input field should be always visible (not covered by keyboard)

**Message Bubble Styling:**
- Sent messages: aligned right, blue background, white text
- Received messages: aligned left, gray background, black text
- Bubble shape with rounded corners
- Tail/pointer optional
- Show timestamp below each message (or group by time)
- Show sender name for group chats only

**Technical Requirements:**
- Use ChatViewModel for data and actions
- Auto-scroll to bottom when view appears
- Auto-scroll to bottom when new message received
- Handle keyboard appearance (move input field up)
- Disable send button when text is empty
- Clear input field after sending message

**Files Created:**
- Views/Chats/ChatDetailView.swift

**Dependencies:** Task 3

---

## Task 8: Create MessageBubbleView

**Description:** Build reusable message bubble component with appropriate styling for sent/received messages.

**Implementation Details:**
- Create MessageBubbleView.swift as a reusable component
- Accept Message model and Bool indicating if it's from current user
- Apply different styling based on sender (sent vs. received)
- Display message text with word wrapping
- Display timestamp in small text below bubble
- Display status indicator for sent messages (will enhance in Phase 3)

**Styling Requirements:**
- Sent messages: trailing alignment, blue background (Color.blue), white text
- Received messages: leading alignment, gray background (Color(.systemGray5)), black text
- Padding inside bubble: 12pt vertical, 16pt horizontal
- Corner radius: 18pt
- Max width: ~70% of screen width
- Timestamp: 10pt font, gray color, below bubble

**Layout Structure:**
- HStack to control alignment (Spacer before or after based on sender)
- VStack for bubble content (text + timestamp)
- Text with multiple lines support
- Timestamp in smaller font

**Technical Notes:**
- Use .frame(maxWidth: .infinity, alignment: ...) for alignment
- Use .fixedSize for proper text wrapping
- Consider adding animation for bubble appearance
- Handle empty text gracefully (shouldn't happen, but defensive coding)

**Files Created:**
- Views/Chats/MessageBubbleView.swift

**Dependencies:** Task 7

---

## Task 9: Implement Message Sending with Optimistic UI

**Description:** Build the message sending flow with immediate local UI update before Firestore confirmation.

**Implementation Details:**
- In ChatViewModel, implement sendMessage(text: String) method
- Create temporary message object with status "sending"
- Immediately add temporary message to local messages array (optimistic update)
- Call MessageService.sendMessage to write to Firestore
- Update local message with Firestore-generated ID and status "sent"
- If send fails, update message status to show error

**Optimistic Update Flow:**
1. User types message and taps send
2. Create Message object with temporary ID, status "sending", current timestamp
3. Add to messages array → UI updates immediately
4. Call MessageService.sendMessage asynchronously
5. On success: replace temporary message with Firestore message
6. On failure: mark message with error state

**Message State Management:**
- Use @Published array of messages in ChatViewModel
- Messages array should be sorted by timestamp
- Update conversation's lastMessage when message is sent
- Handle concurrent sends (multiple messages sent quickly)

**Technical Notes:**
- Use UUID() for temporary message ID until Firestore provides real ID
- Update ConversationService.updateLastMessage after successful send
- Consider retry logic for failed sends (will enhance in Phase 4)
- Ensure UI stays responsive during send operation

**Error Handling:**
- Network failures: mark message as failed, allow retry
- Permission errors: show alert to user
- Invalid data: prevent send and show validation error

**Files Modified:**
- ViewModels/ChatViewModel.swift
- Services/MessageService.swift (if needed)

**Dependencies:** Task 3, Task 7, Task 8

---

## Task 10: Implement Real-time Message Listener

**Description:** Set up Firestore real-time listener to receive new messages instantly as they arrive.

**Implementation Details:**
- In ChatViewModel, set up Firestore snapshot listener in onAppear or init
- Listen to messages collection filtered by conversationId
- When new message arrives, add to messages array
- Handle message updates (status changes)
- Remove listener on view disappear or deinit to prevent memory leaks

**Listener Setup:**
- Call MessageService.listenToMessages(conversationId:)
- Store ListenerRegistration reference for cleanup
- Handle snapshot updates in completion closure
- Differentiate between added, modified, and removed documents

**Real-time Update Handling:**
- New messages: append to messages array
- Modified messages: update existing message in array
- Avoid duplicates: check if message already exists before adding
- Maintain chronological order after updates

**Technical Notes:**
- Clean up listener in deinit or onDisappear
- Use DocumentChangeType to distinguish added/modified/removed
- Handle case where listener receives message that was optimistically added
- Auto-scroll to bottom when new message arrives

**Lifecycle Management:**
- Start listener when ChatDetailView appears
- Stop listener when ChatDetailView disappears
- Handle app background/foreground transitions

**Files Modified:**
- ViewModels/ChatViewModel.swift
- Services/MessageService.swift (if listener method needs enhancement)

**Dependencies:** Task 1, Task 9

---

## Task 11: Implement Conversation List Real-time Updates

**Description:** Set up real-time listener for conversation list to show new conversations and updates instantly.

**Implementation Details:**
- In ConversationsViewModel, set up Firestore snapshot listener for conversations
- Listen to conversations where current user is a participant
- Update conversations array when changes occur
- Handle new conversations, updated conversations, and deleted conversations
- Sort conversations by lastMessageTime after updates

**Listener Behavior:**
- Listen to conversations collection with participantIds array containing current user's ID
- Update UI immediately when conversation is added or modified
- Maintain sorted order (most recent first)
- Clean up listener on deinit

**Technical Requirements:**
- Use ConversationService.listenToConversations(userId:)
- Store ListenerRegistration for cleanup
- Handle document changes: added, modified, removed
- Fetch user profiles for new participants (cache to avoid duplicate fetches)

**Files Modified:**
- ViewModels/ConversationsViewModel.swift

**Dependencies:** Task 2, Task 4

---

## Task 12: Implement Message Input Field with Keyboard Handling

**Description:** Build robust message input field that handles keyboard appearance, send button state, and text input.

**Implementation Details:**
- In ChatDetailView, create input area with TextField and Send Button
- Position input area at bottom of screen using VStack with Spacer
- Handle keyboard appearance using .keyboardAdaptive modifier or similar
- Send button should be disabled when text is empty
- Clear text field after sending message
- Focus on text field when view appears

**UI Components:**
- HStack containing TextField and Button
- TextField: placeholder "Message...", rounded border
- Button: "Send" text or paper plane icon, blue color
- Container: white background, top border, padding

**Keyboard Handling:**
- Input field should move up when keyboard appears
- Use .ignoresSafeArea(.keyboard) or similar modifier
- Ensure input field is never hidden by keyboard
- Dismiss keyboard when user scrolls up in message list

**Text Input Features:**
- Auto-capitalization for sentences
- Auto-correction enabled
- Return key should send message (optional)
- Character limit validation (e.g., 1000 characters max)

**Technical Notes:**
- Use @State for text input binding
- Use @FocusState to manage text field focus
- Send button enabled only when text.trimmingCharacters(in: .whitespacesAndNewlines) is not empty
- Consider adding send on return key behavior

**Files Modified:**
- Views/Chats/ChatDetailView.swift

**Dependencies:** Task 7

---

## Task 13: Implement Auto-scroll to Bottom

**Description:** Ensure message list automatically scrolls to show the most recent message when view loads or new messages arrive.

**Implementation Details:**
- In ChatDetailView, use ScrollViewReader to control scroll position
- Scroll to bottom when view first appears
- Scroll to bottom when new message is added to the list
- Smooth scroll animation for better UX
- Each message needs a unique ID for scroll targeting

**Scroll Behavior:**
- On view appear: scroll to last message immediately (no animation) or with gentle animation
- On new message: scroll to new message with animation
- User manual scroll: do not auto-scroll (respect user's scroll position)
- Use ScrollViewProxy.scrollTo() method

**Technical Implementation:**
- Wrap message list in ScrollViewReader
- Assign .id() to each message bubble with message.id
- Use onAppear and onChange to trigger scroll
- Track whether user has manually scrolled to prevent auto-scroll interruption

**Edge Cases:**
- Empty conversation: no scroll needed
- Long messages: ensure bottom of last message is visible
- Rapid message arrival: don't scroll for each message, debounce

**Technical Notes:**
- Use .onChange(of: messages.count) to detect new messages
- Consider adding "scroll to bottom" button if user scrolls up
- Test with varying message counts and sizes

**Files Modified:**
- Views/Chats/ChatDetailView.swift

**Dependencies:** Task 7, Task 8

---

## Task 14: Test Two-User Real-time Messaging

**Description:** Comprehensive end-to-end testing of messaging between two simulated users.

**Testing Setup:**
- Open two iOS simulators side-by-side
- Sign in as different users on each simulator
- User A creates conversation with User B

**Test Scenarios:**

**Scenario 1: Basic Message Flow**
- User A sends "Hello" to User B
- Verify message appears immediately in User A's chat (optimistic UI)
- Verify message appears on User B's chat within 1-2 seconds
- Verify message displays correctly on both sides (text, timestamp, alignment)

**Scenario 2: Bi-directional Communication**
- User A sends message to User B
- User B replies to User A
- Verify both messages appear in correct order
- Verify sent vs. received styling is correct

**Scenario 3: Rapid Message Sending**
- User A sends 10 messages quickly in succession
- Verify all messages appear on both devices
- Verify messages are in chronological order
- Verify no duplicate messages
- Verify optimistic UI works for all messages

**Scenario 4: Conversation List Updates**
- User A sends message to User B
- Verify User B's conversation list updates with latest message preview
- Verify timestamp updates on conversation row
- Verify conversation moves to top of list

**Scenario 5: Multiple Conversations**
- User A creates conversation with User B
- User A creates conversation with User C
- Send messages in both conversations
- Verify correct messages appear in correct conversations
- Verify conversation list shows both conversations

**Verification Points:**
- Messages sync in real-time (< 2 seconds delay)
- UI is responsive and smooth
- No console errors or warnings
- Messages persist in Firestore (check Firebase Console)
- Conversation list updates correctly
- Keyboard handling works properly
- Auto-scroll works as expected

**Performance Checks:**
- App remains responsive during message sending
- No lag in UI updates
- Memory usage is reasonable
- Firestore read/write counts are acceptable

**Dependencies:** All tasks in Phase 2

---

## Phase 2 Completion Checklist

Before moving to Phase 3, verify:
- [ ] MessageService implemented with send and listen functionality
- [ ] ConversationService implemented with create and fetch functionality
- [ ] ViewModels created for conversations and chat
- [ ] ChatsView displays conversation list with real-time updates
- [ ] ChatDetailView displays messages with proper styling
- [ ] Can create new conversation by selecting a user
- [ ] Can send text messages between two users
- [ ] Messages appear immediately with optimistic UI
- [ ] Messages sync in real-time via Firestore listeners
- [ ] Messages display in chronological order
- [ ] Message bubbles styled correctly for sent/received
- [ ] Keyboard handling works properly
- [ ] Auto-scroll to bottom works
- [ ] Conversation list updates with latest messages
- [ ] No crashes or errors in console

---

## Deliverables

By the end of Phase 2, you should have:
1. Fully functional 1-on-1 text messaging
2. Real-time message synchronization
3. Optimistic UI updates for instant feedback
4. Clean chat interface with proper message styling
5. Conversation list with live updates

---

## Known Limitations (To Address in Later Phases)

- No message status indicators (sending/sent/delivered/read) - Phase 3
- No typing indicators - Phase 3
- No online/offline status - Phase 3
- No persistence for offline messages - Phase 4
- No group chat support - Phase 5
- No image sending - Phase 6

---

## Notes for Next Phase

Phase 3 will enhance the messaging experience with:
- Message status flow (sending → sent → delivered → read)
- Read receipts
- Typing indicators
- Online/offline presence
- "Last seen" timestamps

Ensure Phase 2 is rock-solid before proceeding, as Phase 3 builds upon this real-time infrastructure.
