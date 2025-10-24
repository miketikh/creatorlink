# Intelligent Group FAQ Feature - iOS & Firebase Implementation Plan

## Overview
This plan outlines the changes needed to implement an AI-powered FAQ detection system that automatically links similar questions in group chats to previous answers. The system uses a Python AI service (already implemented) that is triggered by Firebase Cloud Functions when messages are created.

---

## PHASE 1: Data Model & Schema Changes

### 1.1 Conversation Model Updates
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Conversation.swift`

**Changes:**
- Add `aiEnabled: Bool` property (default: false)
- Add `aiConfig: AIConfig?` nested struct with:
  - `faqDetectionEnabled: Bool` (default: true)
  - `minimumSimilarity: Double` (default: 0.85)
- Update `CodingKeys` enum to include new fields
- Update `hash(into:)` and `==` methods to include new properties
- Update initializer to accept new optional parameters

**Firestore Schema:**
```
conversations/{convId}
  aiEnabled: Boolean (default: false)
  aiConfig: {
    faqDetectionEnabled: Boolean
    minimumSimilarity: Number
  }
```

**Considerations:**
- Make fields optional in Codable to support existing conversations without migration
- aiConfig should only exist when aiEnabled is true

### 1.2 Message Model Updates
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Message.swift`

**Current State:** Message model already has `metadata: [String: String]?` field (line 21)

**Changes:**
- NO CODE CHANGES NEEDED - metadata field already exists
- Document the metadata keys that AI will use:
  - `isAIMessage: "true"` - flags AI-generated messages
  - `faqReference: String` - messageId of original answer being referenced
  - `matchConfidence: String` - similarity score (e.g., "0.92")
  - `matchedQuestion: String` - the original question text

**Note:** MessageBubbleView already checks `message.metadata?["ai_generated"] == "true"` (line 113), so we need to ensure Python service uses consistent key naming.

### 1.3 UserProfile Model - AI User
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/UserProfile.swift`

**Changes:** NO MODEL CHANGES NEEDED

**Firestore Document to Create:**
```
users/ai-assistant
  id: "ai-assistant"
  displayName: "AI Assistant"
  email: "ai@creatorlink.app"
  photoURL: "https://ui-avatars.com/api/?name=AI&background=6366f1&color=fff"
  isOnline: true
  lastSeen: [current timestamp]
```

**Implementation:** Create one-time setup script or manual Firestore entry

---

## PHASE 2: AI User & Participant Management

### 2.1 AI User Constant
**New File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/AIConstants.swift`

**Content:**
```swift
struct AIConstants {
    static let AI_USER_ID = "ai-assistant"
    static let AI_DISPLAY_NAME = "AI Assistant"
    // Add other AI-related constants
}
```

### 2.2 Group Creation - AI Toggle
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupNameInputView.swift`

**Changes:**
- Add `@State private var enableAI: Bool = false` toggle state
- Add new Form section with Toggle("Enable AI Assistant")
- When creating group, if `enableAI` is true:
  - Add `AIConstants.AI_USER_ID` to participantIds array
  - Set conversation `aiEnabled = true`
  - Set default `aiConfig` values
- Update group creation call in ConversationService

**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift`

**Changes:**
- Update `createConversation()` method signature to accept optional `aiEnabled: Bool` and `aiConfig: AIConfig?` parameters
- When creating conversation document, include these fields if provided
- Ensure AI user is properly counted in participant list

### 2.3 Existing Groups - Add AI
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift`

**Changes:**
- Add new "AI Assistant" section in Form with:
  - Toggle for enabling/disabling AI
  - Conditional settings UI when enabled (FAQ detection toggle, similarity slider)
- Add method `toggleAIAssistant()` that:
  - Adds/removes AI_USER_ID from participantIds
  - Updates aiEnabled field
  - Updates conversation in Firestore
- Display AI badge/indicator in participant list when AI is enabled

**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/GroupInfoViewModel.swift`

**Changes:**
- Add method `toggleAI(conversationId: String, enabled: Bool)`
- Add method `updateAIConfig(conversationId: String, config: AIConfig)`
- Handle Firestore updates using arrayUnion/arrayRemove for participant management

### 2.4 Participant List Display
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/ParticipantRowView.swift`

**Changes:**
- Add special rendering for AI user:
  - Show robot/sparkles icon
  - Display "AI Assistant" with badge
  - Different styling (purple accent?)
- Add `isAIUser` computed property checking if `participant.id == AIConstants.AI_USER_ID`

**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift` (participants section)

**Changes:**
- Filter participant count to exclude AI when displaying "X members"
- Show "3 members + AI" or similar format
- Prevent AI from being removed via swipe/context menu (show info dialog instead)

---

## PHASE 3: Message Rendering & UI

### 3.1 AI Message Styling
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift`

**Current State:** Already has basic AI message detection (line 112-113) and purple background (line 117-120)

**Changes:**
- Update `isAIMessage` check to look for both:
  - `message.metadata?["ai_generated"] == "true"` OR
  - `message.senderId == AIConstants.AI_USER_ID`
- Enhance AI bubble styling:
  - Add sparkles icon (already exists but may need positioning adjustment)
  - Consider adding "AI" badge label
  - Distinct color scheme (currently light purple - keep or adjust)
- Show sender name as "AI Assistant" in group chats

### 3.2 FAQ Reference Links
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift`

**New Component:** `FAQReferenceLinkView` (can be inline or separate file)

**Changes:**
- Inside MessageBubbleView, after message text, check for `metadata["faqReference"]`
- If exists, render link component showing:
  - Icon (e.g., `arrow.up.forward` or `link.circle`)
  - Text: "View original answer →" or "Similar question asked before"
  - Optional: Show matched question preview
  - Optional: Show confidence score as badge
- Make tappable with `onTapGesture` that calls `onTapFAQReference` closure

**Closure signature:**
```swift
var onTapFAQReference: ((String) -> Void)? = nil  // messageId parameter
```

### 3.3 Message Scroll-to Functionality
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift`

**Current State:** Already has ScrollViewProxy and scrollTo functionality (lines 28, 176, 260, 432, 604)

**Changes:**
- Add `@State private var highlightedMessageId: String?` for flash animation
- Add method `scrollToMessage(messageId: String)` that:
  1. Fetches message from messages array or Firestore if not loaded
  2. Uses existing `scrollProxy?.scrollTo(messageId, anchor: .center)`
  3. Sets `highlightedMessageId` to trigger flash animation
  4. Clears highlight after delay
- Pass `onTapFAQReference` closure to MessageBubbleView that calls `scrollToMessage()`

**New Component:** Flash highlight overlay
- Add `.background()` modifier to message bubble when `messageId == highlightedMessageId`
- Use yellow/blue flash animation with opacity fade

**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift`

**Changes:**
- Add method `fetchMessageById(messageId: String) async -> Message?` for loading referenced messages not in current view
- Cache loaded messages to avoid refetching

### 3.4 Message Context Display
**Enhancement:** When scrolling to referenced message, optionally show 2-3 messages before/after for context

**Implementation:**
- Calculate index of target message
- Ensure surrounding messages are visible in scroll view
- Optional: Gray out or fade non-relevant messages temporarily

---

## PHASE 4: Firebase Cloud Functions & Security

### 4.1 Cloud Function Updates
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts`

**Current State:** Already calls Python service at line 54-63 but doesn't check for aiEnabled

**Changes:**
- Before calling Python service, check if conversation has `aiEnabled: true`
- Fetch conversation document at start of function
- Only proceed with Python service call if:
  - `conversation.aiEnabled === true`
  - `conversation.aiConfig?.faqDetectionEnabled !== false`
- Update payload to include aiConfig settings:
```typescript
const payload = {
  messageId,
  conversationId,
  senderId,
  text,
  timestamp,
  participantIds,
  aiConfig: conversationData?.aiConfig || {} // NEW
};
```

**Build Requirement:** After changes, run `npm run build` in `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions`

### 4.2 AI User ID Consistency
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts`

**Current State:** Checks for `senderId === "ai-agent"` (line 27)

**Changes:**
- Create constant `AI_USER_ID = "ai-assistant"` (match iOS)
- Update check to use constant
- Ensure Python service uses same ID when creating messages

**File:** `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py`

**Assumption:** Update sender_id to "ai-assistant" (verify against actual file)

**File:** `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py`

**Current State:** Uses "ai-agent" at line 139

**Changes:**
- Update to "ai-assistant" to match iOS convention
- Update metadata key to use consistent naming:
  - Change "ai_generated" to "isAIMessage" OR update iOS to check "ai_generated"
  - Recommend: Keep "ai_generated" as it's already used in MessageBubbleView.swift

### 4.3 Firestore Security Rules
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/firebase/firestore.rules`

**Current State:**
- Messages: `allow create` requires `request.auth.uid == request.resource.data.senderId` (line 57)
- Conversations: Participant-based read/write rules

**Changes:**

**Messages Collection (line 52-64):**
```javascript
match /messages/{messageId} {
  allow read: if isAuthenticated() &&
                 request.auth.uid in resource.data.participantIds;

  // Allow AI to create messages, prevent impersonation
  allow create: if isAuthenticated() && (
                     (request.auth.uid == request.resource.data.senderId &&
                      request.auth.uid in request.resource.data.participantIds) ||
                     // AI service account can post as AI user
                     (request.auth.uid == 'ai-service-account' &&
                      request.resource.data.senderId == 'ai-assistant')
                   );

  allow update: if isAuthenticated() &&
                   request.auth.uid in resource.data.participantIds;

  allow delete: if false;
}
```

**Conversations Collection (line 22-49):**
```javascript
// Add after line 26 - allow AI to be added to conversations
allow create: if isAuthenticated() &&
                 (request.auth.uid in request.resource.data.participantIds ||
                  request.resource.data.participantIds.hasAny(['ai-assistant']));
```

**Important:** AI service needs Firebase Admin SDK (already has it) - these rules apply to client-side iOS app to prevent users from impersonating AI

### 4.4 Python Service Metadata Format
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py`

**Current metadata (lines 129-134):**
```python
response_metadata = {
    "ai_generated": "true",
    "original_message_id": request.messageId,
    "agent_type": "echo",
    "agent_version": "0.1.0"
}
```

**For FAQ feature, update to:**
```python
response_metadata = {
    "ai_generated": "true",  # Keep for backward compatibility
    "isAIMessage": "true",   # Add for consistency
    "original_message_id": request.messageId,
    "agent_type": "faq_detector",
    "agent_version": "0.2.0",
    # Add when FAQ match is found:
    "faqReference": matched_message_id,  # if FAQ detected
    "matchConfidence": "0.92",           # similarity score
    "matchedQuestion": original_question # original question text
}
```

---

## PHASE 5: Testing & Demo Data

### 5.1 AI User Setup Script
**New File:** `/Users/Gauntlet/gauntlet/CreatorLink/scripts/setup_ai_user.js`

**Purpose:** One-time setup to create AI user in Firestore

**Content:**
```javascript
// Firebase Admin script to create AI user
// Run: node scripts/setup_ai_user.js
const admin = require('firebase-admin');
// ... initialize admin SDK
// ... create users/ai-assistant document
```

**Alternative:** Manual creation via Firebase Console or during app first launch

### 5.2 Demo Group Data Structure

**Group 1: "Brand Partnerships"**
- Participants: user1, user2, user3, ai-assistant
- aiEnabled: true
- Sample messages:
  1. User1: "What are your rates?"
  2. User2: "I charge $500/hour for sponsored content"
  3. [Later] User3: "How much do you charge?"
  4. AI: "💡 This was asked before! [User2] answered: 'I charge $500/hour...'" [links to message #2]

**Group 2: "Content Collaboration"**
- Participants: user1, user2, user3, user4, ai-assistant
- aiEnabled: true
- Sample messages focusing on scheduling questions

**Implementation Options:**
1. **Script approach:** Create `/Users/Gauntlet/gauntlet/CreatorLink/scripts/create_demo_data.js`
2. **iOS test data:** Add debug menu in app to create test groups
3. **Manual:** Create via app UI and manually send test messages

### 5.3 Test Scenarios

**Scenario 1: New Group with AI**
1. Create new group with 3 users
2. Enable "AI Assistant" toggle
3. Verify AI appears in participant list with badge
4. Send test message
5. Verify Python service is called (check logs)

**Scenario 2: Add AI to Existing Group**
1. Open existing group settings
2. Enable AI toggle
3. Verify AI added to participants
4. Verify aiEnabled field updated in Firestore

**Scenario 3: FAQ Detection**
1. In AI-enabled group, send question
2. Send answer
3. Later, send similar question
4. Verify AI responds with link to original answer
5. Tap link, verify scroll-to works
6. Verify highlight animation

**Scenario 4: Remove AI**
1. Open group settings
2. Disable AI toggle
3. Verify AI removed from participants
4. Verify new messages don't trigger Python service

---

## PHASE 6: Additional Considerations

### 6.1 Error Handling
- Handle case where referenced message no longer exists (deleted conversation)
- Handle case where Python service is down (log error, don't show AI message)
- Handle case where scrollTo fails (message not loaded in current window)

### 6.2 Performance Optimizations
- Cache loaded messages for FAQ references
- Limit FAQ search to recent messages (e.g., last 100 messages)
- Index messages for faster similarity search (Python service responsibility)

### 6.3 UI/UX Polish
- Loading indicator when scrolling to referenced message
- Smooth scroll animation (already implemented via .easeInOut)
- Toast/banner when AI is added to group: "AI Assistant joined the group"
- Settings: Allow users to mute AI responses per-group

### 6.4 Analytics
**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/AnalyticsService.swift`

**New events to track:**
- `ai_enabled_in_group`
- `ai_disabled_in_group`
- `ai_faq_link_tapped`
- `ai_message_sent`
- `ai_config_updated`

### 6.5 Accessibility
- VoiceOver support for FAQ links: "Link to previous answer by [User] from [date]"
- Screen reader announcement when scrolling to referenced message
- Keyboard navigation support for FAQ links

---

## Implementation Order Recommendation

**Week 1: Foundation**
1. Phase 1 - Data models (1-2 days)
2. Phase 2.1-2.2 - AI user constant + group creation (1 day)
3. Phase 4.3 - Security rules (1 day)

**Week 2: Core Features**
4. Phase 2.3-2.4 - Existing group AI management (2 days)
5. Phase 3.1 - AI message styling (1 day)
6. Phase 4.1-4.2 - Cloud function updates (1 day)

**Week 3: FAQ Functionality**
7. Phase 3.2-3.3 - FAQ links + scroll-to (2-3 days)
8. Phase 5.1-5.2 - Demo data setup (1 day)
9. Phase 5.3 - Testing (1-2 days)

**Week 4: Polish**
10. Phase 6 - Error handling, analytics, accessibility (2-3 days)
11. Final QA and bug fixes (1-2 days)

---

## Key Files Summary

### Modified Files
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Conversation.swift`
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupNameInputView.swift`
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift`
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/GroupInfoViewModel.swift`
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift`
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift`
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift`
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift`
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/ParticipantRowView.swift`
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts`
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/firestore.rules`
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py`
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py` (assumed)

### New Files
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/AIConstants.swift`
- `/Users/Gauntlet/gauntlet/CreatorLink/scripts/setup_ai_user.js` (optional)
- `/Users/Gauntlet/gauntlet/CreatorLink/scripts/create_demo_data.js` (optional)

### External Dependencies
**No new iOS dependencies needed** - all features use existing SwiftUI/Firebase SDKs

**Python Service:** May need FAQ detection libraries (already handled in python-service implementation)

---

## Notes & Assumptions

1. **Message Model:** Assumed metadata field supports FAQ-specific keys - verified at line 21 of Message.swift
2. **ScrollViewProxy:** Verified ChatDetailView already has scroll-to functionality - no new implementation needed
3. **AI User ID:** Used "ai-assistant" for consistency (Cloud Function currently uses "ai-agent" - needs update)
4. **Python Service:** Assumed it will be updated to include FAQ detection logic and proper metadata formatting
5. **Firestore Security:** Assumes Firebase Admin SDK is used by Cloud Functions (verified - admin.initializeApp() at line 14 of index.ts)
6. **Message Bubble Styling:** Basic AI detection already exists - needs enhancement for FAQ-specific UI
7. **No dummy data script found:** Will need to create from scratch or use manual approach

---

## Risk Mitigation

**Risk 1:** Python service down causes messages to not get AI responses
- **Mitigation:** Cloud Function logs error but doesn't fail message creation (already implemented at line 71-85)

**Risk 2:** Infinite loops with AI responding to AI
- **Mitigation:** Already handled via senderId check at line 27 of index.ts

**Risk 3:** FAQ links to deleted messages
- **Mitigation:** Graceful error handling in scrollToMessage() - show toast "Original message not found"

**Risk 4:** Performance issues with large message history
- **Mitigation:** FAQ search in Python service should be scoped/indexed (Python service responsibility)

**Risk 5:** Users impersonating AI
- **Mitigation:** Firestore security rules prevent client-side apps from setting senderId to AI user

---

## Success Criteria

- [ ] Users can enable/disable AI when creating new groups
- [ ] Users can add/remove AI from existing groups
- [ ] AI messages display with distinct styling (purple bubble, sparkles icon)
- [ ] FAQ links appear in AI messages when similar questions detected
- [ ] Tapping FAQ link scrolls to referenced message with highlight animation
- [ ] AI participant shows in group member list with special badge
- [ ] Security rules prevent AI impersonation
- [ ] Cloud Function only triggers Python service for AI-enabled groups
- [ ] Demo data can be created for testing
- [ ] All existing functionality remains working (no regressions)
