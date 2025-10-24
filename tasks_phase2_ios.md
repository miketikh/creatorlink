# Intelligent Group FAQ Feature - iOS Implementation Tasks (Phases 3-4)

## Overview

This document contains the implementation tasks for **Phases 3-4** of the intelligent group FAQ detection feature. These phases build on the data model and AI user management foundations (Phases 1-2) to deliver the core user-facing functionality:

- **Phase 3**: Message Rendering & UI - Display AI messages with special styling and FAQ reference links
- **Phase 4**: Firebase Cloud Functions & Security - Configure backend to check aiEnabled flag and enforce security rules

These phases complete the FAQ detection feature, allowing users to see AI-generated responses with links to previous answers, and ensuring proper security controls are in place.

**Context**: This builds on the iOS implementation plan documented in `/Users/Gauntlet/gauntlet/CreatorLink/plan_ios.md`. Phases 1-2 (Data Models and AI User Management) must be completed before starting these phases.

**Note on Data Migration**: No data migration is needed - we assume data is currently empty and will use seed data for testing.

---

## Instructions for AI Agent

When implementing these tasks:
1. **Work sequentially** - Complete Phase 3 before Phase 4
2. **Test after each PR** - Follow the "What to Test" instructions to verify functionality
3. **Use existing patterns** - Reference similar services and views for code style
4. **Preserve existing functionality** - Don't break current message rendering or AI service calls
5. **Follow Swift/SwiftUI conventions** - Use @Observable for services, async/await for asynchronous operations
6. **Update types.md** - Any time model or schema changes are made, update the types documentation

**File path conventions:**
- Services: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/`
- Views: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/`
- Models: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/`
- Components: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/`
- Firebase Functions: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/`
- Python Service: `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/`

---

## Phase 3: Message Rendering & UI

**Estimated Time:** 2-3 days

This phase implements the user-facing components for displaying AI messages with special styling and FAQ reference links, plus the ability to navigate to referenced messages.

### PR 3.1: Enhance AI Message Detection and Styling

**Goal:** Update MessageBubbleView to properly detect AI messages and enhance their visual styling.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/AIConstants.swift` (should exist from Phase 2)
  - Verify constant `AI_USER_ID = "ai-assistant"` exists
  - If file doesn't exist, create it with this constant
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift`
- [ ] Locate the `isAIMessage` computed property (around line 112-114)
- [ ] Update the check to detect both metadata flag AND sender ID:
  ```swift
  private var isAIMessage: Bool {
      message.metadata?["ai_generated"] == "true" ||
      message.senderId == AIConstants.AI_USER_ID
  }
  ```
- [ ] Enhance the AI badge display in the message bubble HStack (lines 67-81)
  - Keep existing sparkles icon
  - Add "AI" text label next to the icon for clarity
  - Use `.font(.caption)` for the label
  - Ensure both icon and label use purple color scheme
- [ ] Update the `backgroundColor` computed property (lines 116-122)
  - Consider making AI messages more visually distinct
  - Current: `Color(red: 0.75, green: 0.6, blue: 0.9, opacity: 0.2)`
  - Recommended: Slightly increase opacity or adjust tint for better visibility
- [ ] In group chat rendering, ensure AI sender name displays as "AI Assistant"
  - Update line 27 to check if sender is AI and override name
  - Use AIConstants.AI_DISPLAY_NAME if available, else "AI Assistant"

**What to Test:**
1. Build the app to verify no compilation errors
2. Open a group conversation that has AI enabled (from Phase 2)
3. Manually create a test message in Firestore with `senderId: "ai-assistant"`
4. Verify AI message appears with purple background and sparkles icon
5. Verify "AI" badge label is visible and readable
6. Test with both metadata flag and senderId detection methods
7. In group chat, verify sender name shows "AI Assistant" not a user name
8. Compare styling to regular user messages - should be clearly distinguishable

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift` - Enhanced AI message detection and styling
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/AIConstants.swift` - Verify or create AI constants (may already exist from Phase 2)

**Notes:**
- The check needs both conditions because Python service uses metadata flag, but we also want to catch any direct messages from AI user ID
- Purple/indigo color scheme is standard for AI features - maintain brand consistency
- Don't break existing non-AI message rendering
- This prepares for FAQ link rendering in next PR

---

### PR 3.2: Create FAQ Reference Link Component

**Goal:** Build a reusable component that displays FAQ reference links with tap handling.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/FAQReferenceLinkView.swift`
- [ ] Import SwiftUI
- [ ] Create `FAQReferenceLinkView` struct conforming to View
- [ ] Add properties:
  - `let faqReferenceId: String` - messageId of referenced answer
  - `let matchedQuestion: String?` - optional original question text
  - `let matchConfidence: String?` - optional similarity score
  - `let onTap: () -> Void` - closure to handle tap
- [ ] Implement view body with:
  - HStack containing:
    - Icon: `Image(systemName: "arrow.up.forward.circle.fill")` or `"link.circle.fill"`
    - Text: "View original answer →" or "Similar question asked before"
    - Optional confidence badge if matchConfidence provided (e.g., "92% match")
  - Styling:
    - Background: Light blue or purple tint (matching AI theme)
    - Padding: 12pt horizontal, 8pt vertical
    - Corner radius: 10pt
    - Font: `.subheadline` or `.callout`
  - `.onTapGesture` that calls `onTap()` closure
- [ ] Add optional preview of matched question if provided
  - Show truncated version below main link text
  - Use `.font(.caption)` and `.foregroundColor(.secondary)`
  - Limit to 2 lines with `.lineLimit(2)`
- [ ] Add hover/press effect for better UX
  - Use `.scaleEffect()` with animation on tap

**What to Test:**
1. Create preview in Xcode with sample data
2. Verify link appears with icon and text
3. Test with and without matchedQuestion preview
4. Test with and without confidence badge
5. Tap the link and verify onTap closure is called (print debug message)
6. Verify styling matches AI message theme
7. Test with long question text - should truncate properly
8. Verify press animation provides tactile feedback

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/FAQReferenceLinkView.swift` - NEW: FAQ reference link component

**Notes:**
- Keep component simple and reusable - all logic handled by parent view
- Match color scheme with AI message bubbles for visual consistency
- Consider accessibility - VoiceOver should announce "Button: View original answer"
- The component just displays and handles tap - navigation logic is in parent

---

### PR 3.3: Integrate FAQ Links into MessageBubbleView

**Goal:** Display FAQ reference links inside AI message bubbles when metadata contains FAQ references.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift`
- [ ] Add new optional closure property at top of struct:
  ```swift
  var onTapFAQReference: ((String) -> Void)? = nil  // messageId parameter
  ```
- [ ] Inside the VStack containing the message bubble (around line 65-101), after the message text bubble and before the timestamp
- [ ] Add conditional FAQ link rendering:
  ```swift
  // FAQ Reference Link (if metadata contains faqReference)
  if let faqRefId = message.metadata?["faqReference"] {
      FAQReferenceLinkView(
          faqReferenceId: faqRefId,
          matchedQuestion: message.metadata?["matchedQuestion"],
          matchConfidence: message.metadata?["matchConfidence"],
          onTap: {
              onTapFAQReference?(faqRefId)
          }
      )
      .padding(.top, 4)
  }
  ```
- [ ] Ensure FAQ link appears below message text but above timestamp
- [ ] Handle alignment properly for sent vs received messages
- [ ] Import the FAQReferenceLinkView component at top of file
- [ ] Update the frame/padding to accommodate the additional content

**What to Test:**
1. Create test message in Firestore with metadata:
   ```json
   {
     "ai_generated": "true",
     "faqReference": "msg123",
     "matchedQuestion": "What are your rates?",
     "matchConfidence": "0.92"
   }
   ```
2. Verify FAQ link appears below the AI message text
3. Verify alignment matches message bubble (left for received, right for sent)
4. Verify matched question preview displays if provided
5. Verify confidence badge shows "92% match"
6. Tap link and check console - should print the faqReferenceId
7. Test with message that has no faqReference - should show no link
8. Test with partial metadata (only faqReference, no confidence) - should gracefully handle
9. Verify regular messages (non-AI) don't show FAQ links

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift` - Add FAQ link rendering

**Notes:**
- Only AI messages should have FAQ metadata, but check defensively
- The closure pattern allows parent view to handle navigation
- Maintain proper spacing and alignment with existing message elements
- FAQ link should be visually part of the message bubble but distinct from the text

---

### PR 3.4: Add Scroll-to-Message Functionality

**Goal:** Implement the ability to scroll to and highlight a specific message when tapped.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift`
- [ ] Add new method `fetchMessageById(messageId: String) async -> Message?`
  - Query Firestore messages collection for specific messageId
  - Use `MessageService.shared` if available, or query directly
  - Return the message if found, nil if not
  - Add error handling with logging
  - Cache the result to avoid repeated fetches
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift`
- [ ] Add new state property:
  ```swift
  @State private var highlightedMessageId: String?
  ```
- [ ] Locate the existing ScrollViewProxy usage (already exists around line 28)
- [ ] Add new method `scrollToMessage(messageId: String) async`:
  ```swift
  private func scrollToMessage(messageId: String) async {
      // First check if message is in current loaded messages
      if viewModel.messages.contains(where: { $0.id == messageId }) {
          // Message already loaded - scroll immediately
          await MainActor.run {
              scrollProxy?.scrollTo(messageId, anchor: .center)
              highlightedMessageId = messageId
          }
      } else {
          // Message not loaded - fetch it
          if let message = await viewModel.fetchMessageById(messageId: messageId) {
              await MainActor.run {
                  scrollProxy?.scrollTo(messageId, anchor: .center)
                  highlightedMessageId = messageId
              }
          } else {
              // Message not found - show error toast
              print("Referenced message not found: \(messageId)")
              // TODO: Show user-facing error message
          }
      }

      // Clear highlight after delay
      try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
      await MainActor.run {
          highlightedMessageId = nil
      }
  }
  ```
- [ ] Update MessageBubbleView instantiation in the ScrollView
- [ ] Add `onTapFAQReference` closure parameter:
  ```swift
  MessageBubbleView(
      // ... existing parameters ...
      onTapFAQReference: { messageId in
          Task {
              await scrollToMessage(messageId: messageId)
          }
      }
  )
  ```
- [ ] Add highlight background modifier to message bubble
- [ ] Wrap MessageBubbleView in a Group with id and background:
  ```swift
  Group {
      MessageBubbleView(...)
  }
  .id(message.id)
  .background(
      highlightedMessageId == message.id ?
          Color.yellow.opacity(0.3) : Color.clear
  )
  .animation(.easeInOut(duration: 0.3), value: highlightedMessageId)
  ```

**What to Test:**
1. Open a conversation with several messages
2. Create an AI message with FAQ reference to a message currently visible
3. Tap the FAQ link
4. Verify:
   - Scroll animation occurs
   - Target message is centered in view
   - Yellow highlight appears on target message
   - Highlight fades after 2 seconds
5. Scroll to bottom, create AI message with reference to message off-screen (scrolled up)
6. Tap FAQ link
7. Verify scroll works even when message is not in viewport
8. Test with message that doesn't exist (deleted)
9. Verify graceful error handling (console log, no crash)
10. Test rapid taps on multiple FAQ links - should queue properly
11. Verify scroll animation is smooth (uses existing .easeInOut)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift` - Add fetchMessageById method
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` - Add scroll-to and highlight functionality

**Notes:**
- ChatDetailView already has ScrollViewProxy - reuse existing infrastructure
- The highlight animation should be subtle but noticeable
- Consider showing 2-3 messages before/after for context (optional enhancement)
- Error handling is important - referenced message might be deleted or access denied
- Use Task.sleep for delay instead of DispatchQueue for async/await consistency
- The fade animation provides nice visual feedback

---

### PR 3.5: Handle Edge Cases and Polish UI

**Goal:** Add error handling, loading states, and UI polish for the FAQ feature.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift`
- [ ] Add state for error handling:
  ```swift
  @State private var faqScrollError: String?
  @State private var showFAQError = false
  ```
- [ ] Update `scrollToMessage` method to set error state when message not found
- [ ] Add `.alert()` modifier to show error to user:
  ```swift
  .alert("Message Not Found", isPresented: $showFAQError) {
      Button("OK") { }
  } message: {
      Text(faqScrollError ?? "The referenced message could not be found.")
  }
  ```
- [ ] Add loading indicator when fetching message
  - Use `@State private var isLoadingFAQReference = false`
  - Show progress view overlay during fetch
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/FAQReferenceLinkView.swift`
- [ ] Add accessibility labels:
  ```swift
  .accessibilityLabel("View original answer to similar question")
  .accessibilityHint("Double tap to jump to the previous answer")
  ```
- [ ] Add optional icon animation when tapped
  - Use `.scaleEffect()` and `.animation()` for tactile feedback
- [ ] Consider showing loading spinner on link while fetching
  - Add `@Binding var isLoading: Bool` parameter
  - Show `ProgressView()` instead of icon when loading
- [ ] Add haptic feedback on tap
  - Import UIKit
  - Add `UIImpactFeedbackGenerator().impactOccurred()` in tap handler

**What to Test:**
1. Tap FAQ link for message that exists
2. Verify smooth scroll with no errors
3. Tap FAQ link for message that doesn't exist
4. Verify error alert appears with clear message
5. Dismiss alert and verify normal functionality continues
6. Enable VoiceOver (Settings > Accessibility)
7. Navigate to AI message with FAQ link
8. Verify VoiceOver announces "View original answer to similar question"
9. Verify hint explains double-tap action
10. Test on physical device for haptic feedback
11. Verify press animation provides visual feedback
12. Test with slow network (simulate in Xcode) - verify loading indicator

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` - Add error handling and loading states
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/FAQReferenceLinkView.swift` - Add accessibility and haptic feedback

**Notes:**
- User-facing errors are important - don't just console log
- Accessibility is not optional - VoiceOver support required
- Haptic feedback makes the app feel more polished
- Loading states prevent user confusion during async operations
- Consider rate limiting FAQ link taps to prevent spam
- All animations should respect iOS reduce motion settings

---

## Phase 4: Firebase Cloud Functions & Security

**Estimated Time:** 2-3 days

This phase configures the Firebase backend to only trigger AI processing for AI-enabled conversations and enforces proper security rules to prevent abuse.

### PR 4.1: Add Conversation aiEnabled Check to Cloud Function

**Goal:** Update the Cloud Function to check if conversation has aiEnabled before calling Python service.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts`
- [ ] Add constant at top of file (after imports, around line 15):
  ```typescript
  const AI_USER_ID = "ai-assistant";
  ```
- [ ] Update the senderId check on line 27 to use constant:
  ```typescript
  if (messageData?.senderId === AI_USER_ID) {
  ```
- [ ] After the existing senderId check (around line 34), add conversation fetch and aiEnabled check:
  ```typescript
  // Fetch conversation to check if AI is enabled
  logger.info("Checking if AI is enabled for conversation", {
    conversationId: messageData?.conversationId,
  });

  const conversationRef = admin.firestore()
    .collection("conversations")
    .doc(messageData?.conversationId);

  const conversationDoc = await conversationRef.get();

  if (!conversationDoc.exists) {
    logger.warn("Conversation not found", {
      conversationId: messageData?.conversationId,
    });
    return null;
  }

  const conversationData = conversationDoc.data();

  // Only proceed if AI is enabled for this conversation
  if (!conversationData?.aiEnabled) {
    logger.info("AI not enabled for conversation - skipping", {
      conversationId: messageData?.conversationId,
      aiEnabled: conversationData?.aiEnabled,
    });
    return null;
  }

  // Check if FAQ detection is enabled (if aiConfig exists)
  if (conversationData?.aiConfig?.faqDetectionEnabled === false) {
    logger.info("FAQ detection disabled - skipping", {
      conversationId: messageData?.conversationId,
    });
    return null;
  }
  ```
- [ ] Update the payload sent to Python service (around line 43-50) to include aiConfig:
  ```typescript
  const payload = {
    messageId,
    conversationId: messageData?.conversationId,
    senderId: messageData?.senderId,
    text: messageData?.text,
    timestamp: messageData?.timestamp,
    participantIds: messageData?.participantIds,
    aiConfig: conversationData?.aiConfig || {
      faqDetectionEnabled: true,
      minimumSimilarity: 0.85
    }
  };
  ```
- [ ] After changes, **IMPORTANT**: Rebuild the functions
- [ ] Run in terminal:
  ```bash
  cd /Users/Gauntlet/gauntlet/CreatorLink/firebase/functions
  npm run build
  ```

**What to Test:**
1. Restart Firebase emulator if running
2. Create a conversation WITHOUT aiEnabled flag (or aiEnabled: false)
3. Send a message from another user
4. Check Cloud Function logs in Firebase emulator
5. Verify log says "AI not enabled for conversation - skipping"
6. Verify Python service is NOT called (no HTTP request)
7. Create a conversation WITH aiEnabled: true
8. Send a message
9. Verify Cloud Function logs show "Checking if AI is enabled"
10. Verify Python service IS called (check logs)
11. Test with aiConfig.faqDetectionEnabled: false
12. Verify Python service is not called
13. Test with missing aiConfig - should use defaults
14. Verify defaults are applied (faqDetectionEnabled: true, minimumSimilarity: 0.85)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts` - Add aiEnabled check and aiConfig forwarding

**Notes:**
- MUST rebuild functions after TypeScript changes - emulator doesn't always auto-reload
- The check happens before calling Python service to save resources
- Default aiConfig values ensure graceful handling of missing config
- Proper logging is critical for debugging - log all decision points
- Return null (not error) to prevent retry loops
- This prevents unnecessary AI processing for non-AI conversations

---

### PR 4.2: Update Python Service to Handle aiConfig

**Goal:** Update Python service to receive and process aiConfig parameters from Cloud Function.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py`
- [ ] Update the `MessageRequest` Pydantic model (around line 43-51) to include aiConfig:
  ```python
  class AIConfig(BaseModel):
      """AI configuration for conversation."""
      faqDetectionEnabled: bool = True
      minimumSimilarity: float = 0.85

  class MessageRequest(BaseModel):
      """Request model for incoming messages from Cloud Functions."""
      messageId: str
      conversationId: str
      senderId: str
      text: str
      timestamp: Dict[str, int]
      participantIds: List[str]
      aiConfig: Optional[AIConfig] = None  # NEW
  ```
- [ ] Update the sender_id constant (line 139) to match iOS:
  ```python
  sender_id="ai-assistant",  # Changed from "ai-agent"
  ```
- [ ] Update metadata structure (lines 129-134) to support FAQ detection:
  ```python
  response_metadata = {
      "ai_generated": "true",  # Keep for backward compatibility
      "original_message_id": request.messageId,
      "agent_type": "faq_detector",  # Changed from "echo"
      "agent_version": "0.2.0",  # Bumped version
  }

  # TODO: When FAQ matching is implemented, add:
  # "faqReference": matched_message_id,
  # "matchConfidence": str(similarity_score),
  # "matchedQuestion": original_question_text
  ```
- [ ] Add logging to show received aiConfig:
  ```python
  logger.info(f"AI Config: faqDetection={request.aiConfig.faqDetectionEnabled if request.aiConfig else True}, "
              f"similarity={request.aiConfig.minimumSimilarity if request.aiConfig else 0.85}")
  ```
- [ ] Add comment placeholder for future FAQ detection logic:
  ```python
  # TODO Phase 5: Implement FAQ detection
  # 1. Fetch recent messages from conversation
  # 2. Use embedding/similarity search to find matches
  # 3. If match found above minimumSimilarity threshold:
  #    - Add faqReference to metadata
  #    - Add matchConfidence to metadata
  #    - Add matchedQuestion to metadata
  #    - Format response text to reference original answer
  ```

**What to Test:**
1. Start Python service: `cd /Users/Gauntlet/gauntlet/CreatorLink/python-service && python -m app.main`
2. Send test message through Cloud Function with aiConfig
3. Check Python service logs
4. Verify aiConfig values are received and logged
5. Verify sender_id is now "ai-assistant" in created message
6. Check Firestore messages collection
7. Verify new message has senderId: "ai-assistant"
8. Verify metadata includes updated agent_type and version
9. Test without aiConfig in payload - should use defaults
10. Verify no crashes or errors with missing aiConfig

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py` - Add aiConfig support and update constants

**Notes:**
- The actual FAQ detection logic will be implemented in a future phase (Phase 5)
- For now, we're just updating infrastructure to pass configuration through
- Changing sender_id to "ai-assistant" maintains consistency with iOS
- Version bump (0.2.0) indicates this is a new feature version
- The TODO comments guide future implementation
- Keep "ai_generated" for backward compatibility with existing code

---

### PR 4.3: Update Firestore Security Rules for AI Messages

**Goal:** Implement security rules that allow AI service to create messages while preventing user impersonation.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/firebase/firestore.rules`
- [ ] Locate the messages collection rules (around line 52-64)
- [ ] Update the `allow create` rule to permit AI service account:
  ```javascript
  match /messages/{messageId} {
    allow read: if isAuthenticated() &&
                   request.auth.uid in resource.data.participantIds;

    // Allow users to create their own messages
    // Allow AI service account to create AI messages
    allow create: if isAuthenticated() && (
                       // Normal user creating their own message
                       (request.auth.uid == request.resource.data.senderId &&
                        request.auth.uid in request.resource.data.participantIds) ||
                       // AI service account creating AI message
                       (request.auth.token.firebase.sign_in_provider == 'custom' &&
                        request.auth.uid == 'ai-service-account' &&
                        request.resource.data.senderId == 'ai-assistant')
                     );

    allow update: if isAuthenticated() &&
                     request.auth.uid in resource.data.participantIds;

    allow delete: if false;
  }
  ```
- [ ] Locate the conversations collection rules (around line 22-49)
- [ ] Update the participant validation to allow AI user:
  ```javascript
  match /conversations/{conversationId} {
    // Allow reading if user is participant
    allow read: if isAuthenticated() &&
                   request.auth.uid in resource.data.participantIds;

    // Allow creation if user is in participant list OR AI is being added
    allow create: if isAuthenticated() && (
                       request.auth.uid in request.resource.data.participantIds ||
                       'ai-assistant' in request.resource.data.participantIds
                     );

    // Allow update only for participants (includes adding/removing AI)
    allow update: if isAuthenticated() &&
                     request.auth.uid in resource.data.participantIds;

    // Prevent deletion (use archived flag instead)
    allow delete: if false;
  }
  ```
- [ ] Add comments documenting the security model:
  ```javascript
  // Security model for AI messages:
  // - AI service uses Firebase Admin SDK with custom token (ai-service-account)
  // - Regular users cannot impersonate AI (senderId check)
  // - AI can only be added to conversations, not create them independently
  // - AI messages must have senderId: 'ai-assistant'
  ```
- [ ] Deploy updated rules to emulator/production as needed

**What to Test:**
1. In Firebase console or emulator, try to create message as regular user with senderId: "ai-assistant"
2. Verify operation is rejected with permission denied error
3. Create message through Python service (simulating AI service account)
4. Verify message creation succeeds
5. Try to create conversation with AI as only participant
6. Verify operation is rejected (at least one human user required)
7. Create conversation with humans + AI
8. Verify creation succeeds
9. Try to update message metadata from iOS client
10. Verify only participants can update (AI messages shouldn't be editable)
11. Try to delete conversation
12. Verify deletion is blocked (should use archived flag)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/firestore.rules` - Add AI-aware security rules

**Notes:**
- These rules assume Python service authenticates with custom token as 'ai-service-account'
- If Python service uses Admin SDK, these client-side rules don't apply to it
- The rules prevent iOS app users from impersonating AI
- Admin SDK bypasses security rules - be careful with server-side code
- Test rules thoroughly in emulator before deploying to production
- Consider using Firebase Rules Unit Testing framework for comprehensive coverage
- The AI user is special - can be added to conversations but can't be the only participant

---

### PR 4.4: Create AI User Document in Firestore

**Goal:** Ensure the AI user profile document exists in Firestore for proper user lookups.

**Tasks:**
- [ ] Decide on implementation approach:
  - **Option A**: Manual creation via Firebase Console (quick, one-time)
  - **Option B**: Automated script (repeatable, good for multiple environments)
  - **Option C**: Check-and-create in Cloud Function (automatic, but adds latency)
- [ ] If using Option A (Manual):
  - Open Firebase Console
  - Navigate to Firestore Database
  - Go to `users` collection
  - Add document with ID: `ai-assistant`
  - Set fields:
    ```json
    {
      "id": "ai-assistant",
      "displayName": "AI Assistant",
      "email": "ai@creatorlink.app",
      "photoURL": "https://ui-avatars.com/api/?name=AI&background=6366f1&color=fff",
      "isOnline": true,
      "lastSeen": {current timestamp}
    }
    ```
- [ ] If using Option B (Script):
  - Create `/Users/Gauntlet/gauntlet/CreatorLink/scripts/setup_ai_user.js`
  - Use Firebase Admin SDK to create document
  - Make script idempotent (check if exists first)
  - Add README with usage instructions
- [ ] If using Option C (Cloud Function):
  - Add initialization check to existing Cloud Function
  - Query for AI user document on function startup
  - Create if doesn't exist
  - Cache result to avoid repeated checks
- [ ] **Recommended**: Use Option A for now, Option B for production
- [ ] Verify AI user appears in iOS app user lists appropriately
- [ ] Consider adding `isAIUser: true` flag to distinguish from regular users

**What to Test:**
1. After creating AI user document, query Firestore to verify it exists
2. Open iOS app and check if AI user can be fetched via UserService
3. Add AI user to a conversation's participants
4. Verify AI user profile loads correctly in group info
5. Check that AI user's displayName and photoURL are used
6. Verify lastSeen timestamp is recent
7. Test that AI user can't sign in (no auth credentials)
8. Verify AI user doesn't appear in "Add participants" user selection lists
9. Confirm AI user shows in participant lists for AI-enabled groups
10. Test AI user profile fetching in MessageBubbleView for sender info

**Files Changed:**
- Manual approach: No code files changed
- Script approach: `/Users/Gauntlet/gauntlet/CreatorLink/scripts/setup_ai_user.js` - NEW (optional)
- Cloud Function approach: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts` - Add initialization logic

**Notes:**
- The AI user needs to exist in Firestore for user lookups to work
- photoURL uses UI Avatars API with indigo background (matches AI theme)
- isOnline: true makes sense since it's a service, not a human user
- Consider adding createdAt timestamp for record keeping
- The AI user document should be read-only from client perspective
- Don't allow regular users to modify AI user profile
- May want to exclude AI user from certain queries (e.g., "find users to chat with")
- Document the AI user in README or admin docs

---

### PR 4.5: End-to-End Testing and Documentation

**Goal:** Comprehensive testing of the complete FAQ feature flow and update documentation.

**Tasks:**
- [ ] Create comprehensive test conversation with AI enabled
- [ ] Document test procedure:
  1. Create group with 3+ users and AI enabled
  2. Send several Q&A messages (manually seed data)
  3. Trigger AI response with FAQ metadata manually
  4. Test FAQ link tap and scroll behavior
  5. Verify all UI elements render correctly
- [ ] Create test script or instructions for manual testing:
  - Document in `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Docs/Features/AI-Service/testing_guide.md`
  - Include Firestore data structure examples
  - Include screenshot locations or video recording guide
- [ ] Update project documentation:
  - Verify `/Users/Gauntlet/gauntlet/CreatorLink/plan_ios.md` reflects implemented state
  - Add "Implemented" markers to relevant sections
- [ ] **IMPORTANT**: Check for `/Users/Gauntlet/gauntlet/CreatorLink/types.md`
  - If it exists, update it with new model fields:
    - Conversation: aiEnabled, aiConfig
    - Message: FAQ-related metadata keys
  - If it doesn't exist, create minimal documentation
- [ ] Create demo data script (optional but recommended):
  - Script to create realistic group with FAQ examples
  - Helps QA testing and demonstrations
  - Can use Firebase Admin SDK or Firestore REST API
- [ ] Test all error paths:
  - AI user doesn't exist
  - Referenced message deleted
  - Conversation not AI-enabled
  - Invalid metadata format
  - Network errors during fetch
- [ ] Performance testing:
  - Test with 100+ messages in conversation
  - Test FAQ link tap latency
  - Test scroll performance with highlights
- [ ] Accessibility audit:
  - Test with VoiceOver enabled
  - Verify all interactive elements are accessible
  - Check color contrast ratios
  - Test with Dynamic Type (large text sizes)

**What to Test:**
1. **Happy Path**:
   - Create AI-enabled group
   - Send message triggering AI response
   - AI response includes FAQ link
   - Tap link scrolls to referenced message
   - Highlight animation plays
   - All styling appears correct
2. **Error Paths**:
   - Tap FAQ link for deleted message - shows error alert
   - AI user document missing - graceful degradation
   - Network offline during fetch - shows error
3. **Edge Cases**:
   - Very long message text with FAQ link
   - Multiple FAQ links in conversation
   - Rapid taps on FAQ links
   - FAQ link at top/bottom of message list
4. **Cross-device**:
   - Test on iPhone and iPad
   - Test on different iOS versions
   - Test with different text sizes
5. **Accessibility**:
   - VoiceOver navigation
   - Voice Control
   - Reduce Motion setting
   - High Contrast mode

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Docs/Features/AI-Service/testing_guide.md` - NEW: Testing documentation
- `/Users/Gauntlet/gauntlet/CreatorLink/types.md` - Update with new fields (if file exists)
- `/Users/Gauntlet/gauntlet/CreatorLink/scripts/create_demo_faq_data.js` - NEW (optional): Demo data script

**Notes:**
- Comprehensive testing is critical before considering feature complete
- Document all test cases for future regression testing
- Consider automated UI tests for critical paths (XCTest)
- Performance testing helps identify bottlenecks early
- Accessibility is not optional - must work with assistive technologies
- Demo data makes it easier to show feature to stakeholders
- Keep test documentation updated as feature evolves

---

## Testing Matrix

### Scenario 1: Basic FAQ Detection Flow
1. Create group with User A, User B, AI enabled
2. User A asks: "What are your rates?"
3. User B answers: "I charge $500/hour"
4. Manually add AI message with FAQ metadata referencing B's answer
5. **Verify**: AI message displays with purple styling and FAQ link
6. **Verify**: FAQ link shows "View original answer" with confidence score
7. Tap FAQ link
8. **Verify**: Scrolls to User B's answer with highlight animation

### Scenario 2: AI Not Enabled
1. Create group WITHOUT aiEnabled flag
2. Send message from User A
3. **Verify**: Cloud Function logs show "AI not enabled - skipping"
4. **Verify**: No AI response generated
5. **Verify**: Python service not called (check logs)

### Scenario 3: Missing Referenced Message
1. Open conversation with AI message containing FAQ link
2. Delete the referenced message from Firestore manually
3. Tap FAQ link
4. **Verify**: Error alert appears: "Message Not Found"
5. **Verify**: No crash or console errors
6. **Verify**: Can continue using app normally

### Scenario 4: AI User Profile
1. Navigate to group with AI participant
2. Open group info view
3. **Verify**: AI user appears in participant list
4. **Verify**: Shows "AI Assistant" name with special icon/badge
5. **Verify**: AI user has profile photo (UI Avatars API)
6. Tap AI user in list
7. **Verify**: Shows AI user info (if implemented)

### Scenario 5: Security Rules
1. Attempt to create message with senderId: "ai-assistant" from iOS app
2. **Verify**: Operation rejected with permission error
3. Send message through Python service
4. **Verify**: Message created successfully with AI sender

### Scenario 6: FAQ Link Accessibility
1. Enable VoiceOver (Settings > Accessibility > VoiceOver)
2. Navigate to AI message with FAQ link
3. Swipe to FAQ link element
4. **Verify**: VoiceOver announces "View original answer to similar question"
5. **Verify**: Hint says "Double tap to jump to the previous answer"
6. Double tap to activate
7. **Verify**: Scrolls to referenced message
8. **Verify**: VoiceOver announces focused message content

### Scenario 7: Multiple FAQ Links
1. Create conversation with 5+ AI messages, each with different FAQ references
2. Scroll through conversation
3. Tap various FAQ links in sequence
4. **Verify**: Each link scrolls to correct target
5. **Verify**: No performance degradation
6. **Verify**: Highlights work correctly for each

### Scenario 8: aiConfig Settings
1. Create group with aiEnabled: true, faqDetectionEnabled: false
2. Send message
3. **Verify**: Cloud Function skips FAQ detection
4. Update aiConfig.minimumSimilarity to 0.95
5. Send message
6. **Verify**: Python service receives updated config (check logs)

---

## Files Summary

### New Files Created

| File Path | Purpose | Phase |
|-----------|---------|-------|
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/FAQReferenceLinkView.swift` | Reusable FAQ reference link component with tap handling | 3 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Docs/Features/AI-Service/testing_guide.md` | Comprehensive testing documentation | 4 |
| `/Users/Gauntlet/gauntlet/CreatorLink/scripts/setup_ai_user.js` | Script to create AI user document (optional) | 4 |
| `/Users/Gauntlet/gauntlet/CreatorLink/scripts/create_demo_faq_data.js` | Demo data generation script (optional) | 4 |

### Files Modified

| File Path | Changes | Phase |
|-----------|---------|-------|
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift` | - Update isAIMessage to check both metadata and senderId<br>- Enhance AI badge styling<br>- Add FAQ reference link rendering<br>- Add onTapFAQReference closure | 3 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ChatViewModel.swift` | - Add fetchMessageById method for loading specific messages<br>- Add message caching to avoid repeated fetches | 3 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` | - Add highlightedMessageId state<br>- Implement scrollToMessage method<br>- Add FAQ link tap handler<br>- Add highlight animation and background<br>- Add error handling for missing messages | 3 |
| `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts` | - Add AI_USER_ID constant<br>- Add conversation fetch and aiEnabled check<br>- Add aiConfig forwarding to Python service<br>- Update logging for decision points | 4 |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py` | - Add AIConfig model<br>- Update MessageRequest with aiConfig field<br>- Change sender_id to "ai-assistant"<br>- Update metadata structure for FAQ support<br>- Add logging for aiConfig values | 4 |
| `/Users/Gauntlet/gauntlet/CreatorLink/firebase/firestore.rules` | - Update messages create rule to allow AI service account<br>- Update conversations rules to allow AI participant<br>- Add security documentation comments | 4 |
| `/Users/Gauntlet/gauntlet/CreatorLink/types.md` | Document new Conversation fields (aiEnabled, aiConfig) and Message metadata keys | 4 |

### No Changes Required

- Message.swift model (metadata field already exists)
- UserProfile.swift model (no changes needed)
- Conversation.swift model changes were in Phase 1
- Firebase Console configuration (uses existing setup)
- Xcode project settings (no new packages needed)

---

## Common Issues and Solutions

### Issue: AI messages not displaying with special styling
**Solution:** Verify both isAIMessage checks are working (metadata and senderId). Check that AIConstants.AI_USER_ID matches the senderId in Firestore.

### Issue: FAQ link tap does nothing
**Solution:** Check that onTapFAQReference closure is properly wired in ChatDetailView. Verify scrollProxy is not nil. Check console logs for errors.

### Issue: Referenced message not found error appears for valid messages
**Solution:** Verify message.id matches the faqReference metadata exactly. Check that message is in Firestore. Ensure fetchMessageById has proper error handling.

### Issue: Cloud Function still calls Python service for non-AI conversations
**Solution:** Verify functions were rebuilt after TypeScript changes: `cd firebase/functions && npm run build`. Restart emulator. Check logs to see which condition is failing.

### Issue: Security rules prevent AI message creation
**Solution:** Verify Python service is using correct authentication (Firebase Admin SDK or custom token). Check that sender_id is "ai-assistant". Review Firestore rules for typos.

### Issue: Highlight animation not appearing
**Solution:** Check that highlightedMessageId is being set. Verify .animation modifier is on correct view. Ensure message.id is being used correctly. Test with explicit Color instead of opacity.

### Issue: FAQ link styling doesn't match AI messages
**Solution:** Review FAQReferenceLinkView color scheme. Use same purple/indigo tones as AI message background. Check that component is using theme colors consistently.

### Issue: VoiceOver not announcing FAQ links
**Solution:** Verify .accessibilityLabel and .accessibilityHint are set on FAQReferenceLinkView. Test that element is focusable. Check that parent views aren't hiding accessibility.

---

## Success Criteria

Implementation is complete when all of the following are verified:

**Phase 3: Message Rendering & UI**
- [ ] AI messages display with distinct purple/indigo styling
- [ ] Sparkles icon and "AI" badge visible on AI messages
- [ ] FAQ reference links appear below AI message text when metadata present
- [ ] FAQ links show original question preview and confidence score
- [ ] Tapping FAQ link scrolls to referenced message
- [ ] Target message highlights with yellow background for 2 seconds
- [ ] Scroll animation is smooth and centers target message
- [ ] Error alert shows when referenced message doesn't exist
- [ ] VoiceOver announces FAQ links with proper labels
- [ ] Haptic feedback works on FAQ link tap (physical device)

**Phase 4: Firebase Cloud Functions & Security**
- [ ] Cloud Function checks aiEnabled before calling Python service
- [ ] Messages for non-AI conversations don't trigger Python service
- [ ] aiConfig values are passed to Python service correctly
- [ ] Python service receives and logs aiConfig parameters
- [ ] AI messages created with senderId: "ai-assistant"
- [ ] Security rules prevent user impersonation of AI
- [ ] Security rules allow AI service account to create messages
- [ ] AI user document exists in Firestore users collection
- [ ] AI user has proper displayName, photoURL, and other fields
- [ ] Functions rebuild successfully without errors

**Overall Integration**
- [ ] Complete flow works: message → check aiEnabled → call Python → create AI response → display with FAQ link → tap link → scroll to reference
- [ ] No regressions in existing message rendering or group chat features
- [ ] Error handling works gracefully for all edge cases
- [ ] Performance is acceptable with 100+ messages in conversation
- [ ] Accessibility works with VoiceOver and other assistive technologies
- [ ] All test scenarios pass successfully

---

## Next Steps

After completing Phases 3-4:

1. **Testing & QA**:
   - Run through complete testing matrix
   - Test on multiple devices and iOS versions
   - Gather user feedback on AI message styling and FAQ links

2. **Phase 5: Actual FAQ Detection** (Future):
   - Implement vector embeddings for message similarity
   - Add semantic search to find similar questions
   - Calculate confidence scores
   - Format AI responses to reference previous answers
   - Add FAQ result caching for performance

3. **Phase 6: Polish & Optimization** (Future):
   - Add settings UI for adjusting minimumSimilarity
   - Add option to disable AI per-conversation
   - Implement AI response previews before sending
   - Add analytics for FAQ link tap rates
   - Optimize Firestore queries and caching

4. **Documentation**:
   - Update README with AI feature description
   - Create admin guide for managing AI user
   - Document metadata schema for other developers
   - Add screenshots to documentation

5. **Deployment**:
   - Test thoroughly in staging environment
   - Deploy security rules to production
   - Deploy Cloud Functions to production
   - Monitor logs for errors after deployment
   - Set up alerts for AI service failures

---

## Estimated Timeline

- **Phase 3** (Message Rendering & UI):
  - PR 3.1: 2-3 hours (AI styling)
  - PR 3.2: 2-3 hours (FAQ component)
  - PR 3.3: 1-2 hours (FAQ integration)
  - PR 3.4: 3-4 hours (Scroll-to functionality)
  - PR 3.5: 2-3 hours (Polish and error handling)
  - **Subtotal: 10-15 hours (1.5-2 days)**

- **Phase 4** (Firebase & Security):
  - PR 4.1: 2-3 hours (Cloud Function updates)
  - PR 4.2: 2-3 hours (Python service updates)
  - PR 4.3: 2-3 hours (Security rules)
  - PR 4.4: 1-2 hours (AI user setup)
  - PR 4.5: 3-4 hours (Testing and docs)
  - **Subtotal: 10-15 hours (1.5-2 days)**

**Total Implementation Time: 20-30 hours (3-4 days)**

**Testing Time: 4-6 hours for comprehensive testing across all scenarios**

---

## Additional Resources

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [SwiftUI ScrollView and ScrollViewReader](https://developer.apple.com/documentation/swiftui/scrollviewreader)
- [iOS Accessibility Guidelines](https://developer.apple.com/accessibility/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Firebase Admin SDK Python](https://firebase.google.com/docs/admin/setup)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-23
**Status:** Ready for Implementation
**Dependencies:** Phases 1-2 must be complete before starting this work
