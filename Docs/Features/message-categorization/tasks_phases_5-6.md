# Smart Message Categorization - Phases 5-6 Implementation Tasks

## Context

This document provides detailed implementation tasks for **Phase 5 (AI Auto-Tagging)** and **Phase 6 (Advanced Filtering & AI Insights)** of the Smart Message Categorization feature. These phases build on Phases 1-4 which establish the data models, core tag management, basic UI components, and manual tag editing capabilities.

**What Phase 5 Provides:**
- Firebase Cloud Function that analyzes message content using GPT-4
- Automatic categorization (Business, Collaboration, Social, Fan)
- Automatic status detection (Urgent, Needs Response, Awaiting Reply, Resolved)
- Learning from user corrections via userOverrideTags flag
- Cost optimization through rate limiting and caching
- Confidence-based tag application (only applies tags above 0.75 confidence)

**What Phase 6 Provides:**
- Advanced filter menu with sort options (Most Recent, Urgency, Unread First)
- Multi-category selection with visual chips
- Show/Hide Resolved toggle
- AI Insights panel in chat detail view
- Explanation of AI-detected tags with confidence scores
- Detected deadlines and urgency reasoning display

**Architecture Overview:**
```
Message Created in Conversation
    ↓
onMessageCreated Firebase Function (existing)
    ↓ calls new analyzeMessageForTags()
AI Categorization Module
    ↓ uses OpenAI GPT-4o-mini
    ↓ analyzes last 5-10 messages
    ↓ checks userOverrideTags flag
    ↓ applies confidence threshold
Updates Conversation tags in Firestore
    ↓ real-time listener updates
iOS UI reflects new tags automatically
```

**Current State (after Phases 1-4):**
- Conversation model has category/status tags, AI metadata fields
- ConversationService has tag CRUD methods
- ConversationsViewModel has filtering logic
- UI components: TagBadgeView, FilterBarView, visual badges in ConversationRowView
- Tag editing UI: TagEditorSheet, swipe actions, long-press menu
- Firebase Functions already has OpenAI integration (FAQ detection, question analysis)
- OpenAI client singleton exists at `/firebase/functions/src/ai/client.ts`

**Key Dependencies:**
- OpenAI API key configured in Firebase Functions environment
- Existing `getOpenAIClient()` from `/firebase/functions/src/ai/client.ts`
- Conversation model schema from Phases 1-4 with tags and AI metadata
- ConversationService tag update methods from Phase 2

---

## Instructions for AI Agent

When implementing these tasks:
1. **Read Phase** - Start each PR by reading relevant files to understand current implementation
2. **Work Sequentially** - Complete tasks in order within each PR
3. **Mark Complete** - Update checkboxes `[x]` as you complete tasks
4. **Test Thoroughly** - Follow "What to Test" instructions before moving to next PR
5. **Provide Summary** - After completing a PR, provide a summary of what was implemented
6. **Wait for Approval** - Don't start next PR until current one is approved
7. **CRITICAL: Rebuild Functions** - After modifying TypeScript in `/firebase/functions/src/`, run `cd /Users/Gauntlet/gauntlet/CreatorLink/firebase/functions && npm run build`
8. **Follow Patterns** - Match existing code patterns from AI service implementation
9. **Use Absolute Paths** - All file paths must be absolute

---

## Phase 5: AI Auto-Tagging (Firebase Functions)

**Estimated Time:** 4-6 hours

This phase extends the existing Firebase Cloud Functions to automatically categorize conversations based on message content using OpenAI GPT-4. The AI analyzes conversation context, detects urgency keywords, identifies business terms, and tracks conversation state to apply appropriate tags.

### PR 5.1: AI Categorization Type Definitions

**Goal:** Define TypeScript interfaces for AI categorization results and create reusable type definitions.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/types.ts` to understand existing AI types
- [ ] Add new interfaces to `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/types.ts`:
  - `CategoryDetectionResult` interface with category, confidence, reasoning fields
  - `StatusDetectionResult` interface with status array, urgency info, detected deadlines
  - `CategorizationResult` interface combining category and status results
  - `TagUpdatePayload` interface for Firestore update data
- [ ] Add enums matching Swift models:
  - `ConversationCategory` enum (Business, Collaboration, Social, Fan)
  - `StatusTag` enum (Urgent, NeedsResponse, AwaitingReply, Resolved)
- [ ] Add type guards for validation:
  - `isCategoryValid()` type guard function
  - `isStatusValid()` type guard function
- [ ] Export all new types for use in other modules

**What to Test:**
1. Build functions - verify no TypeScript errors: `cd /Users/Gauntlet/gauntlet/CreatorLink/firebase/functions && npm run build`
2. Verify all types are properly exported
3. Check that enums match Swift ConversationTag and StatusTag enums
4. Ensure type definitions include all necessary fields for categorization

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/types.ts` - Add categorization type definitions

**Notes:**
- Category should be a single primary category (highest confidence)
- Status can be multiple tags (Urgent + NeedsResponse is valid)
- Include reasoning field to explain why tags were chosen (for AI insights panel)
- Confidence scores are 0.0-1.0 scale matching existing question detection pattern

---

### PR 5.2: Message Categorization Helper

**Goal:** Create AI helper function that analyzes message content and returns category/status suggestions.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/question-detector.ts` to understand existing OpenAI patterns
- [ ] Create NEW: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/categorizer.ts`
- [ ] Implement `categorizeConversation()` function:
  - Accept parameters: messageText, conversationHistory (last 5-10 messages), existingCategory
  - Use `getOpenAIClient()` from `../client`
  - Create system prompt with categorization rules:
    - Business: brand deals, sponsorships, contracts, payments, business opportunities
    - Collaboration: creative projects, partnerships, content ideas, joint ventures
    - Social: casual conversation, personal updates, greetings, social plans
    - Fan: fan messages, appreciation, requests for content, fan interactions
  - Create system prompt with status detection rules:
    - Urgent: ASAP, urgent, deadline, EOD, tonight, time-sensitive keywords
    - NeedsResponse: unanswered questions, pending requests
    - AwaitingReply: user waiting for response from others
    - Resolved: completed conversations, confirmed plans, answered questions
  - Use GPT-4o-mini model (cost-effective, sufficient for classification)
  - Request JSON response format with category, status array, confidence, reasoning
  - Set temperature to 0.3 for consistent categorization
  - Parse and validate response
  - Return CategorizationResult with all fields populated
- [ ] Add error handling:
  - Catch OpenAI API errors
  - Return safe default on error (Social category, empty status, 0 confidence)
  - Log errors with context
- [ ] Add duration logging for performance monitoring

**What to Test:**
1. Build functions - verify no compilation errors
2. Unit test categorizer with sample messages:
   - "Hey! I have a brand deal opportunity for you, need response by Friday" → Business + Urgent
   - "Want to collaborate on a video together?" → Collaboration + NeedsResponse
   - "How are you doing?" → Social, no status
   - "Thanks for the content! Love your work" → Fan, no status
3. Verify confidence scores are reasonable (0.7-0.95 range for clear messages)
4. Check that reasoning field explains the categorization decision
5. Test with empty message - should return safe default
6. Test with very long message - should handle gracefully

**Files Changed:**
- NEW: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/categorizer.ts` - AI categorization logic

**Notes:**
- Use 5-10 most recent messages for context (balances accuracy and API cost)
- Model should consider conversation history, not just single message
- Temperature 0.3 balances creativity and consistency
- Reasoning field is critical for "Why this tag?" feature in Phase 6
- Consider multilingual support - GPT-4 handles this naturally

---

### PR 5.3: Conversation Context Fetcher

**Goal:** Create helper to fetch recent conversation messages for AI context analysis.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/message-fetcher.ts` to understand existing message fetching patterns
- [ ] Create NEW: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/conversation-context.ts`
- [ ] Implement `fetchConversationContext()` function:
  - Accept parameters: conversationId, messageLimit (default 10)
  - Use Firebase Admin SDK to query messages collection
  - Query: `.where('conversationId', '==', conversationId).orderBy('timestamp', 'desc').limit(messageLimit)`
  - Return array of message objects with: id, text, senderId, timestamp, metadata
  - Handle empty results gracefully
  - Add error handling and logging
- [ ] Implement `shouldAnalyzeMessage()` helper:
  - Check if message is from AI user (skip AI messages)
  - Check if conversation has userOverrideTags flag set (respect user overrides)
  - Check last analysis timestamp (don't re-analyze within 5 minutes)
  - Return boolean indicating whether to analyze
- [ ] Add caching logic for rate limiting:
  - Store last analysis timestamp in conversation metadata
  - Compare with current timestamp
  - Return early if analyzed recently

**What to Test:**
1. Build functions - verify no compilation errors
2. Test fetchConversationContext with valid conversationId:
   - Verify returns up to 10 messages
   - Verify messages are ordered by timestamp (newest first)
   - Verify all required fields are present
3. Test with non-existent conversationId - should return empty array
4. Test shouldAnalyzeMessage logic:
   - AI message → false
   - User override set → false
   - Recently analyzed → false
   - Normal user message → true
5. Verify error handling logs errors and doesn't crash

**Files Changed:**
- NEW: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/conversation-context.ts` - Context fetching and analysis gating

**Notes:**
- Limit to 10 messages to balance context quality and API cost
- Recent messages are more relevant than old ones for current categorization
- 5-minute cooldown prevents excessive API calls on rapid message exchanges
- userOverrideTags flag is critical - never override manual user categorization
- AI_USER_ID constant should match existing AIConstants.swift value

---

### PR 5.4: Tag Update Writer

**Goal:** Create helper to write AI-suggested tags to Firestore conversations safely.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/response-writer.ts` to understand existing Firestore write patterns
- [ ] Create NEW: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/tag-writer.ts`
- [ ] Implement `updateConversationTags()` function:
  - Accept parameters: conversationId, categorizationResult, minimumConfidence (default 0.75)
  - Validate confidence threshold - only update if confidence >= minimumConfidence
  - Construct Firestore update payload:
    - `primaryCategory` - single category string
    - `categories` - array with primary category
    - `statusTags` - array of status strings
    - `aiTagMetadata` - object with confidence, reasoning, lastAnalyzed timestamp, aiSuggested flag
  - Use Firebase Admin SDK to update conversation document
  - Use Firestore transaction for atomic updates
  - Check userOverrideTags flag before writing (extra safety)
  - Log successful updates with category and confidence
- [ ] Implement `calculatePrimaryCategory()` helper:
  - If existing category and new category have similar confidence, keep existing
  - Otherwise return category with highest confidence
  - Handles category stability (prevents constant switching)
- [ ] Add error handling:
  - Catch Firestore write errors
  - Log errors with conversation context
  - Don't throw (let function complete gracefully)

**What to Test:**
1. Build functions - verify no compilation errors
2. Test with mock CategorizationResult:
   - Confidence 0.85 → should write tags
   - Confidence 0.60 → should skip (below threshold)
3. Test transaction behavior - verify atomic updates
4. Test userOverrideTags protection:
   - If flag is true, skip write
   - If flag is false or missing, proceed with write
5. Verify aiTagMetadata includes all fields:
   - confidence, reasoning, lastAnalyzed, aiSuggested: true
6. Test error handling - verify doesn't crash on invalid conversationId

**Files Changed:**
- NEW: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/tag-writer.ts` - Safe tag update to Firestore

**Notes:**
- 0.75 confidence threshold prevents low-quality tag suggestions
- aiSuggested flag allows UI to show "AI suggested" indicator
- Transaction ensures atomic updates (prevents partial writes)
- Primary category denormalization enables efficient Firestore queries
- Category stability prevents UI churn from constant tag changes

---

### PR 5.5: Integrate Categorization into Message Trigger

**Goal:** Extend existing onMessageCreated function to automatically categorize conversations.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts` to understand existing message trigger
- [ ] Import new AI helpers in index.ts:
  - `fetchConversationContext` from `./ai/lib/conversation-context`
  - `categorizeConversation` from `./ai/lib/categorizer`
  - `updateConversationTags` from `./ai/lib/tag-writer`
  - `shouldAnalyzeMessage` from `./ai/lib/conversation-context`
- [ ] Add categorization logic to `onMessageCreated` function AFTER existing FAQ detection:
  - Check if message should be analyzed with `shouldAnalyzeMessage()`
  - Fetch conversation context with `fetchConversationContext()`
  - Get conversation document to check for existing category
  - Call `categorizeConversation()` with message and context
  - Call `updateConversationTags()` with categorization result
  - Log categorization results (category, confidence, status tags)
- [ ] Add environment variable check for feature flag:
  - Check `process.env.ENABLE_AUTO_CATEGORIZATION` (default true)
  - Skip categorization if disabled (for gradual rollout)
- [ ] Ensure categorization doesn't interfere with FAQ detection:
  - Run categorization independent of question detection
  - Both can run for same message
  - Categorization runs even if not a question
- [ ] Add comprehensive logging:
  - Log when categorization starts
  - Log categorization result (category, confidence, status)
  - Log when tags are updated in Firestore
  - Log when categorization is skipped (with reason)

**What to Test:**
1. Build functions: `cd /Users/Gauntlet/gauntlet/CreatorLink/firebase/functions && npm run build`
2. Start Firebase emulators: `firebase emulators:start` from `/Users/Gauntlet/gauntlet/CreatorLink/firebase`
3. Send test message from iOS app with business keyword ("brand deal opportunity")
4. Check function logs for categorization trigger
5. Verify conversation document updated with:
   - primaryCategory: "Business"
   - categories: ["Business"]
   - statusTags may include "NeedsResponse" or "Urgent"
   - aiTagMetadata with confidence, reasoning, timestamp
6. Send another message in same conversation within 5 minutes
7. Verify categorization is skipped (rate limit)
8. Manually set userOverrideTags in conversation document
9. Send message - verify categorization respects override (doesn't update)
10. Check existing FAQ detection still works (not broken by new code)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts` - Add categorization to message trigger
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/index.ts` - Export new categorization functions

**Notes:**
- Categorization should not block FAQ detection or message processing
- Use try-catch to prevent categorization errors from failing entire function
- ENABLE_AUTO_CATEGORIZATION allows feature toggle for testing/rollout
- Logging is critical for monitoring AI performance and debugging
- Both FAQ detection and categorization can run on same message

---

### PR 5.6: Cost Optimization and Rate Limiting

**Goal:** Implement advanced rate limiting, caching, and cost controls for AI categorization.

**Tasks:**
- [ ] Create NEW: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/rate-limiter.ts`
- [ ] Implement in-memory cache for recent categorizations:
  - Use Map to store conversationId → {result, timestamp}
  - Set cache TTL to 5 minutes (matches analysis cooldown)
  - Implement `getCachedResult()` function
  - Implement `setCachedResult()` function
  - Add cache cleanup on TTL expiration
- [ ] Implement per-conversation rate limiting:
  - Track last analysis timestamp in Firestore (added in PR 5.4)
  - Implement `checkRateLimit()` function
  - Return early if analyzed within cooldown period
  - Log rate limit hits for monitoring
- [ ] Implement global rate limiting:
  - Track total API calls per minute/hour
  - Implement `incrementAPICallCounter()` function
  - Check against configurable threshold (e.g., 60 calls/minute)
  - Return early if threshold exceeded
  - Log when hitting global limits
- [ ] Add cost tracking:
  - Estimate tokens used per categorization (~500 tokens average)
  - Log estimated cost per call (GPT-4o-mini pricing)
  - Track cumulative cost in logs
  - Add warning when approaching budget threshold
- [ ] Add configuration management:
  - Create config object with:
    - `CACHE_TTL_SECONDS`: 300 (5 minutes)
    - `PER_CONVERSATION_COOLDOWN_SECONDS`: 300
    - `GLOBAL_RATE_LIMIT_PER_MINUTE`: 60
    - `MAX_CONTEXT_MESSAGES`: 10
    - `CONFIDENCE_THRESHOLD`: 0.75
  - Allow environment variable overrides
  - Export config for use in other modules

**What to Test:**
1. Build functions - verify no compilation errors
2. Test caching:
   - Send message, verify categorization runs
   - Send another message immediately, verify uses cache (check logs)
   - Wait 6 minutes, send message, verify runs new categorization
3. Test per-conversation rate limit:
   - Send 2 messages rapidly to same conversation
   - Verify second message skips categorization
4. Test global rate limit:
   - Send messages to 70 different conversations rapidly
   - Verify hits rate limit after 60 calls
   - Check logs for rate limit warnings
5. Test cost tracking:
   - Send several messages
   - Check logs for cost estimates
   - Verify cumulative cost tracking
6. Test configuration:
   - Verify all config values are used
   - Test environment variable override

**Files Changed:**
- NEW: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/rate-limiter.ts` - Rate limiting and cost controls
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/categorizer.ts` - Integrate rate limiter
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/ai/lib/conversation-context.ts` - Check rate limits before fetching

**Notes:**
- In-memory cache is lost on function cold start (acceptable tradeoff)
- For production, consider using Firebase Realtime Database for distributed cache
- GPT-4o-mini costs ~$0.00015 per categorization (very cheap)
- Rate limits protect against runaway costs and API abuse
- Configuration via environment variables enables per-deployment tuning

---

## Phase 6: Advanced Filtering & AI Insights

**Estimated Time:** 5-7 hours

This phase builds sophisticated filtering UI and AI insights panel to surface the intelligent categorization to users. Users can filter by multiple categories, sort conversations, and see detailed explanations of why AI chose certain tags.

### PR 6.1: Advanced Filter Menu Sheet

**Goal:** Create comprehensive filter menu with category selection, sort options, and resolved toggle.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatsView.swift` to understand current view structure
- [ ] Create NEW: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/AdvancedFilterSheet.swift`
- [ ] Implement AdvancedFilterSheet SwiftUI view:
  - Accept binding parameters: selectedCategories, selectedSort, showResolved
  - Use Sheet presentation style
  - Add navigation title "Filter Conversations"
  - Add "Done" button to dismiss
- [ ] Add category selection section:
  - Display all ConversationCategory options as tappable chips
  - Support multi-select (can select Business + Collaboration)
  - Show selected state with filled background
  - Show emoji + label for each category
  - Use horizontal ScrollView if categories don't fit
- [ ] Add sort options section:
  - Radio button selection for: Most Recent, Urgency, Unread First
  - Show selected option with checkmark
  - Use List or VStack for layout
- [ ] Add resolved filter toggle:
  - "Show Resolved Conversations" toggle switch
  - Explanation text: "Hide conversations marked as resolved"
  - Default to true (show all)
- [ ] Add "Clear All" button:
  - Resets to defaults (all categories, Most Recent sort, show resolved)
  - Shows confirmation if filters are active
- [ ] Add filter summary at bottom:
  - Show active filter count: "3 active filters"
  - Preview what's selected

**What to Test:**
1. Build project - verify no compilation errors
2. Present sheet from ChatsView (add temporary test button)
3. Test category selection:
   - Tap Business chip - verify selects
   - Tap again - verify deselects
   - Select multiple categories - verify all highlighted
4. Test sort options:
   - Select each option - verify radio button updates
   - Verify only one can be selected at a time
5. Test resolved toggle:
   - Toggle on/off - verify state changes
   - Verify label and description are clear
6. Test Clear All:
   - Apply filters, tap Clear All
   - Verify resets to defaults
7. Test filter summary updates in real-time
8. Test sheet dismissal saves selections

**Files Changed:**
- NEW: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/AdvancedFilterSheet.swift` - Advanced filter menu

**Notes:**
- Use SF Symbols for category icons (briefcase, person.2, star, heart)
- Categories should use OR logic (Business OR Collaboration)
- Sort options should be enum for type safety
- Resolved toggle affects filtering but not data fetching
- Sheet should be reusable across different contexts

---

### PR 6.2: Integrate Advanced Filters into ChatsView

**Goal:** Connect advanced filter sheet to ChatsView and implement filtering/sorting logic.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatsView.swift`
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ConversationsViewModel.swift` to understand filtering implementation
- [ ] Add state variables to ChatsView:
  - `showAdvancedFilter: Bool` for sheet presentation
  - `selectedCategories: Set<ConversationCategory>` (initially all)
  - `selectedSort: SortOption` (initially .mostRecent)
  - `showResolved: Bool` (initially true)
- [ ] Add filter button to ChatsView toolbar:
  - Use SF Symbol "line.3.horizontal.decrease.circle"
  - Show badge if filters are active (not default state)
  - Present AdvancedFilterSheet on tap
- [ ] Update existing FilterBarView integration:
  - Quick category filter taps update selectedCategories
  - Sync with advanced filter selections
  - Show active state when category selected
- [ ] Add computed property `filteredAndSortedConversations`:
  - First, filter by categories (OR logic)
  - Then, filter by resolved status if toggle is off
  - Finally, apply sort option:
    - Most Recent: sort by lastMessageTime descending
    - Urgency: sort urgent first, then by lastMessageTime
    - Unread First: sort by unread count descending, then lastMessageTime
  - Return filtered and sorted array
- [ ] Update conversation list to use filtered conversations:
  - Replace `viewModel.conversations` with `filteredAndSortedConversations`
  - Ensure list updates when filters change
- [ ] Add filter state persistence:
  - Save to UserDefaults when filters change
  - Restore on view appear
  - Use AppStorage property wrapper for automatic persistence

**What to Test:**
1. Build project - verify no compilation errors
2. Launch app, navigate to ChatsView
3. Test filter button:
   - Tap filter button - verify sheet appears
   - Apply filters - verify button shows badge
4. Test category filtering:
   - Select only "Business" - verify shows only business conversations
   - Select "Business" + "Social" - verify shows both
   - Deselect all - verify shows empty state or all (depends on UX decision)
5. Test sort options:
   - Most Recent - verify sorted by lastMessageTime
   - Urgency - verify urgent conversations at top
   - Unread First - verify unread conversations at top
6. Test resolved toggle:
   - Toggle off - verify hides resolved conversations
   - Toggle on - verify shows all
7. Test filter bar sync:
   - Tap Business in filter bar - verify advanced filter updates
   - Change in advanced filter - verify filter bar updates
8. Test persistence:
   - Apply filters, close app
   - Reopen - verify filters are restored
9. Test with empty state - verify appropriate message shown

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatsView.swift` - Add advanced filter integration
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/ConversationsViewModel.swift` - Add sorting/filtering helpers if needed

**Notes:**
- OR logic for categories is most intuitive (show Business OR Social)
- Urgency sort should respect chronological order for non-urgent
- Empty state should suggest changing filters
- Filter persistence improves UX (remembers user preferences)
- Consider performance for large conversation lists (should be fast with in-memory filtering)

---

### PR 6.3: AI Insights Data Model and Service

**Goal:** Create data structures and service methods to fetch AI categorization insights.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/Conversation.swift` to understand existing metadata
- [ ] Create NEW: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/AIInsights.swift`
- [ ] Define AIInsights struct:
  - `category: ConversationCategory?` - detected category
  - `categoryConfidence: Double` - confidence score (0.0-1.0)
  - `categoryReasoning: String?` - explanation of category choice
  - `statusTags: [StatusTag]` - detected status tags
  - `urgencyInfo: UrgencyInfo?` - details about detected urgency
  - `lastAnalyzed: Date?` - timestamp of last AI analysis
  - `isAISuggested: Bool` - true if tags came from AI vs manual
- [ ] Define UrgencyInfo struct:
  - `isUrgent: Bool` - whether conversation is urgent
  - `detectedKeywords: [String]` - urgency keywords found
  - `detectedDeadlines: [String]` - deadline phrases detected
  - `urgencyReasoning: String?` - explanation of urgency
- [ ] Add Codable conformance to both structs
- [ ] Add Hashable conformance for SwiftUI view updates
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift`
- [ ] Add `fetchAIInsights(conversationId:)` method to ConversationService:
  - Fetch conversation document from Firestore
  - Parse aiTagMetadata field
  - Construct AIInsights object from metadata
  - Return nil if no AI metadata exists
  - Handle errors gracefully

**What to Test:**
1. Build project - verify no compilation errors
2. Verify AIInsights struct compiles
3. Verify UrgencyInfo struct compiles
4. Test Codable encoding/decoding:
   - Create test AIInsights instance
   - Encode to JSON
   - Decode from JSON
   - Verify all fields preserved
5. Test fetchAIInsights service method:
   - Mock conversation with aiTagMetadata
   - Call fetchAIInsights
   - Verify returns valid AIInsights object
6. Test with conversation without AI metadata:
   - Should return nil gracefully
7. Test error handling - invalid data should not crash

**Files Changed:**
- NEW: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/AIInsights.swift` - AI insights data models
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift` - Add fetchAIInsights method

**Notes:**
- AIInsights is a Swift representation of Firebase aiTagMetadata field
- UrgencyInfo provides granular details for UI display
- Service method bridges Firebase data to Swift model
- Nil return for missing metadata is expected (not all conversations analyzed)
- Consider caching insights to reduce Firestore reads

---

### PR 6.4: AI Insights Panel Component

**Goal:** Create expandable AI insights panel that shows categorization reasoning and detected patterns.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` to understand view structure
- [ ] Create NEW: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/AIInsightsView.swift`
- [ ] Implement AIInsightsView component:
  - Accept insights: AIInsights? parameter
  - Show nothing if insights is nil
  - Expandable/collapsible design (DisclosureGroup or custom)
  - Default to collapsed state
- [ ] Add header section:
  - "AI Insights" title with sparkle icon (✨ or SF Symbol "sparkles")
  - Show "AI Suggested" badge if isAISuggested is true
  - Show last analyzed timestamp
- [ ] Add category section (when expanded):
  - Display detected category with emoji
  - Show confidence score as percentage
  - Show reasoning text in secondary font
  - "Why this tag?" as section header
- [ ] Add status tags section:
  - Display each status tag with badge
  - Show urgency info if present:
    - Detected keywords in chips
    - Detected deadlines highlighted
    - Urgency reasoning text
- [ ] Add visual design:
  - Use card/rounded rectangle background
  - Subtle gradient or color accent for AI branding
  - Icon indicators for confidence level (high/medium/low)
  - Readable typography with hierarchy
- [ ] Add interaction:
  - Tap to expand/collapse
  - Smooth animation on expand/collapse
  - "Learn More" button (could open documentation - out of scope for now)

**What to Test:**
1. Build project - verify no compilation errors
2. Test with nil insights - verify nothing renders
3. Test with mock AIInsights object:
   - Verify all sections render correctly
   - Verify category, confidence, reasoning display
   - Verify status tags display
   - Verify urgency info displays
4. Test expansion:
   - Tap header - verify expands smoothly
   - Tap again - verify collapses
   - Verify animation is smooth
5. Test with different confidence levels:
   - High (>0.9) - should show strong indicator
   - Medium (0.7-0.9) - should show moderate indicator
   - Low (<0.7) - should show weak indicator or warning
6. Test with various content lengths:
   - Long reasoning text - should wrap properly
   - Many keywords - should layout nicely
   - Multiple deadlines - should be readable
7. Test appearance in light/dark mode

**Files Changed:**
- NEW: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/AIInsightsView.swift` - AI insights panel component

**Notes:**
- Panel should feel informative but not overwhelming
- Confidence visualization helps users trust (or question) AI suggestions
- Collapsed by default reduces clutter in chat view
- Consider adding "Was this helpful?" feedback in future iteration
- Use SF Symbols for icons (sparkles, checkmark.circle, exclamationmark.triangle)

---

### PR 6.5: Integrate AI Insights into ChatDetailView

**Goal:** Add AI insights panel to chat detail view and fetch insights on conversation load.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift`
- [ ] Add state variable to ChatDetailView:
  - `aiInsights: AIInsights?` to store fetched insights
  - `isLoadingInsights: Bool` for loading state
- [ ] Add insights panel to view hierarchy:
  - Position below chat header / above messages
  - Or position as floating expandable button (design choice)
  - Use AIInsightsView component
  - Pass aiInsights binding
- [ ] Implement insights fetching logic:
  - Fetch on view appear using `.task { }`
  - Call `ConversationService.shared.fetchAIInsights(conversationId:)`
  - Update aiInsights state with result
  - Handle nil result (conversation not analyzed yet)
  - Handle errors gracefully (log and show nothing)
- [ ] Add real-time listener for insights updates:
  - Listen to conversation document changes
  - Update aiInsights when aiTagMetadata changes
  - Use Firestore snapshot listener pattern
  - Clean up listener on view disappear
- [ ] Add loading indicator:
  - Show subtle spinner while fetching
  - Don't block main chat UI
  - Hide once loaded
- [ ] Add conditional rendering:
  - Only show panel if aiInsights is not nil
  - Only show if conversation has AI-suggested tags
  - Hide for manually tagged conversations (userOverrideTags is true)

**What to Test:**
1. Build project - verify no compilation errors
2. Open conversation with AI-categorized messages:
   - Verify insights panel appears
   - Verify shows correct category and reasoning
   - Verify shows detected urgency if applicable
3. Open conversation without AI categorization:
   - Verify panel doesn't appear
4. Test loading state:
   - Verify brief loading indicator on first load
   - Verify disappears when loaded
5. Test real-time updates:
   - Send message that triggers categorization
   - Verify insights panel updates automatically
6. Test manually tagged conversation:
   - Manually tag a conversation (set userOverrideTags)
   - Verify panel hides or shows "Manually tagged" instead
7. Test expansion/collapse interaction in context of full chat view
8. Test with different conversation states:
   - No messages - no insights
   - New conversation - no insights yet
   - Active categorized conversation - insights shown

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` - Add AI insights panel integration

**Notes:**
- Panel should not obstruct primary chat functionality
- Real-time updates keep insights fresh as conversation evolves
- Consider placement carefully (header vs floating vs between messages)
- Loading state should be subtle and non-blocking
- Respect userOverrideTags - don't show AI insights if user manually set tags

---

### PR 6.6: Insights Export and Debugging Tools

**Goal:** Add developer/admin tools to export insights data and debug categorization quality.

**Tasks:**
- [ ] Read `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift`
- [ ] Add `exportInsightsData(conversationId:)` method to ConversationService:
  - Fetch conversation with AI metadata
  - Fetch recent messages for context
  - Compile into JSON format
  - Return formatted string or data object
  - Include: category, confidence, reasoning, messages analyzed, timestamp
- [ ] Create NEW: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Debug/AIInsightsDebugView.swift`
- [ ] Implement debug view (only visible in DEBUG builds):
  - List all conversations with AI categorization
  - Show confidence scores
  - Show category distribution (pie chart or simple counts)
  - Show accuracy metrics (if user corrections available)
  - Allow exporting insights data
- [ ] Add debug menu item in ChatsView (DEBUG only):
  - Long press on navigation title reveals debug menu
  - "AI Insights Debug" option
  - Presents AIInsightsDebugView sheet
- [ ] Add categorization quality metrics:
  - Track manual override rate (how often users change AI tags)
  - Calculate average confidence score
  - Track category distribution
  - Show cost estimates (based on number of API calls)
- [ ] Add export functionality:
  - "Export All Insights" button
  - Generate CSV or JSON file
  - Share via system share sheet
  - Include anonymized conversation metadata

**What to Test:**
1. Build project in DEBUG mode - verify no compilation errors
2. Test debug view access:
   - Long press ChatsView title
   - Verify debug menu appears
   - Tap AI Insights Debug
   - Verify debug view presents
3. Test insights list:
   - Verify shows all categorized conversations
   - Verify confidence scores display correctly
   - Verify category distribution is accurate
4. Test metrics:
   - Manually override a tag
   - Verify override rate updates
   - Verify average confidence calculates correctly
5. Test export:
   - Tap Export All Insights
   - Verify generates file
   - Verify share sheet appears
   - Verify file contains expected data
6. Test in RELEASE build:
   - Verify debug tools are hidden
   - Verify no performance impact
7. Verify no crashes with empty data

**Files Changed:**
- NEW: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Debug/AIInsightsDebugView.swift` - Debug tools for AI insights
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift` - Add export method
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatsView.swift` - Add debug menu trigger

**Notes:**
- Debug tools are invaluable for monitoring AI quality
- Override rate is key metric for AI accuracy
- Export enables offline analysis and ML model improvement
- Only compile debug tools in DEBUG builds to keep release binary small
- Consider adding Firebase Analytics events for production monitoring
- Category distribution helps identify dataset biases

---

## Completion Checklist

After completing both Phase 5 and Phase 6:

### Phase 5 Verification:
- [ ] All Firebase Function files compile without errors
- [ ] onMessageCreated triggers categorization on new messages
- [ ] AI categorization uses GPT-4o-mini and returns category + status
- [ ] Confidence threshold (0.75) is enforced
- [ ] Rate limiting prevents excessive API calls
- [ ] userOverrideTags flag is respected
- [ ] Cost tracking logs API usage
- [ ] Firestore conversation documents update with AI tags

### Phase 6 Verification:
- [ ] Advanced filter sheet presents and functions correctly
- [ ] Category filtering works with OR logic
- [ ] Sort options (Most Recent, Urgency, Unread First) work correctly
- [ ] Show/Hide Resolved toggle filters conversations
- [ ] AI insights panel displays in ChatDetailView
- [ ] Insights show category, confidence, reasoning, urgency info
- [ ] Real-time insights updates work
- [ ] Debug tools compile and function (DEBUG mode only)

### Integration Testing:
- [ ] Send message with business keywords → auto-categorized as Business
- [ ] Send message with urgency keywords → detected as Urgent
- [ ] Filter by Business → shows only business conversations
- [ ] Sort by Urgency → urgent conversations at top
- [ ] AI insights panel shows reasoning for categorization
- [ ] Manually change tag → sets userOverrideTags, AI respects it
- [ ] Rate limiting works → rapid messages don't trigger excessive API calls
- [ ] Performance is acceptable with 100+ conversations

### Production Readiness:
- [ ] All TypeScript builds without errors
- [ ] All Swift code builds without errors
- [ ] No console errors or warnings
- [ ] OpenAI API key is configured
- [ ] Environment variables are documented
- [ ] Feature flag ENABLE_AUTO_CATEGORIZATION works
- [ ] Debug tools hidden in RELEASE builds
- [ ] Firestore security rules allow tag updates
- [ ] Cost per conversation under $0.002

---

## Notes for Implementation

**Firebase Functions Best Practices:**
- Always rebuild after TypeScript changes: `npm run build`
- Use `logger.info()` for debugging, appears in emulator terminal
- Test with emulators before deploying to production
- Environment variables set in `.env` file for local, Firebase console for production

**SwiftUI Best Practices:**
- Use `@State` for view-local state
- Use `@Observable` for shared ViewModels
- Leverage Combine for real-time Firestore listeners
- Test on both light and dark mode
- Test on different device sizes (SE, Pro Max)

**AI/ML Considerations:**
- GPT-4o-mini is cost-effective for classification tasks
- Temperature 0.3 balances consistency and creativity
- Context window of 5-10 messages balances accuracy and cost
- Confidence threshold prevents low-quality suggestions
- User feedback (overrides) is valuable for future model improvements

**Testing Strategy:**
- Unit test categorization logic with various message types
- Integration test end-to-end flow (message → categorization → UI update)
- Manual test edge cases (empty messages, very long messages, multilingual)
- Load test with many conversations to verify filtering performance
- Monitor logs for categorization quality and API costs

**Future Enhancements (Out of Scope):**
- Fine-tune model on user correction data
- Add sentiment analysis (positive/negative tone)
- Detect specific entities (brand names, dates, prices)
- Smart reply suggestions based on category
- Proactive insights ("You have 3 urgent business messages")
- A/B test different categorization prompts
