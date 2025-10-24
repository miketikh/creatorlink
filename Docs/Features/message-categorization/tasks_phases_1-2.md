# Smart Message Categorization & Filtering - Implementation Tasks (Phases 1-2)

## Context

This feature transforms the WhatsApp-style conversation list into an intelligent messaging hub that automatically categorizes conversations and tracks message status. Users can filter conversations by category (Business, Collaboration, Social, Fan) and status (Urgent, Needs Response, Awaiting Reply, Resolved), with AI-powered auto-tagging that learns from message content and user corrections.

The implementation follows a phased approach where **Phase 1** establishes the data foundation with backward-compatible schema changes, and **Phase 2** builds the core tag management service with filtering logic. These phases focus exclusively on the data layer and service layer, ensuring a solid foundation before UI development in later phases.

**Key Technical Decisions:**
- **Per-User Tags**: Tags are user-specific preferences stored in `tagsByUser` map, not global - allows different users in group chats to categorize differently
- **Denormalized Primary Category**: Store single `primaryCategory` field for efficient Firestore queries with `.whereField` filtering
- **Backward Compatibility**: All new fields are optional to ensure existing conversations continue working without migration
- **Atomic Operations**: Use `FieldValue` operations for concurrent-safe tag updates
- **Filter Persistence**: Store user's last filter selection in UserDefaults for seamless experience

## Instructions for AI Agent

Follow this workflow for each PR:

1. **Read Phase**: Read all files listed in "Files Changed" section to understand current implementation
2. **Implement Tasks**: Execute tasks in order, marking each complete with [x]
3. **Test**: Run all tests in "What to Test" section and verify results
4. **Completion Summary**: Provide a brief summary of what was implemented and any notes
5. **Wait for Approval**: Wait for explicit approval before starting the next PR

Each PR should be a complete, testable unit that builds the project successfully.

---

## Phase 1: Data Model & Schema Updates

**Estimated Time:** 4-6 hours

This phase establishes the data foundation by adding category and status tag support to the Conversation model, creating the necessary enums, and ensuring backward compatibility with existing conversations. No UI changes are made in this phase.

### PR 1.1: Create Tag Enums

**Goal:** Define the tag type enums that will categorize conversations and track status.

**Tasks:**
- [ ] Read `CreatorLink/Models/MessageStatus.swift` to understand existing enum pattern
- [ ] Create NEW: `CreatorLink/Models/ConversationTag.swift` with:
  - ConversationTag enum (Business, Collaboration, Social, Fan)
  - String raw values for Firestore storage
  - Codable and Hashable conformance
  - Optional emoji property for UI display (briefcase, handshake, chatBubble, star)
  - Optional displayName property ("Business", "Collaboration", "Social", "Fan")
- [ ] Create NEW: `CreatorLink/Models/StatusTag.swift` with:
  - StatusTag enum (Urgent, NeedsResponse, AwaitingReply, Resolved)
  - String raw values for Firestore storage
  - Codable and Hashable conformance
  - Optional emoji property for UI display (fire, questionMark, clock, checkmark)
  - Optional displayName property ("Urgent", "Needs Response", "Awaiting Reply", "Resolved")

**What to Test:**
1. Build project - verify no compilation errors
2. Open new enum files - verify they follow MessageStatus.swift pattern
3. Check enum cases are correctly defined with raw string values

**Files Changed:**
- NEW: `CreatorLink/Models/ConversationTag.swift` - Category tags enum
- NEW: `CreatorLink/Models/StatusTag.swift` - Status tags enum

**Notes:**
- Follow the exact pattern from MessageStatus.swift (String raw values, Codable, Hashable)
- Emoji and displayName properties are computed properties, not stored
- These enums will be used in arrays in Conversation model

---

### PR 1.2: Add Tag Metadata Struct

**Goal:** Create a nested struct to store AI confidence scores and user override flags for tag suggestions.

**Tasks:**
- [ ] Read `CreatorLink/Models/Conversation.swift` to understand existing AIConfig nested struct pattern
- [ ] Add NEW nested struct `TagMetadata` inside Conversation model:
  - `aiSuggestedCategory: ConversationTag?` - AI's suggested primary category
  - `aiConfidenceScore: Double?` - Confidence score for AI suggestion (0.0-1.0)
  - `userOverrideCategory: Bool` - Flag if user manually set category (default: false)
  - `userOverrideStatus: Bool` - Flag if user manually set status (default: false)
  - `lastAIAnalysisTime: Date?` - Timestamp of last AI analysis
  - Codable and Hashable conformance
  - Default initializer with all fields optional except override flags
  - CodingKeys enum matching field names

**What to Test:**
1. Build project - verify no compilation errors
2. Check TagMetadata follows same pattern as AIConfig nested struct
3. Verify all fields have proper optionality

**Files Changed:**
- `CreatorLink/Models/Conversation.swift` - Add TagMetadata nested struct

**Notes:**
- This struct is nested inside Conversation, similar to AIConfig
- Override flags default to false, other fields default to nil
- Will be stored as optional map in Firestore for backward compatibility

---

### PR 1.3: Extend Conversation Model with Tag Fields

**Goal:** Add category tags, status tags, and metadata fields to Conversation model while maintaining backward compatibility.

**Tasks:**
- [ ] Read `CreatorLink/Models/Conversation.swift` to understand current structure and initialization
- [ ] Add new optional fields to Conversation struct:
  - `categoryTags: [ConversationTag]?` - Array of category tags (user-selected)
  - `statusTags: [StatusTag]?` - Array of status tags (urgent, needs response, etc.)
  - `primaryCategory: ConversationTag?` - Denormalized primary category for filtering
  - `tagMetadata: TagMetadata?` - AI confidence and override tracking
  - `tagsByUser: [String: [String]]?` - Per-user tag preferences (userId -> array of tag raw values)
- [ ] Update custom initializer to include new tag parameters (all optional with default nil)
- [ ] Update CodingKeys enum to include new fields
- [ ] Update hash(into:) method to include new tag fields (for UI updates)
- [ ] Update == operator to compare new tag fields

**What to Test:**
1. Build project - verify no compilation errors
2. Check that all new fields are optional (backward compatible)
3. Verify initializer includes new parameters with default nil values
4. Confirm CodingKeys includes all new fields

**Files Changed:**
- `CreatorLink/Models/Conversation.swift` - Add tag fields and update methods

**Notes:**
- All new fields MUST be optional for backward compatibility
- tagsByUser allows per-user preferences in group chats
- primaryCategory is denormalized for efficient Firestore queries
- Follow existing pattern for unreadCounts and mutedBy optional fields

---

### PR 1.4: Update Database Schema Documentation

**Goal:** Document the new tag fields in the database schema documentation for reference.

**Tasks:**
- [ ] Read `db-types.md` to understand documentation format for conversations collection
- [ ] Update conversations collection section with new fields:
  - Add `categoryTags` field description
  - Add `statusTags` field description
  - Add `primaryCategory` field description
  - Add `tagMetadata` field description with nested structure
  - Add `tagsByUser` field description
- [ ] Add TagMetadata struct documentation with field descriptions
- [ ] Update example JSON documents to show conversations with tags
- [ ] Add notes about backward compatibility and per-user tags

**What to Test:**
1. Read updated db-types.md - verify formatting is consistent
2. Check that all new fields are documented with types and descriptions
3. Verify example JSON shows optional fields correctly

**Files Changed:**
- `db-types.md` - Document new conversation tag fields and TagMetadata struct

**Notes:**
- Follow existing documentation format from AIConfig struct
- Include example with both one-on-one and group chat tag data
- Emphasize that all fields are optional for backward compatibility
- Document the tagsByUser map structure (userId -> string array of raw values)

---

## Phase 2: Core Tag Management Service

**Estimated Time:** 6-8 hours

This phase builds the service layer for tag management, including CRUD operations for tags, filtering logic in the ViewModel, and comprehensive unit tests for the data layer. No UI is built yet - this focuses on the business logic foundation.

### PR 2.1: Add Tag CRUD Methods to ConversationService

**Goal:** Extend ConversationService with methods to update category tags, status tags, and metadata.

**Tasks:**
- [ ] Read `CreatorLink/Services/ConversationService.swift` to understand service patterns (updateAISettings, toggleMute)
- [ ] Add tag management methods to ConversationService:
  - `updateCategoryTags(conversationId:userId:tags:)` - Set category tags for user
  - `updateStatusTags(conversationId:userId:tags:)` - Set status tags for user
  - `updatePrimaryCategory(conversationId:category:)` - Update denormalized primary category
  - `updateTagMetadata(conversationId:metadata:)` - Update AI metadata
- [ ] Each method should:
  - Validate conversationId exists
  - Use atomic Firestore operations (updateData)
  - Handle errors with ConversationError enum
  - Return Void or throw on error
- [ ] Add tagsByUser update logic in updateCategoryTags/updateStatusTags:
  - Convert tags to raw string values
  - Update `tagsByUser.{userId}` field using dot notation
  - Set userOverrideCategory/Status flags in metadata

**What to Test:**
1. Build project - verify no compilation errors
2. Check method signatures match service pattern (async throws)
3. Verify each method uses atomic updateData operations
4. Ensure error handling follows ConversationError pattern

**Files Changed:**
- `CreatorLink/Services/ConversationService.swift` - Add tag CRUD methods

**Notes:**
- Follow pattern from updateAISettings and toggleMute methods
- Use FieldValue for atomic operations where appropriate
- Methods should be async throws to handle Firestore errors
- tagsByUser uses dot notation: `tagsByUser.{userId}` for updates

---

### PR 2.2: Add Quick Tag Helper Methods

**Goal:** Create convenience methods for common tag operations like marking urgent or resolved.

**Tasks:**
- [ ] Read `CreatorLink/Services/ConversationService.swift` to understand new tag methods from PR 2.1
- [ ] Add convenience methods to ConversationService:
  - `markAsUrgent(conversationId:userId:)` - Add Urgent to status tags
  - `markAsResolved(conversationId:userId:)` - Add Resolved, remove Urgent/NeedsResponse
  - `markAsNeedsResponse(conversationId:userId:)` - Add NeedsResponse status
  - `removeUrgent(conversationId:userId:)` - Remove Urgent from status tags
- [ ] Each method should:
  - Fetch current conversation
  - Compute new statusTags array with changes
  - Call updateStatusTags with new array
  - Set userOverrideStatus flag to true

**What to Test:**
1. Build project - verify no compilation errors
2. Check that methods properly manipulate statusTags arrays
3. Verify markAsResolved removes conflicting tags (Urgent, NeedsResponse)
4. Ensure userOverrideStatus is set to true

**Files Changed:**
- `CreatorLink/Services/ConversationService.swift` - Add convenience tag methods

**Notes:**
- These methods provide semantic shortcuts for common operations
- markAsResolved should remove Urgent and NeedsResponse (mutually exclusive)
- Methods internally call updateStatusTags from PR 2.1
- Always set userOverrideStatus to true when user manually changes tags

---

### PR 2.3: Add Tag Filtering Logic to ConversationsViewModel

**Goal:** Implement filtering logic in ViewModel to filter conversations by category and status tags.

**Tasks:**
- [ ] Read `CreatorLink/ViewModels/ConversationsViewModel.swift` to understand current structure
- [ ] Add filter state properties to ConversationsViewModel:
  - `selectedCategoryFilters: [ConversationTag]` - Active category filters
  - `selectedStatusFilters: [StatusTag]` - Active status filters
  - `showResolvedConversations: Bool` - Toggle for resolved conversations (default: true)
- [ ] Add computed property `filteredConversations: [Conversation]`:
  - Start with all conversations
  - Filter by selectedCategoryFilters (OR logic - show if ANY tag matches)
  - Filter by selectedStatusFilters (OR logic - show if ANY tag matches)
  - Filter by showResolvedConversations flag
  - Return filtered array
- [ ] Add filter management methods:
  - `toggleCategoryFilter(_:)` - Add/remove category from filters
  - `toggleStatusFilter(_:)` - Add/remove status from filters
  - `clearAllFilters()` - Reset all filters
- [ ] Add helper method:
  - `getTagsForUser(conversation:userId:)` - Extract user-specific tags from tagsByUser

**What to Test:**
1. Build project - verify no compilation errors
2. Check filteredConversations computed property compiles correctly
3. Verify toggle methods add/remove filters correctly
4. Ensure OR logic in filtering (not AND)

**Files Changed:**
- `CreatorLink/ViewModels/ConversationsViewModel.swift` - Add filtering logic

**Notes:**
- Use OR logic for filters: show conversation if it has ANY selected tag
- Resolved filter is a boolean toggle, not a tag filter
- filteredConversations should be computed property for real-time updates
- getTagsForUser extracts tags from tagsByUser map for current user

---

### PR 2.4: Add Filter Persistence with UserDefaults

**Goal:** Persist user's last filter selections to restore on app launch.

**Tasks:**
- [ ] Read `CreatorLink/ViewModels/ConversationsViewModel.swift` to understand filter properties from PR 2.3
- [ ] Create NEW: `CreatorLink/Services/FilterPreferencesService.swift`:
  - Singleton service for managing filter preferences
  - Property: `lastSelectedCategoryFilters: [String]` - Stored as raw values
  - Property: `lastSelectedStatusFilters: [String]` - Stored as raw values
  - Property: `showResolvedConversations: Bool` - Boolean flag
  - Methods: `saveFilters()`, `loadFilters()`, `clearFilters()`
  - Use UserDefaults for storage with keys: "categoryFilters", "statusFilters", "showResolved"
- [ ] Update ConversationsViewModel to integrate FilterPreferencesService:
  - Load filters in init() using FilterPreferencesService.loadFilters()
  - Save filters after each toggle using FilterPreferencesService.saveFilters()
  - Convert raw string values to/from enum arrays

**What to Test:**
1. Build project - verify no compilation errors
2. Check FilterPreferencesService follows singleton pattern
3. Verify UserDefaults keys are consistent
4. Ensure filters are saved when toggled

**Files Changed:**
- NEW: `CreatorLink/Services/FilterPreferencesService.swift` - Filter persistence service
- `CreatorLink/ViewModels/ConversationsViewModel.swift` - Integrate filter persistence

**Notes:**
- Store enum raw values in UserDefaults, not enum instances
- UserDefaults keys should be namespaced: "conversation.categoryFilters"
- Load filters in init() to restore state on app launch
- Save after every toggle to ensure persistence

---

### PR 2.5: Add Batch Tag Update Method

**Goal:** Support updating tags for multiple conversations at once (future-proofing for bulk operations).

**Tasks:**
- [ ] Read `CreatorLink/Services/ConversationService.swift` to understand tag methods
- [ ] Add batch update method to ConversationService:
  - `batchUpdateCategoryTags(conversationIds:[String], userId:String, tags:[ConversationTag])` async throws
  - Use Firestore batch write operation
  - Update tagsByUser for each conversationId
  - Commit batch atomically
  - Limit batch to 500 operations (Firestore limit)
- [ ] Add validation:
  - Check conversationIds array is not empty
  - Check conversationIds.count <= 500
  - Throw ConversationError.invalidData if validation fails

**What to Test:**
1. Build project - verify no compilation errors
2. Check method uses batch write operations
3. Verify 500 operation limit is enforced
4. Ensure atomic commit (all succeed or all fail)

**Files Changed:**
- `CreatorLink/Services/ConversationService.swift` - Add batch tag update method

**Notes:**
- Firestore batch limit is 500 operations
- Batch writes are atomic - all succeed or all fail
- This method is for future bulk tagging features
- Use db.batch() to create batch, then batch.commit() to execute

---

### PR 2.6: Add Tag Validation Helpers

**Goal:** Create validation helpers to ensure tag combinations are valid and enforce business rules.

**Tasks:**
- [ ] Read `CreatorLink/Services/ConversationService.swift` to understand tag methods
- [ ] Add validation helper methods as private extensions to ConversationService:
  - `validateCategoryTags(_:)` -> Bool - Ensure max 2 category tags
  - `validateStatusTags(_:)` -> Bool - Ensure mutually exclusive rules
  - `sanitizeStatusTags(_:)` -> [StatusTag] - Remove conflicting tags
- [ ] Add business rules to sanitizeStatusTags:
  - If Resolved is present, remove Urgent and NeedsResponse
  - If Urgent is present, ensure NeedsResponse is also present
  - Remove duplicate tags
- [ ] Update updateStatusTags method to call sanitizeStatusTags before saving

**What to Test:**
1. Build project - verify no compilation errors
2. Check validation methods enforce business rules
3. Verify sanitizeStatusTags removes conflicts correctly
4. Ensure updateStatusTags uses sanitization

**Files Changed:**
- `CreatorLink/Services/ConversationService.swift` - Add validation helpers

**Notes:**
- Business rule: Resolved is mutually exclusive with Urgent/NeedsResponse
- Category tags limited to 2 max to avoid UI clutter
- Sanitization happens before Firestore write, not on read
- Private methods since they're internal to service

---

### PR 2.7: Add Tag Query Helpers to ViewModel

**Goal:** Add helper methods to ViewModel for common tag queries used by UI.

**Tasks:**
- [ ] Read `CreatorLink/ViewModels/ConversationsViewModel.swift` to understand current helpers
- [ ] Add query helper methods to ConversationsViewModel:
  - `getConversationsWithCategory(_:)` -> [Conversation] - Get all with specific category
  - `getConversationsWithStatus(_:)` -> [Conversation] - Get all with specific status
  - `getUrgentConversations()` -> [Conversation] - Shortcut for urgent status
  - `getUnresolvedConversations()` -> [Conversation] - Get all without Resolved status
  - `countConversationsWithTag(category:status:)` -> Int - Count conversations with tags
- [ ] Add badge count helpers:
  - `urgentCount: Int` - Computed property for urgent conversation count
  - `needsResponseCount: Int` - Computed property for needs response count

**What to Test:**
1. Build project - verify no compilation errors
2. Check query methods filter conversations correctly
3. Verify computed properties use query helpers
4. Ensure methods respect user-specific tags (tagsByUser)

**Files Changed:**
- `CreatorLink/ViewModels/ConversationsViewModel.swift` - Add query helpers

**Notes:**
- Query methods filter the full conversations array
- Use getTagsForUser helper from PR 2.3 to extract user tags
- Computed properties enable badge display in UI (Phase 3)
- Methods should be efficient since they run on every UI update

---

### PR 2.8: Create TaggingService (Dedicated Service)

**Goal:** Create a dedicated service to encapsulate all tagging logic and separate concerns from ConversationService.

**Tasks:**
- [ ] Create NEW: `CreatorLink/Services/TaggingService.swift`:
  - Singleton service pattern
  - Reference to FirestoreService and ConversationService
  - Move tag-specific methods from ConversationService:
    - updateCategoryTags, updateStatusTags, updatePrimaryCategory, updateTagMetadata
    - markAsUrgent, markAsResolved, markAsNeedsResponse, removeUrgent
    - batchUpdateCategoryTags
    - validateCategoryTags, validateStatusTags, sanitizeStatusTags
- [ ] Add new TaggingService-specific methods:
  - `syncPrimaryCategoryFromTags(conversationId:userId:)` - Auto-update primaryCategory
  - `getEffectiveTags(conversation:userId:)` -> (categories:[ConversationTag], statuses:[StatusTag])
- [ ] Update ConversationService to delegate to TaggingService:
  - Remove moved tag methods
  - Keep references for backward compatibility if needed

**What to Test:**
1. Build project - verify no compilation errors
2. Check TaggingService follows singleton pattern
3. Verify all tag methods moved from ConversationService
4. Ensure ConversationService compiles without tag methods

**Files Changed:**
- NEW: `CreatorLink/Services/TaggingService.swift` - Dedicated tagging service
- `CreatorLink/Services/ConversationService.swift` - Remove tag methods

**Notes:**
- Separating concerns makes codebase more maintainable
- TaggingService focuses only on tag logic
- ConversationService focuses on conversation CRUD
- syncPrimaryCategoryFromTags uses AI confidence or user override to determine primary

---

### PR 2.9: Update ViewModel to Use TaggingService

**Goal:** Refactor ConversationsViewModel to use the new TaggingService instead of ConversationService for tag operations.

**Tasks:**
- [ ] Read `CreatorLink/ViewModels/ConversationsViewModel.swift` to understand tag integration points
- [ ] Read `CreatorLink/Services/TaggingService.swift` to understand new service API
- [ ] Update ConversationsViewModel:
  - Add property: `private let taggingService = TaggingService.shared`
  - Update filter logic to use `taggingService.getEffectiveTags()`
  - Update any tag manipulation to use TaggingService methods
- [ ] Add convenience methods in ViewModel that delegate to TaggingService:
  - `updateConversationCategory(conversationId:tags:)` - User action wrapper
  - `updateConversationStatus(conversationId:tags:)` - User action wrapper
  - `markConversationAsUrgent(conversationId:)` - Quick action wrapper
  - `markConversationAsResolved(conversationId:)` - Quick action wrapper

**What to Test:**
1. Build project - verify no compilation errors
2. Check ViewModel properly delegates to TaggingService
3. Verify convenience methods use currentUserId
4. Ensure filteredConversations still works correctly

**Files Changed:**
- `CreatorLink/ViewModels/ConversationsViewModel.swift` - Integrate TaggingService

**Notes:**
- ViewModel should not directly call ConversationService for tag operations
- Use currentUserId from ViewModel for per-user tag operations
- Convenience methods make it easier for UI to trigger tag updates
- getEffectiveTags abstracts the tagsByUser lookup

---

### PR 2.10: Add Tag Update Error Handling

**Goal:** Add comprehensive error handling for tag operations with user-friendly error messages.

**Tasks:**
- [ ] Read `CreatorLink/Services/ConversationService.swift` to understand ConversationError enum
- [ ] Extend ConversationError enum with tag-specific errors:
  - `.invalidTags` - Tag validation failed
  - `.tooManyTags` - Exceeded max tag limit
  - `.tagConflict` - Conflicting tags detected
- [ ] Update TaggingService methods to throw appropriate errors:
  - Throw `.invalidTags` when validation fails
  - Throw `.tooManyTags` when category tags > 2
  - Throw `.tagConflict` when status tags conflict
- [ ] Add error message descriptions in ConversationError enum
- [ ] Update ConversationsViewModel to catch and display tag errors:
  - Add `tagErrorMessage: String?` property
  - Catch errors in convenience methods and set error message
  - Clear error message after 3 seconds

**What to Test:**
1. Build project - verify no compilation errors
2. Check error enum has descriptive messages
3. Verify TaggingService throws appropriate errors
4. Ensure ViewModel catches and displays errors

**Files Changed:**
- `CreatorLink/Services/ConversationService.swift` - Extend error enum
- `CreatorLink/Services/TaggingService.swift` - Add error throwing
- `CreatorLink/ViewModels/ConversationsViewModel.swift` - Add error handling

**Notes:**
- Error messages should be user-friendly (not technical)
- Follow existing ConversationError pattern
- ViewModel should clear errors automatically to avoid stale messages
- Errors help users understand why tag operations fail

---

## Completion Checklist

After completing Phases 1-2, verify:

- [ ] All new Conversation fields are optional (backward compatible)
- [ ] ConversationTag and StatusTag enums follow MessageStatus pattern
- [ ] TagMetadata struct properly nested in Conversation model
- [ ] db-types.md documentation updated with tag fields
- [ ] TaggingService implements all CRUD operations for tags
- [ ] ConversationsViewModel has filtering logic with OR semantics
- [ ] Filter preferences persist with UserDefaults
- [ ] Batch tag updates use Firestore batch operations
- [ ] Tag validation enforces business rules
- [ ] Error handling provides user-friendly messages
- [ ] Project builds successfully without errors
- [ ] All existing conversations still load correctly (backward compatibility)

**Next Steps:**
- Phase 3 will build the UI components (TagBadgeView, FilterBarView)
- Phase 4 will add tag editing UI (TagEditorSheet, swipe actions)
- Phase 5 will implement AI auto-tagging in Firebase Functions
- Phase 6 will add advanced filtering and AI insights

---

**Document Version:** 1.0
**Last Updated:** October 24, 2025
**Phases Covered:** 1-2 (Data Model & Core Services)
**Target iOS Version:** 17.0+
