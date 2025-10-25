# AI Voice/Auto-Response Feature - Implementation Tasks (Phases 4-5)

## Context

This document covers **Phases 4-5** of the AI Voice/Auto-Response feature, focusing on iOS UI integration and system refinement. Phases 1-3 (knowledge extraction, voice profiling, and draft generation) are complete and documented in `ai_voice_tasks_p1-3.md`.

**What's Been Built (Phases 1-3):**
- **Knowledge Extraction Pipeline**: Extracts factual information from user messages, stores in Firestore with vector embeddings for semantic search
- **Voice Profile System**: Static, manually-authored JSON profiles per category (business, collaboration, social) stored in `users/{userId}/voiceProfiles/{category}`
- **Draft Generation Logic**: Cloud Functions that generate personalized draft responses combining knowledge + voice profile + conversation context

**Draft Schema (Simplified):**
Drafts are stored at `conversations/{conversationId}/drafts/{userId}` with these fields:
- `conversationId`, `userId`, `text`, `category` (required)
- `generatedAt`, `updatedAt` (timestamps)
- `userTouched` (boolean flag - prevents auto-updates when user edits)

**What We're Building (Phases 4-5):**
- Phase 4: iOS app integration - settings toggle, draft preview in conversation list, draft editor in chat view
- Phase 5: Refinement - performance optimization, error handling, testing, cost monitoring

**Core Value Proposition:** Users receive AI-generated draft responses that match their communication style and incorporate accurate information they've previously shared, saving time on routine responses while maintaining authenticity.

## Instructions for AI Agent

**Standard Workflow:**
1. **Read Phase** - Read all referenced files to understand current implementation
2. **Execute Tasks** - Implement tasks in order within each PR
3. **Mark Complete** - Update checkboxes with [x] as you complete tasks
4. **Test** - Run all tests specified in "What to Test" section
5. **Completion Summary** - Provide summary of changes and test results
6. **Wait for Approval** - Wait for human review before moving to next PR

**Important Notes:**
- Follow patterns in existing iOS Services and ViewModels (@Observable, .shared singletons)
- Match Swift naming conventions with TypeScript field names exactly
- Use Firestore listeners for real-time draft updates
- Test with Firebase Emulator before production
- MessageDraft model already exists (created in Phase 3) - reference it

---

## Phase 4: iOS UI Integration

**Estimated Time:** 5-7 days

This phase implements the user-facing iOS features that enable users to interact with AI-generated drafts. We'll add settings controls, conversation list indicators, chat view integration, and visual feedback.

### PR 4.1: DraftService for iOS

**Goal:** Create iOS service layer for reading and managing drafts from Firestore.

**Tasks:**
- [x] Read existing services to understand patterns:
  - `CreatorLink/Services/MessageService.swift` - Firestore read/write patterns
  - `CreatorLink/Services/ConversationService.swift` - Listener setup patterns
  - `CreatorLink/Services/UserService.swift` - User-scoped operations
- [x] Read MessageDraft model:
  - `CreatorLink/Models/MessageDraft.swift` - Understand draft structure
- [x] Create NEW: `CreatorLink/Services/DraftService.swift`:
  - Make it @Observable with static shared instance (singleton pattern)
  - Use FirestoreService.shared.db for database access
  - Implement `fetchDraft(conversationId: String, userId: String) async throws -> MessageDraft?`:
    - Query `conversations/{conversationId}/drafts/{userId}`
    - Return nil if doesn't exist
    - Parse Firestore document to MessageDraft model
    - Handle Firestore errors gracefully
  - Implement `listenToDraft(conversationId: String, userId: String, onUpdate: @escaping (MessageDraft?) -> Void) -> ListenerRegistration`:
    - Set up real-time listener on draft document
    - Call onUpdate with draft when it changes
    - Call onUpdate with nil when draft is deleted
    - Return ListenerRegistration for cleanup
  - Implement `markDraftTouched(conversationId: String, userId: String) async throws`:
    - Update draft document with `userTouched: true`
    - Use Firestore `updateData()` method
    - Prevents Cloud Functions from auto-updating this draft
  - Implement `deleteDraft(conversationId: String, userId: String) async throws`:
    - Delete draft document from subcollection
    - Used when user sends message or explicitly dismisses draft
  - Add error enum `DraftError` with cases:
    - `fetchFailed(Error)`, `updateFailed(Error)`, `deleteFailed(Error)`
  - Follow error handling patterns from MessageService
  - Add logging for debugging (use print statements)

**What to Test:**
1. Build iOS project in Xcode - verify no compilation errors
2. Start Firebase Emulator with test data (drafts seeded via Phase 3)
3. Test fetchDraft with existing draft - verify draft returned
4. Test fetchDraft with non-existent draft - verify nil returned
5. Test listenToDraft - create/update draft in Firestore, verify callback fires
6. Test markDraftTouched - verify userTouched flag updates in Firestore
7. Test deleteDraft - verify document removed from Firestore
8. Check console logs for debugging output

**Files Changed:**
- NEW: `CreatorLink/Services/DraftService.swift` - Draft service layer

**Notes:**
- Service is read-only from iOS perspective (Cloud Functions generate drafts)
- DraftService manages draft metadata (userTouched, deletion)
- Real-time listeners enable instant draft updates in UI
- Follow singleton pattern with .shared instance

---

### PR 4.2: AI Response Mode Settings ✅ COMPLETED

**Goal:** Add user setting to enable/disable AI response mode in user profile.

**Tasks:**
- [x] Read `CreatorLink/Models/UserProfile.swift` to understand current structure
- [x] Update UserProfile model:
  - Add field `aiResponseModeEnabled: Bool?` (optional for backward compatibility)
  - Add to CodingKeys enum
  - Set default value `false` in computed property if nil
- [x] Read `CreatorLink/Services/UserService.swift` to understand user update patterns
- [x] Update UserService:
  - Add method `updateAIResponseMode(userId: String, enabled: Bool) async throws`:
    - Update user document in Firestore: `users/{userId}`
    - Use `updateData(["aiResponseModeEnabled": enabled])`
    - Handle errors with UserError enum
- [x] Update `db-types.md`:
  - Document new `aiResponseModeEnabled` field in users collection
  - Note it's optional (nil defaults to false)
  - Add to UserProfile field list

**What to Test:**
1. Build iOS project - verify no compilation errors
2. Verify existing user documents load without errors (backward compatible)
3. Test updateAIResponseMode - verify Firestore document updates
4. Check Firestore emulator UI to see field added
5. Test with nil value - verify defaults to false
6. Test with explicit true/false values

**Files Changed:**
- `CreatorLink/Models/UserProfile.swift` - Add aiResponseModeEnabled field
- `CreatorLink/Services/UserService.swift` - Add update method
- `CreatorLink/db-types.md` - Document new field

**Notes:**
- Optional field for backward compatibility (existing users default to false)
- Setting is per-user, not per-conversation
- Cloud Functions will check this flag before generating drafts (Phase 5 integration)
- Future PR will add UI toggle in profile/settings view

---

### PR 4.3: Profile Settings UI ✅ COMPLETED

**Goal:** Add AI response mode toggle to user profile/settings screen.

**Tasks:**
- [x] Research existing profile/settings UI:
  - Use `Glob` to find profile-related views in `CreatorLink/Views/`
  - If profile view doesn't exist, create new settings view
- [x] Create or update profile/settings view:
  - Add Section titled "AI Features"
  - Add Toggle control:
    - Label: "AI Draft Responses"
    - Binding: `$aiResponseModeEnabled`
    - Use SwiftUI Toggle component
  - Add descriptive text below toggle:
    - "Automatically generate draft responses based on your communication style and knowledge"
  - Add informational note about enabling feature:
    - "Drafts appear in conversations when AI has enough context to respond"
  - Follow existing SwiftUI view patterns in codebase
- [x] Create ViewModel if needed (or extend existing profile ViewModel):
  - Add `@Published var aiResponseModeEnabled: Bool = false`
  - Load current value from UserService on init
  - Save changes via UserService.updateAIResponseMode()
  - Handle async operations with Task
- [x] Update navigation to settings view:
  - Ensure settings view is accessible from main app navigation
  - Add gear icon or settings button if needed

**What to Test:**
1. Build and run iOS app in simulator
2. Navigate to profile/settings screen
3. Verify "AI Features" section appears
4. Toggle AI Draft Responses on/off
5. Verify toggle state persists (check Firestore)
6. Restart app - verify toggle reflects saved state
7. Test with no initial value (new user) - verify defaults to false
8. Verify descriptive text is clear and helpful

**Files Changed:**
- NEW or UPDATED: `CreatorLink/Views/Profile/SettingsView.swift` (or similar) - Settings UI
- NEW or UPDATED: `CreatorLink/ViewModels/SettingsViewModel.swift` (if needed) - Settings logic

**Notes:**
- Keep UI simple and clear - single toggle with explanation
- Consider adding "Learn More" link in future PR
- This toggle controls draft generation globally for the user
- Future enhancement: Per-conversation AI enable/disable

---

### PR 4.4: Draft Preview in Conversation List ✅ COMPLETED

**Goal:** Show draft preview indicator in conversation list when draft exists.

**Tasks:**
- [x] Read conversation list implementation:
  - `CreatorLink/ViewModels/ConversationsViewModel.swift` - List management
  - Find conversation list view in `CreatorLink/Views/` (likely ConversationListView or similar)
- [x] Update ConversationsViewModel:
  - Add property `draftsCache: [String: MessageDraft] = [:]` (conversationId → draft)
  - Add method `loadDrafts(conversationIds: [String], userId: String) async`:
    - For each conversation, fetch draft using DraftService.fetchDraft()
    - Update draftsCache with results
    - Only load drafts for conversations user participates in
  - Add method `getDraft(for conversationId: String) -> MessageDraft?`:
    - Return draftsCache[conversationId]
  - Call loadDrafts() after conversations load
  - Set up draft listeners for active conversations (optional optimization)
- [x] Update conversation list item view:
  - Add visual indicator when draft exists:
    - Show "AI DRAFT:" prefix before preview text
    - Use different color (e.g., indigo/purple) to distinguish from regular lastMessage
    - Show draft.previewText instead of conversation.lastMessage
  - Add small AI icon/badge (e.g., sparkle ✨ or robot 🤖)
  - Ensure draft preview is visually distinct from regular messages
  - Show draft timestamp (draft.updatedAt) instead of lastMessageTime
- [x] Handle draft display logic:
  - If draft exists → show draft preview
  - If no draft → show conversation.lastMessage as usual
  - Don't show draft if conversation is from user who has AI mode disabled

**What to Test:**
1. Build and run iOS app in simulator
2. Seed test data with drafts (use Phase 3 seed scripts)
3. Open conversation list - verify drafts appear with "AI DRAFT:" prefix
4. Verify draft preview shows first 50 characters (truncated with ...)
5. Verify AI icon/badge is visible and distinct
6. Verify draft timestamp displays correctly
7. Test conversation without draft - verify regular lastMessage shows
8. Test with multiple conversations - verify drafts load for all
9. Update draft in Firestore - verify UI updates (if listener enabled)

**Files Changed:**
- `CreatorLink/ViewModels/ConversationsViewModel.swift` - Add draft loading logic
- `CreatorLink/Views/Chats/ConversationListView.swift` (or similar) - Add draft preview UI

**Notes:**
- Draft preview is read-only in list view (editing happens in chat view)
- Visual distinction is critical - users must recognize AI drafts vs regular messages
- Consider performance with many conversations (lazy loading if needed)
- Draft cache helps avoid repeated Firestore reads

---

### PR 4.5: Draft Editor in Chat View - Part 1 (Load & Display) ✅ COMPLETED

**Goal:** Load draft into chat input when conversation opens and display visual indicator.

**Tasks:**
- [x] Read chat view implementation:
  - `CreatorLink/ViewModels/ChatViewModel.swift` - Chat logic
  - Find chat view in `CreatorLink/Views/` (likely ChatView or MessageThreadView)
- [x] Update ChatViewModel:
  - Add property `currentDraft: MessageDraft?`
  - Add property `isDraftLoaded: Bool = false`
  - Add property `draftListener: ListenerRegistration?`
  - Add method `loadDraft() async`:
    - Fetch draft using DraftService.fetchDraft(conversationId, userId)
    - Set currentDraft if found
    - Set isDraftLoaded = true
  - Add method `setupDraftListener()`:
    - Use DraftService.listenToDraft() to set up real-time listener
    - Update currentDraft when draft changes
    - Clear currentDraft if draft deleted
    - Store listener in draftListener property
  - Update `loadMessages()` method:
    - Call loadDraft() after messages load
    - Call setupDraftListener() to enable real-time updates
  - Add method `removeDraftListener()`:
    - Call draftListener?.remove()
    - Clean up on view disappear
  - Update cleanup/deinit to remove listener
- [x] Update chat view UI:
  - Add draft indicator banner above message input:
    - Show when currentDraft != nil
    - Display: "✨ AI Draft" with indigo/purple background
    - Show draft.category badge (e.g., "Business")
    - Add "Dismiss" button to clear draft
  - Auto-populate message input with draft.text when draft loads:
    - Set messageText binding to draft.text
    - Only auto-load if input is empty
  - Add visual styling to indicate AI draft mode:
    - Border color or background tint on input field
    - Icon or label showing AI assistance active
- [x] Handle draft loading logic:
  - Load draft only once when view appears
  - Don't reload if user is already typing
  - Clear draft indicator if user starts editing (mark as touched)

**What to Test:**
1. Build and run iOS app in simulator
2. Create test scenario: conversation with existing draft
3. Open conversation - verify draft text loads into input field
4. Verify "AI Draft" banner appears above input
5. Verify category badge displays correctly
6. Test with no draft - verify normal input behavior
7. Test real-time draft updates:
   - Update draft in Firestore
   - Verify new draft text appears in UI
8. Test "Dismiss" button - verify banner disappears and input clears
9. Verify draft doesn't overwrite user's in-progress message

**Files Changed:**
- `CreatorLink/ViewModels/ChatViewModel.swift` - Add draft loading logic
- `CreatorLink/Views/Chats/ChatView.swift` (or similar) - Add draft UI elements

**Notes:**
- Don't overwrite user's message if they're already typing
- Draft indicator should be obvious but not intrusive
- Real-time updates ensure latest draft always shown
- "Dismiss" clears draft from UI but doesn't delete from Firestore (user choice)

---

### PR 4.6: Draft Editor in Chat View - Part 2 (Edit & Send) ✅ COMPLETED

**Goal:** Handle user edits to drafts and manage draft lifecycle when sending.

**Tasks:**
- [x] Update ChatViewModel draft handling:
  - Add property `draftWasTouched: Bool = false`
  - Add method `onDraftTextChanged(newText: String)`:
    - Called when user modifies message input
    - If newText != currentDraft?.text && currentDraft != nil:
      - Set draftWasTouched = true
      - Call DraftService.markDraftTouched() async
      - Prevents Cloud Functions from overwriting user's edits
  - Update `sendMessage()` method:
    - After message sent successfully:
      - If currentDraft != nil:
        - Call DraftService.deleteDraft()
        - Clear currentDraft
        - Reset draftWasTouched
      - Draft is no longer needed after user responds
  - Add method `dismissDraft()`:
    - Clear currentDraft from view model
    - Optionally delete from Firestore (or just hide in UI)
    - Reset draftWasTouched and isDraftLoaded
    - Clear message input if it contains draft text
- [x] Update chat view UI:
  - Bind message input `onChange` to call onDraftTextChanged()
  - Connect "Dismiss" button to dismissDraft()
  - Add "Regenerate" button (optional):
    - Allows user to request new draft
    - Deletes current draft → Cloud Functions will generate new one
  - Show visual feedback when draft is touched:
    - Change banner text from "AI Draft" to "AI Draft (Edited)"
    - Change color slightly to indicate modification
- [x] Handle edge cases:
  - User edits draft, then draft updates from server:
    - Don't overwrite if draftWasTouched = true
  - User sends message while draft is loading:
    - Ensure draft deleted after send
  - User navigates away with unsent edited draft:
    - Keep userTouched flag set (preserve edit protection)

**What to Test:**
1. Build and run iOS app in simulator
2. Test draft editing:
   - Load draft in chat view
   - Edit text in input field
   - Verify "Edited" indicator appears
   - Verify userTouched flag set in Firestore
3. Test sending with draft:
   - Send message from draft
   - Verify draft deleted from Firestore
   - Verify UI clears draft indicator
4. Test dismissing draft:
   - Click "Dismiss" button
   - Verify draft banner disappears
   - Verify input clears
5. Test draft protection:
   - Edit draft (mark touched)
   - Simulate server draft update (manually update in Firestore)
   - Verify edited version preserved in UI
6. Test regenerate (if implemented):
   - Click regenerate button
   - Verify draft deleted
   - Wait for new draft from Cloud Functions
7. Test navigation:
   - Edit draft but don't send
   - Navigate away and back
   - Verify edited draft still shown

**Files Changed:**
- `CreatorLink/ViewModels/ChatViewModel.swift` - Add edit handling and send logic
- `CreatorLink/Views/Chats/ChatView.swift` (or similar) - Add UI for edit states

**Notes:**
- userTouched flag is critical - prevents Cloud Functions from overwriting user edits
- Delete draft on send to avoid confusion
- "Edited" indicator helps user understand draft state
- Consider UX for regenerate (may take 2-3 seconds)

---

### PR 4.7: Visual Polish & Indicators

**Goal:** Add final visual polish, icons, and user feedback for AI draft feature.

**Tasks:**
- [ ] Create visual assets:
  - Add AI icon/symbol (sparkle ✨, stars, or custom SF Symbol)
  - Choose brand colors for AI features (suggest indigo/purple theme)
  - Ensure consistent styling across conversation list and chat view
- [ ] Polish conversation list draft preview:
  - Add subtle animation when draft first appears (fade in)
  - Add badge with draft age (e.g., "2m ago", "Just now")
  - Consider showing draft confidence (if added in future)
  - Ensure tap on draft preview opens conversation (same as normal)
- [ ] Polish chat view draft indicator:
  - Add smooth transitions when draft loads/dismisses
  - Add loading state while draft is being fetched
  - Add icon animation (pulse or sparkle) to indicate AI activity
  - Improve banner design (rounded corners, shadow, modern look)
- [ ] Add empty states and feedback:
  - If AI mode enabled but no draft: subtle hint in chat view
    - "AI drafts will appear here when available"
  - If AI mode disabled: no draft indicators shown
  - Add loading spinner when waiting for draft
- [ ] Accessibility improvements:
  - Add VoiceOver labels for AI draft elements
  - Ensure color contrast meets accessibility standards
  - Add semantic labels: "AI generated draft message"
  - Support Dynamic Type for text scaling
- [ ] Add haptic feedback (iOS-specific):
  - Haptic when draft loads
  - Haptic on dismiss action
  - Haptic on send with draft

**What to Test:**
1. Build and run iOS app in simulator
2. Enable AI response mode
3. Test visual appearance:
   - Verify consistent colors and icons
   - Check animations are smooth
   - Verify badge displays correctly
4. Test accessibility:
   - Enable VoiceOver
   - Navigate through draft elements
   - Verify labels are descriptive
5. Test on different screen sizes (iPhone SE, Pro Max)
6. Test with Dynamic Type (larger text sizes)
7. Test haptic feedback on physical device
8. Test empty states (no draft, AI disabled)
9. Verify loading states display correctly

**Files Changed:**
- `CreatorLink/Views/Chats/ChatView.swift` - Visual polish
- `CreatorLink/Views/Chats/ConversationListView.swift` - Visual polish
- `CreatorLink/Views/Common/DraftIndicatorView.swift` (NEW) - Reusable draft indicator component
- `CreatorLink/Utilities/Constants.swift` (or similar) - AI feature colors and icons

**Notes:**
- Consistent visual language helps users understand AI features
- Subtle animations improve perceived performance
- Accessibility is critical for iOS approval
- Haptic feedback enhances user experience on physical devices
- Consider creating reusable SwiftUI components for draft indicators

---

## Phase 5: Refinement & Optimization

**Estimated Time:** 3-5 days

This phase focuses on polishing the feature, improving performance, adding comprehensive error handling, and preparing for production deployment.

### PR 5.1: Error Handling & Edge Cases

**Goal:** Add comprehensive error handling and graceful degradation for edge cases.

**Tasks:**
- [ ] Review all service methods for error handling:
  - DraftService: Handle Firestore read/write failures
  - UserService: Handle profile update failures
  - Cloud Functions: Handle LLM API failures (already in Phase 3)
- [ ] Add user-facing error messages:
  - In ChatViewModel: Add `draftErrorMessage: String?`
  - Show error banner when draft loading fails
  - Show error when marking touched fails
  - Show error when deleting draft fails
  - Use clear, actionable error messages
- [ ] Handle Cloud Function failures:
  - If draft generation fails (no draft appears):
    - Don't show error in UI (silent failure is acceptable)
    - Log error for debugging
  - If draft is incomplete or malformed:
    - Validate draft fields before displaying
    - Skip invalid drafts (treat as no draft)
- [ ] Handle edge cases:
  - User sends message while draft is loading:
    - Cancel draft loading, proceed with send
  - Draft arrives after user already typed response:
    - Don't overwrite user's message
    - Show notification: "New draft available"
  - User has AI mode enabled but no voice profile:
    - No drafts will generate (expected behavior)
    - Don't show error (feature just inactive)
  - Conversation with no knowledge to draw from:
    - No drafts will generate (expected behavior)
  - Draft older than 24 hours:
    - Consider showing warning or auto-dismissing
  - Group chat with multiple drafts:
    - Each user gets their own draft (per userId)
    - No special handling needed
- [ ] Add retry logic:
  - If draft loading fails, retry once after 2 seconds
  - If marking touched fails, retry once
  - Don't retry on deletion failures (not critical)
- [ ] Add logging for debugging:
  - Log draft load attempts and results
  - Log draft touch events
  - Log draft deletion events
  - Use consistent log format for filtering

**What to Test:**
1. Test Firestore errors:
   - Disconnect network during draft load
   - Verify error message displays
   - Reconnect and verify retry works
2. Test invalid drafts:
   - Manually create malformed draft in Firestore
   - Verify app doesn't crash
   - Verify draft skipped gracefully
3. Test race conditions:
   - Start typing, then trigger draft load
   - Verify user's text not overwritten
4. Test with missing voice profile:
   - User with AI enabled, no voice profile
   - Verify no errors shown
5. Test old drafts:
   - Create draft with old timestamp
   - Verify warning or auto-dismiss (if implemented)
6. Test group chats:
   - Multiple users with AI enabled
   - Verify each gets their own draft
7. Review logs for debugging info

**Files Changed:**
- `CreatorLink/Services/DraftService.swift` - Enhanced error handling
- `CreatorLink/ViewModels/ChatViewModel.swift` - Error state management
- `CreatorLink/Views/Chats/ChatView.swift` - Error UI

**Notes:**
- Graceful degradation is key - feature should never break core messaging
- Silent failures acceptable for draft generation (it's a nice-to-have feature)
- Loud failures for user actions (marking touched, dismissing)
- Comprehensive logging helps debug production issues

---

### PR 5.2: Performance Optimization

**Goal:** Optimize draft loading, caching, and reduce unnecessary Firestore reads.

**Tasks:**
- [ ] Optimize draft loading in conversation list:
  - Implement lazy loading: only load drafts for visible conversations
  - Add batch loading: fetch multiple drafts in single query (if possible)
  - Consider pagination for long conversation lists
  - Cache drafts in memory to avoid redundant fetches
- [ ] Optimize draft listeners:
  - Only attach listeners to active/visible conversations
  - Remove listeners when conversation goes off-screen
  - Use lightweight listeners (metadata only if possible)
  - Debounce listener updates to avoid UI thrashing
- [ ] Add draft caching layer:
  - Implement in-memory cache in DraftService
  - Cache draft for 5 minutes before re-fetching
  - Invalidate cache when draft updated or deleted
  - Reduce Firestore reads for frequently-opened conversations
- [ ] Optimize Cloud Function triggers (backend):
  - Add rate limiting per user (max 20 drafts per hour)
  - Skip draft generation if too many recent drafts (avoid spam)
  - Add debouncing: wait 2 seconds after message before generating
  - Log performance metrics (draft generation time)
- [ ] Optimize AI API calls:
  - Implement request batching if possible
  - Use GPT-4o-mini for lower-confidence drafts (cost optimization)
  - Cache voice profiles in Cloud Functions memory
  - Cache knowledge search results for 5 minutes
- [ ] Add performance monitoring:
  - Track draft load time in iOS
  - Track draft generation time in Cloud Functions
  - Log slow operations (>2 seconds)
  - Add Firebase Performance Monitoring (optional)

**What to Test:**
1. Test conversation list performance:
   - Open list with 50+ conversations
   - Verify smooth scrolling
   - Check Firestore read count (should be minimal)
2. Test draft loading performance:
   - Measure time to load draft in chat view
   - Should be <500ms for cached, <2s for network
3. Test listener performance:
   - Open/close conversations rapidly
   - Verify listeners attach/detach properly
   - Check memory usage (no leaks)
4. Test Cloud Function performance:
   - Send test message
   - Measure time to draft generation
   - Should be <3 seconds for simple draft
5. Test with slow network:
   - Throttle network to 3G speeds
   - Verify app remains responsive
   - Verify loading states display
6. Test memory usage:
   - Open many conversations
   - Check memory doesn't grow unbounded
   - Verify caches have size limits
7. Review Firebase Console:
   - Check Firestore read/write counts
   - Check Cloud Function invocation counts
   - Verify costs are reasonable

**Files Changed:**
- `CreatorLink/Services/DraftService.swift` - Add caching layer
- `CreatorLink/ViewModels/ConversationsViewModel.swift` - Lazy loading
- `CreatorLink/ViewModels/ChatViewModel.swift` - Listener optimization
- `firebase/functions/src/index.ts` - Rate limiting and debouncing
- `firebase/functions/src/ai/lib/draft-generator.ts` - Caching and optimization

**Notes:**
- Performance critical for user experience (drafts should feel instant)
- Caching reduces Firestore costs significantly
- Rate limiting prevents abuse and controls costs
- Monitor production metrics to identify bottlenecks

---

### PR 5.3: Testing & Validation

**Goal:** Create comprehensive test suite and validation scripts for the feature.

**Tasks:**
- [ ] Create test scenarios for emulator:
  - Update seed script `emulator-seed/seed-files/voice-profiles.js`:
    - Add users with AI mode enabled
    - Add users with AI mode disabled
    - Add users with voice profiles
    - Add users without voice profiles
  - Create test conversations with various scenarios:
    - User asks question matching knowledge
    - User asks question with no knowledge
    - Group chat with multiple AI-enabled users
    - Conversation with old messages
- [ ] Create manual test plan document:
  - Location: `Docs/Features/ai-voice/test_plan.md`
  - Include test cases for:
    - Settings toggle on/off
    - Draft appears in conversation list
    - Draft loads in chat view
    - Draft editing and userTouched flag
    - Draft deletion on send
    - Draft dismissal
    - Real-time draft updates
    - Error states
    - Performance scenarios
  - Include expected results for each test
  - Include steps to reproduce issues
- [ ] Add validation for draft quality:
  - Manually review generated drafts:
    - Does it match user's voice profile?
    - Does it include relevant knowledge?
    - Is it grammatically correct?
    - Does it sound natural?
  - Document criteria for "good draft" vs "bad draft"
  - Create feedback form for test users
- [ ] Test with real user data (if available):
  - Import real conversations (anonymized)
  - Generate drafts based on real patterns
  - Compare draft quality to user expectations
  - Iterate on prompts if needed
- [ ] Add automated tests (optional but recommended):
  - Unit tests for DraftService methods
  - Unit tests for view model draft logic
  - Integration tests for draft lifecycle
  - Use XCTest framework for iOS
- [ ] Stress testing:
  - Test with 100+ conversations
  - Test with rapid message sending
  - Test with network interruptions
  - Test with multiple users simultaneously

**What to Test:**
1. Run all manual test cases in test plan
2. Verify seed data creates expected test scenarios
3. Test with 3-5 different user personas
4. Test on iOS simulator and physical device
5. Test with Firebase Emulator and production
6. Document any bugs or issues found
7. Verify all test cases pass before shipping

**Files Changed:**
- `emulator-seed/seed-files/voice-profiles.js` - Enhanced test data
- NEW: `Docs/Features/ai-voice/test_plan.md` - Manual test plan
- NEW: `CreatorLinkTests/DraftServiceTests.swift` (optional) - Unit tests
- NEW: `CreatorLinkTests/ChatViewModelTests.swift` (optional) - View model tests

**Notes:**
- Comprehensive testing critical for AI features (hard to debug in production)
- Manual testing reveals UX issues automated tests miss
- Real user data provides best validation of draft quality
- Document test results for future iterations

---

### PR 5.4: Cost Monitoring & Optimization

**Goal:** Implement cost tracking and optimization for AI API usage.

**Tasks:**
- [ ] Add cost tracking to Cloud Functions:
  - Track OpenAI API costs per operation:
    - Knowledge extraction: ~$0.01 per message
    - Draft generation: ~$0.05 per draft (GPT-4o)
    - Embedding generation: ~$0.0001 per fact
  - Log cost estimates with each operation
  - Aggregate costs per user per day
  - Store cost data in Firestore (optional):
    - Collection: `analytics/costs/daily/{date}`
    - Track per-operation totals
- [ ] Implement cost controls:
  - Add daily spending caps per user:
    - Max $1.00 per user per day for drafts
    - Disable drafts if cap reached
    - Reset at midnight UTC
  - Add global spending cap:
    - Max $100.00 per day total
    - Disable feature if reached
    - Alert admin
  - Store caps in Cloud Functions config
  - Log when caps triggered
- [ ] Add cost optimization strategies:
  - Use GPT-4o-mini for simple drafts (70% cheaper):
    - If knowledge available and high confidence → GPT-4o-mini
    - If complex context or low confidence → GPT-4o
  - Implement prompt caching (OpenAI feature):
    - Cache voice profile prompts
    - Cache common knowledge facts
  - Reduce token usage:
    - Limit conversation context to 10 messages (already done)
    - Limit knowledge facts to top 5 results (already done)
    - Optimize system prompts (shorter but effective)
  - Skip unnecessary operations:
    - Don't extract knowledge from short messages (<10 words)
    - Don't generate drafts for messages without questions
    - Skip draft updates if draft is old (>60 min, already done)
- [ ] Create cost monitoring dashboard:
  - Add Cloud Function to aggregate daily costs
  - Create simple web dashboard (optional):
    - Show total costs per day
    - Show costs per user
    - Show costs per operation type
  - Export cost data to CSV for analysis
  - Set up email alerts for unusual spending
- [ ] Document cost estimates:
  - Update PRD with cost projections:
    - Per active user per month
    - Per 1000 drafts generated
    - Per 1000 knowledge facts extracted
  - Include in Phase 5 success criteria

**What to Test:**
1. Run cost tracking in emulator:
   - Generate test drafts
   - Extract test knowledge
   - Verify cost logs appear
2. Test spending caps:
   - Manually trigger many draft generations
   - Verify caps enforced
   - Verify user gets error message
3. Test cost optimization:
   - Compare costs with GPT-4o vs GPT-4o-mini
   - Measure token usage before/after optimization
   - Verify quality not degraded
4. Test monitoring dashboard (if built):
   - View daily costs
   - Verify aggregation correct
   - Test alert triggers
5. Calculate real costs from test data:
   - 100 drafts generated = $X
   - 1000 facts extracted = $Y
   - Verify within budget

**Files Changed:**
- `firebase/functions/src/ai/lib/cost-tracker.ts` (NEW) - Cost tracking utility
- `firebase/functions/src/ai/lib/draft-generator.ts` - Add cost logging
- `firebase/functions/src/ai/lib/knowledge-extractor.ts` - Add cost logging
- `firebase/functions/src/index.ts` - Add spending caps
- `Docs/Features/ai-voice/cost_analysis.md` (NEW) - Cost documentation

**Notes:**
- Cost control critical for AI features (can get expensive fast)
- GPT-4o-mini is good enough for most drafts (70% cost savings)
- Spending caps prevent runaway costs
- Monitoring helps identify optimization opportunities
- Real production costs may differ from estimates

---

### PR 5.5: Production Readiness & Documentation

**Goal:** Prepare feature for production deployment with complete documentation.

**Tasks:**
- [ ] Review and update all documentation:
  - Update `ai_voice_prd.md` with learnings from implementation
  - Document any deviations from original plan
  - Update success metrics with realistic targets
  - Add troubleshooting section
- [ ] Create deployment checklist:
  - Location: `Docs/Features/ai-voice/deployment_checklist.md`
  - Include steps:
    - Deploy Cloud Functions with feature flag disabled
    - Test in production with test users
    - Monitor costs for 24 hours
    - Enable feature flag for 10% of users
    - Monitor error rates and costs
    - Gradually roll out to 100%
  - Include rollback plan
  - Include monitoring setup
- [ ] Add feature flags for gradual rollout:
  - Cloud Functions: `ENABLE_DRAFT_GENERATION` (already exists)
  - iOS app: Remote config for enabling feature per user
  - Add A/B testing support (optional)
- [ ] Create admin tools:
  - Script to disable AI mode for specific user
  - Script to view user's voice profiles
  - Script to view user's knowledge base
  - Script to manually regenerate drafts
  - Location: `firebase/functions/src/admin/` (optional)
- [ ] Update Firestore security rules:
  - Ensure drafts only readable by conversation participants
  - Ensure voice profiles only readable by owner
  - Ensure knowledge facts only readable by owner
  - Review and test all rules
- [ ] Create user documentation:
  - Location: `Docs/Features/ai-voice/user_guide.md`
  - Explain AI response mode feature
  - How to enable/disable
  - How drafts work
  - How to edit/dismiss drafts
  - Privacy and data usage
  - FAQ section
- [ ] Set up monitoring and alerts:
  - Firebase Performance Monitoring for iOS
  - Cloud Function error rate monitoring
  - Cost alert thresholds
  - User feedback collection
  - Crash reporting (Crashlytics)
- [ ] Conduct final review:
  - Code review with team
  - Security review
  - Privacy review
  - UX review with designers
  - Performance review

**What to Test:**
1. Test in production-like environment:
   - Deploy to staging project
   - Test with real data volumes
   - Test with multiple concurrent users
2. Test security rules:
   - Verify users can't access others' drafts
   - Verify users can't access others' voice profiles
   - Verify users can't access others' knowledge
3. Test feature flags:
   - Disable feature via flag
   - Verify drafts stop generating
   - Enable feature via flag
   - Verify drafts resume
4. Test rollback:
   - Simulate production issue
   - Execute rollback plan
   - Verify app works without feature
5. Review all documentation:
   - Have someone else follow deployment checklist
   - Verify all steps are clear
   - Fix any ambiguities
6. Test monitoring:
   - Trigger error in Cloud Function
   - Verify alert fires
   - Verify logs capture issue

**Files Changed:**
- `Docs/Features/ai-voice/deployment_checklist.md` (NEW) - Deployment guide
- `Docs/Features/ai-voice/user_guide.md` (NEW) - User documentation
- `firebase/firestore.rules` - Security rules for drafts
- `firebase/functions/src/admin/` (NEW, optional) - Admin tools
- `ai_voice_prd.md` - Updated with learnings

**Notes:**
- Production deployment is multi-stage process (don't rush)
- Feature flags enable safe rollout and quick rollback
- Documentation critical for team and users
- Monitoring catches issues before users report them
- Security review non-negotiable for production

---

### PR 5.6: A/B Testing Different Prompts (Optional)

**Goal:** Set up infrastructure for testing different LLM prompts to improve draft quality.

**Tasks:**
- [ ] Design A/B test framework:
  - Define prompt variations to test:
    - Variation A: Current prompt (baseline)
    - Variation B: More formal/structured prompt
    - Variation C: More casual/friendly prompt
    - Variation D: Shorter/more concise prompt
  - Define user groups:
    - 25% of users get each variation
    - Assign via hash of userId
  - Define success metrics:
    - Draft acceptance rate (sent without edit)
    - Draft dismissal rate (completely discarded)
    - Average edit distance (how much user changes)
    - User satisfaction (survey)
- [ ] Implement prompt selection in Cloud Functions:
  - Add `selectPromptVariation(userId: string): string` function
  - Hash userId to consistently assign to group
  - Load prompt template based on group
  - Log which variation used for each draft
- [ ] Add experiment tracking:
  - Store experiment data in Firestore:
    - Collection: `experiments/draft_prompts/results/{draftId}`
    - Fields: userId, variation, accepted, edited, dismissed
  - Aggregate results per variation
  - Calculate metrics per group
- [ ] Create analysis dashboard:
  - Script to analyze experiment results
  - Compare metrics across variations
  - Statistical significance testing
  - Export results to CSV
  - Visualize with charts (optional)
- [ ] Document findings:
  - Location: `Docs/Features/ai-voice/ab_test_results.md`
  - Include metrics for each variation
  - Include sample drafts from each variation
  - Include recommendation (winning variation)
  - Include plan to roll out winner
- [ ] Roll out winning variation:
  - Update default prompt to winner
  - Remove experiment code
  - Document final prompt in PRD

**What to Test:**
1. Test prompt variation assignment:
   - Generate drafts for test users
   - Verify each user consistently gets same variation
   - Verify distribution is roughly 25% each
2. Test experiment tracking:
   - Generate drafts
   - Accept/edit/dismiss drafts
   - Verify data logged correctly
3. Test analysis script:
   - Run analysis on test data
   - Verify metrics calculated correctly
   - Verify statistical tests work
4. Review prompt variations:
   - Generate sample drafts with each variation
   - Manually review quality
   - Ensure prompts follow voice profiles
5. Run experiment for 2 weeks:
   - Collect data from real users
   - Analyze results
   - Choose winner

**Files Changed:**
- `firebase/functions/src/ai/lib/prompt-selector.ts` (NEW) - Prompt variation logic
- `firebase/functions/src/ai/lib/draft-generator.ts` - Integrate prompt selection
- `firebase/functions/src/ai/lib/experiment-tracker.ts` (NEW) - Experiment data logging
- `firebase/functions/src/analytics/analyze-experiment.ts` (NEW) - Analysis script
- `Docs/Features/ai-voice/ab_test_results.md` (NEW) - Experiment results

**Notes:**
- A/B testing is optional but highly recommended for AI features
- Prompt engineering has huge impact on draft quality
- Statistical significance requires enough samples (100+ per group)
- Consider testing one change at a time (not multiple variables)
- User feedback more valuable than automated metrics

---

## Success Criteria

### Phase 4 Complete (iOS UI Integration):
- [ ] DraftService implemented with real-time listeners
- [ ] AI response mode toggle added to settings
- [ ] Draft preview appears in conversation list with visual indicator
- [ ] Drafts load into chat input automatically
- [ ] User can edit drafts (userTouched flag set)
- [ ] Drafts deleted when message sent
- [ ] Visual polish complete (icons, colors, animations)
- [ ] All iOS builds succeed without errors
- [ ] All manual tests pass on simulator and device

### Phase 5 Complete (Refinement & Optimization):
- [ ] Error handling comprehensive (no crashes on failures)
- [ ] Performance optimized (draft load <2s, smooth scrolling)
- [ ] Test plan created and all tests pass
- [ ] Cost monitoring implemented (daily cap enforced)
- [ ] Production deployment checklist complete
- [ ] Security rules tested and verified
- [ ] User documentation written
- [ ] Feature ready for production rollout

### Overall Feature Success (MVP):
- [ ] 20% of active users enable AI response mode within 2 weeks
- [ ] 60% draft acceptance rate (sent with or without edits)
- [ ] <3 second draft generation time (95th percentile)
- [ ] <$0.10 per draft cost (API + infrastructure)
- [ ] Zero security incidents or data leakage
- [ ] <1% error rate in draft generation
- [ ] User feedback >4.0/5.0 rating (if survey conducted)

### Technical Quality:
- [ ] iOS app builds and runs without errors
- [ ] No memory leaks or performance issues
- [ ] All Firestore listeners properly cleaned up
- [ ] Error states display user-friendly messages
- [ ] Logging provides clear debugging information
- [ ] Code follows existing patterns and conventions
- [ ] Feature can be disabled via feature flag
- [ ] Rollback plan tested and documented

---

## Open Questions & Decisions Needed

### 1. Settings UI Location
**Question:** Where should AI response mode toggle live?

**Options:**
- Dedicated "AI Settings" screen
- Profile/settings screen (recommended)
- In-app feature discovery banner

**Recommendation:** Add to profile/settings screen for Phase 4. Consider dedicated AI settings screen in future if more AI features added.

---

### 2. Draft Regeneration
**Question:** Should users be able to manually regenerate drafts?

**Options:**
- Yes - add "Regenerate" button (more control)
- No - only auto-generate (simpler UX)
- Maybe - add in Phase 5 if users request it

**Recommendation:** Skip for Phase 4 MVP. Add if user feedback indicates need.

---

### 3. Draft Privacy
**Question:** Should users be able to see/manage their voice profiles and knowledge base?

**Options:**
- Yes - add UI for viewing/editing (complex)
- No - keep it automatic (simpler)
- Admin-only tools (recommended for MVP)

**Recommendation:** Admin-only tools for Phase 4-5. Add user-facing UI in future phase if needed.

---

### 4. Multi-Draft Support
**Question:** Should users be able to have multiple draft options to choose from?

**Options:**
- Yes - generate 2-3 variations (more expensive)
- No - single draft only (recommended for MVP)
- Future enhancement

**Recommendation:** Single draft for MVP. Consider multiple drafts in future based on user feedback and cost analysis.

---

### 5. Draft Expiration
**Question:** Should drafts expire after a certain time?

**Options:**
- Yes - delete after 24 hours (keeps data fresh)
- No - keep until user responds (simpler)
- Warn but don't delete (recommended)

**Recommendation:** Show warning for drafts older than 24 hours but don't auto-delete. User decides when to dismiss.

---

## Next Steps After Phase 5

**Future Enhancements (Post-MVP):**
- Dynamic voice profile learning from user messages (replace static profiles)
- Learning from user edits to improve draft quality
- Multi-language support for knowledge and drafts
- Voice note transcription and integration
- Knowledge base UI for review/editing
- Shared knowledge bases for team accounts
- Integration with calendar for availability facts
- Admin UI for voice profile creation/editing
- Contextual draft variations (formal vs casual on-demand)
- Multi-draft suggestions (2-3 options per conversation)

**Production Rollout Plan:**
1. Deploy Cloud Functions with feature flag disabled (Week 1)
2. Test with internal users (5-10 people, Week 1-2)
3. Enable for 10% of users, monitor closely (Week 3)
4. Increase to 50% if metrics good (Week 4)
5. Full rollout to 100% of users (Week 5)
6. Collect feedback and iterate (Ongoing)

---

**Document Status:** Implementation Ready
**Last Updated:** 2025-10-25
**Covers:** Phases 4-5 (iOS UI Integration and Refinement)
**Previous Phases:** See `ai_voice_tasks_p1-3.md` for Phases 1-3
**PRD Reference:** See `ai_voice_prd.md` for full feature specification
