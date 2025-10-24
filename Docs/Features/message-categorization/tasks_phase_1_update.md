# Smart Message Categorization - Phase 1 Update: Per-User Status Tags

## Context

This update restructures the status tag system to be per-user instead of conversation-level. The original Phase 1 implementation stored `statusTags` as a top-level conversation property, meaning all participants saw the same status. However, status is inherently user-specific: different participants in the same conversation have different status perspectives.

**Example Use Case:**
- User A sends a message → Their view: "Awaiting Reply" (waiting for User B)
- User B receives message → Their view: "Needs Response" (they need to reply)
- Same conversation, different status tags for each user

The solution moves `statusTags` into a new `UserTagData` struct that is stored per-user in the `tagsByUser` map. Category tags remain conversation-level (shared) since categorization is a general classification (e.g., "Business" applies to the conversation itself, not the user's perspective).

**Key Technical Changes:**
- Create `UserTagData` struct to hold both category and status tags per user
- Remove top-level `statusTags` property from Conversation
- Change `tagsByUser` type from `[String: [String]]` to `[String: UserTagData]`
- Update all references to use the new nested structure
- Maintain backward compatibility with optional fields

## Instructions for AI Agent

Follow this workflow for each PR:

1. **Read Phase**: Read all files listed in "Files Changed" section to understand current implementation
2. **Implement Tasks**: Execute tasks in order, marking each complete with [x]
3. **Test**: Run all tests in "What to Test" section and verify results
4. **Completion Summary**: Provide a brief summary of what was implemented and any notes
5. **Wait for Approval**: Wait for explicit approval before starting the next PR

Each PR should be a complete, testable unit that builds the project successfully.

---

## Phase 1 Update: Per-User Status Tags Restructuring

**Estimated Time:** 2-3 hours

This phase restructures the tag system to support per-user status tags while keeping category tags at the conversation level.

### PR 1-Update.1: Create UserTagData Struct

**Goal:** Create a new struct to encapsulate per-user tag data (category and status tags).

**Tasks:**
- [ ] Read `CreatorLink/Models/Conversation.swift` to understand current structure and TagMetadata pattern
- [ ] Add NEW nested struct `UserTagData` inside Conversation model (after TagMetadata):
  - `categoryTags: [ConversationTag]?` - Per-user category tag preferences (optional)
  - `statusTags: [StatusTag]?` - Per-user status tags (optional)
  - Codable and Hashable conformance
  - Default initializer with all fields optional (default: nil)
  - CodingKeys enum matching field names
- [ ] Add documentation comment explaining:
  - UserTagData enables per-user tag preferences in conversations
  - Category tags can be overridden per-user but default to conversation-level tags
  - Status tags are always per-user (no conversation-level default)

**What to Test:**
1. Build project - verify no compilation errors
2. Check UserTagData follows same pattern as TagMetadata nested struct
3. Verify Codable and Hashable conformance compiles correctly
4. Ensure all fields are optional for backward compatibility

**Files Changed:**
- `CreatorLink/Models/Conversation.swift` - Add UserTagData nested struct

**Notes:**
- Place UserTagData after TagMetadata in the file for logical grouping
- Both fields are optional to support minimal data storage (only store when needed)
- Follows existing pattern from AIConfig and TagMetadata
- This struct will be stored in Firestore as a map within tagsByUser

**Before (Current Model):**
```swift
struct Conversation {
    let categoryTags: [ConversationTag]?
    let statusTags: [StatusTag]?  // ❌ Conversation-level
    let tagsByUser: [String: [String]]?  // Simple string arrays
}
```

**After (New Model):**
```swift
struct Conversation {
    let categoryTags: [ConversationTag]?
    // statusTags removed - now per-user in UserTagData
    let tagsByUser: [String: UserTagData]?  // ✅ Structured data

    struct UserTagData: Codable, Hashable {
        let categoryTags: [ConversationTag]?
        let statusTags: [StatusTag]?  // ✅ Now per-user
    }
}
```

---

### PR 1-Update.2: Update Conversation Model Schema

**Goal:** Remove top-level statusTags and update tagsByUser type to use UserTagData.

**Tasks:**
- [ ] Read `CreatorLink/Models/Conversation.swift` to understand current field structure
- [ ] Remove top-level `statusTags` property:
  - Delete the `let statusTags: [StatusTag]?` line (around line 26)
- [ ] Update `tagsByUser` type:
  - Change from `let tagsByUser: [String: [String]]?` to `let tagsByUser: [String: UserTagData]?`
- [ ] Update custom initializer:
  - Remove `statusTags: [StatusTag]? = nil` parameter
  - Change `tagsByUser` parameter type to `[String: UserTagData]? = nil`
  - Remove assignment: `self.statusTags = statusTags`
- [ ] Update CodingKeys enum:
  - Remove `case statusTags` entry
  - Keep `case tagsByUser` (type change is transparent to Codable)

**What to Test:**
1. Build project - verify no compilation errors
2. Check that statusTags is completely removed from Conversation struct
3. Verify tagsByUser now uses UserTagData type
4. Ensure initializer compiles with updated signature
5. Confirm CodingKeys excludes statusTags

**Files Changed:**
- `CreatorLink/Models/Conversation.swift` - Update schema (remove statusTags, change tagsByUser type)

**Notes:**
- This is a breaking change for any code referencing `conversation.statusTags`
- Next PRs will update all references to use `tagsByUser[userId]?.statusTags`
- Firestore data migration is not required - old data will be ignored (statusTags field unused)
- Optional fields ensure backward compatibility with existing conversations

---

### PR 1-Update.3: Update Conversation Hash and Equality Operators

**Goal:** Update hash(into:) and == operator to reflect schema changes.

**Tasks:**
- [ ] Read `CreatorLink/Models/Conversation.swift` to find hash and equality implementations
- [ ] Update `hash(into:)` method (around line 116):
  - Remove `hasher.combine(statusTags)` line
  - Keep `hasher.combine(categoryTags)` (unchanged)
  - tagsByUser already excluded from hash (line 132 comment confirms this)
- [ ] Update `==` operator (around line 136):
  - Remove the entire `statusTagsEqual` comparison block (lines 162-167)
  - Remove `statusTagsEqual &&` from the final return statement (around line 191)
  - Keep categoryTagsEqual and tagsByUserEqual comparisons (unchanged)

**What to Test:**
1. Build project - verify no compilation errors
2. Check hash method excludes removed statusTags field
3. Verify equality operator compiles without statusTags comparison
4. Ensure tagsByUser equality logic remains intact (handles nil cases)

**Files Changed:**
- `CreatorLink/Models/Conversation.swift` - Update hash and equality operators

**Notes:**
- tagsByUser is excluded from hash (line 132 comment) for real-time updates
- tagsByUser IS included in equality operator to detect changes
- Removing statusTags from both methods aligns with schema changes
- UserTagData within tagsByUser automatically handled by dictionary equality

---

### PR 1-Update.4: Update Database Schema Documentation

**Goal:** Update db-types.md to reflect the new per-user status tag structure.

**Tasks:**
- [ ] Read `db-types.md` to find conversations collection documentation (around line 103)
- [ ] Update conversations collection fields section:
  - Remove `statusTags` field description (around line 125)
  - Update `tagsByUser` description to reflect new type:
    - Old: "per-user tag preferences (userId → array of tag raw values)"
    - New: "per-user tag data including category and status tags (userId → UserTagData object)"
- [ ] Add UserTagData struct documentation after TagMetadata section (after line 160):
  - Document structure with nested fields
  - Explain categoryTags vs statusTags usage
  - Note all fields are optional
  - Include example JSON structure
- [ ] Update Example Document (Group Chat) section (around line 167):
  - Remove `"statusTags": ["needsResponse"]` field
  - Update `tagsByUser` to use UserTagData structure:
    ```json
    "tagsByUser": {
      "user123": {
        "categoryTags": ["collaboration"],
        "statusTags": ["needsResponse"]
      },
      "user456": {
        "categoryTags": ["collaboration"],
        "statusTags": ["urgent"]
      },
      "user789": {
        "categoryTags": ["business"],
        "statusTags": ["awaitingReply"]
      }
    }
    ```
- [ ] Update Notes section (around line 251):
  - Remove reference to statusTags as conversation-level field
  - Update tagsByUser description to explain UserTagData structure
  - Add note: "Status tags are per-user (different users see different statuses for same conversation)"
  - Add note: "Category tags can be per-user overrides or default to conversation-level categoryTags"

**What to Test:**
1. Read updated db-types.md - verify formatting is consistent
2. Check that statusTags is removed from conversations collection fields
3. Verify UserTagData struct is documented with all fields
4. Ensure example JSON shows proper nested structure
5. Confirm notes explain per-user vs conversation-level distinction

**Files Changed:**
- `db-types.md` - Update conversations schema and add UserTagData documentation

**Notes:**
- Follow existing documentation format from AIConfig and TagMetadata sections
- Include both one-on-one and group chat examples showing different user perspectives
- Emphasize backward compatibility (all fields optional)
- UserTagData is stored as a nested map in Firestore: `tagsByUser/{userId}/categoryTags`

**UserTagData Documentation Template:**
```markdown
#### UserTagData Struct

**Purpose:** Encapsulates per-user tag data for category and status tags in conversations.

**Fields:**
- `categoryTags: [ConversationTag]?` - *Optional* per-user category tag preferences (overrides conversation-level tags)
- `statusTags: [StatusTag]?` - *Optional* per-user status tags (urgent, needsResponse, awaitingReply, resolved)

**Notes:**
- UserTagData is a nested struct within Conversation
- Stored in Firestore as a map within `tagsByUser/{userId}`
- Both fields are optional to minimize data storage (only store when tags exist)
- Category tags in UserTagData override conversation-level `categoryTags` for that user
- Status tags are always per-user (no conversation-level default)
- Different users in the same conversation can have completely different status tags
```

---

### PR 1-Update.5: Create Migration Helper for Legacy Data

**Goal:** Add helper methods to safely access tags from both old and new data structures during transition.

**Tasks:**
- [ ] Read `CreatorLink/Models/Conversation.swift` to understand current structure
- [ ] Add extension to Conversation struct (at end of file before final closing brace):
  - Add comment: `// MARK: - Tag Access Helpers (supports legacy and new data structures)`
  - Add method: `func getUserStatusTags(userId: String) -> [StatusTag]?`
    - Return `tagsByUser?[userId]?.statusTags` (new structure)
    - Return nil if not found
  - Add method: `func getUserCategoryTags(userId: String) -> [ConversationTag]?`
    - Return `tagsByUser?[userId]?.categoryTags ?? categoryTags` (user override or fallback)
    - Prioritize per-user tags, fallback to conversation-level
  - Add method: `func setUserTags(userId: String, categoryTags: [ConversationTag]?, statusTags: [StatusTag]?) -> [String: UserTagData]`
    - Create or update UserTagData for userId
    - Return updated tagsByUser dictionary for Firestore update
    - Helper for service layer to create proper update data

**What to Test:**
1. Build project - verify no compilation errors
2. Check getUserStatusTags returns nil for missing user
3. Verify getUserCategoryTags falls back to conversation-level tags
4. Ensure setUserTags creates proper UserTagData structure
5. Test with mock conversations that have both old and new data

**Files Changed:**
- `CreatorLink/Models/Conversation.swift` - Add tag access helper methods

**Notes:**
- Helper methods provide clean API for accessing per-user tags
- Fallback logic handles transition period gracefully
- setUserTags helper simplifies service layer updates
- These methods abstract the data structure complexity from ViewModels

**Example Implementation:**
```swift
// MARK: - Tag Access Helpers (supports legacy and new data structures)

func getUserStatusTags(userId: String) -> [StatusTag]? {
    return tagsByUser?[userId]?.statusTags
}

func getUserCategoryTags(userId: String) -> [ConversationTag]? {
    // Prioritize per-user category tags, fallback to conversation-level
    return tagsByUser?[userId]?.categoryTags ?? categoryTags
}

func setUserTags(userId: String, categoryTags: [ConversationTag]?, statusTags: [StatusTag]?) -> [String: UserTagData] {
    var updatedTagsByUser = tagsByUser ?? [:]
    updatedTagsByUser[userId] = UserTagData(categoryTags: categoryTags, statusTags: statusTags)
    return updatedTagsByUser
}
```

---

### PR 1-Update.6: Update Phase 1 Task Document References

**Goal:** Update the original Phase 1 task document to reference the new per-user structure.

**Tasks:**
- [ ] Read `CreatorLink/Docs/Features/message-categorization/tasks_phases_1-2.md` to find statusTags references
- [ ] Add prominent note at the top of Phase 1 section (after line 30):
  - Add warning: "**⚠️ IMPORTANT UPDATE:** Status tags have been restructured to be per-user. See `tasks_phase_1_update.md` for migration details."
  - Add note: "The tasks below reflect the original plan. PR 1.3 and related PRs have been superseded by the update."
- [ ] Update PR 1.3 description (around line 102):
  - Add note at top: "**NOTE:** This PR has been updated. `statusTags` is no longer a top-level field. See Phase 1 Update tasks."
  - Update field list to reflect final structure:
    - `categoryTags: [ConversationTag]?` - Array of category tags (conversation-level)
    - `statusTags` - **REMOVED** (now per-user in `tagsByUser`)
    - `tagsByUser: [String: UserTagData]?` - Per-user tag data (updated type)
- [ ] Update PR 1.4 notes (around line 160):
  - Update tagsByUser description to mention UserTagData structure
  - Add note: "Status tags are per-user, stored within UserTagData"

**What to Test:**
1. Read updated task document - verify notes are clear
2. Check that warning is prominent at top of Phase 1
3. Verify PR 1.3 reflects actual implementation
4. Ensure developers understand the change when following tasks

**Files Changed:**
- `CreatorLink/Docs/Features/message-categorization/tasks_phases_1-2.md` - Add update notes and warnings

**Notes:**
- This update ensures future developers following Phase 1 tasks understand the change
- Original task document preserved as historical reference
- Warnings prevent confusion about schema differences
- Links between documents create clear migration path

---

## Testing Strategy

After completing all PRs in this phase, verify:

### Build Validation
- [ ] Project builds successfully with zero compilation errors
- [ ] All Conversation model tests pass (if any exist)
- [ ] UserTagData conforms to Codable and Hashable

### Schema Validation
- [ ] `statusTags` property completely removed from Conversation
- [ ] `tagsByUser` type changed to `[String: UserTagData]?`
- [ ] UserTagData struct includes both categoryTags and statusTags
- [ ] All fields remain optional for backward compatibility

### Data Access Validation
- [ ] `getUserStatusTags(userId:)` returns per-user status tags
- [ ] `getUserCategoryTags(userId:)` falls back to conversation-level tags
- [ ] `setUserTags(userId:categoryTags:statusTags:)` creates proper structure
- [ ] Helper methods handle nil cases gracefully

### Documentation Validation
- [ ] db-types.md reflects UserTagData structure with examples
- [ ] Example JSON shows proper nested structure
- [ ] Notes explain per-user vs conversation-level distinction
- [ ] Phase 1 task document includes update warnings

### Backward Compatibility
- [ ] Existing conversations without tags still load correctly
- [ ] Conversations with old statusTags field are ignored gracefully
- [ ] New UserTagData structure serializes/deserializes correctly
- [ ] Optional fields default to nil when not present

---

## Migration Notes

### Firestore Data Migration

**No migration required** - This is a schema evolution, not a breaking change:

1. **Old data handling:**
   - Existing `statusTags` field in Firestore will be ignored (removed from model)
   - Old `tagsByUser` data (`[String: [String]]`) will fail to decode (type mismatch)
   - Conversations without tags continue to work (all fields optional)

2. **New data creation:**
   - New tags use `tagsByUser: [String: UserTagData]` structure
   - Status tags stored per-user in `tagsByUser/{userId}/statusTags`
   - Category tags can be per-user overrides or conversation-level

3. **Transition period:**
   - Conversations may have no tags (backward compatible)
   - Existing tag data from Phase 1 testing will be lost (acceptable for development)
   - Production deployment should clear test data before launch

### Code Migration

**Phase 2 PRs need updates** to reference the new structure:

1. **Service Layer (Phase 2 PRs):**
   - Replace `conversation.statusTags` with `conversation.getUserStatusTags(userId)`
   - Update Firestore writes to use `tagsByUser/{userId}` path
   - Use `setUserTags` helper for creating update data

2. **ViewModel Layer (Phase 2 PRs):**
   - Update filter logic to iterate through all users' statusTags
   - Use `getUserStatusTags(currentUserId)` for current user's view
   - Badge counts aggregate across all participants

3. **UI Layer (Phase 3+ PRs):**
   - Display per-user status tags from `getUserStatusTags(userId)`
   - Tag editors update user-specific tags only
   - Status indicators reflect current user's perspective

### Example Service Update

**Before (Old Phase 2):**
```swift
// ❌ Old approach - conversation-level
func updateStatusTags(conversationId: String, tags: [StatusTag]) async throws {
    let data: [String: Any] = ["statusTags": tags.map { $0.rawValue }]
    try await db.collection("conversations").document(conversationId).updateData(data)
}
```

**After (Updated Phase 2):**
```swift
// ✅ New approach - per-user
func updateStatusTags(conversationId: String, userId: String, tags: [StatusTag]) async throws {
    let userTagData = UserTagData(categoryTags: nil, statusTags: tags)
    let data: [String: Any] = [
        "tagsByUser.\(userId)": try Firestore.Encoder().encode(userTagData)
    ]
    try await db.collection("conversations").document(conversationId).updateData(data)
}
```

---

## Next Steps

After completing this Phase 1 Update:

1. **Review Phase 2 tasks** (`tasks_phases_1-2.md`) and update service methods
2. **Update ConversationService** to use per-user status tags
3. **Update TaggingService** to handle UserTagData structure
4. **Update ConversationsViewModel** to aggregate per-user tags for filtering
5. **Test end-to-end** that status tags work correctly for multiple users

Phase 2+ PRs will need adjustments to work with the new per-user structure. This update provides the foundation for proper multi-user tag management.

---

**Document Version:** 1.0
**Created:** October 24, 2025
**Depends On:** Phase 1 (tasks_phases_1-2.md PR 1.1-1.4)
**Affects:** Phase 2+ (all service and ViewModel layers)
**Target iOS Version:** 17.0+
