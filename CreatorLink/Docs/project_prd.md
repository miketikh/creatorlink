# MessageAI PRD: MVP-First Messaging App

## Project Overview

Build a production-quality cross-platform messaging app with real-time sync, offline support, and AI features tailored for content creators/influencers. Focus: prove core messaging infrastructure works flawlessly before adding AI capabilities.

**Timeline:** 7 days (Tuesday MVP checkpoint, Sunday final submission)

## Key Decisions

- **Platform:** Swift with SwiftUI (iOS native)
- **Backend:** Firebase (Firestore, Auth, Cloud Functions, FCM)
- **Local Storage:** SwiftData
- **Auth:** Firebase Auth with Google Sign-In
- **Testing:** Two iOS simulators (no TestFlight required for MVP)
- **AI Target Persona:** Content Creator/Influencer (implemented post-MVP)

## Success Criteria by Timeline

### MVP Checkpoint (Tuesday, 24 hours)
Hard gate. Must demonstrate:
- Two simulators chatting in real-time
- Messages persist after app restart
- Optimistic UI (messages appear instantly)
- Basic group chat (3+ users)
- Online/offline status
- Read receipts
- Typing indicators
- Push notifications (foreground minimum)
- Image sending/receiving
- All core message states working (sending → sent → delivered → read)

### Final Submission (Sunday, 7 days)
Everything above PLUS:
- 5 required AI features for content creators
- 1 advanced AI capability
- Polished UI/UX
- Demo video showing all features
- GitHub repo with setup instructions

## Architecture

### Tech Stack
- **Frontend:** Swift, SwiftUI, SwiftData
- **Backend:** Firebase (Firestore realtime database, Cloud Functions, Auth, FCM)
- **AI:** OpenAI GPT-4 or Anthropic Claude via Cloud Functions
- **Agent Framework:** AI SDK by Vercel or LangChain

### Data Flow
1. User sends message → immediate local write (SwiftData) + optimistic UI update
2. Message queued to Firebase → background sync
3. Firebase triggers real-time listener on recipient device
4. Recipient receives → local storage + UI update
5. Read receipt flows back through same pipeline

### Firebase Collections Structure

```
users/
  {userId}/
    displayName: string
    photoURL: string?
    email: string
    isOnline: boolean
    lastSeen: timestamp

conversations/
  {conversationId}/
    participantIds: [string]
    lastMessage: string
    lastMessageTime: timestamp
    isGroupChat: boolean
    groupName: string?

messages/
  {messageId}/
    conversationId: string
    senderId: string
    text: string
    timestamp: timestamp
    status: "sending" | "sent" | "delivered" | "read"
    readBy: [userId: timestamp]
    imageUrl: string?
    metadata: {}  // Future: AI categorization, sentiment, etc.
```

### Message States
- **sending:** Local only, queued for Firebase
- **sent:** Confirmed by Firebase
- **delivered:** Received on recipient device(s)
- **read:** Recipient opened conversation

### SwiftData Models
Mirror Firebase structure for offline-first capability. Sync strategy: write local first, then sync to Firebase. On reconnect, reconcile any conflicts (Firebase timestamp wins).

## Build Phases

### Phase 1: Foundation (Day 1 Morning)
**Deadline: Day 1, 12pm**

**Firebase Setup:**
- Create Firebase project
- Enable Auth, Firestore, Cloud Functions, FCM
- Configure security rules (authenticated users only)
- Create composite indexes for message queries

**Xcode Project:**
- Create SwiftUI app
- Add Firebase SPM packages
- Configure Info.plist for Firebase
- Setup basic app structure: TabView (Chats, Profile)

**Authentication:**
- Firebase Auth integration
- Google Sign-In flow
- User profile creation (name, photo)
- Persist auth state

### Phase 2: Core Messaging (Day 1 Afternoon - Day 2 Morning)
**Deadline: Day 2, 10am**

**Goal: Send text message from User A → User B in real-time**

**Data Layer:**
- SwiftData models (User, Conversation, Message)
- Firebase service classes (AuthService, MessageService, ConversationService)
- Real-time Firestore listeners

**UI Layer:**
- Chat list view (all conversations)
- Chat detail view (message thread)
- Message input field
- Send button

**Core Functionality:**
- Create/fetch conversation
- Send text message
- Receive messages (real-time listener)
- Display messages in chronological order
- Optimistic UI updates

### Phase 3: Message Infrastructure (Day 2 Afternoon)
**Deadline: Day 2, 6pm**

**Message States:**
- Implement status flow: sending → sent → delivered → read
- Visual indicators for each state
- Retry logic for failed sends
- Queue management for offline messages

**Presence & Indicators:**
- Online/offline status (Firestore presence with onDisconnect)
- Typing indicators (ephemeral state, not persisted)
- Timestamps on messages
- "Last seen" for offline users

**Read Receipts:**
- Track when user opens conversation
- Update message.readBy map
- Display read status to sender

### Phase 4: Persistence & Offline (Day 2 Evening)
**Deadline: Day 3, 9am**

**Local Storage:**
- SwiftData persistence layer
- Save all messages locally
- Cache conversations and user profiles
- Sync strategy implementation

**Offline Handling:**
- Detect network state
- Queue messages when offline
- Auto-send when online
- Handle app lifecycle (background, foreground, force quit)
- Conflict resolution

**Testing Scenarios:**
- Force quit app, reopen → messages still there
- Go offline, send message → appears in queue
- Come online → message sends automatically
- Airplane mode testing

### Phase 5: Group Chat (Day 3 Morning)
**Deadline: Day 3, 2pm**

**Group Infrastructure:**
- Multi-participant conversations (up to 10)
- Group metadata (name optional)
- Member list display

**Group Messaging:**
- Send message to all participants
- Delivery tracking per member
- Read receipts from multiple users
- Message attribution (show sender name/photo)

### Phase 6: Media & Polish (Day 3 Afternoon)
**Deadline: Day 3, 8pm**

**Image Support:**
- Image picker integration
- Upload to Firebase Storage
- Download and display images
- Thumbnail generation
- Loading states

**Push Notifications:**
- FCM setup and configuration
- Foreground notifications
- Background notifications (best effort)
- Notification payload with conversation context

**UI Polish:**
- Profile pictures throughout
- Smooth animations
- Pull-to-refresh
- Loading states
- Error handling UI

### Phase 7: MVP Testing & Hardening (Day 4 Morning)
**Deadline: Day 4, 12pm - MVP COMPLETE**

**Comprehensive Testing:**
- Two simulators side-by-side testing
- Rapid-fire messages (20+ quickly)
- Group chat with 3 users
- Offline/online scenarios
- App lifecycle testing
- Poor network simulation

**Bug Fixes:**
- Fix any critical issues
- Ensure reliable message delivery
- Verify all MVP checkpoints met

---

## AI Features (Post-MVP)

**Note:** AI features are intentionally excluded from Phases 1-7 to avoid scope creep before MVP. The `metadata` field on messages is a placeholder for future AI data.

### Required AI Features (All 5)
1. Auto-categorization: fan/business/spam/urgent
2. Response drafting in creator's voice
3. FAQ auto-responder
4. Sentiment analysis
5. Collaboration opportunity scoring

### Advanced AI Feature (Pick 1)
- Context-aware smart replies (learns creator's personality)
- OR Multi-step agent (handles daily DMs, auto-responds, flags important)

### AI Implementation (Day 4-7)
- Cloud Functions for OpenAI/Claude API calls
- RAG pipeline for conversation history
- AI interface (likely contextual: long-press message → AI actions)
- Agent framework setup
- Tool calling for message operations
- Prompt engineering and testing

## Non-Goals for MVP
- Video/voice messages
- End-to-end encryption
- Message editing/deletion
- User blocking
- Advanced group features (admins, permissions)
- Cross-platform (Android, web)
- Message search (beyond basic)
- File attachments (non-image)

## Testing Strategy

**MVP Proof Points:**
1. Two simulators open side-by-side
2. User A sends message → appears on User B instantly
3. Force quit both apps → reopen → messages persist
4. Turn off wifi on one simulator → send messages → turn wifi back on → messages deliver
5. Create group with 3 users → all receive messages
6. Send 20 messages rapidly → all deliver reliably
7. Send image → displays correctly

**Demo Video Requirements:**
- Show simulator setup (two devices)
- Real-time chat demonstration
- Offline/online scenario
- Group chat
- Image sending
- App restart with persistence
- AI features in action (post-MVP)

## Risk Mitigation

**High Risk Areas:**
- **Firebase sync reliability:** Test extensively on Day 2-3
- **Offline message queue:** Can break easily, needs careful state management  
- **Push notifications:** iOS background limitations, may not work perfectly
- **App lifecycle:** Messages lost if not properly persisted

**Mitigation:**
- Build messaging infrastructure FIRST, verify rock-solid
- Extensive offline testing before moving to AI
- Accept push notifications may be imperfect for MVP
- SwiftData auto-save + manual sync checkpoints

## Success Metrics

**MVP:**
- ✅ Can send 100 messages between two users with zero failures
- ✅ Messages survive force quit + reopen
- ✅ Offline queue works reliably
- ✅ Group chat functional with 3+ users

**Final:**
- ✅ All 5 AI features working with real examples
- ✅ Advanced AI feature demonstrates clear value
- ✅ Demo video covers all requirements
- ✅ Deployed and testable (even if just simulators)