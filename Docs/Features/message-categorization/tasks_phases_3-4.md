# Message Categorization - Phases 3-4 Implementation Tasks

## Context

This document covers **Phase 3 (Basic UI Components)** and **Phase 4 (Tag Editing & Manual Override)** of the Smart Message Categorization feature. These phases focus on the user-facing UI elements that display category tags, status badges, and provide filtering/editing capabilities.

**What Already Exists:**
- Phases 1-2 have established data models (ConversationTag, StatusTag enums) and core tag management services
- Conversation model now has `categoryTags`, `statusTags`, `primaryCategory`, `aiConfidence`, and `userOverrideTags` fields
- ConversationService includes tag CRUD methods (updateTags, markAsUrgent, markAsResolved)
- ConversationsViewModel has filtering logic (filterByCategory, filterByStatus, filteredConversations computed property)
- Existing UI patterns: ChatsView (conversation list), ConversationRowView (list row), ChatDetailView (detail screen)

**What We're Building:**
- **Phase 3:** Visual components to display tags as emoji badges, filter bar for quick category/status filtering, urgent indicators
- **Phase 4:** Interactive tag editing UI via long-press menus, swipe actions, and modal tag editor sheet

**Key Design Decisions:**
- Tags displayed as emoji-only badges (compact, no text) - max 2-3 badges per row to avoid clutter
- Filter bar uses horizontal scroll of emoji buttons (similar to emoji reaction pickers)
- Urgent conversations get subtle red tint + fire emoji badge (no auto-floating to top)
- Long-press on conversation row opens context menu with quick actions
- Swipe actions: right = mark urgent, left = mark resolved
- Full tag editor sheet accessible from ChatDetailView header
- All tag changes set userOverrideTags flag to prevent AI from overwriting

---

## Instructions for AI Agent

**Standard Workflow:**
1. **Read Phase**: Start each PR by reading all files listed in "Files to Read" section
2. **Implement**: Complete tasks in the order listed, marking each with [x] when done
3. **Test**: Follow testing steps to verify the implementation works correctly
4. **Completion Summary**: After finishing all tasks, provide a summary of what was implemented and what files were changed
5. **Wait for Approval**: Do NOT proceed to the next PR until the user approves
6. **Iterate**: Address any feedback, then move to the next PR

**Code Style Guidelines:**
- Follow existing patterns in ConversationRowView and ChatsView
- Use SF Symbols for all icons (no custom assets)
- Keep UI components reusable and testable
- Use @State for local UI state, @Observable for shared state
- Follow SwiftUI best practices for composition

---

## Phase 3: Basic UI Components

**Estimated Time:** 6-8 hours

This phase creates the visual foundation for displaying tags and filtering conversations. Users will see emoji badges on conversation rows and can tap filter buttons to show only specific categories/statuses.

### PR 3.1: Tag Badge Components

**Goal:** Create reusable badge components to display category and status tags as compact emoji indicators.

**Tasks:**
- [ ] Read `CreatorLink/Views/Chats/ConversationRowView.swift` to understand current row layout and spacing
- [ ] Read `CreatorLink/Views/Chats/Components/GroupAvatarView.swift` as reference for component structure
- [ ] Read `CreatorLink/Models/Conversation.swift` to see tag field structure (categoryTags, statusTags, primaryCategory)
- [ ] Create NEW: `CreatorLink/Views/Chats/Components/TagBadgeView.swift`:
  - Struct TagBadgeView displaying single emoji in small circle
  - Accept emoji String and optional background color
  - Size: 24x24 circle with 14pt font emoji
  - Default background: clear, urgent background: red.opacity(0.1)
  - Include Preview with sample badges
- [ ] Create NEW: `CreatorLink/Views/Chats/Components/ConversationTagsView.swift`:
  - Horizontal HStack of TagBadgeView components
  - Accept Conversation model, extract categoryTags and statusTags
  - Map ConversationTag/StatusTag enums to emoji strings
  - Display max 2-3 badges (priority: Urgent > NeedsResponse > primaryCategory)
  - Spacing: 4pt between badges
  - Include logic to show fire emoji for urgent, question mark for needs response
- [ ] Update `CreatorLink/Models/ConversationTag.swift` (if not already done in Phase 1):
  - Add computed property `emoji: String` returning emoji for each case
  - Business: "💼", Collaboration: "🤝", Social: "💬", Fan: "⭐"
- [ ] Update `CreatorLink/Models/StatusTag.swift` (if not already done in Phase 1):
  - Add computed property `emoji: String` returning emoji for each case
  - Urgent: "🔥", NeedsResponse: "❓", AwaitingReply: "⏳", Resolved: "✅"

**What to Test:**
1. Build project - verify no compilation errors
2. Preview TagBadgeView in Xcode canvas - verify emoji displays correctly in circle
3. Preview ConversationTagsView with mock conversation - verify max 3 badges shown
4. Test with various tag combinations - ensure priority ordering (urgent first)

**Files Changed:**
- NEW: `CreatorLink/Views/Chats/Components/TagBadgeView.swift` - Single emoji badge component
- NEW: `CreatorLink/Views/Chats/Components/ConversationTagsView.swift` - Multi-badge layout for conversation row
- `CreatorLink/Models/ConversationTag.swift` - Add emoji computed property
- `CreatorLink/Models/StatusTag.swift` - Add emoji computed property

**Notes:**
- Keep badges small and unobtrusive - conversation rows already have avatar, name, message, timestamp, unread badge
- Use SF Symbols only if emoji rendering is inconsistent, but prefer native emoji for cross-platform consistency

---

### PR 3.2: Integrate Tags into Conversation Row

**Goal:** Display tag badges in ConversationRowView without cluttering the existing layout.

**Tasks:**
- [ ] Read `CreatorLink/Views/Chats/ConversationRowView.swift` to understand current layout structure
- [ ] Read `CreatorLink/Views/Chats/Components/ConversationTagsView.swift` (just created in PR 3.1)
- [ ] Update `CreatorLink/Views/Chats/ConversationRowView.swift`:
  - Add ConversationTagsView below conversation name (between headline and last message)
  - Position tags in left VStack, aligned with conversation info
  - Only show if conversation has at least one tag (categoryTags or statusTags not empty)
  - Maintain existing spacing and layout (4pt spacing in VStack)
  - Add subtle red tint to entire row if conversation has Urgent status (background: Color.red.opacity(0.03))
  - Ensure unread badge and timestamp remain in right VStack, unaffected

**What to Test:**
1. Build project - verify no compilation errors
2. Open ChatsView - verify tag badges appear below conversation name
3. Check conversation with urgent tag - verify subtle red background tint
4. Test with different tag combinations - verify max 3 badges shown
5. Test with no tags - verify badges don't appear (no empty space)
6. Verify existing layout elements (avatar, name, message, timestamp, unread badge) still display correctly

**Files Changed:**
- `CreatorLink/Views/Chats/ConversationRowView.swift` - Add ConversationTagsView to layout, urgent row styling

**Notes:**
- ConversationRowView already has complex layout with avatar, online indicator, typing indicator, group status icons - be careful not to disrupt existing logic
- Red tint should be very subtle (opacity 0.03-0.05) to avoid harsh visual

---

### PR 3.3: Filter Bar UI Component

**Goal:** Create horizontal scrollable filter bar with emoji buttons for category and status filtering.

**Tasks:**
- [ ] Read `CreatorLink/Views/Chats/ChatsView.swift` to understand navigation structure
- [ ] Read `CreatorLink/ViewModels/ConversationsViewModel.swift` to see filtering properties (selectedCategories, selectedStatuses, filteredConversations)
- [ ] Create NEW: `CreatorLink/Views/Chats/Components/FilterChipView.swift`:
  - Small tappable chip with emoji + optional count badge
  - Accept emoji String, count Int, isSelected Bool
  - Appearance: 44pt height, 8pt padding, rounded corners (20pt radius)
  - Selected state: blue background with white emoji
  - Unselected state: gray.opacity(0.2) background with default emoji color
  - Optional red badge showing count (e.g., "3" for 3 urgent conversations)
  - Include tap gesture handler (pass closure to parent)
- [ ] Create NEW: `CreatorLink/Views/Chats/Components/FilterBarView.swift`:
  - Horizontal ScrollView of FilterChipView components
  - Accept binding to ConversationsViewModel for filtering state
  - Show All (no emoji), Business 💼, Collaboration 🤝, Social 💬, Fan ⭐
  - Show Urgent 🔥 with count, NeedsResponse ❓, AwaitingReply ⏳
  - Tapping chip toggles selection (multi-select allowed for categories)
  - Tapping "All" clears all filters
  - Include logic to count conversations per filter
  - Height: 60pt (including 8pt top/bottom padding)

**What to Test:**
1. Build project - verify no compilation errors
2. Preview FilterBarView in Xcode canvas - verify chips display in horizontal scroll
3. Test tap interaction - verify selected state changes (blue background)
4. Test multi-select - verify multiple categories can be selected simultaneously
5. Test "All" button - verify clears all filters

**Files Changed:**
- NEW: `CreatorLink/Views/Chats/Components/FilterChipView.swift` - Single filter button chip
- NEW: `CreatorLink/Views/Chats/Components/FilterBarView.swift` - Horizontal scrollable filter bar

**Notes:**
- Similar pattern to emoji reaction pickers in messaging apps
- Keep chips small enough that 4-5 are visible without scrolling on iPhone SE

---

### PR 3.4: Integrate Filter Bar into ChatsView

**Goal:** Add filter bar above conversation list and wire up filtering logic to show/hide conversations.

**Tasks:**
- [ ] Read `CreatorLink/Views/Chats/ChatsView.swift` to understand view structure
- [ ] Read `CreatorLink/Views/Chats/Components/FilterBarView.swift` (just created in PR 3.3)
- [ ] Read `CreatorLink/ViewModels/ConversationsViewModel.swift` to verify filtering methods exist
- [ ] Update `CreatorLink/Views/Chats/ChatsView.swift`:
  - Add FilterBarView above conversationListView (inside Group, after loading/empty checks)
  - Position filter bar above List, full width
  - Pass viewModel binding to FilterBarView
  - Update List to iterate over viewModel.filteredConversations instead of viewModel.conversations
  - Add animation when filter changes (.animation(.easeInOut, value: viewModel.selectedCategories))
  - Hide filter bar when conversations array is empty
- [ ] Update `CreatorLink/ViewModels/ConversationsViewModel.swift` (if not already done in Phase 2):
  - Verify selectedCategories: [ConversationTag] property exists
  - Verify selectedStatuses: [StatusTag] property exists
  - Verify filteredConversations computed property exists and works
  - Add clearFilters() method if not present

**What to Test:**
1. Build project - verify no compilation errors
2. Open ChatsView - verify filter bar appears above conversation list
3. Tap Business filter - verify only business conversations show
4. Tap multiple categories - verify OR logic (shows conversations matching ANY selected category)
5. Tap Urgent filter - verify only urgent conversations show
6. Tap "All" - verify all conversations reappear
7. Verify filter bar hides when no conversations exist (empty state)

**Files Changed:**
- `CreatorLink/Views/Chats/ChatsView.swift` - Add FilterBarView, update List to use filteredConversations
- `CreatorLink/ViewModels/ConversationsViewModel.swift` - Verify/add filtering properties and methods

**Notes:**
- filteredConversations should default to all conversations when no filters selected
- Animation keeps UI smooth when filtering changes

---

### PR 3.5: Urgent Count Indicator & Visual Polish

**Goal:** Add red badge to urgent filter chip showing count and polish urgent conversation styling.

**Tasks:**
- [ ] Read `CreatorLink/Views/Chats/Components/FilterBarView.swift` to understand chip layout
- [ ] Read `CreatorLink/ViewModels/ConversationsViewModel.swift` to add urgent count logic
- [ ] Update `CreatorLink/ViewModels/ConversationsViewModel.swift`:
  - Add computed property urgentCount: Int that counts conversations with StatusTag.urgent
  - Add computed property needsResponseCount: Int that counts conversations with StatusTag.needsResponse
- [ ] Update `CreatorLink/Views/Chats/Components/FilterBarView.swift`:
  - Pass urgentCount to Urgent 🔥 FilterChipView
  - Pass needsResponseCount to NeedsResponse ❓ FilterChipView
  - Display count as small red badge (white text) on top-right of chip
  - Badge appearance: 18x18 circle, 10pt font, offset(x: 8, y: -8)
- [ ] Update `CreatorLink/Views/Chats/Components/FilterChipView.swift`:
  - Accept optional count: Int? parameter
  - When count > 0, show red badge with count overlay
  - Use ZStack to position badge on top-right corner
- [ ] Update `CreatorLink/Views/Chats/ConversationRowView.swift`:
  - Refine urgent row styling (current: red.opacity(0.03))
  - Add subtle left border (2pt width, Color.red.opacity(0.4)) for urgent conversations
  - Ensure fire emoji badge is prominently displayed in ConversationTagsView

**What to Test:**
1. Build project - verify no compilation errors
2. Create test conversation with urgent tag - verify count badge appears on Urgent filter chip
3. Mark conversation as urgent - verify count increments immediately
4. Mark conversation as resolved - verify count decrements
5. Verify urgent conversation has subtle red tint + left border
6. Test with 10+ urgent conversations - verify badge shows "10" not "99+"

**Files Changed:**
- `CreatorLink/ViewModels/ConversationsViewModel.swift` - Add urgentCount and needsResponseCount computed properties
- `CreatorLink/Views/Chats/Components/FilterBarView.swift` - Pass counts to chips
- `CreatorLink/Views/Chats/Components/FilterChipView.swift` - Add count badge overlay
- `CreatorLink/Views/Chats/ConversationRowView.swift` - Refine urgent styling with left border

**Notes:**
- Badge count helps users prioritize - "3 urgent messages" is actionable
- Don't show badge for 0 count - only display when count > 0
- Left border makes urgent conversations stand out without being too aggressive

---

## Phase 4: Tag Editing & Manual Override

**Estimated Time:** 8-10 hours

This phase adds interactive tag editing capabilities via long-press menus, swipe actions, and a full tag editor modal. All manual tag changes set the userOverrideTags flag to prevent AI from overwriting user preferences.

### PR 4.1: Long-Press Context Menu for Quick Actions

**Goal:** Add long-press gesture to ConversationRowView showing context menu with quick tag actions.

**Tasks:**
- [ ] Read `CreatorLink/Views/Chats/ConversationRowView.swift` to understand current gesture handling
- [ ] Read `CreatorLink/Views/Chats/GroupInfoView.swift` as reference for contextMenu usage (line 393)
- [ ] Read `CreatorLink/Services/ConversationService.swift` to verify tag update methods exist (updateTags, markAsUrgent, markAsResolved)
- [ ] Update `CreatorLink/Views/Chats/ConversationRowView.swift`:
  - Add .contextMenu modifier to entire row HStack
  - Menu items: "Mark as Urgent" (fire emoji), "Mark as Resolved" (checkmark emoji), "Change Category" (folder emoji)
  - Each action calls ConversationService method with appropriate tags
  - Set userOverrideTags: true when making changes
  - Show current tags with checkmarks (e.g., "Business ✓" if already tagged)
  - Include "Remove Tags" option to clear all tags
  - Add haptic feedback (.impact(.medium)) when menu opens
- [ ] Update `CreatorLink/Services/ConversationService.swift` (if not already done in Phase 2):
  - Verify markAsUrgent method exists and sets userOverrideTags flag
  - Verify markAsResolved method exists and sets userOverrideTags flag
  - Verify updateTags method accepts userOverride parameter

**What to Test:**
1. Build project - verify no compilation errors
2. Long-press on conversation row - verify context menu appears
3. Tap "Mark as Urgent" - verify fire emoji badge appears immediately
4. Long-press urgent conversation - verify "Mark as Urgent" shows checkmark (already set)
5. Tap "Mark as Resolved" - verify checkmark badge appears, urgent badge removed
6. Tap "Remove Tags" - verify all badges disappear
7. Verify haptic feedback when menu opens

**Files Changed:**
- `CreatorLink/Views/Chats/ConversationRowView.swift` - Add contextMenu with quick actions
- `CreatorLink/Services/ConversationService.swift` - Verify tag methods support userOverride flag

**Notes:**
- Context menu is iOS native pattern - familiar to users from Messages app
- Keep menu items concise - max 5-6 options to avoid overwhelming
- Current tags should show checkmark to indicate state

---

### PR 4.2: Swipe Actions for Mark Urgent/Resolved

**Goal:** Add swipe gestures to ConversationRowView for quick urgent/resolved tagging.

**Tasks:**
- [ ] Read `CreatorLink/Views/Chats/ChatsView.swift` to understand List structure (line 157)
- [ ] Read `CreatorLink/Views/Chats/ConversationRowView.swift` to see current row implementation
- [ ] Update `CreatorLink/Views/Chats/ChatsView.swift`:
  - Add .swipeActions(edge: .trailing) to List row (swipe left to reveal)
  - Add "Urgent" button with fire emoji, red background
  - Calls viewModel.markConversationAsUrgent(conversation)
  - Add .swipeActions(edge: .leading) to List row (swipe right to reveal)
  - Add "Resolved" button with checkmark emoji, green background
  - Calls viewModel.markConversationAsResolved(conversation)
  - Both actions set userOverrideTags: true
  - Add haptic feedback (.success) when action completes
- [ ] Update `CreatorLink/ViewModels/ConversationsViewModel.swift`:
  - Add markConversationAsUrgent(_ conversation: Conversation) async method
  - Calls ConversationService.markAsUrgent with userOverride: true
  - Add markConversationAsResolved(_ conversation: Conversation) async method
  - Calls ConversationService.markAsResolved with userOverride: true
  - Handle errors gracefully (set errorMessage)

**What to Test:**
1. Build project - verify no compilation errors
2. Swipe left on conversation row - verify "Urgent" button appears with red background
3. Tap "Urgent" button - verify fire emoji badge appears immediately
4. Swipe right on conversation row - verify "Resolved" button appears with green background
5. Tap "Resolved" button - verify checkmark badge appears, urgent removed
6. Verify haptic feedback on successful action
7. Test swipe actions don't interfere with row tap (opening chat)

**Files Changed:**
- `CreatorLink/Views/Chats/ChatsView.swift` - Add swipeActions to List row
- `CreatorLink/ViewModels/ConversationsViewModel.swift` - Add markAsUrgent and markAsResolved methods

**Notes:**
- Swipe actions are fastest way to triage - prioritize urgent/resolved as most common actions
- Keep action buttons compact - single emoji + short label
- Ensure swipe doesn't conflict with navigation tap gesture

---

### PR 4.3: Tag Editor Sheet - Core UI

**Goal:** Create modal sheet for editing all conversation tags with full control.

**Tasks:**
- [ ] Read `CreatorLink/Views/Chats/NewConversationView.swift` as reference for sheet structure
- [ ] Read `CreatorLink/Models/Conversation.swift` to understand tag fields
- [ ] Read `CreatorLink/Models/ConversationTag.swift` and `CreatorLink/Models/StatusTag.swift` for enum cases
- [ ] Create NEW: `CreatorLink/Views/Chats/Components/TagEditorSheet.swift`:
  - NavigationStack with "Edit Tags" title and Cancel/Save buttons
  - Section "CATEGORY" with list of ConversationTag options
  - Each tag shows emoji + name (e.g., "💼 Business")
  - Multi-select allowed (checkmarks for selected)
  - Section "STATUS" with list of StatusTag options
  - Each status shows emoji + name (e.g., "🔥 Urgent")
  - Single-select for status (radio buttons, optional - can clear)
  - Section "AI SUGGESTION" showing current AI confidence if available
  - Display "AI suggested: Business (85% confidence)" if aiConfidence exists
  - Toggle "Don't auto-tag this conversation" (sets userOverrideTags)
  - Save button calls completion handler with selected tags
  - Cancel button dismisses without saving
- [ ] Create NEW: `CreatorLink/ViewModels/TagEditorViewModel.swift`:
  - @Observable class managing tag selection state
  - selectedCategories: Set<ConversationTag>
  - selectedStatus: StatusTag?
  - userOverride: Bool
  - init with existing Conversation tags
  - saveTags() method calling ConversationService.updateTags

**What to Test:**
1. Build project - verify no compilation errors
2. Preview TagEditorSheet in Xcode canvas - verify sections display correctly
3. Test multi-select categories - verify multiple checkmarks
4. Test single-select status - verify only one can be selected
5. Test toggle "Don't auto-tag" - verify state changes
6. Test Cancel button - verify dismisses without saving
7. Test Save button - verify sheet dismisses (completion handler called)

**Files Changed:**
- NEW: `CreatorLink/Views/Chats/Components/TagEditorSheet.swift` - Full tag editing modal
- NEW: `CreatorLink/ViewModels/TagEditorViewModel.swift` - Tag editor state management

**Notes:**
- Similar pattern to Settings sheets in iOS apps
- Show AI confidence to build trust in auto-tagging
- "Don't auto-tag" toggle gives users full control

---

### PR 4.4: Integrate Tag Editor into ChatDetailView

**Goal:** Add tag editor button to ChatDetailView header and wire up sheet presentation.

**Tasks:**
- [ ] Read `CreatorLink/Views/Chats/ChatDetailView.swift` to understand toolbar structure (line 106)
- [ ] Read `CreatorLink/Views/Chats/Components/TagEditorSheet.swift` (just created in PR 4.3)
- [ ] Update `CreatorLink/Views/Chats/ChatDetailView.swift`:
  - Add @State var showTagEditor = false
  - Add ToolbarItem(placement: .navigationBarTrailing) with tag button
  - Button shows emoji "🏷️" (tag emoji)
  - Tapping button sets showTagEditor = true
  - Add .sheet(isPresented: $showTagEditor) presenting TagEditorSheet
  - Pass current conversation to TagEditorSheet
  - On save, update conversation tags via ConversationService
  - Show small tag badges below chat header (below participant count/status)
  - Display current category + status tags (emoji only, same as ConversationRowView)
- [ ] Update `CreatorLink/Views/Chats/Components/TagEditorSheet.swift`:
  - Accept Conversation binding
  - Accept completion handler: (Set<ConversationTag>, StatusTag?, Bool) -> Void
  - Call completion with selected tags on Save
  - Dismiss sheet automatically after completion

**What to Test:**
1. Build project - verify no compilation errors
2. Open ChatDetailView - verify tag button (🏷️) appears in navigation bar
3. Tap tag button - verify TagEditorSheet slides up
4. Select Business category + Urgent status - tap Save
5. Verify sheet dismisses and badges appear below chat header
6. Open tag editor again - verify previously selected tags are checked
7. Test Cancel button - verify no changes applied
8. Verify tags sync across ChatsView and ChatDetailView (real-time listener)

**Files Changed:**
- `CreatorLink/Views/Chats/ChatDetailView.swift` - Add tag editor button and sheet presentation
- `CreatorLink/Views/Chats/Components/TagEditorSheet.swift` - Wire up completion handler

**Notes:**
- Tag button placement in trailing position (right side) follows iOS patterns
- Show tags below header so they're always visible while chatting
- Real-time listener ensures tags update immediately across views

---

### PR 4.5: Tag Override Indicator & AI Suggestion Display

**Goal:** Show visual indicator when tags are user-set vs AI-suggested, with option to accept AI suggestions.

**Tasks:**
- [ ] Read `CreatorLink/Views/Chats/Components/ConversationTagsView.swift` to understand badge layout
- [ ] Read `CreatorLink/Models/Conversation.swift` to see userOverrideTags and aiConfidence fields
- [ ] Update `CreatorLink/Views/Chats/Components/ConversationTagsView.swift`:
  - Add small "AI" badge next to tags if userOverrideTags is false and aiConfidence exists
  - "AI" badge: 12x12 circle, purple background, white text, 8pt font
  - Position badge as overlay on first tag (top-right corner)
  - Add "USER" badge if userOverrideTags is true
  - "USER" badge: similar style but blue background
- [ ] Update `CreatorLink/Views/Chats/Components/TagEditorSheet.swift`:
  - In "AI SUGGESTION" section, add button "Accept AI Suggestion"
  - Button only visible if aiConfidence exists and differs from current selection
  - Tapping button auto-selects AI-suggested tags
  - Clear userOverrideTags flag when accepting (let AI continue auto-tagging)
  - Show confidence score as percentage (e.g., "85% confident")
  - Add info text: "AI analyzes message content to suggest relevant tags"
- [ ] Create NEW: `CreatorLink/Views/Chats/Components/AITagIndicatorView.swift`:
  - Small info popover explaining AI vs manual tags
  - Shows when user taps "?" icon next to AI badge
  - Text: "AI automatically tags conversations based on message content. You can override tags at any time."
  - Use .popover or .alert modifier

**What to Test:**
1. Build project - verify no compilation errors
2. View conversation with AI-suggested tags - verify "AI" badge appears
3. Manually edit tags - verify "USER" badge appears instead
4. Open tag editor on AI-tagged conversation - verify "Accept AI Suggestion" button shows
5. Tap "Accept AI Suggestion" - verify tags update to AI suggestion
6. Verify confidence score displays as percentage
7. Tap "?" icon - verify info popover explains AI tagging

**Files Changed:**
- `CreatorLink/Views/Chats/Components/ConversationTagsView.swift` - Add AI/USER badges
- `CreatorLink/Views/Chats/Components/TagEditorSheet.swift` - Add AI suggestion section with accept button
- NEW: `CreatorLink/Views/Chats/Components/AITagIndicatorView.swift` - Info popover for AI tagging

**Notes:**
- Transparency builds trust - users should know when AI is tagging
- Easy to revert to AI suggestions if user changes mind
- Confidence score shows AI uncertainty (helps users decide whether to override)

---

### PR 4.6: Tag Editing Polish & Accessibility

**Goal:** Add loading states, error handling, accessibility labels, and UI polish for tag editing features.

**Tasks:**
- [ ] Read `CreatorLink/Views/Chats/Components/TagEditorSheet.swift` to understand save flow
- [ ] Read `CreatorLink/ViewModels/TagEditorViewModel.swift` to add loading state
- [ ] Update `CreatorLink/ViewModels/TagEditorViewModel.swift`:
  - Add @Published var isLoading = false
  - Add @Published var errorMessage: String?
  - Wrap saveTags() with isLoading state management
  - Catch errors and set errorMessage
- [ ] Update `CreatorLink/Views/Chats/Components/TagEditorSheet.swift`:
  - Disable Save button while isLoading
  - Show ProgressView overlay when isLoading (similar to GroupInfoView line 63)
  - Add .alert for errorMessage display
  - Add .accessibilityLabel to all interactive elements
  - Category buttons: "Tag as Business", "Tag as Collaboration", etc.
  - Status buttons: "Mark as Urgent", "Mark as Needs Response", etc.
  - Save button: "Save tag changes"
- [ ] Update `CreatorLink/Views/Chats/Components/FilterChipView.swift`:
  - Add .accessibilityLabel: "Filter by [category/status]"
  - Add .accessibilityHint: "Shows only [category/status] conversations"
  - Add .accessibilityValue: "[count] conversations" if count > 0
- [ ] Update `CreatorLink/Views/Chats/ConversationRowView.swift`:
  - Add .accessibilityLabel to context menu items
  - Add .accessibilityHint explaining what each action does
  - Ensure badges have proper accessibility labels (read as "Business category", "Urgent status")

**What to Test:**
1. Build project - verify no compilation errors
2. Open tag editor, tap Save - verify ProgressView shows during save
3. Test network error (airplane mode) - verify error alert appears
4. Enable VoiceOver - verify all buttons have descriptive labels
5. Navigate with VoiceOver - verify logical tab order
6. Test VoiceOver on filter chips - verify counts are announced
7. Test VoiceOver on context menu - verify actions are clear
8. Verify Save button is disabled during loading (can't double-tap)

**Files Changed:**
- `CreatorLink/ViewModels/TagEditorViewModel.swift` - Add loading and error state
- `CreatorLink/Views/Chats/Components/TagEditorSheet.swift` - Add loading overlay, error alert, accessibility labels
- `CreatorLink/Views/Chats/Components/FilterChipView.swift` - Add accessibility labels and hints
- `CreatorLink/Views/Chats/ConversationRowView.swift` - Add accessibility to context menu and badges

**Notes:**
- Loading states prevent duplicate saves (common issue with sheets)
- Accessibility is not optional - VoiceOver users need proper labels
- Test with VoiceOver enabled to catch missing labels
- Follow iOS HIG for accessibility best practices

---

## Completion Checklist

After finishing all PRs in Phases 3-4, verify:

- [ ] Tag badges display correctly in ConversationRowView (max 2-3, emoji only)
- [ ] Filter bar shows all categories and statuses with correct emojis
- [ ] Urgent count badge updates in real-time on filter chip
- [ ] Urgent conversations have subtle red tint + left border
- [ ] Long-press context menu opens on conversation row with quick actions
- [ ] Swipe actions (urgent/resolved) work smoothly without interfering with tap
- [ ] Tag editor sheet opens from ChatDetailView header button
- [ ] Tag editor shows current tags with checkmarks
- [ ] AI suggestion section displays confidence score
- [ ] "Accept AI Suggestion" button works correctly
- [ ] AI/USER badges display on conversation tags
- [ ] All tag changes set userOverrideTags flag
- [ ] Loading states prevent duplicate saves
- [ ] Error alerts display for network failures
- [ ] VoiceOver announces all interactive elements correctly
- [ ] No compilation errors or warnings
- [ ] No performance issues when filtering 100+ conversations

**Next Steps:**
After completing Phases 3-4, the UI foundation is complete. Phase 5 will implement the AI auto-tagging backend (Firebase Functions analyzing message content), and Phase 6 will add advanced filtering and AI insights panel.
