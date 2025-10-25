# AI Voice/Auto-Response Feature - Implementation Tasks (Phases 1-3)

## Context

The AI Voice/Auto-Response feature enables CreatorLink to learn each user's communication style and knowledge base to automatically generate personalized draft responses. The system extracts factual information (pricing, availability, preferences) from user messages and analyzes communication patterns (tone, length, emoji usage) per conversation category. This allows automatic generation of authentic, contextually-relevant draft responses that sound like the user while incorporating accurate information they've previously shared.

**Core Value Proposition:** Saves creators time by automating routine responses while maintaining their authentic voice and ensuring accurate information based on what they've previously shared.

**Key Technical Approach:**
- **Knowledge Extraction**: Uses vector database for semantic search of factual information
- **Voice Profiling**: Stores communication patterns as structured JSON in Firestore
- **Draft Generation**: Combines retrieved knowledge + voice profile + conversation context using LLM

This document covers **Phases 1-3 only** (knowledge extraction, voice profiling, and draft generation). Phases 4-5 (iOS UI integration and refinement) will be documented separately.

## Instructions for AI Agent

**Standard Workflow:**
1. **Read Phase** - Read all referenced files to understand current implementation
2. **Execute Tasks** - Implement tasks in order within each PR
3. **Mark Complete** - Update checkboxes with [x] as you complete tasks
4. **Test** - Run all tests specified in "What to Test" section
5. **Completion Summary** - Provide summary of changes and test results
6. **Wait for Approval** - Wait for human review before moving to next PR

**Important Notes:**
- Follow existing patterns in `firebase/functions/src/ai/` directory
- All TypeScript changes require rebuild: `cd firebase/functions && npm run build`
- Match data model field names between TypeScript and Swift exactly
- Use OpenAI client pattern from `ai/client.ts`
- Update `db-types.md` for any schema changes

---

## Phase 1: Knowledge Extraction Pipeline

**Estimated Time:** 3-5 days

This phase builds the foundation for capturing and storing factual information from user messages. We'll implement vector database integration, fact extraction logic, and knowledge storage mechanisms.

### PR 1.1: Vector Database Research & Setup ✅ COMPLETED

**Goal:** Research Firestore vector search capabilities and set up the chosen vector database solution for knowledge storage.

**Tasks:**
- [x] Read PRD section on Vector Database Choice (Open Question #3)
- [x] Research Firestore Vector Search capabilities (as of 2025):
  - Native vector search available in Firestore
  - Works in Firebase emulators (firebase-tools 13.10.0+)
  - Supports semantic search with COSINE, EUCLIDEAN, DOT_PRODUCT
- [x] Evaluate alternative: Pinecone integration
  - External service adds complexity and cost (~$70/month minimum)
  - Not needed for our scale
- [x] Make technical decision and document in `/Users/Gauntlet/gauntlet/CreatorLink/Docs/Features/ai-voice/vector_db_decision.md`:
  - **Decision: Use Firestore native vector search**
  - Chosen solution with justification
  - Setup requirements and dependencies
  - Cost estimates and scaling considerations
  - Integration approach with Firebase Functions
- [x] Test vector search in emulator
  - Created test script at `firebase/functions/src/test-vector-search.ts`
  - Verified storing vectors with `FieldValue.vector()`
  - Verified searching with `findNearest()`
  - Confirmed pre-filtering works with `.where()`

**What to Test:**
1. Document can be created with technical recommendation
2. If external service chosen, verify API connection works
3. Confirm cost and performance requirements align with PRD

**Files Changed:**
- NEW: `/Users/Gauntlet/gauntlet/CreatorLink/Docs/Features/ai-voice/vector_db_decision.md` - Technical decision document
- `firebase/functions/package.json` - Add vector DB dependency if needed
- NEW: `firebase/functions/src/ai/vector/client.ts` - Vector DB client initialization (if external service)

**Notes:**
- This is a research task - no code implementation yet
- Decision impacts all subsequent PRs
- Consider long-term scalability and cost

---

### PR 1.2: Knowledge Schema & Types

**Goal:** Define TypeScript types and Firestore schema for storing knowledge facts with embeddings (simplified, minimal schema).

**Tasks:**
- [x] Read existing `firebase/functions/src/ai/types.ts` to understand type patterns
- [x] Add new types to `firebase/functions/src/ai/types.ts`:
  - `KnowledgeFact` interface with fields:
    - id: string (Firestore document ID)
    - userId: string (owner of knowledge)
    - text: string (normalized, self-contained fact - e.g., "User has a dog named Max")
    - embedding: number[] (vector representation - 1536 dimensions from OpenAI)
    - createdAt: Date
    - updatedAt: Date
  - `KnowledgeExtractionResult` interface:
    - success: boolean
    - facts: KnowledgeFact[]
    - error?: string
- [x] Update `db-types.md` with new Firestore collection:
  - Collection: `knowledge` (path: `knowledge/{factId}`)
  - Document all fields and types
  - Add index needed for userId queries
  - Document security rules requirements
- [x] Export new types from `firebase/functions/src/ai/index.ts`

**What to Test:**
1. Build TypeScript - verify no compilation errors: `cd firebase/functions && npm run build`
2. Review types follow minimal schema approach
3. Verify field names follow Firebase/Firestore conventions

**Files Changed:**
- `firebase/functions/src/ai/types.ts` - Add KnowledgeFact types
- `firebase/functions/src/ai/index.ts` - Export new types
- `/Users/Gauntlet/gauntlet/CreatorLink/db-types.md` - Document knowledge collection schema

**Notes:**
- Minimal schema: userId, text, embedding, timestamps only
- No categories, factTypes, or confidence scores - the embedding handles semantic grouping
- Text field stores normalized, self-contained facts extracted by LLM (PR 1.3)
- Vector similarity (embedding) is used for deduplication (PR 1.5)

---

### PR 1.3: Fact Extraction LLM Function ✅ COMPLETED

**Goal:** Implement LLM-based fact extraction that creates normalized, self-contained facts from user messages using conversation context.

**Tasks:**
- [x] Read `firebase/functions/src/ai/lib/question-detector.ts` to understand LLM call patterns
- [x] Create NEW: `firebase/functions/src/ai/lib/knowledge-extractor.ts`:
  - Implement `extractKnowledge(messageText: string, recentMessages: Message[], senderId: string): Promise<KnowledgeExtractionResult>`
  - Takes **last 5 messages** as context (for multi-message facts like "Yes" → "Max" → "3 years old")
  - Use OpenAI GPT-4o-mini with JSON response format
  - System prompt should:
    - Extract factual information ABOUT the user (not about others)
    - **Normalize facts to be self-contained** - no pronouns, complete sentences
    - Example: "Yes, a dog" + context → "User has one dog"
    - Example: "Max" + context ("dog's name?") → "User's dog is named Max"
    - Example: "He's 3" + context → "User's dog Max is three years old"
    - Ignore questions, greetings, and general conversation
    - Return 0-N facts per message (most messages have 0 facts)
    - Each fact should make sense without reading the conversation
  - Temperature: 0.3 (consistent extraction)
  - Max tokens: 500 (allow multiple facts)
  - Include error handling pattern from existing AI functions
  - Add logging for debugging extraction quality
- [x] Export function from `firebase/functions/src/ai/index.ts`
- [x] Add unit test examples in code comments for:
  - Q: "Do you have pets?" A: "Yes, one dog" → "User has one dog"
  - Q: "What's his name?" A: "Max" → "User's dog is named Max"
  - "I charge $500/hour for consulting" → "User charges $500/hour for consulting"
  - "I'm vegan" → "User is vegan"
  - "How are you doing?" → No facts

**What to Test:**
1. Build project: `cd firebase/functions && npm run build`
2. Test multi-message extraction (answer split across messages)
3. Test single complete message extraction
4. Verify facts are self-contained (read without context)
5. Test that no facts are extracted from questions/greetings
6. Check logging output for debugging information

**Files Changed:**
- NEW: `firebase/functions/src/ai/lib/knowledge-extractor.ts` - Fact extraction logic
- `firebase/functions/src/ai/index.ts` - Export extractKnowledge function

**Notes:**
- **Critical: Facts must be normalized and self-contained** (key design principle)
- Pass last 5 messages as context to handle multi-message answers
- Keep prompt focused on facts ABOUT the user (not facts they mention about others)
- Consider rate limiting (follow patterns in rate-limiter.ts)

---

### PR 1.4: Vector Embedding Generation ✅ COMPLETED

**Goal:** Generate vector embeddings for extracted facts to enable semantic search.

**Tasks:**
- [x] Read vector DB decision from PR 1.1
- [x] Create NEW: `firebase/functions/src/ai/lib/embedding-generator.ts`:
  - Implement `generateEmbedding(text: string): Promise<number[]>`
  - Use OpenAI Embeddings API (text-embedding-3-small model - cost-effective)
  - Handle errors gracefully with retries
  - Add caching if same text appears multiple times (optional optimization)
  - Follow patterns from existing AI lib files
- [x] If using external vector DB (Pinecone):
  - Implement `storeEmbedding(factId: string, embedding: number[], metadata: object): Promise<string>`
  - Return external ID for reference in Firestore fact document
- [x] If using Firestore Vector Search:
  - Embedding stored directly in fact document
  - No separate storage function needed
- [x] Export functions from `firebase/functions/src/ai/index.ts`
- [x] Add cost tracking for embedding API calls using rate-limiter pattern

**What to Test:**
1. Build project: `cd firebase/functions && npm run build`
2. Test embedding generation with sample text
3. Verify embedding dimensions match expected size (1536 for text-embedding-3-small)
4. If external DB: Test storage and verify retrieval by ID
5. Confirm error handling works with API failures

**Files Changed:**
- NEW: `firebase/functions/src/ai/lib/embedding-generator.ts` - Embedding generation and storage
- `firebase/functions/src/ai/index.ts` - Export embedding functions
- `firebase/functions/package.json` - May need to update openai package if new features required

**Notes:**
- OpenAI text-embedding-3-small: ~$0.02 per 1M tokens (very cheap)
- Consider batch embedding if processing multiple facts
- Store raw embedding array or external ID based on PR 1.1 decision

---

### PR 1.5: Knowledge Storage Service ✅ COMPLETED

**Goal:** Implement service to save extracted knowledge facts with embeddings to Firestore, using vector similarity for deduplication.

**Tasks:**
- [x] Read `firebase/functions/src/ai/lib/response-writer.ts` to understand Firestore write patterns
- [x] Create NEW: `firebase/functions/src/ai/lib/knowledge-store.ts`:
  - Implement `storeKnowledgeFact(fact: Partial<KnowledgeFact>): Promise<string | null>`
  - Generate embedding for fact.text using embedding-generator
  - **Deduplication using vector similarity:**
    - Query existing facts for this userId
    - Calculate cosine similarity between new embedding and existing embeddings
    - If any existing fact has similarity > 0.95 → return null (skip, it's a duplicate)
    - Otherwise, proceed to store
  - Store in Firestore `knowledge` collection:
    - Use FieldValue.vector() for embedding field
    - Use FieldValue.serverTimestamp() for createdAt/updatedAt
  - Return document ID if stored, null if skipped as duplicate
- [x] Implement `getKnowledgeByUserId(userId: string, limit?: number): Promise<KnowledgeFact[]>`
  - Simple query: Firestore where userId == userId
  - Order by createdAt descending
  - Default limit: 100
- [x] Export functions from `firebase/functions/src/ai/index.ts`

**What to Test:**
1. Build project: `cd firebase/functions && npm run build`
2. Store test fact and verify it appears in Firestore with embedding
3. Store same fact again - verify it's skipped (similarity > 0.95)
4. Store slightly different fact - verify it's stored (similarity < 0.95)
5. Query facts by userId - verify retrieval works
6. Test vector search in emulator UI to see embeddings

**Files Changed:**
- NEW: `firebase/functions/src/ai/lib/knowledge-store.ts` - Knowledge storage and retrieval
- `firebase/functions/src/ai/index.ts` - Export storage functions

**Notes:**
- **Deduplication threshold: 0.95 similarity** (very high = almost identical)
- Use FieldValue.vector() for Firestore native vector storage
- Consider batch writes if storing multiple facts from one message
- Similarity calculation: use cosine similarity (dot product / (norm1 * norm2))

---

### PR 1.6: Knowledge Extraction Cloud Function ✅ COMPLETED

**Goal:** Create Cloud Function trigger that extracts knowledge from user messages automatically, passing recent message context.

**Tasks:**
- [x] Read `firebase/functions/src/index.ts` to understand function trigger patterns
- [x] Update `firebase/functions/src/index.ts`:
  - Import knowledge extraction functions
  - Add new function `onMessageCreated_extractKnowledge` within existing `onMessageCreated` trigger
  - Skip if message from AI user (AI_USER_ID)
  - Skip if message from "system"
  - Skip if message is a question (use existing question detection)
  - **Fetch last 5 messages from conversation** (for context):
    - Query messages collection for conversationId
    - Order by createdAt descending, limit 5
    - Reverse order so oldest is first
  - Call extractKnowledge() with messageText, recentMessages, senderId
  - For each extracted fact:
    - Call storeKnowledgeFact() with fact data
    - Log if stored or skipped (duplicate)
  - Add comprehensive logging for debugging
  - Use try/catch to prevent failures from breaking message creation
- [x] Add feature flag: `ENABLE_KNOWLEDGE_EXTRACTION` (default: true)
- [x] Follow error handling patterns from existing AI features

**What to Test:**
1. Rebuild functions: `cd firebase/functions && npm run build`
2. Start Firebase Emulator
3. Send test message with factual info: "My rate is $500/hour"
4. Verify fact extracted and stored in Firestore knowledge collection
5. Check function logs for debugging output
6. Test with message containing no facts - should skip gracefully
7. Test with AI message - should skip
8. Verify existing message flow still works (no breaking changes)

**Files Changed:**
- `firebase/functions/src/index.ts` - Add knowledge extraction to onMessageCreated trigger

**Notes:**
- This runs alongside existing FAQ detection - both can execute
- Knowledge extraction should not block message creation
- Add rate limiting if needed (similar to categorization)
- Consider message history threshold (e.g., start after 5 messages to reduce noise)

---

### PR 1.7: Knowledge Retrieval by Semantic Search ✅ COMPLETED

**Goal:** Implement semantic search to find relevant knowledge facts using Firestore vector search.

**Tasks:**
- [x] Read vector DB decision from PR 1.1 (using Firestore native vector search)
- [x] Create NEW: `firebase/functions/src/ai/lib/knowledge-retriever.ts`:
  - Implement `searchKnowledge(queryText: string, userId: string, topK?: number): Promise<KnowledgeFact[]>`
  - Generate embedding for query text using embedding-generator
  - Use Firestore vector search:
    - Query knowledge collection with .where('userId', '==', userId)
    - Use .findNearest() with:
      - vectorField: 'embedding'
      - queryVector: generated embedding
      - limit: topK (default: 5)
      - distanceMeasure: 'COSINE'
  - Return results sorted by relevance (Firestore does this automatically)
  - Optional: Add minimum similarity threshold filter (0.7) if needed
- [x] Export function from `firebase/functions/src/ai/index.ts`

**What to Test:**
1. Build project: `cd firebase/functions && npm run build`
2. Store test fact: "User charges $500/hour for consulting"
3. Search with query: "What are your rates?"
4. Verify fact is retrieved with high similarity
5. Test with irrelevant query - should return empty or low-similarity results
6. Test with multiple related facts - verify all are found
7. Verify userId filtering works (doesn't return other users' facts)

**Files Changed:**
- NEW: `firebase/functions/src/ai/lib/knowledge-retriever.ts` - Semantic search implementation
- `firebase/functions/src/ai/index.ts` - Export searchKnowledge function

**Notes:**
- Using Firestore native vector search with .findNearest()
- COSINE distance measure is best for normalized embeddings
- Firestore automatically returns results sorted by similarity
- May need to tune topK based on real usage (start with 5)

---

## Phase 2: Voice Profile Configuration

**Estimated Time:** 1-2 days

This phase implements static voice profile configuration system that stores manually authored communication style profiles for users in different conversation categories (business vs social vs collaboration). This is server-side only - iOS integration happens in Phase 4.

### PR 2.1: Voice Profile Schema & Types ✅ COMPLETED

**Goal:** Define simple data model for storing arbitrary JSON voice profiles in Firestore.

**Tasks:**
- [x] Read existing `firebase/functions/src/ai/types.ts` for patterns
- [x] Add new types to `firebase/functions/src/ai/types.ts`:
  - `VoiceProfile` interface with fields:
    - userId: string
    - category: ConversationCategory
    - styleRules: Record<string, any> (arbitrary JSON with style preferences)
    - createdAt: Date
    - lastUpdated: Date
- [x] Update `db-types.md` with new Firestore subcollection:
  - Subcollection: `users/{userId}/voiceProfiles/{category}`
  - Document that styleRules is arbitrary JSON passed to AI as context
  - Note that profiles are static, manually authored configurations
  - Example styleRules formats (no enforcement, just examples)
- [x] Export VoiceProfile type from `firebase/functions/src/ai/index.ts`

**What to Test:**
1. Build TypeScript: `cd firebase/functions && npm run build`
2. Verify types compile without errors
3. Confirm Record<string, any> allows flexible JSON structure

**Files Changed:**
- `firebase/functions/src/ai/types.ts` - Add VoiceProfile type
- `firebase/functions/src/ai/index.ts` - Export VoiceProfile
- `/Users/Gauntlet/gauntlet/CreatorLink/db-types.md` - Document voiceProfiles subcollection

**Notes:**
- styleRules is arbitrary JSON - no schema enforcement
- Content is passed directly to AI as context for draft generation
- Allows maximum flexibility for different style attributes
- Can evolve structure without TypeScript changes

---

### PR 2.2: Static Profile Seed Script ✅ COMPLETED

**Goal:** Create seed data with arbitrary JSON voice profiles for test users.

**Tasks:**
- [x] Read existing seed files in `emulator-seed/seed-files/` to understand seed data patterns
- [x] Create NEW: `emulator-seed/seed-files/voice-profiles.js`:
  - Define arbitrary JSON voice profiles for test users:
    - Alice - Business, Collaboration, Social (professional-friendly → warm-casual)
    - Bob - Business, Collaboration, Social (direct-professional → casual-laid-back)
    - David - Business, Collaboration, Social (formal-detailed → relaxed-brief)
  - Export function `seedVoiceProfiles(db, users)` that:
    - Reads JSON files from voice-profiles/{user}/{category}.json
    - Stores profiles in `users/{userId}/voiceProfiles/{category}` subcollection
    - Uses Firestore FieldValue.serverTimestamp() for createdAt and lastUpdated
    - Handles business, collaboration, and social categories for Alice, Bob, and David
- [x] Update `emulator-seed/seed-files/generic.js`:
  - Import seedVoiceProfiles function
  - Call seedVoiceProfiles after user creation
  - Add logging for voice profile seeding
- [x] Test seed script runs without errors

**What to Test:**
1. Run seed script: `cd emulator-seed && node seed.js`
2. Verify voice profiles created in Firestore emulator
3. Check profiles exist at correct path: `users/{userId}/voiceProfiles/{category}`
4. Verify styleRules contains arbitrary JSON
5. Confirm createdAt and lastUpdated timestamps set

**Files Changed:**
- NEW: `emulator-seed/seed-files/voice-profiles.js` - Voice profile seed data
- `emulator-seed/seed.js` - Import and call voice profile seeding

**Notes:**
- styleRules JSON can have any structure - no schema enforcement
- Examples show different approaches (some detailed, some simple)
- AI will interpret the JSON as context for draft generation
- Easy to modify and experiment with different profile formats

---

### PR 2.3: Profile Loader Utility ✅ COMPLETED

**Goal:** Create helper function to load static voice profiles from Firestore for use in draft generation.

**Tasks:**
- [x] Read `firebase/functions/src/ai/lib/response-writer.ts` for Firestore read patterns
- [x] Create NEW: `firebase/functions/src/ai/lib/voice-profile-loader.ts`:
  - Import VoiceProfile type from ai/types
  - Implement `loadVoiceProfile(userId: string, category: ConversationCategory): Promise<VoiceProfile | null>`
  - Fetch document from `users/{userId}/voiceProfiles/{category}`
  - Parse document data into VoiceProfile type
  - Return null if document doesn't exist
  - Add error handling for Firestore read failures
  - Add logging for debugging (profile found/not found)
  - Use admin.firestore() instance
- [x] Export function from `firebase/functions/src/ai/index.ts`

**What to Test:**
1. Build project: `cd firebase/functions && npm run build`
2. Seed voice profiles using PR 2.3 seed script
3. Test loadVoiceProfile with valid userId and category - verify profile returned
4. Test with non-existent userId - verify null returned
5. Test with valid user but invalid category - verify null returned
6. Check logging output shows profile load status

**Files Changed:**
- NEW: `firebase/functions/src/ai/lib/voice-profile-loader.ts` - Profile loader utility
- `firebase/functions/src/ai/index.ts` - Export loadVoiceProfile function

**Notes:**
- Simple utility function - no complex logic needed
- Used by draft generation to fetch user's voice profile
- Returns null for missing profiles (graceful degradation)
- Will be used in Phase 3 draft generation

---

## Phase 3: Draft Generation Logic

**Estimated Time:** 5-7 days

This phase implements the core draft generation system that combines knowledge retrieval and voice profiles to create personalized response drafts.

### PR 3.1: Draft Schema & Types

**Goal:** Define data models for storing AI-generated draft responses in Firestore.

**Tasks:**
- [ ] Read PRD section on Conversation Draft data model
- [ ] Read existing `firebase/functions/src/ai/types.ts`
- [ ] Add new types to `firebase/functions/src/ai/types.ts`:
  - `MessageDraft` interface with fields:
    - id?: string (document ID)
    - conversationId: string
    - userId: string (who the draft is for - the recipient)
    - text: string (draft message text)
    - category: ConversationCategory
    - generatedAt: Date
    - updatedAt: Date
    - sourceMessageIds: string[] (messages that triggered this draft)
    - confidence: number (0.0-1.0, based on available data)
    - knowledgeUsed: KnowledgeReference[] (for transparency)
    - voiceProfileUsed: boolean (was voice profile available?)
  - `KnowledgeReference` interface:
    - factId: string
    - text: string (fact text for debugging)
    - similarity: number (how relevant was this fact)
  - `DraftGenerationResult` interface:
    - success: boolean
    - draft?: MessageDraft
    - reason?: string (why generation succeeded/failed)
    - error?: string
- [ ] Update `db-types.md` with new Firestore subcollection:
  - Subcollection: `conversations/{conversationId}/drafts/{userId}`
  - Document all fields
  - Note: One draft per user per conversation (overwrites on update)
  - Add indexes if needed
- [ ] Export new types from `firebase/functions/src/ai/index.ts`

**What to Test:**
1. Build TypeScript: `cd firebase/functions && npm run build`
2. Verify types compile without errors
3. Review schema matches PRD specifications
4. Confirm subcollection path structure

**Files Changed:**
- `firebase/functions/src/ai/types.ts` - Add MessageDraft types
- `firebase/functions/src/ai/index.ts` - Export new types
- `/Users/Gauntlet/gauntlet/CreatorLink/db-types.md` - Document drafts subcollection

**Notes:**
- Subcollection under conversation for better organization
- Per-user drafts allow personalized responses in group chats
- knowledgeUsed provides transparency for debugging

---

### PR 3.2: Draft Prerequisites Check

**Goal:** Implement logic to determine if sufficient data exists to generate a quality draft.

**Tasks:**
- [ ] Create NEW: `firebase/functions/src/ai/lib/draft-prerequisites.ts`:
  - Implement `checkDraftPrerequisites(userId: string, category: ConversationCategory, messageText: string): Promise<boolean>`
  - Check 1: Voice profile exists (using loadVoiceProfile from Phase 2, returns non-null)
  - Check 2: Message is a question or request (reuse question detector)
  - Check 3: Relevant knowledge available (search knowledge base, check if results > 0 with similarity > 0.7)
  - Return simple boolean: true if all checks pass, false otherwise
  - Add logging for debugging which specific checks failed
- [ ] Export function from `firebase/functions/src/ai/index.ts`

**What to Test:**
1. Build project: `cd firebase/functions && npm run build`
2. Test with no voice profile - should return false
3. Test with profile but no knowledge - depends on message type
4. Test with profile, knowledge, and question - should return true
5. Test with statement (not question) - should return false
6. Verify logging output shows clear reasons for failures

**Files Changed:**
- NEW: `firebase/functions/src/ai/lib/draft-prerequisites.ts` - Prerequisites checking
- `firebase/functions/src/ai/index.ts` - Export checkDraftPrerequisites

**Notes:**
- Prerequisites prevent generating low-quality drafts
- Simplified to return boolean - profile either exists or doesn't (no confidence scores)
- Knowledge requirement may be relaxed for some message types (not all questions need facts)
- Logging provides clear debugging information about which checks failed

---

### PR 3.3: Draft Generation LLM Function

**Goal:** Implement LLM-based draft generation that combines knowledge, voice profile, and conversation context.

**Tasks:**
- [ ] Read `firebase/functions/src/ai/lib/faq-matcher.ts` and `categorizer.ts` for complex LLM prompting
- [ ] Create NEW: `firebase/functions/src/ai/lib/draft-generator.ts`:
  - Implement `generateDraft(userId: string, conversationId: string, incomingMessages: ConversationMessage[], category: ConversationCategory): Promise<DraftGenerationResult>`
  - Fetch voice profile for user + category (profile either exists or doesn't)
  - Extract latest message(s) as the prompt to respond to
  - Search knowledge base for relevant facts
  - Fetch last 10 messages for conversation context
  - Build LLM prompt:
    - System: Instruct to write response matching user's voice profile
    - Include voice profile details (formality, common phrases, emoji usage, etc.)
    - Include retrieved knowledge facts with context
    - Include recent conversation for continuity
    - Request response that sounds authentic to the user
  - Use OpenAI GPT-4o (higher quality for draft generation)
  - Temperature: 0.7 (creative but consistent)
  - Max tokens: 300 (reasonable response length)
  - Parse response and create MessageDraft object
  - Calculate confidence based on:
    - Knowledge availability: 0.6 if relevant facts found, 0.0 if not
    - Conversation context: 0.4 if sufficient history, 0.0 if not
    - (No profile confidence component - profile either exists or generation doesn't happen)
  - Return DraftGenerationResult
- [ ] Export function from `firebase/functions/src/ai/index.ts`

**What to Test:**
1. Build project: `cd firebase/functions && npm run build`
2. Create test scenario with:
   - Voice profile (formal business style)
   - Knowledge fact: "I charge $500/hour"
   - Incoming message: "What are your rates for consulting?"
3. Generate draft - verify it:
   - Includes pricing information
   - Matches formality level
   - Uses common phrases from profile
   - Sounds natural and authentic
4. Test with minimal knowledge - verify lower confidence score
5. Verify error handling with API failures

**Files Changed:**
- NEW: `firebase/functions/src/ai/lib/draft-generator.ts` - Draft generation logic
- `firebase/functions/src/ai/index.ts` - Export generateDraft function

**Notes:**
- GPT-4o for better quality (more expensive but worth it for user-facing drafts)
- Prompt engineering critical - may need iteration based on results
- Consider showing knowledge sources to user (transparency)
- Confidence calculation simplified - profile existence is prerequisite, not confidence factor

---

### PR 3.4: Draft Storage & Update Logic

**Goal:** Implement service to save/update drafts in Firestore with intelligent update logic.

**Tasks:**
- [ ] Create NEW: `firebase/functions/src/ai/lib/draft-manager.ts`:
  - Implement `saveDraft(draft: MessageDraft): Promise<string>`
  - Save to `conversations/{conversationId}/drafts/{userId}`
  - Use set with merge to overwrite existing draft
  - Return document ID
  - Implement `getDraft(conversationId: string, userId: string): Promise<MessageDraft | null>`
  - Fetch from subcollection
  - Return null if doesn't exist
  - Implement `deleteDraft(conversationId: string, userId: string): Promise<void>`
  - Delete document from subcollection
  - Implement `shouldUpdateDraft(existingDraft: MessageDraft | null, newSourceMessages: string[]): boolean`
  - Return true if no existing draft
  - Return true if new messages not in existingDraft.sourceMessageIds
  - Return false if draft already includes all messages (avoid redundant updates)
  - Implement `markDraftTouched(conversationId: string, userId: string): Promise<void>`
  - Add metadata field `userTouched: true` to draft
  - Used in Phase 4 to prevent auto-updates of edited drafts
- [ ] Export functions from `firebase/functions/src/ai/index.ts`

**What to Test:**
1. Build project: `cd firebase/functions && npm run build`
2. Test saveDraft creates document in correct subcollection path
3. Test getDraft retrieves existing draft
4. Test getDraft returns null for non-existent draft
5. Test shouldUpdateDraft logic with various scenarios
6. Test deleteDraft removes document
7. Verify markDraftTouched adds metadata field

**Files Changed:**
- NEW: `firebase/functions/src/ai/lib/draft-manager.ts` - Draft management
- `firebase/functions/src/ai/index.ts` - Export draft functions

**Notes:**
- Using set with merge allows updating specific fields
- shouldUpdateDraft prevents generating duplicate drafts
- userTouched flag will be used in Phase 4 iOS integration

---

### PR 3.5: Draft Generation Cloud Function

**Goal:** Create Cloud Function trigger that generates drafts when users receive messages.

**Tasks:**
- [ ] Read `firebase/functions/src/index.ts` onMessageCreated trigger
- [ ] Update `firebase/functions/src/index.ts`:
  - Within `onMessageCreated` trigger, add new section for draft generation
  - Import draft-related functions
  - After message created:
    - Skip if sender is AI or system
    - For each recipient (other participants):
      - Check if user has AI response mode enabled (skip for Phase 3 - assume enabled for testing)
      - Check prerequisites for draft generation
      - If prerequisites pass:
        - Get existing draft
        - Check if should update draft
        - If yes:
          - Fetch recent messages
          - Generate draft
          - Save draft to Firestore
      - Add comprehensive logging
  - Use try/catch to prevent blocking message creation
- [ ] Add feature flag: `ENABLE_DRAFT_GENERATION` (default: false initially)
- [ ] Add configuration: `DRAFT_MIN_CONFIDENCE` (default: 0.5)

**What to Test:**
1. Rebuild functions: `cd firebase/functions && npm run build`
2. Enable feature flag: `ENABLE_DRAFT_GENERATION=true`
3. Set up test scenario:
   - User A has voice profile + knowledge facts
   - User B sends question to User A
4. Verify draft created in `conversations/{id}/drafts/{userA}`
5. Check draft contains appropriate response
6. Send another message from B - verify draft updates
7. Check function logs for debugging output
8. Verify existing message flow still works
9. Test with prerequisites not met - verify graceful skip

**Files Changed:**
- `firebase/functions/src/index.ts` - Add draft generation to onMessageCreated trigger

**Notes:**
- Draft generation most expensive operation (uses GPT-4o)
- Consider rate limiting per user to control costs
- Phase 4 will add user setting for AI response mode (for now assume enabled)
- Initially disable with feature flag until thoroughly tested

---

### PR 3.6: Draft Update on New Messages

**Goal:** Implement logic to update existing drafts when sender sends additional messages.

**Tasks:**
- [ ] Update `firebase/functions/src/index.ts` onMessageCreated trigger:
  - After draft generation section, add draft update section
  - When message created, check all participants:
    - For each other participant (potential draft owner):
      - Check if they have existing draft for this conversation
      - If yes and draft not marked userTouched:
        - Fetch new messages since draft created
        - Check prerequisites still met
        - If yes:
          - Regenerate draft with updated context
          - Update sourceMessageIds to include new messages
          - Save updated draft
  - Add logging for draft updates
- [ ] Add configuration: `MAX_DRAFT_AGE_MINUTES` (default: 60)
  - Only update drafts created/updated within last hour
  - Older drafts assumed stale or abandoned

**What to Test:**
1. Rebuild functions: `cd firebase/functions && npm run build`
2. Set up scenario:
   - User A has draft to respond to User B
   - User B sends additional message
3. Verify User A's draft updates with new context
4. Check sourceMessageIds includes both messages
5. Test with userTouched=true draft - verify no update
6. Test with old draft (>60 min) - verify no update
7. Check logs for update triggers

**Files Changed:**
- `firebase/functions/src/index.ts` - Add draft update logic to onMessageCreated trigger

**Notes:**
- Update logic runs alongside initial generation
- userTouched flag (Phase 4) prevents overwriting user edits
- Age limit prevents wasting API calls on stale conversations

---

### PR 3.7: iOS Draft Model (Read-Only for Phase 3)

**Goal:** Create Swift model for MessageDraft to enable future iOS features (Phase 4), but no UI integration yet.

**Tasks:**
- [ ] Read `CreatorLink/Models/Message.swift` for Swift model patterns
- [ ] Create NEW: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/MessageDraft.swift`:
  - Define `MessageDraft` struct conforming to Codable, Hashable, Identifiable
  - Use @DocumentID for id field
  - Mirror TypeScript MessageDraft structure exactly
  - Define nested struct: `KnowledgeReference`
  - Use ConversationTag type for category field
  - Add CodingKeys enum
  - Add computed property `isHighConfidence: Bool` returning `confidence > 0.7`
  - Add preview text helper: `var previewText: String` returning first 50 chars
- [ ] No service integration yet (Phase 4)
- [ ] Update `db-types.md` with Swift model reference

**What to Test:**
1. Build iOS project in Xcode - verify no compilation errors
2. Create test MessageDraft instance in code
3. Verify Codable conformance
4. Test computed properties (isHighConfidence, previewText)

**Files Changed:**
- NEW: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/MessageDraft.swift` - Draft Swift model
- `/Users/Gauntlet/gauntlet/CreatorLink/db-types.md` - Add MessageDraft Swift model reference

**Notes:**
- No ViewModels or Services yet - just data model
- Field names MUST match TypeScript exactly
- Enables Phase 4 iOS integration later
- Consider adding to existing Models directory structure

---

## Open Questions Requiring Decisions

These questions from the PRD must be resolved during implementation:

### 1. Vector Database Choice (PR 1.1)
**Question:** Use Firestore Vector Search Extension or external service (Pinecone)?

**Decision Required Before:** PR 1.2

**Options:**
- Firestore Vector Search Extension (if available in 2025)
- Pinecone (proven, easy integration, added cost)
- Hybrid approach

**Impact:** Affects all knowledge storage and retrieval code

---

### 2. Knowledge Deduplication Strategy (PR 1.5)
**Question:** How aggressive should deduplication be?

**Recommendation:** Start with 0.95 similarity threshold, monitor in production

**Impact:** Knowledge base size and quality

---

### 3. Draft Generation Model Choice (PR 3.3)
**Question:** Use GPT-4o or GPT-4o-mini for draft generation?

**Recommendation:** GPT-4o for better quality (user-facing feature)

**Alternative:** Start with mini, upgrade if quality insufficient

**Impact:** Cost vs quality tradeoff

---

### 4. API Cost Management
**Question:** What rate limits and cost caps to implement?

**Recommendation:**
- Draft generation: Max 20 per user per hour
- Knowledge extraction: Max 50 per user per day

**Impact:** User experience vs infrastructure cost

---

## Success Criteria for Phases 1-3

**Phase 1 Complete:**
- [ ] Knowledge extracted from user messages and stored in vector DB
- [ ] Semantic search retrieves relevant facts with >80% accuracy
- [ ] At least 3 fact types supported (pricing, availability, preference)
- [ ] Cloud Function runs without errors on message creation

**Phase 2 Complete:**
- [ ] Voice profile schema and types defined in TypeScript (with arbitrary JSON styleRules)
- [ ] Seed script creates static voice profiles for test users (Alice, Bob)
- [ ] Profiles contain styleRules JSON describing user's communication preferences
- [ ] Profile loader utility successfully retrieves profiles from Firestore

**Phase 3 Complete:**
- [ ] Drafts generated when prerequisites met
- [ ] Drafts include knowledge facts + voice style
- [ ] Drafts update when new messages arrive
- [ ] Draft quality validated with test scenarios (sounds like user)

**Technical Quality:**
- [ ] All TypeScript code compiles without errors
- [ ] Cloud Functions deploy successfully
- [ ] Firebase Emulator tests pass
- [ ] Logging provides clear debugging information
- [ ] Error handling prevents cascade failures
- [ ] Cost tracking shows API usage within budget

---

## Next Steps After Phase 3

Phase 4 and Phase 5 will be documented in a separate task file:

**Phase 4: iOS UI Integration**
- iOS VoiceProfile and MessageDraft models
- AI response mode toggle in settings
- Draft display in conversation list
- Draft preview/editor in chat view
- Visual indicators (AI DRAFT badge)
- Draft auto-load into message input

**Phase 5: Refinement & Optimization**
- Learning from user edits
- Confidence scoring improvements
- Conflict detection for contradictory knowledge
- Performance optimization
- A/B testing different prompts

---

**Document Status:** Implementation Ready
**Last Updated:** 2025-10-25
**Covers:** Phases 1-3 only
**Next:** Phases 4-5 task document (separate)
