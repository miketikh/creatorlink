# Smart Message Categorization & Filtering

## Overview
Transform the WhatsApp-style conversation list into an intelligent messaging hub that automatically categorizes conversations (Business, Collaboration, Social, Fan) and tracks message status (Urgent, Needs Response, Awaiting Reply, Resolved). Users can filter conversations by category and status, with AI-powered auto-tagging learning from message content and user corrections.

## Current State Analysis

**Files Affected:**
- `/CreatorLink/Models/Conversation.swift` - Add category/status tags, AI metadata
- `/CreatorLink/Models/Message.swift` - Already has metadata field (leverage for AI analysis)
- `/CreatorLink/Views/Chats/ChatsView.swift` - Add filter bar UI above conversation list
- `/CreatorLink/Views/Chats/ConversationRowView.swift` - Add visual badges/indicators
- `/CreatorLink/Views/Chats/ChatDetailView.swift` - Add tag editing UI, AI insights panel
- `/CreatorLink/ViewModels/ConversationsViewModel.swift` - Add filtering logic, tag management
- `/CreatorLink/Services/ConversationService.swift` - Add tag CRUD operations
- `/firebase/functions/src/index.ts` - Extend onMessageCreated to analyze for categorization

**Existing Patterns to Leverage:**
- **AI Integration**: App already has OpenAI integration via Firebase Cloud Functions (FAQ detection, question analysis)
- **Real-time Listeners**: ConversationRowView uses real-time Firestore listeners - tags will update automatically
- **Metadata Pattern**: Message model already has metadata field for AI features - use same pattern for tag confidence
- **Service Layer**: ConversationService follows established Firebase patterns for atomic operations
- **Denormalized Optimization**: App uses denormalized unreadCounts in Conversation model - apply same pattern for tag filtering efficiency
- **Swipe Actions**: iOS 15+ swipe actions already used in similar contexts - familiar pattern for users
- **Filter UI Pattern**: Can reference NewConversationView and NewGroupConversationView for modal/sheet patterns

**Dependencies & Conflicts:**
- **AI Service Integration**: Requires OpenAI API calls - already configured in Firebase Functions
- **Conversation Model Changes**: Must maintain backward compatibility for existing conversations (make new fields optional)
- **Firestore Security Rules**: Need to allow users to update own tags but not others' tags in same conversation
- **Real-time Listener Performance**: Adding filters may impact query performance - use indexed queries and denormalized primary category
- **Multi-tag Display**: ConversationRowView already dense with info (avatar, name, message, timestamp, unread badge) - must avoid UI clutter
- **Group Chat Considerations**: Group chats have multiple participants - tag changes should be per-user preference, not global

## Implementation Approach

**Phase 1: Data Model & Schema**
- Add category tag array to Conversation model (conversation-level)
- Create UserTagData struct containing both category and status tags (per-user)
- Add AI confidence scores and user override flags
- Create ConversationTag enum (Business, Collaboration, Social, Fan)
- Create StatusTag enum (Urgent, NeedsResponse, AwaitingReply, Resolved)
- Update Firestore schema with new optional fields (backward compatible)
- Add primaryCategory denormalized field for efficient filtering
- Add tagsByUser map (userId → UserTagData) for per-user tag preferences
- **Key Change**: Status tags are per-user only (stored in tagsByUser), not conversation-level
- Create FirestoreService migration helper to backfill existing conversations with default tags

**Phase 2: Core Tag Management**
- Extend ConversationService with tag CRUD methods (updateTags, markAsUrgent, markAsResolved)
- Add filtering logic to ConversationsViewModel (filterByCategory, filterByStatus)
- Implement multi-select filter with OR logic
- Add computed properties for filtered conversation lists
- Handle tag persistence with atomic Firestore operations
- Add user preference storage for last-used filters

**Phase 3: Basic UI Components**
- Create TagBadgeView component (emoji + optional text)
- Add visual badges to ConversationRowView (max 2-3 badges, left side)
- Implement FilterBarView component with tap-to-filter emoji buttons
- Add urgent count indicator (red badge on fire emoji)
- Style urgent conversations (subtle red tint or border)
- Add tag legends/tooltips for first-time users

**Phase 4: Tag Editing & Manual Override**
- Create TagEditorSheet view (modal for editing conversation tags)
- Add long-press menu to ConversationRowView with quick tag actions
- Implement swipe actions (right: mark urgent, left: mark resolved)
- Add tag editor button in ChatDetailView header
- Set userOverrideTags flag when user manually changes tags
- Display "AI suggested" vs "Manually set" indicator

**Phase 5: AI Auto-Tagging (Firebase Functions)**
- Extend onMessageCreated function in Firebase to analyze message content
- Add categorization logic using OpenAI GPT-4 (similar to existing FAQ detection)
- Detect urgency keywords (ASAP, urgent, deadline, EOD, tonight, etc.)
- Identify business terms (brand deal, sponsorship, contract, payment, collaboration)
- Track conversation state (question without answer = Needs Response)
- Calculate confidence scores for tag suggestions
- Write tag updates to Firestore only if confidence > 0.75
- Respect userOverrideTags flag (don't auto-update if user has manually set)

**Phase 6: Advanced Filtering & AI Insights**
- Create AdvancedFilterSheet with sort options (Most Recent, Urgency, Unread First)
- Add multi-category selection with visual chips
- Implement "Show/Hide Resolved" toggle
- Add AI insights panel in ChatDetailView (detected deadlines, suggested responses)
- Create AIInsightsView component (expandable panel below chat header)
- Display confidence scores and reasoning for auto-tags
- Add "Why this tag?" explanation button

**Key Technical Decisions:**
- **Per-User Tags**: Tags are user-specific preferences stored in Conversation.tagsByUser map (not global) - allows different users in group chat to categorize differently
- **Per-User Status Tags**: Status tags (Urgent, Needs Response, etc.) are ALWAYS per-user, stored in UserTagData within tagsByUser - this allows User A to see "Awaiting Reply" while User B sees "Needs Response" for the same conversation
- **Category Tags**: Can exist at both conversation-level (shared) and per-user (override) - user's per-user tags take precedence in UI
- **Denormalized Primary Category**: Store single primaryCategory field for efficient Firestore queries (allows .whereField filtering)
- **AI Model Choice**: Use GPT-4-turbo for categorization (better reasoning than 3.5, same as FAQ detection) - analyze last 5-10 messages for context
- **Tag Update Strategy**: AI updates tags on every new message in conversation, but backs off if userOverrideTags = true
- **Filter Persistence**: Store user's last filter selection in UserDefaults, restore on app launch
- **Urgent Floating**: Urgent conversations do NOT auto-float to top (respect chronological order), but have visual prominence

**User Flow:**
1. User opens ChatsView - sees familiar conversation list with subtle emoji badges
2. Taps Business emoji in filter bar - list filters to show only business conversations
3. Receives new message from brand - AI detects keywords ("sponsorship opportunity") and auto-tags as Business + Urgent
4. Urgent badge count increments, conversation shows fire emoji
5. User taps conversation - sees AI insights panel: "Detected urgency: mentions 'respond by Friday'"
6. User long-presses conversation - quick menu to mark as resolved or change category
7. User manually changes tag - AI respects override and no longer auto-updates this conversation's tags

## Considerations

**Edge Cases:**
- **Existing Conversations**: Conversations created before feature launch have no tags - backfill with "Social" default or run one-time AI analysis
- **AI Confidence Threshold**: Low confidence tags (<0.75) should not be applied automatically - perhaps show as suggestions in UI
- **Tag Conflicts**: User manually sets "Social" but AI detects "Business" - user override always wins, but show subtle suggestion indicator
- **Group Chats**: Multiple participants may have different categorizations - tags must be stored per-user, not globally
- **Status Tag Perspective**: Same conversation can have different status tags per user (e.g., User A sent last message → sees "Awaiting Reply", User B received it → sees "Needs Response")
- **Deleted Messages**: If urgent message is deleted, should conversation lose Urgent tag? Need message-level tracking
- **Offline Tagging**: User changes tags while offline - must queue Firestore updates and handle conflicts on sync
- **Performance**: Filtering with tags adds Firestore query complexity - use composite indexes and limit to primaryCategory only
- **Multilingual**: AI must detect urgency/categories in multiple languages - GPT-4 handles this naturally

**Technical Challenges:**
- **Firestore Query Limitations**: Cannot filter on arrays efficiently - hence denormalized primaryCategory field for queries
- **Real-time Tag Updates**: When AI updates tags, all ConversationRowView listeners must refresh - leverage existing listener pattern
- **AI Cost Management**: Each new message triggers OpenAI API call - implement rate limiting and caching (e.g., don't re-analyze if last analysis was <5 minutes ago)
- **Tag Learning**: "AI learns from user corrections" requires ML feedback loop - Phase 1 can store corrections in Firestore, Phase 2 could fine-tune model or use retrieval-augmented generation
- **Context Window**: Analyzing entire conversation history expensive - limit to last 10 messages or use sliding window
- **Race Conditions**: User manually tags while AI auto-tags - use Firestore transactions or last-write-wins with timestamp comparison

**Testing Strategy:**
- **Unit Tests**: ConversationService tag methods, ViewModel filtering logic
- **Integration Tests**: Firebase Functions AI categorization with mock OpenAI responses
- **UI Tests**: Filter bar interaction, tag editing sheet, badge display
- **Manual Testing Scenarios**:
  - Send message with "brand deal" - verify Business tag applied
  - Send message with "urgent" - verify Urgent status and red indicator
  - Manually change tag - verify AI respects override
  - Filter by multiple categories - verify OR logic
  - Test with 100+ conversations - verify performance
  - Test group chat - verify per-user tags don't interfere
- **A/B Testing**: Track tag accuracy rate, manual override frequency, filter usage rate

**Performance/Security:**
- **Firestore Indexes**: Create composite indexes for primaryCategory + lastMessageTime queries
- **Security Rules**: Users can only update tags in conversations they participate in - add validation:
  ```javascript
  allow update: if request.auth.uid in resource.data.participantIds
    && request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['tagsByUser', 'primaryCategory', 'lastTagUpdate']);
  ```
- **AI Rate Limiting**: Limit OpenAI calls to 1 per conversation per 5 minutes - cache recent analysis
- **Lazy Loading**: Don't load AI insights until user expands panel - reduce API calls
- **Tag Badge Rendering**: Use SF Symbols for category emojis (native rendering, no custom assets)
- **Filter Performance**: Filtering happens in-memory after Firestore fetch (conversations already loaded) - should be <50ms for 1000 conversations

**Open Questions (to resolve during implementation):**
1. **Urgent Priority**: Should urgent conversations float to top or respect chronological order? → Decided: Respect chronological, but add visual prominence
2. **Multi-Tag Primary**: If conversation is both Business AND Collaboration, which is primaryCategory? → Use AI confidence scores, highest wins
3. **Group Chat Tags**: Should group admins be able to set "canonical" tags for all members? → No, keep per-user for MVP
4. **Resolved Auto-Archive**: Should resolved conversations auto-archive after 7 days? → No for MVP, add in Phase 2
5. **Notification Strategy**: Should urgent conversations have different notification sounds? → Out of scope for MVP (notification customization is separate feature)

**Success Metrics:**
- Tag accuracy rate > 80% (measured by manual override rate)
- Filter feature adoption > 60% of users within first week
- Time to find specific conversation reduced by 40% (via analytics)
- User satisfaction score > 4.2/5 in post-feature survey
- AI cost per conversation < $0.002 (OpenAI GPT-4 turbo pricing)
- Zero performance regression in conversation list scroll (maintain 60fps)
