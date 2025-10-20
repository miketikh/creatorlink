# Phase 4: Persistence & Offline Support

**Timeline:** Day 2 Evening - Day 3 Morning
**Deadline:** Day 3, 9am
**Duration:** ~8 hours

## Phase Overview

Build a robust offline-first architecture using SwiftData for local persistence, enabling users to view messages, compose new messages, and queue outgoing messages while offline. Implement sync strategies to reconcile local and remote data when connectivity is restored. This phase is critical for production readiness, as network conditions are unpredictable in real-world usage.

## Dependencies

- Phase 1 complete (Firebase, Auth, Models)
- Phase 2 complete (Messaging infrastructure)
- Phase 3 complete (Message states, real-time features)

## Success Criteria

- All messages persist locally using SwiftData
- App displays cached messages instantly on launch (no loading delay)
- Users can send messages while offline (queued locally)
- Queued messages automatically send when connectivity returns
- Messages survive force quit and app restart
- Conflict resolution handles edge cases (e.g., same message sent on multiple devices)
- Network state detection accurate and responsive
- Sync strategy reliable and efficient

---

## Task 1: Set Up SwiftData Model Container

**Description:** Configure SwiftData as the local persistence layer with models matching Firestore schema.

**Implementation Details:**
- Create SwiftData model container in CreatorLinkApp.swift
- Define SwiftData models for User, Conversation, and Message
- Configure schema with appropriate relationships
- Set up automatic migration strategy for future schema changes
- Initialize model container before app views load

**SwiftData Configuration:**
- Use @Model macro on data models
- Store models in ModelContainer
- Pass ModelContext to views via environment
- Configure in-memory vs. persistent storage (use persistent)

**Model Requirements:**
- Models should mirror Firestore schema exactly for easy sync
- Use appropriate property wrappers (@Attribute, @Relationship)
- Ensure all models conform to Codable for Firestore compatibility
- Use UUID or String for unique identifiers

**Technical Notes:**
- SwiftData requires models to be classes (not structs)
- Use @Model macro for automatic persistence
- Define relationships between models (e.g., Message belongs to Conversation)
- Configure delete rules for cascading deletes

**Files Modified:**
- CreatorLinkApp.swift (add .modelContainer modifier)

**Files Created:**
- Persistence/SwiftDataModels.swift (or update existing Models)

**Dependencies:** Phase 1 (existing models)

---

## Task 2: Create SwiftData Models

**Description:** Define SwiftData-compatible data models that mirror Firestore schema while supporting local persistence.

**Implementation Details:**
- Convert existing User, Conversation, Message models to SwiftData @Model classes
- Maintain Codable conformance for Firestore sync
- Add sync metadata fields (lastSyncedAt, isSynced, isPendingDelete, etc.)
- Define relationships between entities

**UserModel Fields:**
- id: String (Firebase UID)
- displayName: String
- email: String
- photoURL: String?
- isOnline: Bool
- lastSeen: Date
- lastSyncedAt: Date (tracks last sync with Firestore)
- isSynced: Bool (true if data matches Firestore)

**ConversationModel Fields:**
- id: String (Firestore document ID)
- participantIds: [String]
- lastMessage: String
- lastMessageTime: Date
- isGroupChat: Bool
- groupName: String?
- lastSyncedAt: Date
- isSynced: Bool

**MessageModel Fields:**
- id: String (Firestore document ID or temporary UUID)
- conversationId: String (foreign key)
- senderId: String
- text: String
- timestamp: Date
- status: String (store enum as String)
- readBy: Data? (encoded dictionary)
- imageUrl: String?
- metadata: Data? (encoded dictionary)
- lastSyncedAt: Date
- isSynced: Bool
- isPendingUpload: Bool (true if message queued for send)
- syncRetryCount: Int (tracks retry attempts)

**Relationships:**
- Message @Relationship to Conversation (many-to-one)
- Conversation @Relationship to User (many-to-many via participantIds)

**Technical Notes:**
- Use @Attribute for special property configurations
- Use Data type for complex fields (dictionaries, arrays)
- Consider using @Transient for computed properties
- Ensure all properties have default values or are optional

**Files Created:**
- Persistence/UserModel.swift
- Persistence/ConversationModel.swift
- Persistence/MessageModel.swift

**Dependencies:** Task 1

---

## Task 3: Create Persistence Service

**Description:** Build a service layer to abstract SwiftData operations and provide clean API for saving, fetching, and syncing data.

**Implementation Details:**
- Create PersistenceService.swift to manage SwiftData operations
- Implement CRUD operations for all models
- Handle ModelContext transactions
- Provide methods for querying data with filters and sorting
- Manage background context for sync operations

**Core Methods:**
- saveMessage(message: MessageModel) -> throws
- fetchMessages(conversationId: String) -> [MessageModel]
- fetchConversations(userId: String) -> [ConversationModel]
- saveConversation(conversation: ConversationModel) -> throws
- deleteMessage(messageId: String) -> throws
- fetchPendingMessages() -> [MessageModel] (messages needing sync)

**Transaction Handling:**
- Use ModelContext.save() for persisting changes
- Wrap operations in do-catch for error handling
- Use background context for large batch operations
- Ensure thread safety for concurrent access

**Query Capabilities:**
- Support filtering by conversation, user, sync status
- Support sorting by timestamp, status
- Support pagination for large datasets
- Support counting queries (e.g., unread count)

**Technical Notes:**
- Inject ModelContext via environment or singleton
- Use FetchDescriptor for complex queries
- Handle duplicate prevention (check before inserting)
- Implement proper error handling and logging

**Files Created:**
- Services/PersistenceService.swift

**Dependencies:** Task 2

---

## Task 4: Implement Sync Service

**Description:** Build synchronization service to reconcile local SwiftData with remote Firestore, handling conflicts and ensuring data consistency.

**Implementation Details:**
- Create SyncService.swift to orchestrate bidirectional sync
- Implement push strategy: upload local changes to Firestore
- Implement pull strategy: download Firestore changes to local storage
- Implement conflict resolution: Firestore timestamp wins
- Handle network state changes and trigger sync when online

**Sync Strategies:**
- **Initial Sync:** On app launch, fetch all data from Firestore and save locally
- **Incremental Sync:** After initial sync, only fetch changes since last sync
- **Push Sync:** Upload pending local messages to Firestore
- **Pull Sync:** Download new Firestore messages to local storage

**Conflict Resolution Rules:**
- For messages: Firestore version always wins (use serverTimestamp)
- For conversations: merge fields, prefer most recent lastMessageTime
- For users: Firestore version wins (source of truth for profiles)
- Delete local items that no longer exist in Firestore

**Sync Triggers:**
- App launch (full sync if first launch, incremental otherwise)
- Network connectivity restored (automatic push pending messages)
- Manual pull-to-refresh
- Periodic background sync (every 5 minutes if app is active)

**Technical Implementation:**
- Track last sync timestamp per collection
- Use Firestore queries with .whereField("timestamp", isGreaterThan: lastSync)
- Use batch operations for efficient syncing
- Handle large datasets with pagination

**Error Handling:**
- Network failures: queue for retry
- Permission errors: log and alert user
- Quota limits: implement exponential backoff
- Concurrent modifications: use Firestore transactions

**Files Created:**
- Services/SyncService.swift

**Dependencies:** Task 3, Phase 2 services

---

## Task 5: Implement Network Monitoring

**Description:** Build network state monitoring to detect online/offline transitions and trigger sync operations accordingly.

**Implementation Details:**
- Use Network framework (NWPathMonitor) to monitor network connectivity
- Publish network state changes for UI and services to react
- Distinguish between different connection types (WiFi, Cellular, None)
- Handle VPN and proxy scenarios
- Trigger sync when connectivity is restored

**Network States:**
- Online (WiFi): full sync enabled
- Online (Cellular): sync enabled (consider limiting media uploads)
- Offline: queue operations, disable sync
- Limited connectivity: retry with backoff

**Implementation Approach:**
- Create NetworkMonitor.swift using NWPathMonitor
- Use @Published or @Observable for state changes
- Start monitoring on app launch
- Stop monitoring when app backgrounds (to save battery)

**Sync Integration:**
- When state changes from offline to online, trigger SyncService.pushPendingMessages()
- When state changes from online to offline, pause active syncs
- Show connectivity status in UI (banner or status indicator)

**Technical Notes:**
- NWPathMonitor runs on background queue
- Publish state changes on MainActor for UI updates
- Debounce rapid state changes to avoid sync thrashing
- Consider battery impact of continuous monitoring

**Files Created:**
- Services/NetworkMonitor.swift

**Dependencies:** Task 4

---

## Task 6: Update MessageService for Offline Support

**Description:** Extend MessageService to save messages locally first, then sync to Firestore, enabling offline message composition.

**Implementation Details:**
- Modify sendMessage to save to SwiftData first, then Firestore
- If offline, mark message as "pending upload" and queue for later
- When online, automatically retry pending messages
- Update local message status as sync progresses

**Offline Send Flow:**
1. User composes message and taps send
2. Create MessageModel with isPendingUpload = true
3. Save to SwiftData immediately (optimistic UI update)
4. Attempt Firestore upload asynchronously
5. If successful: update isPendingUpload = false, update Firestore ID
6. If failed (offline): leave in pending state, retry when online
7. NetworkMonitor detects online: SyncService pushes pending messages

**Optimistic UI with Persistence:**
- Message appears in UI immediately (from SwiftData)
- Show "pending" or "sending" status indicator
- When Firestore confirms, update status to "sent"
- If send fails, show error indicator with retry option

**Retry Logic:**
- Implement exponential backoff for failed uploads
- Max retry attempts: 5
- Retry intervals: 1s, 2s, 4s, 8s, 16s
- After max retries, show permanent error state

**Technical Implementation:**
- Check NetworkMonitor.isOnline before attempting Firestore write
- If offline, only save to SwiftData
- If online, save to SwiftData then Firestore
- Use background queue for sync operations

**Files Modified:**
- Services/MessageService.swift
- Services/SyncService.swift (add retry logic)

**Dependencies:** Task 3, Task 4, Task 5

---

## Task 7: Update ConversationService for Offline Support

**Description:** Modify ConversationService to support offline conversation creation and updates with local persistence.

**Implementation Details:**
- Save conversations to SwiftData immediately
- Sync conversation metadata to Firestore when online
- Cache conversation list locally for instant loading
- Update conversation's lastMessage and lastMessageTime locally and remotely

**Offline Conversation Creation:**
- User creates new conversation while offline
- Save conversation to SwiftData with temporary ID
- Mark as isPendingUpload = true
- When online, create conversation in Firestore and update local ID

**Conversation Updates:**
- When message is sent, update conversation's lastMessage and lastMessageTime
- Save update to SwiftData immediately
- Sync to Firestore when online
- Handle conflicts by preferring most recent timestamp

**Technical Implementation:**
- Implement createConversation with offline support
- Implement updateLastMessage with local-first approach
- Use SyncService to push conversation changes to Firestore
- Handle temporary IDs vs. Firestore IDs

**Files Modified:**
- Services/ConversationService.swift

**Dependencies:** Task 3, Task 4

---

## Task 8: Update ViewModels to Use Local Persistence

**Description:** Modify ViewModels to fetch data from SwiftData instead of directly from Firestore, with background sync.

**Implementation Details:**
- ConversationsViewModel: fetch from SwiftData, listen for changes
- ChatViewModel: fetch messages from SwiftData, subscribe to updates
- Use SwiftData queries with @Query property wrapper where possible
- Keep Firestore listeners active for real-time updates in background
- Sync Firestore updates to SwiftData automatically

**Data Flow:**
- UI reads from SwiftData (immediate, no network delay)
- Firestore listeners run in background
- When Firestore updates arrive, save to SwiftData
- SwiftData changes trigger UI updates via @Query or publishers

**ConversationsViewModel Changes:**
- Fetch conversations from PersistenceService instead of Firestore
- Keep ConversationService listener active to catch remote updates
- Save remote updates to SwiftData
- UI reactively updates from SwiftData changes

**ChatViewModel Changes:**
- Fetch messages from PersistenceService
- Keep MessageService listener active for real-time updates
- Save new messages from Firestore to SwiftData
- Display messages from SwiftData (single source of truth for UI)

**Technical Notes:**
- Use @Query in SwiftUI views where possible for automatic updates
- For complex queries, manually observe SwiftData changes
- Ensure no duplicate listeners (one for Firestore, one for SwiftData)
- Handle race conditions between local writes and remote updates

**Files Modified:**
- ViewModels/ConversationsViewModel.swift
- ViewModels/ChatViewModel.swift

**Dependencies:** Task 3, Task 6, Task 7

---

## Task 9: Implement Message Queue Management

**Description:** Build queue management system for pending messages, with retry logic and error handling.

**Implementation Details:**
- Create MessageQueue.swift to manage pending outgoing messages
- Track messages with isPendingUpload = true
- Implement queue processing: attempt upload in order
- Handle queue persistence across app restarts
- Provide UI feedback for queue status

**Queue Operations:**
- Enqueue: add message to queue when send fails or offline
- Dequeue: remove message from queue after successful upload
- Process: attempt to upload all queued messages
- Retry: exponential backoff for failed uploads
- Clear: remove permanently failed messages after max retries

**Queue Processing Logic:**
- Triggered by NetworkMonitor when connectivity restored
- Process messages in chronological order (by timestamp)
- Upload one message at a time (or small batches)
- Update message status as processing progresses
- Stop processing if network is lost again

**Error Handling:**
- Track retry count per message
- Exponential backoff between retries
- Mark as permanently failed after max retries
- Allow user to manually retry failed messages

**UI Integration:**
- Show queue status in conversation row ("1 message pending")
- Show retry button on failed messages
- Show overall sync status (e.g., "Syncing 3 messages...")

**Technical Implementation:**
- Use SwiftData query to fetch pending messages
- Process queue on background thread
- Update UI on main thread
- Persist queue state automatically via SwiftData

**Files Created:**
- Services/MessageQueue.swift

**Dependencies:** Task 6, Task 5

---

## Task 10: Implement Data Sync on App Launch

**Description:** Perform initial data sync when app launches to ensure local cache is up-to-date with Firestore.

**Implementation Details:**
- On app launch, check if initial sync has been performed
- If first launch, perform full sync (download all user's data)
- If subsequent launch, perform incremental sync (only changes since last sync)
- Show loading indicator during initial sync
- Cache last sync timestamp for incremental syncing

**Initial Sync Flow:**
1. App launches and user is authenticated
2. Check if initial sync completed (store flag in UserDefaults)
3. If not completed: fetch all conversations and messages from Firestore
4. Save everything to SwiftData
5. Mark initial sync complete
6. Show main UI

**Incremental Sync Flow:**
1. App launches (not first time)
2. Load data from SwiftData immediately (instant UI)
3. In background, fetch changes from Firestore since last sync
4. Merge changes into SwiftData
5. UI updates automatically as data changes

**Sync Coordination:**
- Track last sync timestamp per collection (conversations, messages, users)
- Use Firestore queries with timestamp filters for efficient syncing
- Handle pagination for large datasets (>1000 items)
- Show progress indicator for long-running syncs

**Technical Implementation:**
- Implement SyncService.performInitialSync() and SyncService.performIncrementalSync()
- Call from CreatorLinkApp or root view on appear
- Use UserDefaults to track sync state
- Update last sync timestamps after successful sync

**Files Modified:**
- Services/SyncService.swift
- CreatorLinkApp.swift (trigger sync on launch)

**Dependencies:** Task 4, Task 8

---

## Task 11: Handle App Lifecycle for Persistence

**Description:** Ensure data persists correctly across app lifecycle events: background, foreground, termination.

**Implementation Details:**
- Save SwiftData context when app backgrounds
- Flush pending writes to disk before termination
- Resume sync when app returns to foreground
- Handle force quit scenarios gracefully

**Lifecycle Events:**
- App backgrounds: save ModelContext, pause sync
- App foregrounds: resume sync, check for pending messages
- App terminates: SwiftData auto-saves (but ensure critical data is saved)

**Implementation Approach:**
- Use scenePhase observer in CreatorLinkApp
- Call ModelContext.save() on background
- Trigger SyncService.processQueue() on foreground
- Ensure no data loss on force quit

**Background Processing:**
- iOS allows limited background time (30 seconds)
- Use background tasks to complete critical syncs
- Don't attempt long-running operations in background
- Queue operations for next foreground session if needed

**Technical Notes:**
- SwiftData ModelContext auto-saves periodically
- Explicitly save on background to ensure persistence
- Test with force quit to verify data integrity
- Monitor console for SwiftData save errors

**Files Modified:**
- CreatorLinkApp.swift
- Services/PersistenceService.swift (if manual save needed)

**Dependencies:** Task 1, Task 3

---

## Task 12: Implement Conflict Resolution

**Description:** Handle conflicts when local and remote data diverge, with clear rules for determining the source of truth.

**Implementation Details:**
- Detect conflicts during sync (local and remote versions differ)
- Apply resolution rules: Firestore timestamp always wins
- Merge non-conflicting fields when possible
- Log conflicts for debugging
- Notify user if critical data was overwritten (optional)

**Conflict Scenarios:**
- Same message modified locally and remotely: use Firestore version
- Conversation updated on multiple devices: merge, prefer recent lastMessageTime
- User profile updated: Firestore wins (profiles only update server-side)
- Message deleted remotely but exists locally: delete local

**Resolution Strategy:**
- Compare lastSyncedAt with Firestore timestamp
- If Firestore timestamp is newer, overwrite local
- If timestamps are equal, no conflict
- For messages, conflict is rare (immutable after creation)

**Message-Specific Handling:**
- Status updates flow one direction (local → Firestore for reads)
- Text content is immutable (no conflicts possible)
- Deleted messages: mark as deleted rather than hard delete

**Technical Implementation:**
- In SyncService, compare timestamps before applying updates
- Use Firestore serverTimestamp as authoritative source
- Update local lastSyncedAt after resolving conflict
- Consider using Firestore transactions for critical operations

**Files Modified:**
- Services/SyncService.swift

**Dependencies:** Task 4

---

## Task 13: Add Offline Indicators to UI

**Description:** Display clear visual indicators when app is offline, messages are pending, or sync is in progress.

**Implementation Details:**
- Show offline banner at top of screen when no connectivity
- Display sync status in conversation list (e.g., "Syncing...")
- Show pending indicator on unsent messages
- Add pull-to-refresh to manually trigger sync

**UI Components:**

**Offline Banner:**
- Red banner at top of screen: "No Internet Connection"
- Appears when NetworkMonitor.isOnline = false
- Dismisses automatically when connectivity restored
- Non-intrusive (doesn't block UI)

**Sync Status:**
- Small text below navigation bar: "Syncing..." with spinner
- Shows during active sync operations
- Shows "X messages pending" if messages are queued
- Disappears when sync complete

**Message Pending Indicator:**
- Gray clock icon or spinner on pending messages
- "Tap to retry" on permanently failed messages
- Different from "sending" status (which is for active uploads)

**Pull-to-Refresh:**
- Available on conversation list and message list
- Triggers manual sync
- Shows progress indicator during sync
- Provides feedback on completion

**Technical Implementation:**
- Observe NetworkMonitor.isOnline for banner
- Observe SyncService.isSyncing for sync status
- Use .refreshable modifier for pull-to-refresh
- Use conditional view rendering for indicators

**Files Modified:**
- Views/Chats/ChatsView.swift
- Views/Chats/ChatDetailView.swift
- Views/Chats/MessageBubbleView.swift

**Files Created:**
- Views/Common/OfflineBannerView.swift (optional)

**Dependencies:** Task 5, Task 9

---

## Task 14: Comprehensive Offline Testing

**Description:** Thoroughly test offline functionality across various scenarios to ensure reliability and data integrity.

**Testing Setup:**
- Two iOS simulators
- Network Link Conditioner for simulating poor connectivity
- Force quit capability to test persistence

**Test Scenarios:**

**Scenario 1: Offline Message Sending**
1. Open app while online, navigate to chat
2. Turn off WiFi on Mac (simulates offline)
3. Send 5 messages in the chat
4. Verify messages appear in UI immediately (optimistic UI)
5. Verify messages have "pending" indicator
6. Turn WiFi back on
7. Verify messages upload to Firestore automatically
8. Verify status changes to "sent" then "delivered" then "read"
9. Check Firestore console to confirm messages exist

**Scenario 2: App Restart with Pending Messages**
1. Go offline and send 3 messages
2. Force quit app (swipe up in app switcher)
3. Reopen app (still offline)
4. Verify messages are still visible in chat
5. Verify pending indicator is still shown
6. Go online
7. Verify messages sync automatically on next app open

**Scenario 3: Offline Message Receiving**
1. User A is online, User B is offline
2. User A sends message to User B
3. User B comes online
4. Verify User B receives message via sync
5. Verify message appears in chat and conversation list

**Scenario 4: Offline Conversation Creation**
1. Go offline
2. Create new conversation with a user
3. Send message in the new conversation
4. Verify conversation appears in list
5. Force quit and reopen (still offline)
6. Verify conversation and message still exist
7. Go online
8. Verify conversation syncs to Firestore

**Scenario 5: Conflict Resolution**
1. Send message on User A's device while online
2. Immediately go offline on both devices
3. Modify message status locally on both devices (simulate conflict)
4. Bring both devices online
5. Verify Firestore version prevails on both devices
6. Verify no duplicate messages

**Scenario 6: Poor Connectivity**
1. Use Network Link Conditioner to simulate 3G speeds
2. Send messages and verify they eventually sync
3. Receive messages and verify they appear (with delay)
4. Verify retry logic handles intermittent failures

**Scenario 7: App Lifecycle**
1. Send message while online
2. Background app immediately
3. Foreground app
4. Verify message successfully sent
5. Repeat with offline scenario

**Verification Points:**
- All messages persist across force quit
- Pending messages auto-sync when online
- No data loss in any scenario
- UI accurately reflects sync state
- Firestore matches local data after sync
- No duplicate messages created
- Conflict resolution works correctly
- Retry logic handles failures gracefully

**Performance Checks:**
- App launches quickly even with large local cache
- Sync completes within reasonable time (< 10 seconds for typical usage)
- Battery usage is acceptable
- No memory leaks from persistence layer

**Dependencies:** All tasks in Phase 4

---

## Phase 4 Completion Checklist

Before moving to Phase 5, verify:
- [ ] SwiftData model container configured
- [ ] SwiftData models created for User, Conversation, Message
- [ ] PersistenceService implemented with CRUD operations
- [ ] SyncService implemented with push/pull strategies
- [ ] Network monitoring active and accurate
- [ ] MessageService supports offline sending
- [ ] ConversationService supports offline operations
- [ ] ViewModels fetch from SwiftData (local-first)
- [ ] Message queue manages pending uploads
- [ ] Data syncs on app launch (initial and incremental)
- [ ] App lifecycle events handled correctly
- [ ] Conflict resolution implemented
- [ ] Offline indicators visible in UI
- [ ] Comprehensive offline testing passed
- [ ] Messages persist across force quit
- [ ] Pending messages auto-sync when online
- [ ] No data loss or corruption

---

## Deliverables

By the end of Phase 4, you should have:
1. Robust offline support with local persistence
2. Reliable message queueing and retry logic
3. Automatic sync when connectivity restored
4. Data integrity across all lifecycle events
5. Professional offline UX with clear indicators
6. Production-ready persistence layer

---

## Known Issues and Future Improvements

- SwiftData performance with very large datasets (>10,000 messages) - may need optimization
- Background sync limited by iOS background execution limits
- Conflict resolution is simple (Firestore wins) - could be more sophisticated
- No peer-to-peer sync for offline scenarios (requires server mediation)

---

## Notes for Next Phase

Phase 5 will extend the messaging infrastructure to support group chats:
- Multi-participant conversations
- Group-specific UI (member list, group name)
- Delivery and read receipts for multiple users
- Group typing indicators

The offline persistence built in Phase 4 will work seamlessly with group chats, as the data models already support multiple participants.
