# AI-Powered FAQ Detection - iOS Implementation Tasks (Phases 1-2)

## Context

This document provides step-by-step implementation tasks for adding AI-powered FAQ detection to CreatorLink's iOS app. This feature enables an AI assistant to automatically link similar questions in group chats to previous answers, reducing redundant conversations.

**What this provides:**
- AI-enabled conversation toggle (opt-in per group)
- Special AI user participant that appears in group member lists
- Data model updates to support AI configuration per conversation
- Foundation for FAQ detection (Python AI service handles the detection logic)

**Current State:**
- Python AI service with FAQ detection capability exists
- Firebase Cloud Functions trigger on new messages
- Message model already has `metadata: [String: String]?` field for AI features
- No iOS support for enabling/managing AI in conversations yet

This implementation covers **Phase 1 (Data Model & Schema Changes)** and **Phase 2 (AI User & Participant Management)** from the iOS implementation plan. These phases build the foundation for the FAQ feature by:
1. Updating data models to support AI configuration
2. Creating AI user infrastructure
3. Enabling users to add/remove AI from conversations
4. Managing AI as a special participant

**Important Notes:**
- **No data migration needed** - All fields are optional and default-initialized for existing conversations
- **Update types.md** - Any schema changes MUST be documented in `/Users/Gauntlet/gauntlet/CreatorLink/types.md`
- **Follow existing patterns** - Reference similar services (AuthService, PresenceService, ConversationService) for code style

---

## Instructions for AI Agent

When implementing these tasks:
1. **Work sequentially** - Complete PRs in order within each phase
2. **Test after each PR** - Follow "What to Test" instructions before moving to next PR
3. **Update types.md** - Document all schema changes in types.md immediately
4. **Use existing patterns** - Follow Swift/SwiftUI conventions used in codebase
5. **Preserve existing functionality** - Don't break current conversation or messaging features
6. **Read files first** - Always read files before editing to understand context

**File path conventions:**
- Models: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/`
- Services: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/`
- Views: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/`
- ViewModels: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/`
- Documentation: `/Users/Gauntlet/gauntlet/CreatorLink/types.md`

---

## Phase 1: Data Model & Schema Changes

**Estimated Time:** 1-2 hours

This phase updates the Conversation and Message models to support AI features, establishes the AI user constant, and documents the schema changes.

### PR 1.1: Add AI Configuration to Conversation Model

**Goal:** Update the Conversation model to include AI enablement flag and configuration settings.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Conversation.swift`
- [ ] Create `AIConfig` struct inside Conversation.swift (nested struct):
  - Add `faqDetectionEnabled: Bool` property with default value true
  - Add `minimumSimilarity: Double` property with default value 0.85
  - Make it `Codable` and `Hashable`
  - Add CodingKeys enum
- [ ] Add `aiEnabled: Bool?` property to Conversation struct
  - Make it optional to support existing conversations without migration
  - Place after `mutedBy` property
- [ ] Add `aiConfig: AIConfig?` property to Conversation struct
  - Optional - only exists when aiEnabled is true
  - Place after `aiEnabled` property
- [ ] Update Conversation initializer to accept new optional parameters:
  - `aiEnabled: Bool? = nil`
  - `aiConfig: AIConfig? = nil`
  - Initialize properties in init body
- [ ] Update CodingKeys enum to include:
  - `case aiEnabled`
  - `case aiConfig`
- [ ] Update `hash(into:)` method to include:
  - `hasher.combine(aiEnabled)`
  - `hasher.combine(aiConfig)` (if AIConfig is Hashable)
- [ ] Update `==` operator to compare:
  - `lhs.aiEnabled == rhs.aiEnabled`
  - `lhs.aiConfig == rhs.aiConfig`
- [ ] **CRITICAL:** Update `/Users/Gauntlet/gauntlet/CreatorLink/types.md`:
  - Add AIConfig struct documentation
  - Add aiEnabled and aiConfig fields to Conversation schema
  - Document default values and optional nature
  - Document Firestore schema structure

**What to Test:**
1. Build project in Xcode - verify no compilation errors
2. Create test code to instantiate Conversation with new fields:
   - Test with aiEnabled = nil (backward compatibility)
   - Test with aiEnabled = true and aiConfig set
   - Test with aiEnabled = false and aiConfig = nil
3. Verify Codable encoding/decoding works:
   - Encode conversation to JSON
   - Decode back from JSON
   - Verify optional fields handled correctly
4. Verify Hashable works correctly
5. Check that existing conversations (without AI fields) still work

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Conversation.swift` - Add AIConfig nested struct, aiEnabled and aiConfig properties, update all conformances
- `/Users/Gauntlet/gauntlet/CreatorLink/types.md` - Document new schema fields and structure

**Notes:**
- Optional fields ensure backward compatibility - existing conversations work without migration
- AIConfig should only exist when aiEnabled is true (enforced in UI layer, not model)
- Default values in AIConfig make it easy to enable AI with sensible defaults
- minimumSimilarity of 0.85 is 85% similarity threshold for FAQ matching
- Follow existing pattern: mutedBy is optional array, use same approach for AI fields

---

### PR 1.2: Create AI Constants and Documentation

**Goal:** Create a centralized file for AI-related constants and document the AI user setup.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/AIConstants.swift`
- [ ] Add file header comment (match style of other model files)
- [ ] Import Foundation
- [ ] Create `struct AIConstants`:
  - Add `static let AI_USER_ID = "ai-assistant"` constant
  - Add `static let AI_DISPLAY_NAME = "AI Assistant"` constant
  - Add `static let AI_EMAIL = "ai@creatorlink.app"` constant
  - Add `static let AI_PHOTO_URL = "https://ui-avatars.com/api/?name=AI&background=6366f1&color=fff"` constant
  - Add comment explaining each constant's purpose
- [ ] Add documentation comment for struct explaining:
  - AI user is a special system user that participates in conversations
  - AI user ID must match what Python service and Cloud Functions use
  - AI user must exist in Firestore before being added to conversations
- [ ] **CRITICAL:** Update `/Users/Gauntlet/gauntlet/CreatorLink/types.md`:
  - Add section for AI User documentation
  - Document the AI user Firestore structure
  - Document that AI user ID must be consistent across systems
  - Add note about AI user creation (manual or via seed script)

**What to Test:**
1. Build project in Xcode - verify no compilation errors
2. Create test code that references AIConstants:
   - `let aiUserId = AIConstants.AI_USER_ID`
   - Verify constant is accessible
3. Verify file follows Swift naming conventions
4. Check that AI_USER_ID matches what's used in Firebase Functions
5. Verify types.md documentation is clear and complete

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/AIConstants.swift` - NEW: Centralized AI constants
- `/Users/Gauntlet/gauntlet/CreatorLink/types.md` - Document AI user structure and constants

**Notes:**
- Using "ai-assistant" instead of "ai-agent" for consistency across the system
- AI user ID must match exactly what Cloud Functions use when checking senderId
- photoURL uses UI Avatars API with indigo background (6366f1) to distinguish from regular users
- This constant file prevents hardcoding AI user ID throughout the codebase
- Constants are in a struct (not enum) following Swift convention for namespacing

---

### PR 1.3: Verify Message Model Metadata Support

**Goal:** Verify Message model supports AI metadata and document the metadata keys used by AI system.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Message.swift`
- [ ] Verify `metadata: [String: String]?` property exists (should be at line 21)
- [ ] Verify metadata is included in CodingKeys enum
- [ ] Verify metadata is handled in initializer
- [ ] Create code documentation comment above metadata property explaining AI usage:
  - Document that metadata is used for AI-generated messages
  - List standard AI metadata keys:
    - `"isAIMessage"` or `"ai_generated"` - flags AI-generated messages (value: "true")
    - `"faqReference"` - messageId of original answer being referenced
    - `"matchConfidence"` - similarity score (e.g., "0.92")
    - `"matchedQuestion"` - the original question text
  - Note that Python service sets these keys
- [ ] **CRITICAL:** Update `/Users/Gauntlet/gauntlet/CreatorLink/types.md`:
  - Document Message metadata field if not already documented
  - Add section for AI metadata keys and their meanings
  - Document expected value format for each key
  - Document that metadata is optional and only present on AI messages

**What to Test:**
1. Build project - verify no compilation errors
2. Review Message.swift to confirm metadata property exists
3. Create test Message with AI metadata:
   ```swift
   let metadata = [
       "isAIMessage": "true",
       "faqReference": "msg123",
       "matchConfidence": "0.92",
       "matchedQuestion": "What are your rates?"
   ]
   ```
4. Verify Message can be created with metadata
5. Verify Message can be created without metadata (nil)
6. Check types.md documentation is comprehensive

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Message.swift` - Add documentation comment for metadata property
- `/Users/Gauntlet/gauntlet/CreatorLink/types.md` - Document AI metadata keys and usage

**Notes:**
- NO CODE CHANGES to Message model - just verification and documentation
- Metadata field already exists, added in Phase 8 of original project
- Python service currently uses "ai_generated" key - iOS should check both "ai_generated" and "isAIMessage" for compatibility
- FAQ reference links will use faqReference metadata in Phase 3
- All metadata values are strings (limitation of Firestore map<string, string>)

---

### PR 1.4: Document AI User Firestore Structure

**Goal:** Document the AI user Firestore document structure without implementing creation yet.

**Tasks:**
- [ ] **CRITICAL:** Update `/Users/Gauntlet/gauntlet/CreatorLink/types.md`:
  - Add detailed AI user Firestore document structure:
    ```
    users/ai-assistant
      id: "ai-assistant"
      displayName: "AI Assistant"
      email: "ai@creatorlink.app"
      photoURL: "https://ui-avatars.com/api/?name=AI&background=6366f1&color=fff"
      isOnline: true
      lastSeen: [current timestamp]
    ```
  - Document that AI user must be created before being added to conversations
  - Document creation options:
    - Manual creation via Firebase Console
    - One-time setup script (future PR)
    - Seed data script update (recommended for development)
  - Note that AI user ID must match AIConstants.AI_USER_ID
  - Document that AI user is a regular UserProfile but with special ID
- [ ] Add TODO comment in types.md about creating seed data script

**What to Test:**
1. Review types.md to ensure documentation is clear
2. Verify AI user structure matches UserProfile model
3. Check that all required UserProfile fields are documented
4. Verify AI_USER_ID constant matches documented ID
5. Ensure documentation explains setup requirements

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/types.md` - Document AI user Firestore structure and setup requirements

**Notes:**
- This PR is documentation-only - no code implementation
- AI user creation will be handled in seed data script (Phase 2 or separate task)
- AI user follows standard UserProfile structure - no special model needed
- isOnline should be true to make AI appear available (AI doesn't actually go offline)
- photoURL uses UI Avatars API to generate distinctive avatar
- For production, would create AI user via Cloud Function or Firebase Admin SDK

---

## Phase 2: AI User & Participant Management

**Estimated Time:** 2-3 hours

This phase implements the UI and service logic for managing AI as a participant in conversations, including group creation, existing group updates, and participant list display.

### PR 2.1: Update ConversationService for AI Support

**Goal:** Add methods to ConversationService for creating conversations with AI enabled and updating AI configuration.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift`
- [ ] Import AIConstants (if needed): `import Foundation` should already allow access
- [ ] Locate `createConversation()` method
- [ ] Update method signature to accept optional AI parameters:
  - Add `aiEnabled: Bool? = nil` parameter
  - Add `aiConfig: Conversation.AIConfig? = nil` parameter
- [ ] In method body, when creating conversation data dictionary:
  - Check if `aiEnabled` parameter is provided
  - If aiEnabled is true, include in data dictionary
  - If aiConfig is provided, include in data dictionary
  - If aiEnabled is true and AI_USER_ID is not in participantIds, add it
- [ ] Create new method `updateAISettings(conversationId:aiEnabled:aiConfig:)`:
  - Accept conversationId: String
  - Accept aiEnabled: Bool
  - Accept optional aiConfig: Conversation.AIConfig?
  - Build update dictionary with aiEnabled field
  - If aiConfig provided, add to update dictionary
  - Update Firestore document: `db.collection("conversations").document(conversationId).updateData()`
  - If enabling AI: use arrayUnion to add AI_USER_ID to participantIds
  - If disabling AI: use arrayRemove to remove AI_USER_ID from participantIds
  - Handle errors and throw if update fails
  - Add logging for debugging
- [ ] Add method `fetchConversation(conversationId:)` if it doesn't exist:
  - Async method that fetches single conversation
  - Returns optional Conversation
  - Used by UI to refresh conversation data after updates

**What to Test:**
1. Build project - verify no compilation errors
2. Create test conversation with AI enabled:
   - Call createConversation with aiEnabled: true
   - Verify conversation created in Firestore
   - Check participantIds includes AI_USER_ID
   - Check aiEnabled field is true
3. Create test conversation without AI:
   - Call createConversation with aiEnabled: false or nil
   - Verify conversation created normally
   - Check participantIds does NOT include AI_USER_ID
4. Test updateAISettings:
   - Enable AI on existing conversation
   - Verify participantIds updated
   - Disable AI on conversation
   - Verify AI_USER_ID removed
5. Check error handling works

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift` - Update createConversation signature, add updateAISettings method

**Notes:**
- Use Firestore arrayUnion/arrayRemove for atomic participant updates
- Handle case where AI_USER_ID already exists in participantIds (idempotent operation)
- Error handling critical - don't leave conversation in inconsistent state
- Log all AI operations for debugging
- Follow existing service patterns (async/await, error throwing)
- Verify participant count includes AI user when enabled

---

### PR 2.2: Add AI Toggle to Group Creation

**Goal:** Add toggle to GroupNameInputView allowing users to enable AI when creating new groups.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupNameInputView.swift`
- [ ] Add state property: `@State private var enableAI: Bool = false`
- [ ] Locate the Form section with group name and image inputs
- [ ] Add new Form Section after existing sections:
  - Section header: "AI Assistant"
  - Toggle with label "Enable AI Assistant" bound to `$enableAI`
  - Optional: Add subtitle text explaining what AI does (e.g., "AI can help answer frequently asked questions")
- [ ] Locate the "Create Group" button action
- [ ] When creating conversation, check if `enableAI` is true:
  - If true, create default AIConfig: `Conversation.AIConfig(faqDetectionEnabled: true, minimumSimilarity: 0.85)`
  - Pass aiEnabled: enableAI to createConversation call
  - Pass aiConfig: config to createConversation call
  - Ensure AI_USER_ID is included in participantIds (ConversationService should handle this)
- [ ] Add import for AIConstants if needed
- [ ] Update any participant count displays to account for AI user (optional)

**What to Test:**
1. Build and run app in simulator
2. Navigate to new group creation flow
3. Verify "Enable AI Assistant" toggle appears in form
4. Toggle AI on and off - verify state updates
5. Create group with AI enabled:
   - Tap Create Group button
   - Verify no errors
   - Check Firestore - conversation should have aiEnabled: true
   - Check participantIds includes "ai-assistant"
6. Create group with AI disabled:
   - Leave toggle off
   - Create group
   - Verify aiEnabled is false or nil
   - Verify participantIds does NOT include AI user
7. Test form validation still works

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupNameInputView.swift` - Add AI toggle section and pass AI settings to createConversation

**Notes:**
- Default toggle to false - AI is opt-in
- Keep UI simple - just a toggle for MVP, detailed config in group settings
- Subtitle text should be helpful but brief
- Follow existing Form section styling
- Ensure group creation flow isn't disrupted
- Consider adding info button with explanation of AI features (future enhancement)
- AI toggle should only appear for group chats, not 1:1 conversations (verify isGroupChat context)

---

### PR 2.3: Create GroupInfoViewModel for AI Management

**Goal:** Create or update GroupInfoViewModel to handle AI enable/disable logic.

**Tasks:**
- [ ] Check if `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/GroupInfoViewModel.swift` exists
- [ ] If it doesn't exist, create new file:
  - Add file header comment
  - Import Foundation, FirebaseFirestore
  - Create `@Observable class GroupInfoViewModel`
  - Add conversationService dependency
- [ ] If it exists, read and understand current structure
- [ ] Add method `toggleAI(conversation: Conversation, enabled: Bool) async throws`:
  - Accept conversation and enabled flag
  - Create AIConfig if enabling: `Conversation.AIConfig(faqDetectionEnabled: true, minimumSimilarity: 0.85)`
  - Call `ConversationService.shared.updateAISettings()`
  - Pass conversationId, enabled, and config
  - Handle errors and rethrow with user-friendly message
  - Add logging
- [ ] Add method `updateAIConfig(conversationId: String, config: Conversation.AIConfig) async throws`:
  - Accept conversationId and new config
  - Call ConversationService.shared.updateAISettings with aiEnabled: true and new config
  - Handle errors
  - Will be used in Phase 3 for configuration UI
- [ ] Add published property if needed: `@Published var isUpdatingAI: Bool = false`
  - Set to true during AI update operations
  - Use to show loading indicator in UI
- [ ] Add error handling property: `@Published var errorMessage: String?`
  - Set when operations fail
  - Clear when new operation starts

**What to Test:**
1. Build project - verify no compilation errors
2. Create test code to instantiate GroupInfoViewModel
3. Test toggleAI method:
   - Create mock conversation
   - Call toggleAI with enabled: true
   - Verify ConversationService method is called
   - Verify no errors thrown
4. Test toggleAI with enabled: false
5. Test error handling:
   - Mock ConversationService to throw error
   - Verify errorMessage is set
6. Check loading state updates correctly

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/GroupInfoViewModel.swift` - NEW or UPDATED: Add AI management methods

**Notes:**
- Use @Observable (not ObservableObject) following Swift 5.9+ patterns
- Follow existing ViewModel patterns in codebase
- Keep ViewModels thin - delegate Firestore operations to services
- Error messages should be user-friendly (not technical)
- Loading state prevents duplicate operations
- ViewModel should not hold conversation state - pass it in methods
- Consider adding success callback or published success state

---

### PR 2.4: Add AI Controls to GroupInfoView

**Goal:** Add AI toggle and settings section to GroupInfoView for managing AI in existing groups.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift`
- [ ] Add StateObject for ViewModel: `@StateObject private var viewModel = GroupInfoViewModel()`
- [ ] Add state for AI toggle: `@State private var aiEnabled: Bool`
  - Initialize from conversation.aiEnabled in onAppear or init
- [ ] Add state for error alert: `@State private var showError = false`
- [ ] Locate the Form where group info is displayed
- [ ] Add new Section after participants section:
  - Section header: "AI Assistant"
  - Toggle("Enable AI Assistant", isOn: $aiEnabled)
    - Add .onChange(of: aiEnabled) modifier to call toggleAI when changed
  - If aiEnabled is true, show additional info:
    - Text showing FAQ detection is enabled
    - Optional: Show similarity threshold (will add config UI in Phase 3)
  - Optional: Add info text explaining what AI does
- [ ] Implement onChange handler for aiEnabled:
  - Create async Task
  - Call viewModel.toggleAI(conversation: conversation, enabled: aiEnabled)
  - Handle errors by setting showError = true
  - Show loading indicator during operation
  - Refresh conversation data after successful toggle
- [ ] Add .alert modifier for error display:
  - Show when viewModel.errorMessage is not nil
  - Display error message
  - Dismiss button to clear error
- [ ] Add loading overlay if viewModel.isUpdatingAI is true
- [ ] Update participant list to show AI user with special badge (next PR will enhance)

**What to Test:**
1. Build and run app
2. Open existing group conversation
3. Tap group info button to open GroupInfoView
4. Verify "AI Assistant" section appears
5. Toggle AI on:
   - Verify loading indicator appears
   - Check Firestore - aiEnabled should be true
   - Check participantIds includes "ai-assistant"
   - Verify toggle stays in "on" position
6. Toggle AI off:
   - Verify loading indicator
   - Check Firestore - aiEnabled should be false
   - Check participantIds no longer includes AI user
7. Test error case:
   - Disconnect from internet
   - Try toggling
   - Verify error alert appears
8. Test with group that already has AI enabled

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift` - Add AI toggle section and integration with GroupInfoViewModel

**Notes:**
- Initialize aiEnabled state from conversation.aiEnabled ?? false
- Use .onChange instead of .onTapGesture for toggle to get new value
- Loading state prevents user from toggling rapidly
- Error handling is critical - user needs feedback on failures
- Consider haptic feedback on successful toggle
- Follow existing GroupInfoView styling and patterns
- AI section should integrate naturally with existing UI
- Consider showing participant count excluding AI user ("5 members + AI")

---

### PR 2.5: Enhance Participant Display for AI User

**Goal:** Update participant list views to show AI user with special styling and prevent removal.

**Tasks:**
- [ ] Check if `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/ParticipantRowView.swift` exists
- [ ] If it doesn't exist, check where participants are displayed (likely in GroupInfoView directly)
- [ ] Locate the view component that renders individual participants
- [ ] Add computed property `isAIUser`:
  - Return `participant.id == AIConstants.AI_USER_ID`
  - Use this to conditionally apply special styling
- [ ] Update participant row UI for AI users:
  - If isAIUser, show robot or sparkles icon next to name (use SF Symbols: "sparkles", "brain", or "waveform.circle")
  - Add "AI" badge or label (small capsule with "AI" text)
  - Use different text color (e.g., purple/indigo to match photo)
  - Optional: Show "Always Online" or similar status text
- [ ] Prevent AI user removal:
  - If swipe-to-delete exists, disable for AI user
  - If remove button exists, hide for AI user
  - Show info dialog if user tries to remove AI: "To remove AI Assistant, use the toggle in AI Settings"
- [ ] Update participant count display in GroupInfoView:
  - Calculate human participants: `let humanParticipants = participants.filter { $0.id != AIConstants.AI_USER_ID }`
  - Display count as: "{count} members" or "{count} members + AI"
  - Alternatively: "5 members (including AI Assistant)"

**What to Test:**
1. Build and run app
2. Create group with AI enabled
3. Open GroupInfoView and scroll to participants section
4. Verify AI user appears in participant list
5. Verify AI user has special icon/badge
6. Verify AI user has different styling
7. Try to swipe to delete AI user - verify it's prevented
8. Verify participant count is displayed correctly
9. Test with AI disabled - verify AI user doesn't appear
10. Toggle AI on - verify AI user appears immediately in list
11. Test with different numbers of participants

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/ParticipantRowView.swift` - NEW or UPDATED: Add special AI user rendering
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift` - Update participant count display logic

**Notes:**
- AI user styling should be distinctive but not jarring
- Purple/indigo theme matches the photoURL color (6366f1)
- SF Symbols to consider: "sparkles", "brain.head.profile", "waveform.circle.fill"
- Badge should be small and unobtrusive
- Participant count should clearly distinguish AI from human members
- Consider accessibility - icon should have accessibility label
- If participant list is a reusable component, ensure AI styling works everywhere
- Follow existing participant row styling patterns

---

### PR 2.6: Verify AI User Profile Loading

**Goal:** Ensure UserService can fetch and display AI user profile correctly.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/UserService.swift`
- [ ] Locate `fetchUser(userId:)` or similar method
- [ ] Verify method can fetch users by any userId (should not filter by auth state)
- [ ] Verify AI user profile can be loaded from Firestore
- [ ] NO CODE CHANGES should be needed - just verification
- [ ] Add test to ensure AI user profile is fetched correctly
- [ ] Verify profile cache works for AI user (if caching is implemented)
- [ ] Check that AI user appears correctly in conversation participant lists

**What to Test:**
1. Ensure AI user exists in Firestore (create manually or via console):
   ```
   users/ai-assistant
     id: "ai-assistant"
     displayName: "AI Assistant"
     email: "ai@creatorlink.app"
     photoURL: "https://ui-avatars.com/api/?name=AI&background=6366f1&color=fff"
     isOnline: true
     lastSeen: [current timestamp]
   ```
2. Build and run app
3. Create conversation with AI enabled
4. Open conversation in ChatDetailView
5. Verify AI user profile loads (check logs)
6. Send test message as AI user (via Firestore console):
   - senderId: "ai-assistant"
   - Verify message appears with "AI Assistant" sender name
   - Verify AI avatar appears
7. Test conversation list - verify AI user info appears in group conversations
8. Check that UserService caching works (no redundant fetches)

**Files Changed:**
- None - this is a verification PR

**Notes:**
- UserService should already handle fetching any user by ID
- AI user is a regular UserProfile - no special handling needed
- If AI user doesn't appear, check that user document exists in Firestore
- If avatar doesn't load, check photoURL is accessible
- UserService may cache profiles - ensure AI user is cacheable
- Consider adding AI user to seed data script (separate task)
- This PR validates that existing infrastructure works with AI user

---

### PR 2.7: Update Seed Data Script with AI User

**Goal:** Add AI user creation to the Firebase emulator seed data script.

**Tasks:**
- [ ] Locate seed data script (check if it exists):
  - Check `/Users/Gauntlet/gauntlet/CreatorLink/firebase/seed-data/` or similar
  - Check `/Users/Gauntlet/gauntlet/CreatorLink/emulator-seed/` or similar
  - Use Glob to find: `**/*seed*.js`
- [ ] If seed script exists, read it to understand structure
- [ ] Add AI user creation to seed script:
  - Create Firestore document in `users` collection
  - Document ID: `AIConstants.AI_USER_ID` value ("ai-assistant")
  - Set all UserProfile fields:
    - id: "ai-assistant"
    - displayName: "AI Assistant"
    - email: "ai@creatorlink.app"
    - photoURL: "https://ui-avatars.com/api/?name=AI&background=6366f1&color=fff"
    - isOnline: true
    - lastSeen: current timestamp
  - Add logging to confirm AI user creation
- [ ] Optionally create Firebase Auth user for AI:
  - Email: "ai@creatorlink.app"
  - UID: "ai-assistant"
  - Only needed if auth is required
- [ ] Update seed script README if exists
- [ ] If seed script doesn't exist, document manual setup in types.md

**What to Test:**
1. Stop Firebase emulators if running
2. Clear emulator data (delete firebase/emulator-data directory)
3. Start Firebase emulators
4. Run seed script
5. Verify script completes without errors
6. Open Firebase Emulator UI (http://localhost:4000)
7. Navigate to Firestore → users collection
8. Verify ai-assistant document exists with all fields
9. Check photoURL is valid (copy URL to browser)
10. Optional: Check Auth tab for ai-assistant user if auth user created
11. Restart emulators and verify AI user persists (if using export/import)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/seed-data/seed.js` or similar - Add AI user creation logic
- `/Users/Gauntlet/gauntlet/CreatorLink/types.md` - Document AI user seed data setup

**Notes:**
- Seed script location may vary - use Glob/Grep to find it
- If no seed script exists, create instructions for manual Firestore setup
- AI user should be created early in seed script (before conversations)
- photoURL uses UI Avatars API - no file upload needed
- isOnline: true makes AI always appear available
- lastSeen should be current timestamp or server timestamp
- Consider adding AI to a test conversation in seed data for easier testing
- AI auth user is optional - Firestore profile is sufficient for message display

---

## Testing Checklist

After completing both phases, verify the following functionality:

### Phase 1 Verification
- [ ] Conversation model compiles with new aiEnabled and aiConfig fields
- [ ] Existing conversations load without errors (backward compatibility)
- [ ] New conversations can be created with AI fields
- [ ] AIConstants file provides centralized AI user ID
- [ ] Message metadata is documented and understood
- [ ] types.md has complete documentation of all schema changes
- [ ] AI user structure is documented in types.md

### Phase 2 Verification
- [ ] GroupNameInputView shows AI toggle during group creation
- [ ] New groups can be created with AI enabled
- [ ] New groups created without AI work normally
- [ ] GroupInfoView shows AI toggle for existing groups
- [ ] AI can be enabled on existing groups
- [ ] AI can be disabled on groups
- [ ] AI user appears in participant list with special styling
- [ ] AI user cannot be removed via swipe/delete
- [ ] Participant counts correctly handle AI user
- [ ] ConversationService correctly manages AI participant
- [ ] Seed data includes AI user
- [ ] AI user profile loads correctly in app

### End-to-End Flow
1. Start Firebase emulators with seed data
2. Build and run iOS app
3. Create new group with AI enabled
4. Verify AI user in participant list
5. Open group info, verify AI toggle is on
6. Toggle AI off, verify AI removed from participants
7. Toggle AI back on, verify AI re-added
8. Create new group without AI
9. Open group info, enable AI via toggle
10. Verify AI added to existing group

---

## Files Summary

### New Files Created
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/AIConstants.swift` - Centralized AI user constants
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/GroupInfoViewModel.swift` - NEW (if doesn't exist): AI management logic
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/Components/ParticipantRowView.swift` - NEW (if doesn't exist): Participant row with AI styling

### Files Modified
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Conversation.swift` - Add AIConfig struct, aiEnabled and aiConfig properties
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Message.swift` - Add documentation for metadata field
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift` - Add AI parameter support, updateAISettings method
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupNameInputView.swift` - Add AI toggle for new groups
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift` - Add AI toggle section and participant count logic
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/seed-data/seed.js` (or similar) - Add AI user creation
- `/Users/Gauntlet/gauntlet/CreatorLink/types.md` - CRITICAL: Document all schema changes, AI user structure, metadata keys

### No Changes Required
- UserProfile model (AI user uses existing structure)
- Message model structure (metadata field already exists)
- MessageService (works with any senderId including AI)
- ChatDetailView (will display AI messages automatically)

---

## Success Criteria

Phases 1 and 2 are complete when:

- [ ] Conversation model supports aiEnabled and aiConfig fields
- [ ] AIConfig struct exists with faqDetectionEnabled and minimumSimilarity
- [ ] AIConstants provides centralized AI_USER_ID
- [ ] types.md documents all schema changes comprehensively
- [ ] ConversationService can create conversations with AI enabled
- [ ] ConversationService can enable/disable AI on existing conversations
- [ ] GroupNameInputView has AI toggle for new group creation
- [ ] GroupInfoView has AI toggle for existing groups
- [ ] AI user appears in participant lists with special styling
- [ ] AI user cannot be removed except via AI toggle
- [ ] Participant counts correctly account for AI user
- [ ] Seed data creates AI user automatically
- [ ] AI user profile loads correctly in app
- [ ] All existing functionality still works (no regressions)

---

## Common Issues and Solutions

### Issue: Build error "Cannot find AIConstants in scope"
**Solution:** Verify AIConstants.swift is in the Xcode project target. Check File Inspector → Target Membership.

### Issue: Conversation fields not encoding to Firestore
**Solution:** Verify CodingKeys enum includes all new fields (aiEnabled, aiConfig). Check that field names match exactly.

### Issue: AI user doesn't appear in participant list
**Solution:** Check that AIConstants.AI_USER_ID matches the user document ID in Firestore. Verify UserService can fetch the AI user.

### Issue: Toggle doesn't update Firestore
**Solution:** Check ConversationService.updateAISettings is being called. Verify Firebase emulators are running. Check Firestore security rules allow updates.

### Issue: Existing conversations crash when loading
**Solution:** Verify aiEnabled and aiConfig are optional (Bool?, AIConfig?). Check decoding handles nil values correctly.

### Issue: Participant count is incorrect
**Solution:** Verify participant count logic filters out AI user correctly using AIConstants.AI_USER_ID comparison.

---

## Next Steps

After completing Phases 1 and 2:

1. **Test thoroughly** using the Testing Checklist above
2. **Verify types.md** is complete and accurate
3. **Gather feedback** on AI toggle UX
4. **Begin Phase 3** (Message Rendering & UI) from the plan:
   - AI message styling in MessageBubbleView
   - FAQ reference links
   - Scroll-to-message functionality
   - Message highlighting
5. **Begin Phase 4** (Firebase Cloud Functions & Security) from the plan:
   - Update Cloud Functions to check aiEnabled
   - Update security rules for AI messages
   - Ensure Python service metadata matches iOS expectations

---

## Estimated Timeline

- **Phase 1** (Data Models): 1-2 hours
  - PR 1.1: 30 minutes
  - PR 1.2: 20 minutes
  - PR 1.3: 15 minutes
  - PR 1.4: 15 minutes

- **Phase 2** (AI Management): 2-3 hours
  - PR 2.1: 30 minutes
  - PR 2.2: 30 minutes
  - PR 2.3: 30 minutes
  - PR 2.4: 45 minutes
  - PR 2.5: 30 minutes
  - PR 2.6: 15 minutes
  - PR 2.7: 30 minutes

**Total Implementation Time:** 3-5 hours

**Testing Time:** 1-2 hours for comprehensive validation

---

**Document Version:** 1.0
**Last Updated:** 2025-10-23
**Status:** Ready for Implementation
**Covers:** Phase 1 (Data Model & Schema) and Phase 2 (AI User & Participant Management) from iOS implementation plan
