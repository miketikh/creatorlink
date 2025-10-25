# AI Voice/Auto-Response Feature

## Overview

The AI Voice feature enables CreatorLink to generate personalized draft responses using each user's communication style and knowledge base. When enabled, the AI analyzes user messages to extract factual information (pricing, availability, preferences) and uses manually-configured voice profiles per conversation category (business, social, collaboration) to generate authentic, contextually-relevant draft responses that sound like the user.

**Core Value:** Saves creators time by automating routine responses while maintaining their authentic voice and ensuring accurate information based on what they've previously shared.

**Note:** Initial implementation uses static voice profiles. Dynamic profile learning from messages can be added in future phases.

## User Goals

**Primary Problem:** Creators spend significant time responding to similar questions repeatedly, but can't use generic templates because they need to maintain their authentic voice and provide personalized context.

**User Needs:**
- Quickly respond to common questions without typing the same information repeatedly
- Maintain authentic communication style that varies by context (business vs social)
- Ensure consistent, accurate information in responses (rates, availability, policies)
- Review and edit AI suggestions before sending (not auto-send)
- Have drafts automatically update as new messages arrive in the conversation

## Key Features

### 1. Knowledge Extraction
- Automatically extracts factual information from user messages as they're sent
- Identifies key facts: pricing, availability, preferences, constraints, policies
- Stores facts in a vector knowledge base for semantic retrieval
- Only adds new information to avoid duplication
- Associates knowledge with conversation categories (business, social, collaboration)

**Example:** User says "I charge $500/hour for consulting, but $750 for weekend work"
- Extracts two facts with context and stores in vector DB
- Future questions about rates retrieve these facts

### 2. Voice Profile Configuration
- Static, manually-authored communication style profiles per conversation category
- Profiles define structural patterns: message length, sentence count, paragraph style
- Profiles specify language patterns: formality, contractions, slang, technical terms
- Profiles set punctuation habits: capitalization, exclamation usage, emoji frequency
- Profiles include common greetings, closings, and transition phrases
- Stored as JSON documents in Firestore at `users/{userId}/voiceProfiles/{category}`
- For emulator: Created via seed scripts
- For production: Created manually or via future admin UI
- Dynamic profile learning can be added in future phases

**Example Profile Elements:**
- Business: Formal, 2-3 sentences, no emojis, "Best regards" closing
- Social: Casual, 1-2 sentences, frequent emojis, "talk soon" closing

### 3. AI Draft Response Generation
- Creates draft responses only when AI response mode is enabled
- Requires sufficient information: valid style profile AND relevant knowledge
- Combines retrieved knowledge with configured voice/style for the category
- Generates drafts automatically when user receives messages
- Updates drafts as new messages arrive in the conversation
- Drafts are clearly marked as AI-generated (vs user-created drafts)

### 4. Draft Management
- Drafts stored per conversation (not just in-memory)
- UI shows "AI DRAFT: [preview]" in conversation list
- Opening conversation loads draft into message input
- User can edit, use as-is, or discard
- Drafts update intelligently as sender adds more messages

## User Experience

### Enabling AI Response Mode
- **Location:** User profile settings (one-time toggle)
- **States:** On/Off per user (not per conversation)
- **Default:** Off (opt-in feature)
- **Behavior:** When enabled, AI generates drafts for any conversation where it has sufficient data

### Draft Appearance in UI

**Conversation List:**
- Show "AI DRAFT: [first 50 chars]" as preview
- Visual indicator differentiates AI drafts from user drafts
- Draft timestamp shows when generated/updated

**Chat View:**
- Draft automatically loads into message input when conversation opens
- Clear visual indicator that it's an AI-suggested draft
- User can edit freely before sending
- Option to dismiss/regenerate draft

### Draft Updates
- As sender sends additional messages, AI re-evaluates and updates draft
- Updates happen automatically in background
- User sees updated draft next time they open conversation
- If user has already edited draft, preserve their edits vs regenerate (TBD)

### Cold Start Experience
- New users need voice profiles configured before AI can generate drafts
- AI only starts generating drafts after:
  - Voice profile exists for the conversation category
  - Relevant knowledge available for the question
- Without profile, feature remains inactive (no drafts)
- In emulator: Profiles seeded automatically for testing
- In production: Profiles created manually or via admin tools

## Technical Architecture

### Data Models

**1. User Voice Profile** (`users/{userId}/voiceProfiles/{category}`)
- Stored in Firestore as manually-authored JSON document per category
- Structure includes:
  - Structural patterns (avgMessageLength, sentencesPerMessage, paragraphStyle)
  - Language patterns (formality, contractionFreq, commonPhrases)
  - Mechanics (capitalization, punctuationStyle, emojiFrequency)
  - Common patterns (greetings, closings, responseStarters)
  - Metadata (created, lastUpdated)
- Static profiles created via seed scripts (emulator) or manual configuration (production)
- Dynamic learning can be added in future phases

**2. Knowledge Base** (Vector Store)
- Each fact stored with embedding + metadata
- Metadata includes:
  - userId, category, factType (pricing/availability/preference)
  - Original text, source message, confidence
  - Time-sensitive flag and expiration (if applicable)
- Semantic search retrieves relevant facts for incoming questions

**3. Conversation Draft** (`conversations/{conversationId}/drafts/{userId}`)
- Stored in Firestore subcollection
- Fields:
  - text, generatedAt, updatedAt, category
  - sourceMessageIds (messages that triggered this draft)
  - confidence, knowledgeUsed (for debugging/transparency)

### Core Workflows

**Knowledge Extraction Workflow:**
1. User sends message → Cloud Function intercepts
2. LLM analyzes: "Does this message contain factual info about the user?"
3. If yes → extract facts with context
4. Generate embeddings for each fact
5. Store in vector DB with metadata

**Draft Generation Workflow:**
1. User receives new message → check if AI mode enabled
2. Check prerequisites:
   - Does user have voice profile configured for this category?
   - Is message a question or request?
3. Query vector DB for relevant knowledge
4. If insufficient knowledge → skip draft generation
5. Build LLM prompt with:
   - Style instructions from configured profile
   - Retrieved knowledge facts
   - Recent conversation context (last 10 messages)
6. Generate draft response
7. Save to Firestore drafts subcollection
8. UI updates automatically via Firestore listener

**Draft Update Workflow:**
1. Sender sends additional message(s)
2. Cloud Function checks if recipient has existing draft for conversation
3. Re-run draft generation with updated context
4. Update draft in Firestore
5. UI reflects new draft automatically

### Firebase Functions Architecture

**New Functions Required:**
- `onMessageCreated_extractKnowledge` - Extract facts from user messages
- `onMessageCreated_generateDraft` - Generate draft for recipient if AI mode enabled
- `onMessageCreated_updateExistingDrafts` - Update drafts when new messages arrive

**Integration Points:**
- Extend existing `ai/` directory structure
- Add `ai/lib/knowledge-extractor.ts`
- Add `ai/lib/draft-generator.ts`
- Add `ai/lib/voice-profile-loader.ts` - Load static profiles
- Update `ai/types.ts` with new interfaces

### iOS App Integration

**New Models:**
- `VoiceProfile.swift` - User's communication style profile
- `MessageDraft.swift` - Draft message model
- `KnowledgeFact.swift` - For potential local caching (optional)

**Service Updates:**
- `MessageService.swift` - Add draft management methods
- `UserService.swift` - Add voice profile fetching
- New `AIVoiceService.swift` - Centralize AI voice feature logic

**ViewModel Updates:**
- `ChatViewModel.swift` - Load/display drafts, handle draft editing
- `ConversationsViewModel.swift` - Show draft previews in list
- New `AIVoiceSettingsViewModel.swift` - Manage AI mode settings

**UI Components:**
- Settings toggle for AI response mode
- Draft indicator in conversation list
- Draft preview/editor in chat input
- Learning progress indicator for new users

## Implementation Phases

### Phase 1: Foundation - Knowledge Extraction
**Goal:** Build knowledge extraction pipeline
- Create vector database infrastructure (research Firestore vector capabilities)
- Implement knowledge extraction Cloud Function
- Design and test LLM prompts for fact extraction
- Set up embedding generation (OpenAI embeddings)
- Create Firestore schema for knowledge storage (if not using vectors)
- Test with sample conversations

**Key Decisions:**
- Vector DB solution (Firestore Extensions, Pinecone, or custom)
- Fact extraction prompt engineering
- Deduplication strategy

### Phase 2: Voice Profile Configuration
**Goal:** Set up static voice profile infrastructure
- Design voice profile schema (based on brainstorm)
- Create Firestore collection structure: `users/{userId}/voiceProfiles/{category}`
- Implement profile loader in Cloud Functions
- Create seed script to generate sample profiles for emulator testing
- Document profile JSON structure and configuration options
- Add validation for profile structure

**Key Decisions:**
- Profile JSON schema and required fields
- Category taxonomy (business, social, collaboration, other?)
- Future admin UI requirements for profile creation

**Note:** Dynamic profile learning can be added in future phases

### Phase 3: Draft Generation
**Goal:** Generate AI draft responses
- Implement draft generation Cloud Function
- Build LLM prompts combining style + knowledge + context
- Create draft storage schema in Firestore
- Implement vector search for knowledge retrieval
- Add draft update logic for incoming messages
- Test draft quality with various scenarios

**Key Decisions:**
- When to regenerate vs update existing drafts
- How to handle user edits to drafts
- Draft expiration/cleanup strategy

### Phase 4: iOS UI Integration
**Goal:** User-facing features
- Add AI response mode toggle in settings
- Implement draft display in conversation list
- Create draft preview/editor in chat view
- Add visual indicators (AI DRAFT badge)
- Implement draft loading into message input
- Add learning progress indicator

**Key Decisions:**
- Draft edit behavior (preserve edits vs regenerate)
- UI/UX for draft acceptance/dismissal
- Onboarding flow for new feature

### Phase 5: Refinement & Optimization
**Goal:** Polish and optimize
- Add learning from user edits (what they change)
- Implement confidence scoring improvements
- Add conflict detection for contradictory knowledge
- Performance optimization (caching, rate limiting)
- A/B testing different prompts
- User feedback collection

## Open Questions & Technical Decisions

### 1. AI Architecture Evolution
**Question:** Should we move to LangChain or an orchestrator AI pattern?

**Context:** Current AI implementation uses if/else chains in Cloud Functions. Adding voice features will increase complexity significantly.

**Options:**
- Continue with current approach (simpler, more control)
- Adopt LangChain (better abstractions, more overhead)
- Create custom orchestrator AI that routes requests

**Recommendation:** Defer to Phase 5, but document current pain points. If we add 3+ more AI features, revisit.

### 2. Vector Database Choice
**Question:** Does Firestore have vector capabilities? What should we use?

**Context:** Need semantic search for knowledge retrieval. Firestore (as of 2025) has vector search extensions.

**Options:**
- Firestore Vector Search Extension (native, simpler)
- External service (Pinecone, Weaviate - more features, added cost)
- Hybrid: Firestore + embeddings, manual similarity

**Recommendation:** Research Firestore Vector Search Extension first. If insufficient, use Pinecone for MVP (proven, easy integration).

### 3. Draft Edit Handling
**Question:** When user edits a draft and more messages arrive, regenerate or preserve edits?

**Options:**
- Always regenerate (simpler, may frustrate users)
- Preserve user edits (complex tracking)
- Ask user preference (adds friction)
- Track "touched" state and skip regeneration if edited

**Recommendation:** Phase 3 - start with "touched" flag. If draft edited, don't auto-regenerate. User can manually regenerate.

### 4. Knowledge Conflicts
**Question:** How to handle contradictory information? ("Rate is $500" then "$600")

**Options:**
- Always use most recent
- Flag conflicts and ask user
- Time-weight facts with decay
- Show user knowledge base for review/editing

**Recommendation:** Phase 5. Initially, timestamp facts and use most recent. Add conflict detection later.

### 5. Privacy & Security
**Question:** How to handle sensitive information extraction?

**Concerns:**
- Extracting personal info unintentionally
- Knowledge base accessible to others
- Draft content visible in database

**Recommendation:**
- Security rules: Knowledge and profiles only readable by owner
- Add sensitive info filtering in extraction
- Consider opt-out for specific conversations
- Document in privacy policy

## Success Metrics

### Feature Adoption
- Percentage of users who enable AI response mode
- Percentage of conversations with drafts generated
- Average time to first draft (after feature enable)

### Draft Quality
- Draft acceptance rate (% sent without editing)
- Draft dismissal rate (% completely discarded)
- Average edit count before sending
- User satisfaction surveys
- Draft relevance (manual review samples)

### Time Savings
- Average response time comparison (with/without feature)
- Number of drafts used per day per active user
- Estimated time saved per user (based on typing time)

### Technical Performance
- Draft generation latency
- Knowledge extraction accuracy (manual review samples)
- Profile configuration completeness (% of users with profiles)
- API cost per draft generated
- Knowledge base growth rate

## Success Criteria

**MVP Success (Phase 4 Complete):**
- 20% of active users enable AI response mode
- 60% draft acceptance rate (with or without edits)
- <3 second draft generation time
- Voice profiles configured for all test users
- Zero data leakage incidents (security working)

**Feature Maturity (Phase 5 Complete):**
- 40% of active users enabled
- 70% draft acceptance rate
- User feedback >4.0/5.0 rating
- <$0.10 per draft cost (API + infrastructure)
- Knowledge base scales to 1000+ facts per active user

## Risks & Mitigations

**Risk: AI generates inappropriate responses**
- Mitigation: Drafts require user review, implement content filtering, start with opt-in

**Risk: Knowledge extraction misses context**
- Mitigation: Show knowledge sources to user, allow editing knowledge base

**Risk: Style profile doesn't match user**
- Mitigation: Manual profile configuration, profile editing tools, future dynamic learning

**Risk: High API costs**
- Mitigation: Rate limiting, caching, batch processing, cost monitoring

**Risk: User reliance reduces authentic communication**
- Mitigation: Vary suggestions, prompt for personalization, educate on use cases

## Future Enhancements (Post-MVP)

- Dynamic voice profile learning from user messages (replace static profiles)
- Learning from user edits (reinforcement learning)
- Multi-language support for knowledge and style
- Voice note transcription and style learning
- Knowledge base UI for review/editing
- Contextual draft variations (formal vs casual on-demand)
- Integration with calendar for availability facts
- Shared knowledge bases for team accounts
- Style transfer between categories
- Admin UI for voice profile creation/editing

## Related Documents

- `ai_voice_brainstorm.md` - Original feature discussion and technical exploration
- `../../project_architecture.mermaid` - Overall system architecture
- `../../project_prd.md` - Main project requirements
- `/CLAUDE.md` - Project patterns and conventions
- `/db-types.md` - Database schema reference

---

**Document Status:** Draft for Discussion
**Last Updated:** 2025-10-25
**Owner:** Product/Engineering
**Next Steps:** Review open questions, approve Phase 1 scope, research vector DB options
