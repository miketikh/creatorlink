# Python FAQ Detection Service - Implementation Tasks (Phases 3-5)

## Context

This document provides detailed, step-by-step implementation tasks for building the intelligent FAQ detection backend service for CreatorLink. This service automatically detects when users ask questions that have been answered before and links them to previous answers using vector similarity search.

**What this provides:**
- FAQ detection service that identifies similar questions using embeddings
- Integration with Firestore to fetch conversation history and create AI responses
- Historical data seeding to populate the vector database with existing messages
- Complete end-to-end FAQ matching pipeline

**Current State:**
- FastAPI service exists at `/Users/Gauntlet/gauntlet/CreatorLink/python-service/` with basic message processing
- Firebase Cloud Functions trigger on new messages and call Python service
- Firebase client (`firebase_client.py`) has basic message creation capability
- iOS app has AI-enabled conversation support (Phases 1-2 complete)
- Cloud Function checks `aiEnabled` flag (Phase 4 complete)

**Architecture:**
- **Vector Database**: Qdrant for storing message embeddings
- **Embeddings**: OpenAI text-embedding-3-small (1536 dimensions)
- **Similarity**: Cosine similarity with 0.85 threshold
- **Storage**: Firestore for messages, Qdrant for vectors

This implementation covers **Phase 3 (FAQ Detection Service)**, **Phase 4 (Firestore Integration)**, and **Phase 5 (Historical Data Seeding)** from the Python implementation plan.

---

## Instructions for AI Agent

When implementing these tasks:
1. **Work sequentially** - Complete PRs in order within each phase
2. **Test after each PR** - Follow "What to Test" instructions before moving to next PR
3. **Use existing patterns** - Reference `main.py` and `firebase_client.py` for code style
4. **Follow Python conventions** - Use type hints, async/await, Pydantic models
5. **Log everything** - Use structured logging for debugging
6. **Handle errors gracefully** - Never crash the `/process-message` endpoint

**File path conventions:**
- Python service: `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/`
- Scripts: `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/`
- Tests: `/Users/Gauntlet/gauntlet/CreatorLink/python-service/tests/`
- Config: `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.env`
- Docker: `/Users/Gauntlet/gauntlet/CreatorLink/python-service/docker-compose.yml`

---

## Phase 3: FAQ Detection Service

**Estimated Time:** 2-3 days

This phase implements the core FAQ detection logic including question detection, similarity search, and response generation.

### PR 3.1: Set Up Qdrant Vector Database

**Goal:** Install and configure Qdrant vector database for storing message embeddings.

**Tasks:**
- [ ] Update `/Users/Gauntlet/gauntlet/CreatorLink/python-service/requirements.txt`
  - Add: `qdrant-client==1.11.0`
  - Add: `openai==1.52.0`
  - Add: `tiktoken==0.7.0`
- [ ] Create `/Users/Gauntlet/gauntlet/CreatorLink/python-service/docker-compose.yml`
  - Add Qdrant service definition:
    ```yaml
    version: '3.8'
    services:
      qdrant:
        image: qdrant/qdrant:v1.11.0
        ports:
          - "6333:6333"  # HTTP API
          - "6334:6334"  # gRPC
        volumes:
          - ./qdrant_storage:/qdrant/storage
        environment:
          - QDRANT__SERVICE__GRPC_PORT=6334
    ```
- [ ] Update `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.env.example`
  - Add Qdrant configuration:
    ```
    # Vector Database Configuration
    QDRANT_HOST=localhost
    QDRANT_PORT=6333
    QDRANT_COLLECTION_NAME=message_embeddings
    QDRANT_API_KEY=  # Empty for local, required for cloud

    # OpenAI Configuration
    OPENAI_API_KEY=sk-proj-...  # User must provide
    OPENAI_EMBEDDING_MODEL=text-embedding-3-small
    OPENAI_EMBEDDING_DIMENSIONS=1536
    ```
- [ ] Copy `.env.example` to `.env` and add your OpenAI API key
- [ ] Install new dependencies:
  ```bash
  cd /Users/Gauntlet/gauntlet/CreatorLink/python-service
  pip install -r requirements.txt
  ```
- [ ] Start Qdrant via Docker:
  ```bash
  cd /Users/Gauntlet/gauntlet/CreatorLink/python-service
  docker-compose up -d qdrant
  ```

**What to Test:**
1. Verify Docker Compose file is valid: `docker-compose config`
2. Start Qdrant: `docker-compose up -d qdrant`
3. Check Qdrant is running: `docker ps | grep qdrant`
4. Verify Qdrant API is accessible: `curl http://localhost:6333/healthz`
5. Should return: `{"title":"qdrant - vector search engine","version":"..."}`
6. Check Qdrant dashboard: Open `http://localhost:6333/dashboard` in browser
7. Verify dependencies installed: `pip list | grep -E "qdrant|openai|tiktoken"`
8. Stop Qdrant: `docker-compose down`

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/requirements.txt` - Add vector DB and embedding dependencies
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/docker-compose.yml` - NEW: Docker services configuration
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.env.example` - Add Qdrant and OpenAI config

**Notes:**
- Qdrant data persists in `./qdrant_storage` directory - add to `.gitignore`
- For production, use Qdrant Cloud or self-hosted Kubernetes deployment
- text-embedding-3-small is 1536 dimensions, cost-effective at $0.02/1M tokens
- Keep API keys in `.env` file, never commit to git
- Docker Compose makes local development simple - one command to start/stop

---

### PR 3.2: Create Vector Store Module

**Goal:** Implement `vector_store.py` to manage Qdrant connection and operations.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/vector_store.py`
- [ ] Add file header docstring explaining purpose
- [ ] Import dependencies:
  ```python
  import os
  import logging
  from typing import List, Dict, Optional, Any
  from qdrant_client import QdrantClient
  from qdrant_client.models import Distance, VectorParams, PointStruct, Filter, FieldCondition, MatchValue
  ```
- [ ] Create `VectorStore` class with:
  - `__init__()` method to initialize Qdrant client
  - Read `QDRANT_HOST`, `QDRANT_PORT`, `QDRANT_COLLECTION_NAME` from environment
  - Connect to Qdrant using `QdrantClient(host=..., port=...)`
  - Store collection name as instance variable
- [ ] Implement `create_collection()` method:
  - Check if collection exists: `self.client.collection_exists(collection_name)`
  - If not, create with schema:
    ```python
    self.client.create_collection(
        collection_name=self.collection_name,
        vectors_config=VectorParams(size=1536, distance=Distance.COSINE)
    )
    ```
  - Create payload indexes for fast filtering:
    ```python
    # Index for conversationId filtering
    self.client.create_payload_index(
        collection_name=self.collection_name,
        field_name="conversationId",
        field_schema="keyword"
    )
    # Index for isQuestion filtering
    self.client.create_payload_index(
        collection_name=self.collection_name,
        field_name="isQuestion",
        field_schema="bool"
    )
    ```
  - Add logging for collection creation
- [ ] Implement `upsert_message_embedding()` method:
  - Parameters: `message_id: str, conversation_id: str, text: str, embedding: List[float], is_question: bool, is_answer: bool, user_id: str, timestamp: int, participant_ids: List[str]`
  - Create Qdrant point:
    ```python
    point = PointStruct(
        id=message_id,  # Use message ID as point ID for idempotency
        vector=embedding,
        payload={
            "messageId": message_id,
            "conversationId": conversation_id,
            "userId": user_id,
            "text": text,
            "timestamp": timestamp,
            "isQuestion": is_question,
            "isAnswer": is_answer,
            "participantIds": participant_ids
        }
    )
    ```
  - Upsert to Qdrant: `self.client.upsert(collection_name=..., points=[point])`
  - Return success boolean
- [ ] Implement `search_similar_questions()` method:
  - Parameters: `query_vector: List[float], conversation_id: str, top_k: int = 3, min_score: float = 0.85`
  - Build filter for conversation and questions only:
    ```python
    search_filter = Filter(
        must=[
            FieldCondition(key="conversationId", match=MatchValue(value=conversation_id)),
            FieldCondition(key="isQuestion", match=MatchValue(value=True))
        ]
    )
    ```
  - Search Qdrant:
    ```python
    results = self.client.search(
        collection_name=self.collection_name,
        query_vector=query_vector,
        query_filter=search_filter,
        limit=top_k,
        score_threshold=min_score
    )
    ```
  - Return list of results with scores and payloads
- [ ] Add error handling and logging throughout

**What to Test:**
1. Start Qdrant: `docker-compose up -d qdrant`
2. Create test script `test_vector_store.py`:
   ```python
   from app.vector_store import VectorStore

   vs = VectorStore()
   vs.create_collection()
   print("Collection created successfully")

   # Test upsert
   test_embedding = [0.1] * 1536  # Dummy embedding
   vs.upsert_message_embedding(
       message_id="test123",
       conversation_id="conv123",
       text="What are your rates?",
       embedding=test_embedding,
       is_question=True,
       is_answer=False,
       user_id="user1",
       timestamp=1234567890,
       participant_ids=["user1", "user2"]
   )
   print("Message embedded successfully")

   # Test search
   results = vs.search_similar_questions(
       query_vector=test_embedding,
       conversation_id="conv123",
       top_k=1,
       min_score=0.5
   )
   print(f"Search results: {results}")
   ```
3. Run test script: `python -m test_vector_store`
4. Verify no errors occur
5. Check Qdrant dashboard - collection should exist with 1 point
6. Verify search returns the test message
7. Test with non-existent conversation - should return empty list
8. Test with low min_score - should return results
9. Clean up: Delete test collection via dashboard or API

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/vector_store.py` - NEW: Vector database operations

**Notes:**
- Using message ID as Qdrant point ID makes upserts idempotent (re-running won't duplicate)
- Cosine distance is best for semantic similarity (ranges 0-2, lower is more similar)
- Qdrant score is inverted (1.0 = identical, 0.0 = completely different) for cosine
- Payload indexes enable fast filtering by conversationId and isQuestion
- Keep collection name configurable via environment variable
- Error handling critical - Qdrant might be down, handle gracefully

---

### PR 3.3: Create Embeddings Module

**Goal:** Implement `embeddings.py` for generating OpenAI embeddings.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/embeddings.py`
- [ ] Add docstring explaining OpenAI embedding generation
- [ ] Import dependencies:
  ```python
  import os
  import logging
  from typing import List
  import openai
  from openai import AsyncOpenAI
  import tiktoken
  ```
- [ ] Create `EmbeddingService` class:
  - Initialize in `__init__()`:
    ```python
    self.api_key = os.getenv("OPENAI_API_KEY")
    if not self.api_key:
        raise ValueError("OPENAI_API_KEY environment variable not set")

    self.client = AsyncOpenAI(api_key=self.api_key)
    self.model = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
    self.dimensions = int(os.getenv("OPENAI_EMBEDDING_DIMENSIONS", "1536"))
    self.tokenizer = tiktoken.get_encoding("cl100k_base")  # GPT-4 tokenizer
    ```
- [ ] Implement `count_tokens()` method:
  ```python
  def count_tokens(self, text: str) -> int:
      """Count tokens in text using tiktoken."""
      return len(self.tokenizer.encode(text))
  ```
- [ ] Implement `generate_embedding()` async method:
  - Parameters: `text: str`
  - Validate text is not empty
  - Count tokens and log for cost tracking
  - Truncate if > 8191 tokens (model limit):
    ```python
    tokens = self.tokenizer.encode(text)
    if len(tokens) > 8191:
        logger.warning(f"Text too long ({len(tokens)} tokens), truncating to 8191")
        tokens = tokens[:8191]
        text = self.tokenizer.decode(tokens)
    ```
  - Call OpenAI API with retry logic:
    ```python
    try:
        response = await self.client.embeddings.create(
            model=self.model,
            input=text,
            dimensions=self.dimensions
        )
        embedding = response.data[0].embedding
        return embedding
    except openai.RateLimitError as e:
        logger.error(f"Rate limit hit: {e}")
        raise
    except Exception as e:
        logger.error(f"Embedding generation failed: {e}")
        raise
    ```
  - Return list of floats (1536 dimensions)
- [ ] Implement `batch_generate_embeddings()` async method:
  - Parameters: `texts: List[str], batch_size: int = 100`
  - Split texts into batches of max 100 (OpenAI limit)
  - For each batch:
    ```python
    response = await self.client.embeddings.create(
        model=self.model,
        input=batch_texts,
        dimensions=self.dimensions
    )
    embeddings.extend([item.embedding for item in response.data])
    ```
  - Return list of embeddings in same order as input
- [ ] Add comprehensive error handling and logging

**What to Test:**
1. Ensure OpenAI API key is in `.env` file
2. Create test script:
   ```python
   import asyncio
   from app.embeddings import EmbeddingService

   async def test():
       service = EmbeddingService()

       # Test single embedding
       text = "What are your consulting rates?"
       embedding = await service.generate_embedding(text)
       print(f"Generated embedding with {len(embedding)} dimensions")
       assert len(embedding) == 1536

       # Test token counting
       tokens = service.count_tokens(text)
       print(f"Text has {tokens} tokens")

       # Test batch embeddings
       texts = ["Question 1", "Question 2", "Question 3"]
       embeddings = await service.batch_generate_embeddings(texts)
       print(f"Generated {len(embeddings)} embeddings")
       assert len(embeddings) == 3

       print("All tests passed!")

   asyncio.run(test())
   ```
3. Run test: `python test_embeddings.py`
4. Verify embeddings are generated (should take 1-2 seconds)
5. Check that dimensions match (1536)
6. Test with very long text (>8191 tokens) - should truncate
7. Test with empty string - should handle gracefully
8. Monitor OpenAI API usage in dashboard

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/embeddings.py` - NEW: OpenAI embedding generation

**Notes:**
- text-embedding-3-small costs $0.02 per 1M tokens - very affordable
- Batch API is much more efficient than individual calls (100x faster for bulk)
- tiktoken tokenizer matches OpenAI's internal counting for accurate cost estimation
- 8191 token limit is strict - must truncate long texts
- Rate limits: 3,000 RPM for tier 1, increase as needed
- Consider caching embeddings for frequently asked questions (future optimization)

---

### PR 3.4: Create Text Analysis Module

**Goal:** Implement question and answer detection heuristics.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/text_analysis.py`
- [ ] Add docstring explaining text classification logic
- [ ] Import dependencies:
  ```python
  import re
  import logging
  from typing import Optional
  ```
- [ ] Create `is_question()` function:
  ```python
  def is_question(text: str) -> bool:
      """
      Detect if text is a question using multiple heuristics.

      Checks:
      1. Contains question mark (?)
      2. Starts with question words (how, what, when, etc.)
      3. Starts with auxiliary verbs (can, do, does, is, are, etc.)
      4. Contains common question patterns

      Args:
          text: Message text to analyze

      Returns:
          True if message is likely a question
      """
      if not text or len(text.strip()) == 0:
          return False

      text_lower = text.lower().strip()

      # Check 1: Contains question mark
      if '?' in text:
          return True

      # Check 2: Starts with question words
      question_words = ['how', 'what', 'when', 'where', 'why', 'which', 'who', 'whose', 'whom']
      if any(text_lower.startswith(word + ' ') for word in question_words):
          return True

      # Check 3: Starts with auxiliary verbs
      auxiliary_verbs = ['can', 'could', 'would', 'should', 'will', 'do', 'does', 'did',
                         'is', 'are', 'was', 'were', 'has', 'have', 'had']
      if any(text_lower.startswith(verb + ' ') for verb in auxiliary_verbs):
          return True

      # Check 4: Common question patterns
      question_patterns = [
          r'\banyone know\b',
          r'\bdoes anyone\b',
          r'\bcan someone\b',
          r'\bwho knows\b',
          r'\bany idea\b',
          r'\bany thoughts\b'
      ]
      if any(re.search(pattern, text_lower) for pattern in question_patterns):
          return True

      return False
  ```
- [ ] Create `is_answer()` function:
  ```python
  def is_answer(
      text: str,
      sender_id: str,
      min_length: int = 10
  ) -> bool:
      """
      Detect if message is likely an answer.

      Criteria:
      1. Sender is not AI or system
      2. Text length >= min_length (filters "ok", "👍", etc.)
      3. Contains substantive content

      Args:
          text: Message text
          sender_id: ID of sender
          min_length: Minimum character count

      Returns:
          True if message is likely an answer
      """
      # Filter out AI and system messages
      if sender_id in ["ai-assistant", "ai-agent", "system"]:
          return False

      # Filter very short messages
      if not text or len(text.strip()) < min_length:
          return False

      # Simple heuristic - if it's not a question and meets length, it's an answer
      return not is_question(text)
  ```
- [ ] Add helper function `classify_message()`:
  ```python
  def classify_message(text: str, sender_id: str) -> dict:
      """
      Classify message as question, answer, or neither.

      Returns:
          Dict with classification results
      """
      is_q = is_question(text)
      is_a = is_answer(text, sender_id)

      return {
          "is_question": is_q,
          "is_answer": is_a,
          "classification": "question" if is_q else ("answer" if is_a else "other")
      }
  ```

**What to Test:**
1. Create test script with various message types:
   ```python
   from app.text_analysis import is_question, is_answer, classify_message

   # Test questions
   assert is_question("What are your rates?") == True
   assert is_question("How does this work?") == True
   assert is_question("Can you help me") == True  # No question mark
   assert is_question("Does anyone know the answer?") == True

   # Test non-questions
   assert is_question("I think this is great") == False
   assert is_question("Thanks for the help") == False

   # Test answers
   assert is_answer("My rates are $500/hour", "user1") == True
   assert is_answer("ok", "user1") == False  # Too short
   assert is_answer("Here's how it works...", "user1") == True

   # Test AI/system filtering
   assert is_answer("Some text", "ai-assistant") == False
   assert is_answer("Some text", "system") == False

   # Test classification
   result = classify_message("What time is the meeting?", "user1")
   assert result["is_question"] == True
   assert result["classification"] == "question"

   print("All tests passed!")
   ```
2. Run tests: `python test_text_analysis.py`
3. Verify all assertions pass
4. Test with edge cases:
   - Empty string
   - Very long text (>1000 chars)
   - Unicode characters and emojis
   - Multiple question marks
   - Mixed case text
5. Manually test with real conversation examples

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/text_analysis.py` - NEW: Question/answer detection logic

**Notes:**
- Heuristics are not perfect but should catch 80-90% of questions
- False positives are acceptable (will be filtered by similarity threshold)
- False negatives mean missed FAQ opportunities - less critical
- Consider future ML model for better classification (future enhancement)
- Regex patterns are case-insensitive via text.lower()
- Can tune min_length threshold based on actual data patterns

---

### PR 3.5: Implement FAQ Service

**Goal:** Create the main FAQ detection service that ties everything together.

**Tasks:**
- [ ] Create new file `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/faq_service.py`
- [ ] Add comprehensive docstring explaining FAQ detection pipeline
- [ ] Import dependencies:
  ```python
  import logging
  from typing import Optional, Dict, Any, List
  from dataclasses import dataclass
  from datetime import datetime

  from .embeddings import EmbeddingService
  from .vector_store import VectorStore
  from .text_analysis import is_question, is_answer
  from .firebase_client import FirebaseClient
  ```
- [ ] Create `FAQRequest` dataclass:
  ```python
  @dataclass
  class FAQRequest:
      """Request data for FAQ detection."""
      messageId: str
      conversationId: str
      senderId: str
      text: str
      timestamp: Dict[str, int]  # Firebase timestamp
      participantIds: List[str]
      minimumSimilarity: float = 0.85
  ```
- [ ] Create `FAQService` class with initialization:
  ```python
  class FAQService:
      def __init__(self):
          self.embedding_service = EmbeddingService()
          self.vector_store = VectorStore()
          self.firebase_client = FirebaseClient()
          self.logger = logging.getLogger(__name__)

          # Create Qdrant collection on startup
          self.vector_store.create_collection()
  ```
- [ ] Implement `embed_and_store_message()` async method:
  ```python
  async def embed_and_store_message(
      self,
      message_id: str,
      conversation_id: str,
      sender_id: str,
      text: str,
      timestamp: int,
      participant_ids: List[str]
  ) -> bool:
      """
      Generate embedding for message and store in vector DB.

      Args:
          message_id: Message document ID
          conversation_id: Conversation ID
          sender_id: User ID of sender
          text: Message text
          timestamp: Unix timestamp
          participant_ids: List of conversation participants

      Returns:
          True if successful, False otherwise
      """
      try:
          # Classify message
          is_q = is_question(text)
          is_a = is_answer(text, sender_id)

          # Generate embedding
          embedding = await self.embedding_service.generate_embedding(text)

          # Store in vector database
          success = self.vector_store.upsert_message_embedding(
              message_id=message_id,
              conversation_id=conversation_id,
              text=text,
              embedding=embedding,
              is_question=is_q,
              is_answer=is_a,
              user_id=sender_id,
              timestamp=timestamp,
              participant_ids=participant_ids
          )

          if success:
              self.logger.info(f"Embedded message {message_id}: is_question={is_q}, is_answer={is_a}")

          return success

      except Exception as e:
          self.logger.error(f"Failed to embed message {message_id}: {e}")
          return False
  ```
- [ ] Implement `detect_and_respond_faq()` async method (core logic):
  ```python
  async def detect_and_respond_faq(self, request: FAQRequest) -> Optional[str]:
      """
      Main FAQ detection pipeline.

      Steps:
      1. Pre-checks (is it a question, not from AI)
      2. Embed the current message and store it
      3. Search for similar questions in same conversation
      4. If match found, fetch original answer
      5. Create AI response with FAQ reference

      Args:
          request: FAQ detection request data

      Returns:
          Response message ID if FAQ found, None otherwise
      """
      try:
          # Step 1: Pre-checks
          if request.senderId in ["ai-assistant", "ai-agent", "system"]:
              self.logger.info("Skipping FAQ for AI/system message")
              return None

          if not is_question(request.text):
              self.logger.info(f"Message is not a question: '{request.text[:50]}...'")
              # Still embed it for future reference
              await self.embed_and_store_message(
                  message_id=request.messageId,
                  conversation_id=request.conversationId,
                  sender_id=request.senderId,
                  text=request.text,
                  timestamp=request.timestamp.get("_seconds", 0),
                  participant_ids=request.participantIds
              )
              return None

          # Step 2: Embed the question and store it
          question_embedding = await self.embedding_service.generate_embedding(request.text)

          await self.embed_and_store_message(
              message_id=request.messageId,
              conversation_id=request.conversationId,
              sender_id=request.senderId,
              text=request.text,
              timestamp=request.timestamp.get("_seconds", 0),
              participant_ids=request.participantIds
          )

          # Step 3: Search for similar questions
          similar_questions = self.vector_store.search_similar_questions(
              query_vector=question_embedding,
              conversation_id=request.conversationId,
              top_k=1,  # Only best match
              min_score=request.minimumSimilarity
          )

          if not similar_questions or len(similar_questions) == 0:
              self.logger.info("No similar questions found above threshold")
              return None

          # Get best match
          best_match = similar_questions[0]
          match_score = best_match.score
          matched_question_id = best_match.payload.get("messageId")
          matched_question_text = best_match.payload.get("text")

          self.logger.info(f"Found similar question (score={match_score:.2f}): {matched_question_text[:50]}...")

          # Step 4: Fetch answer message (TODO: implement in next PR - Phase 4)
          # For now, just log that we found a match
          self.logger.info(f"Match confidence: {match_score:.2%}")

          # TODO Phase 4: Implement answer fetching and response creation
          # For now, return None (no response created)
          return None

      except Exception as e:
          self.logger.error(f"FAQ detection failed: {e}", exc_info=True)
          return None  # Graceful degradation - don't crash
  ```
- [ ] Add helper method `_format_confidence_level()`:
  ```python
  def _format_confidence_level(self, score: float) -> str:
      """Return confidence level string based on score."""
      if score >= 0.95:
          return "very_high"
      elif score >= 0.90:
          return "high"
      elif score >= 0.85:
          return "medium"
      else:
          return "low"
  ```

**What to Test:**
1. Start Qdrant: `docker-compose up -d qdrant`
2. Create test script:
   ```python
   import asyncio
   from app.faq_service import FAQService, FAQRequest

   async def test():
       service = FAQService()

       # Test embedding storage
       success = await service.embed_and_store_message(
           message_id="msg1",
           conversation_id="conv1",
           sender_id="user1",
           text="What are your rates?",
           timestamp=1234567890,
           participant_ids=["user1", "user2"]
       )
       assert success == True
       print("Message embedded successfully")

       # Test FAQ detection with similar question
       request = FAQRequest(
           messageId="msg2",
           conversationId="conv1",
           senderId="user2",
           text="How much do you charge?",  # Similar question
           timestamp={"_seconds": 1234567900},
           participantIds=["user1", "user2"],
           minimumSimilarity=0.7  # Lower threshold for testing
       )

       result = await service.detect_and_respond_faq(request)
       print(f"FAQ detection result: {result}")

       # Should find similar question (even though we don't create response yet)
       # Check logs for "Found similar question" message

   asyncio.run(test())
   ```
3. Run test: `python test_faq_service.py`
4. Check logs - should see:
   - "Embedded message msg1: is_question=True"
   - "Found similar question (score=0.XX): What are your rates?..."
5. Verify no crashes or errors
6. Test with non-question - should not find matches
7. Test with AI sender - should skip entirely
8. Check Qdrant dashboard - should have 2 points in collection

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/faq_service.py` - NEW: Core FAQ detection logic

**Notes:**
- This PR implements the detection logic but doesn't create responses yet (Phase 4)
- Graceful degradation is critical - always return None on error, never crash
- Logging is essential for debugging - log every decision point
- The service automatically embeds all messages for future reference
- Questions get stored as is_question=True for targeted search
- Similarity threshold of 0.85 balances precision vs recall
- Future enhancement: cache recent embeddings to avoid recomputing

---

### PR 3.6: Integrate FAQ Service with Main Endpoint

**Goal:** Connect FAQ service to the `/process-message` endpoint.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py`
- [ ] Add import at top:
  ```python
  from .faq_service import FAQService, FAQRequest
  ```
- [ ] Initialize FAQ service after other services (around line 37):
  ```python
  logger.info("Initializing FAQ service...")
  faq_service = FAQService()
  ```
- [ ] Update `process_message` endpoint (replace existing logic):
  ```python
  @app.post("/process-message", response_model=MessageResponse)
  async def process_message(request: MessageRequest) -> MessageResponse:
      """
      Process incoming message and detect FAQ opportunities.

      Args:
          request: Message data from Cloud Function

      Returns:
          Processing result with response message ID (if FAQ found)
      """
      try:
          logger.info(f"Received message: {request.messageId} from {request.senderId}")
          logger.info(f"Text: '{request.text}'")
          logger.info(f"AI Config: faqDetection={request.aiConfig.faqDetectionEnabled if request.aiConfig else True}, "
                      f"similarity={request.aiConfig.minimumSimilarity if request.aiConfig else 0.85}")

          # Extract minimum similarity from config
          min_similarity = request.aiConfig.minimumSimilarity if request.aiConfig else 0.85

          # Create FAQ request
          faq_request = FAQRequest(
              messageId=request.messageId,
              conversationId=request.conversationId,
              senderId=request.senderId,
              text=request.text,
              timestamp=request.timestamp,
              participantIds=request.participantIds,
              minimumSimilarity=min_similarity
          )

          # Run FAQ detection
          response_message_id = await faq_service.detect_and_respond_faq(faq_request)

          if response_message_id:
              logger.info(f"FAQ response created: {response_message_id}")
              return MessageResponse(
                  success=True,
                  message="FAQ match found and response created",
                  responseMessageId=response_message_id
              )
          else:
              logger.info("No FAQ match found")
              return MessageResponse(
                  success=True,
                  message="Message processed, no FAQ match",
                  responseMessageId=None
              )

      except Exception as e:
          logger.error(f"Error processing message {request.messageId}: {e}", exc_info=True)
          # Don't raise exception - return success=False instead
          return MessageResponse(
              success=False,
              message=f"Error: {str(e)}",
              responseMessageId=None
          )
  ```
- [ ] Remove old AI agent echo logic (no longer needed)
- [ ] Keep health check endpoints unchanged

**What to Test:**
1. Start all services:
   ```bash
   docker-compose up -d qdrant
   python -m app.main
   ```
2. Test with curl (simulate Cloud Function call):
   ```bash
   curl -X POST http://localhost:8000/process-message \
     -H "Content-Type: application/json" \
     -d '{
       "messageId": "test123",
       "conversationId": "conv123",
       "senderId": "user1",
       "text": "What are your consulting rates?",
       "timestamp": {"_seconds": 1234567890},
       "participantIds": ["user1", "user2"],
       "aiConfig": {
         "faqDetectionEnabled": true,
         "minimumSimilarity": 0.85
       }
     }'
   ```
3. Check response - should return success=True
4. Check Python logs - should see:
   - "Received message: test123"
   - "Message is not a question" OR "Embedded message test123"
   - "No FAQ match found" (first message, nothing to match)
5. Send second similar message:
   ```bash
   curl -X POST http://localhost:8000/process-message \
     -H "Content-Type: application/json" \
     -d '{
       "messageId": "test456",
       "conversationId": "conv123",
       "senderId": "user2",
       "text": "How much do you charge for consulting?",
       "timestamp": {"_seconds": 1234567900},
       "participantIds": ["user1", "user2"],
       "aiConfig": {
         "faqDetectionEnabled": true,
         "minimumSimilarity": 0.75
       }
     }'
   ```
6. Check logs - should find similar question from first message
7. Verify health endpoint still works: `curl http://localhost:8000/health`
8. Test error handling - send invalid request, verify graceful response

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py` - Integrate FAQ service into endpoint

**Notes:**
- Old echo agent can be removed or kept for testing
- Error handling returns success=False instead of raising exception (prevents Cloud Function retries)
- FAQ service is initialized once at startup for performance
- Logging shows full pipeline execution for debugging
- minimumSimilarity from aiConfig is passed through to FAQ service
- Next phase will implement actual response creation

---

## Phase 4: Firestore Integration

**Estimated Time:** 2-3 days

This phase extends the Firebase client to fetch conversation data, find answer messages, and create AI responses with FAQ metadata.

### PR 4.1: Extend Firebase Client with Query Methods

**Goal:** Add Firestore query methods for fetching conversations, messages, and checking existence.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py`
- [ ] Add new method `get_conversation()`:
  ```python
  async def get_conversation(self, conversation_id: str) -> Optional[Dict[str, Any]]:
      """
      Fetch conversation document by ID.

      Args:
          conversation_id: Conversation document ID

      Returns:
          Conversation data dict or None if not found
      """
      try:
          conversation_ref = self.db.collection("conversations").document(conversation_id)
          conversation_doc = conversation_ref.get()

          if not conversation_doc.exists:
              logger.warning(f"Conversation not found: {conversation_id}")
              return None

          data = conversation_doc.to_dict()
          logger.info(f"Fetched conversation {conversation_id}")
          return data

      except Exception as e:
          logger.error(f"Failed to fetch conversation {conversation_id}: {e}")
          return None
  ```
- [ ] Add new method `get_message()`:
  ```python
  async def get_message(self, message_id: str) -> Optional[Dict[str, Any]]:
      """
      Fetch single message by ID.

      Args:
          message_id: Message document ID

      Returns:
          Message data dict or None if not found
      """
      try:
          # Note: Messages are stored with auto-generated IDs, need to query by ID
          messages_ref = self.db.collection("messages")
          message_doc = messages_ref.document(message_id).get()

          if not message_doc.exists:
              logger.warning(f"Message not found: {message_id}")
              return None

          data = message_doc.to_dict()
          logger.info(f"Fetched message {message_id}")
          return data

      except Exception as e:
          logger.error(f"Failed to fetch message {message_id}: {e}")
          return None
  ```
- [ ] Add new method `get_messages_after()`:
  ```python
  async def get_messages_after(
      self,
      conversation_id: str,
      after_timestamp: int,
      limit: int = 5
  ) -> List[Dict[str, Any]]:
      """
      Fetch messages after a specific timestamp in a conversation.

      Args:
          conversation_id: Conversation ID to query
          after_timestamp: Unix timestamp (seconds since epoch)
          limit: Maximum number of messages to return

      Returns:
          List of message dicts ordered by timestamp ascending
      """
      try:
          from google.cloud.firestore_v1 import FieldFilter

          messages_ref = self.db.collection("messages")

          # Build query
          query = messages_ref \
              .where(filter=FieldFilter("conversationId", "==", conversation_id)) \
              .where(filter=FieldFilter("timestamp", ">", after_timestamp)) \
              .order_by("timestamp") \
              .limit(limit)

          # Execute query
          docs = query.stream()
          messages = []
          for doc in docs:
              message_data = doc.to_dict()
              message_data['id'] = doc.id  # Include document ID
              messages.append(message_data)

          logger.info(f"Fetched {len(messages)} messages after timestamp {after_timestamp}")
          return messages

      except Exception as e:
          logger.error(f"Failed to fetch messages after timestamp: {e}")
          return []
  ```
- [ ] Add new method `message_exists()`:
  ```python
  async def message_exists(self, message_id: str) -> bool:
      """
      Check if message document exists (not deleted).

      Args:
          message_id: Message document ID

      Returns:
          True if exists, False otherwise
      """
      try:
          message_doc = self.db.collection("messages").document(message_id).get()
          exists = message_doc.exists
          logger.debug(f"Message {message_id} exists: {exists}")
          return exists
      except Exception as e:
          logger.error(f"Failed to check message existence: {e}")
          return False
  ```

**What to Test:**
1. Ensure Firebase emulator is running with test data
2. Create test script:
   ```python
   import asyncio
   from app.firebase_client import FirebaseClient

   async def test():
       client = FirebaseClient()

       # Test get_conversation (use real conversation ID from emulator)
       conv = await client.get_conversation("your-test-conv-id")
       assert conv is not None
       print(f"Conversation: {conv.get('name')}")

       # Test get_message (use real message ID)
       msg = await client.get_message("your-test-message-id")
       assert msg is not None
       print(f"Message text: {msg.get('text')}")

       # Test get_messages_after
       messages = await client.get_messages_after(
           conversation_id="your-test-conv-id",
           after_timestamp=1234567890,
           limit=5
       )
       print(f"Found {len(messages)} messages")

       # Test message_exists
       exists = await client.message_exists("your-test-message-id")
       assert exists == True

       not_exists = await client.message_exists("fake-id-123")
       assert not_exists == False

       print("All tests passed!")

   asyncio.run(test())
   ```
3. Run test: `python test_firebase_queries.py`
4. Verify all queries return expected data
5. Test with non-existent IDs - should return None/False gracefully
6. Check logs for proper info/warning messages
7. Test timestamp filtering - should only return messages after cutoff

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py` - Add query methods

**Notes:**
- Firestore timestamp in messages might be ServerTimestamp object - handle carefully
- get_messages_after needs composite index if not created automatically
- All methods return None/empty on error for graceful degradation
- Include document ID in returned message dicts (needed for referencing)
- Async methods even though Firestore SDK is sync (for consistency)

---

### PR 4.2: Implement Answer Discovery Logic

**Goal:** Add method to find the answer message that followed a question.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py`
- [ ] Add new method `find_answer_message()`:
  ```python
  async def find_answer_message(
      self,
      conversation_id: str,
      question_timestamp: int
  ) -> Optional[Dict[str, Any]]:
      """
      Find the answer message that followed a question.

      Algorithm:
      1. Fetch next 2-3 messages after question timestamp
      2. Filter out system and AI messages
      3. Filter out very short messages (< 10 chars)
      4. Return first valid participant message

      Args:
          conversation_id: Conversation ID
          question_timestamp: Timestamp of original question (seconds)

      Returns:
          Answer message dict or None if no valid answer found
      """
      try:
          # Fetch messages after the question
          messages = await self.get_messages_after(
              conversation_id=conversation_id,
              after_timestamp=question_timestamp,
              limit=3  # Look ahead max 3 messages
          )

          if not messages:
              logger.info("No messages found after question")
              return None

          # Filter for valid answers
          for msg in messages:
              sender_id = msg.get("senderId", "")
              text = msg.get("text", "")

              # Skip AI and system messages
              if sender_id in ["ai-assistant", "ai-agent", "system"]:
                  logger.debug(f"Skipping AI/system message from {sender_id}")
                  continue

              # Skip very short messages
              if len(text.strip()) < 10:
                  logger.debug(f"Skipping short message: '{text}'")
                  continue

              # Found valid answer
              logger.info(f"Found answer message: {msg.get('id')} from {sender_id}")
              return msg

          logger.info("No valid answer message found")
          return None

      except Exception as e:
          logger.error(f"Failed to find answer message: {e}")
          return None
  ```
- [ ] Add helper method `get_user_display_name()` (for response formatting):
  ```python
  async def get_user_display_name(self, user_id: str) -> str:
      """
      Fetch user's display name from Firestore.

      Args:
          user_id: User document ID

      Returns:
          Display name or "Someone" if not found
      """
      try:
          user_doc = self.db.collection("users").document(user_id).get()

          if not user_doc.exists:
              logger.warning(f"User not found: {user_id}")
              return "Someone"

          user_data = user_doc.to_dict()
          display_name = user_data.get("displayName", "Someone")

          return display_name

      except Exception as e:
          logger.error(f"Failed to fetch user {user_id}: {e}")
          return "Someone"
  ```

**What to Test:**
1. Create test messages in Firestore emulator:
   - Message 1 (t=1000): "What are your rates?" from user1
   - Message 2 (t=1010): "My rates are $500/hour" from user2
   - Message 3 (t=1020): "Thanks!" from user1
2. Create test script:
   ```python
   import asyncio
   from app.firebase_client import FirebaseClient

   async def test():
       client = FirebaseClient()

       # Test finding answer
       answer = await client.find_answer_message(
           conversation_id="your-conv-id",
           question_timestamp=1000  # Timestamp of question
       )

       assert answer is not None
       assert answer.get("text") == "My rates are $500/hour"
       print(f"Found answer: {answer.get('text')}")

       # Test with no answer (timestamp after all messages)
       no_answer = await client.find_answer_message(
           conversation_id="your-conv-id",
           question_timestamp=9999999999
       )
       assert no_answer is None

       # Test get_user_display_name
       name = await client.get_user_display_name("user2")
       print(f"User display name: {name}")

       print("All tests passed!")

   asyncio.run(test())
   ```
3. Run test: `python test_answer_discovery.py`
4. Verify answer is found correctly
5. Test with only short responses - should return None
6. Test with only AI responses - should skip and return None
7. Test with 10+ messages after question - should only look at first 3
8. Verify user display names are fetched correctly

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py` - Add answer discovery methods

**Notes:**
- Looking ahead 3 messages is a reasonable heuristic - captures most Q&A pairs
- Very short messages like "ok", "👍" are not useful answers
- AI messages should never be referenced as answers (prevents loops)
- System messages are for notifications, not answers
- Fallback to "Someone" if user not found (graceful degradation)
- Future enhancement: use ML to better identify answer messages

---

### PR 4.3: Create FAQ Response Message with Metadata

**Goal:** Implement method to create AI response with FAQ reference metadata.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py`
- [ ] Add new method `send_faq_message()`:
  ```python
  async def send_faq_message(
      self,
      conversation_id: str,
      participant_ids: List[str],
      matched_question: str,
      faq_reference_id: str,
      match_confidence: float,
      answerer_name: str = "Someone"
  ) -> str:
      """
      Create AI-generated FAQ response message in Firestore.

      Args:
          conversation_id: Conversation ID
          participant_ids: List of participant user IDs
          matched_question: Original question text
          faq_reference_id: Message ID of answer being referenced
          match_confidence: Similarity score (0.0-1.0)
          answerer_name: Display name of person who answered

      Returns:
          Message document ID of created response
      """
      try:
          # Format response text based on confidence
          if match_confidence >= 0.90:
              # High confidence - direct reference
              response_text = (
                  f"💡 This question was asked before!\n\n"
                  f"{answerer_name} answered it previously."
              )
          elif match_confidence >= 0.85:
              # Medium confidence - softer language
              response_text = (
                  f"💡 This might be related to a previous question.\n\n"
                  f"{answerer_name} may have the answer."
              )
          else:
              # Low confidence - shouldn't happen but handle gracefully
              response_text = (
                  f"💡 Found a potentially related answer from {answerer_name}."
              )

          # Create metadata matching iOS Message model structure
          # All values must be strings (Firestore map<string, string>)
          metadata = {
              "ai_generated": "true",  # iOS compatibility
              "faqReference": faq_reference_id,  # iOS expects this key
              "matchConfidence": f"{match_confidence:.2f}",  # e.g., "0.92"
              "matchedQuestion": matched_question[:200],  # Truncate for storage
              "agentType": "faq_detector",
              "agentVersion": "0.2.0"
          }

          # Send message using existing method
          message_id = await self.send_message(
              conversation_id=conversation_id,
              sender_id="ai-assistant",
              text=response_text,
              participant_ids=participant_ids,
              metadata=metadata
          )

          logger.info(f"Created FAQ response message: {message_id} "
                      f"(confidence={match_confidence:.2%}, reference={faq_reference_id})")

          return message_id

      except Exception as e:
          logger.error(f"Failed to send FAQ message: {e}")
          raise
  ```

**What to Test:**
1. Create test script:
   ```python
   import asyncio
   from app.firebase_client import FirebaseClient

   async def test():
       client = FirebaseClient()

       # Test high confidence FAQ message
       msg_id = await client.send_faq_message(
           conversation_id="test-conv",
           participant_ids=["user1", "user2", "ai-assistant"],
           matched_question="What are your consulting rates?",
           faq_reference_id="original-answer-msg-id",
           match_confidence=0.92,
           answerer_name="Alice"
       )

       assert msg_id is not None
       print(f"Created FAQ message: {msg_id}")

       # Fetch and verify message
       msg = await client.get_message(msg_id)
       assert msg is not None
       assert msg["senderId"] == "ai-assistant"
       assert "This question was asked before" in msg["text"]
       assert msg["metadata"]["faqReference"] == "original-answer-msg-id"
       assert msg["metadata"]["matchConfidence"] == "0.92"
       print(f"Message text: {msg['text']}")
       print(f"Metadata: {msg['metadata']}")

       # Test medium confidence
       msg_id2 = await client.send_faq_message(
           conversation_id="test-conv",
           participant_ids=["user1", "user2", "ai-assistant"],
           matched_question="How much do you charge?",
           faq_reference_id="another-answer-id",
           match_confidence=0.87,
           answerer_name="Bob"
       )

       msg2 = await client.get_message(msg_id2)
       assert "might be related" in msg2["text"]
       print(f"Medium confidence text: {msg2['text']}")

       print("All tests passed!")

   asyncio.run(test())
   ```
2. Run test: `python test_faq_message.py`
3. Verify messages created in Firestore
4. Check message structure matches iOS Message model
5. Verify metadata keys match iOS expectations (faqReference, matchConfidence)
6. Verify text formatting is correct for both confidence levels
7. Check that conversation lastMessage is updated
8. Test with very long matched_question - should truncate

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py` - Add FAQ message creation

**Notes:**
- Response text uses emoji (💡) for visual distinction
- Two confidence levels: high (>=0.90) and medium (0.85-0.89)
- Metadata keys must match exactly what iOS expects (faqReference not faq_reference)
- All metadata values are strings (Firestore limitation)
- matchConfidence formatted as "0.92" not "92%" for iOS parsing
- Matched question truncated to 200 chars to avoid storage bloat
- answerer_name personalization makes response more helpful

---

### PR 4.4: Complete FAQ Service with Response Creation

**Goal:** Connect all pieces together - detect similar questions and create FAQ responses.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/faq_service.py`
- [ ] Update `detect_and_respond_faq()` method to complete the pipeline:
  - Replace the "TODO Phase 4" comments with actual implementation
  - After finding similar question (around line where best_match is found):
  ```python
  # Step 4: Fetch the answer message that followed the matched question
  matched_timestamp = best_match.payload.get("timestamp")

  answer_message = await self.firebase_client.find_answer_message(
      conversation_id=request.conversationId,
      question_timestamp=matched_timestamp
  )

  if not answer_message:
      self.logger.info("No answer found for matched question")
      return None

  answer_message_id = answer_message.get("id")

  # Verify answer message still exists
  if not await self.firebase_client.message_exists(answer_message_id):
      self.logger.warning(f"Referenced answer message {answer_message_id} no longer exists")
      return None

  # Get answerer's display name
  answerer_id = answer_message.get("senderId")
  answerer_name = await self.firebase_client.get_user_display_name(answerer_id)

  # Step 5: Create AI response with FAQ reference
  response_message_id = await self.firebase_client.send_faq_message(
      conversation_id=request.conversationId,
      participant_ids=request.participantIds,
      matched_question=matched_question_text,
      faq_reference_id=answer_message_id,
      match_confidence=match_score,
      answerer_name=answerer_name
  )

  self.logger.info(f"FAQ response created: {response_message_id} "
                   f"(matched: {matched_question_text[:50]}..., "
                   f"confidence: {match_score:.2%})")

  return response_message_id
  ```
- [ ] Add edge case handling for deleted messages:
  - Check message exists before creating reference
  - Check answerer is still a participant (optional)
- [ ] Add rate limiting to prevent spam (optional):
  ```python
  # At class level, add rate limiting state
  def __init__(self):
      # ... existing initialization ...
      self._last_faq_time: Dict[str, float] = {}  # conversationId -> timestamp
      self._faq_cooldown_seconds = 60  # 1 minute between FAQ responses

  # In detect_and_respond_faq, before creating response:
  import time
  current_time = time.time()
  last_faq = self._last_faq_time.get(request.conversationId, 0)

  if current_time - last_faq < self._faq_cooldown_seconds:
      self.logger.info(f"FAQ cooldown active, skipping (last: {last_faq})")
      return None

  # After successful response creation:
  self._last_faq_time[request.conversationId] = current_time
  ```

**What to Test:**
1. Create full end-to-end test scenario:
   ```python
   import asyncio
   from app.faq_service import FAQService, FAQRequest

   async def test_full_pipeline():
       service = FAQService()

       # Step 1: First question and answer
       req1 = FAQRequest(
           messageId="q1",
           conversationId="conv1",
           senderId="user1",
           text="What are your consulting rates?",
           timestamp={"_seconds": 1000},
           participantIds=["user1", "user2", "ai-assistant"],
           minimumSimilarity=0.85
       )

       result1 = await service.detect_and_respond_faq(req1)
       # Should be None (no previous questions)
       assert result1 is None
       print("✓ First question embedded")

       # Manually create answer in Firestore (simulate user response)
       # ... use firebase_client.send_message() ...

       # Step 2: Similar question from different user
       req2 = FAQRequest(
           messageId="q2",
           conversationId="conv1",
           senderId="user3",
           text="How much do you charge for consulting?",
           timestamp={"_seconds": 2000},
           participantIds=["user1", "user2", "user3", "ai-assistant"],
           minimumSimilarity=0.85
       )

       result2 = await service.detect_and_respond_faq(req2)
       # Should create FAQ response
       assert result2 is not None
       print(f"✓ FAQ response created: {result2}")

       # Verify response in Firestore
       msg = await service.firebase_client.get_message(result2)
       assert msg is not None
       assert msg["metadata"]["faqReference"] is not None
       assert "This question was asked before" in msg["text"]
       print(f"✓ Response text: {msg['text']}")

       print("✅ Full pipeline test passed!")

   asyncio.run(test_full_pipeline())
   ```
2. Run full test: `python test_full_pipeline.py`
3. Verify complete flow:
   - First question embedded
   - Answer message created
   - Second similar question detected
   - FAQ response created with metadata
   - iOS can parse and display
4. Test edge cases:
   - Answer message deleted before reference created
   - Very similar questions (>0.95 similarity)
   - Marginal matches (0.85-0.87 similarity)
   - Multiple matches (should pick highest)
5. Test rate limiting (if implemented):
   - Two questions 30 seconds apart - both should process
   - Two questions 10 seconds apart - second should skip
6. Check logs for complete execution trace

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/faq_service.py` - Complete FAQ response creation

**Notes:**
- This PR completes the core FAQ detection feature
- All pieces working together: embedding → search → find answer → create response
- Edge case handling prevents broken references
- Rate limiting prevents spam (optional but recommended)
- Logging provides full audit trail for debugging
- Next phase will add bulk embedding for historical data

---

## Phase 5: Historical Data Seeding

**Estimated Time:** 1-2 days

This phase implements scripts to populate the vector database with existing message history.

### PR 5.1: Create Historical Embedding Script

**Goal:** Build script to embed all existing messages from AI-enabled conversations.

**Tasks:**
- [ ] Create new directory `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/`
- [ ] Create file `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/seed_embeddings.py`
- [ ] Add script header and imports:
  ```python
  #!/usr/bin/env python3
  """
  Historical Message Embedding Script

  Processes existing messages from AI-enabled conversations and
  populates the vector database with embeddings.

  Usage:
      python -m scripts.seed_embeddings [--batch-size 100] [--dry-run]
  """

  import asyncio
  import argparse
  import logging
  import sys
  import os
  from typing import List, Dict, Any

  # Add parent directory to path for imports
  sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

  from app.firebase_client import FirebaseClient
  from app.embeddings import EmbeddingService
  from app.vector_store import VectorStore
  from app.text_analysis import is_question, is_answer
  ```
- [ ] Create main function:
  ```python
  async def seed_historical_embeddings(
      batch_size: int = 100,
      dry_run: bool = False
  ) -> Dict[str, int]:
      """
      Seed vector database with embeddings from existing messages.

      Args:
          batch_size: Number of messages to process per batch
          dry_run: If True, don't actually insert embeddings

      Returns:
          Stats dict with counts
      """
      logger = logging.getLogger(__name__)
      logger.info("Starting historical embedding process...")

      # Initialize services
      firebase_client = FirebaseClient()
      embedding_service = EmbeddingService()
      vector_store = VectorStore()

      # Create collection if needed
      if not dry_run:
          vector_store.create_collection()

      # Stats tracking
      stats = {
          "conversations_processed": 0,
          "messages_found": 0,
          "messages_embedded": 0,
          "questions_found": 0,
          "answers_found": 0,
          "errors": 0,
          "total_tokens": 0
      }

      # Step 1: Find all AI-enabled conversations
      logger.info("Querying AI-enabled conversations...")
      from google.cloud.firestore_v1 import FieldFilter

      conversations_ref = firebase_client.db.collection("conversations")
      query = conversations_ref.where(
          filter=FieldFilter("aiEnabled", "==", True)
      )

      ai_conversations = []
      for doc in query.stream():
          conv_data = doc.to_dict()
          conv_data['id'] = doc.id
          ai_conversations.append(conv_data)

      logger.info(f"Found {len(ai_conversations)} AI-enabled conversations")

      # Step 2: Process each conversation
      for conv in ai_conversations:
          conv_id = conv['id']
          logger.info(f"Processing conversation: {conv_id} ({conv.get('name', 'Unnamed')})")

          try:
              # Fetch all messages for this conversation
              messages_ref = firebase_client.db.collection("messages")
              msg_query = messages_ref.where(
                  filter=FieldFilter("conversationId", "==", conv_id)
              ).order_by("timestamp")

              messages = []
              for msg_doc in msg_query.stream():
                  msg_data = msg_doc.to_dict()
                  msg_data['id'] = msg_doc.id
                  messages.append(msg_data)

              stats["messages_found"] += len(messages)
              logger.info(f"  Found {len(messages)} messages")

              # Step 3: Batch embed messages
              texts_to_embed = []
              message_metadata = []

              for msg in messages:
                  # Skip AI messages (don't embed our own responses)
                  if msg.get("senderId") in ["ai-assistant", "ai-agent", "system"]:
                      continue

                  text = msg.get("text", "")
                  if not text or len(text.strip()) == 0:
                      continue

                  # Classify message
                  is_q = is_question(text)
                  is_a = is_answer(text, msg.get("senderId"))

                  if is_q:
                      stats["questions_found"] += 1
                  if is_a:
                      stats["answers_found"] += 1

                  texts_to_embed.append(text)
                  message_metadata.append({
                      "message_id": msg["id"],
                      "conversation_id": conv_id,
                      "sender_id": msg.get("senderId"),
                      "timestamp": msg.get("timestamp"),
                      "participant_ids": msg.get("participantIds", []),
                      "is_question": is_q,
                      "is_answer": is_a,
                      "text": text
                  })

                  # Count tokens for cost estimation
                  stats["total_tokens"] += embedding_service.count_tokens(text)

              # Generate embeddings in batches
              if texts_to_embed and not dry_run:
                  logger.info(f"  Embedding {len(texts_to_embed)} messages...")

                  embeddings = await embedding_service.batch_generate_embeddings(
                      texts=texts_to_embed,
                      batch_size=batch_size
                  )

                  # Insert into vector store
                  for i, (embedding, metadata) in enumerate(zip(embeddings, message_metadata)):
                      # Extract timestamp - handle both dict and timestamp object
                      timestamp_value = metadata["timestamp"]
                      if isinstance(timestamp_value, dict):
                          timestamp_seconds = timestamp_value.get("_seconds", 0)
                      else:
                          # Assume it's already a number
                          timestamp_seconds = int(timestamp_value) if timestamp_value else 0

                      vector_store.upsert_message_embedding(
                          message_id=metadata["message_id"],
                          conversation_id=metadata["conversation_id"],
                          text=metadata["text"],
                          embedding=embedding,
                          is_question=metadata["is_question"],
                          is_answer=metadata["is_answer"],
                          user_id=metadata["sender_id"],
                          timestamp=timestamp_seconds,
                          participant_ids=metadata["participant_ids"]
                      )

                      stats["messages_embedded"] += 1

                      if (i + 1) % 50 == 0:
                          logger.info(f"    Embedded {i + 1}/{len(embeddings)} messages")

              stats["conversations_processed"] += 1

          except Exception as e:
              logger.error(f"Error processing conversation {conv_id}: {e}")
              stats["errors"] += 1
              continue

      # Calculate cost estimate
      cost_per_million_tokens = 0.02  # text-embedding-3-small pricing
      estimated_cost = (stats["total_tokens"] / 1_000_000) * cost_per_million_tokens

      logger.info("\n" + "="*60)
      logger.info("SEEDING COMPLETE")
      logger.info("="*60)
      logger.info(f"Conversations processed: {stats['conversations_processed']}")
      logger.info(f"Messages found: {stats['messages_found']}")
      logger.info(f"Messages embedded: {stats['messages_embedded']}")
      logger.info(f"Questions found: {stats['questions_found']}")
      logger.info(f"Answers found: {stats['answers_found']}")
      logger.info(f"Errors: {stats['errors']}")
      logger.info(f"Total tokens: {stats['total_tokens']:,}")
      logger.info(f"Estimated cost: ${estimated_cost:.4f}")
      logger.info("="*60)

      return stats
  ```
- [ ] Add CLI argument parsing:
  ```python
  if __name__ == "__main__":
      parser = argparse.ArgumentParser(description="Seed vector DB with historical messages")
      parser.add_argument("--batch-size", type=int, default=100,
                          help="Batch size for embedding generation")
      parser.add_argument("--dry-run", action="store_true",
                          help="Don't actually insert embeddings")
      parser.add_argument("--verbose", action="store_true",
                          help="Enable verbose logging")

      args = parser.parse_args()

      # Configure logging
      log_level = logging.DEBUG if args.verbose else logging.INFO
      logging.basicConfig(
          level=log_level,
          format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
      )

      # Run seeding
      asyncio.run(seed_historical_embeddings(
          batch_size=args.batch_size,
          dry_run=args.dry_run
      ))
  ```

**What to Test:**
1. Ensure Qdrant and Firebase emulator are running
2. Create test data in Firestore:
   - At least 2 conversations with aiEnabled: true
   - Each with 10-20 messages
   - Mix of questions and answers
3. Run dry-run first: `python -m scripts.seed_embeddings --dry-run --verbose`
4. Verify script finds conversations and messages
5. Check that stats are calculated correctly
6. Run actual seeding: `python -m scripts.seed_embeddings --batch-size 50`
7. Monitor progress logs
8. Verify completion stats:
   - Messages embedded count matches expected
   - Cost estimate is reasonable
   - No errors
9. Check Qdrant dashboard - collection should have points
10. Query Qdrant to verify embeddings exist
11. Test with empty database - should handle gracefully
12. Test with no AI-enabled conversations - should exit cleanly

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/seed_embeddings.py` - NEW: Historical embedding script

**Notes:**
- Batch size of 100 is optimal for OpenAI API (max allowed)
- Script is idempotent - re-running updates existing embeddings
- Skips AI messages to avoid self-referencing
- Provides cost estimate before running (good for large datasets)
- Dry-run mode allows testing without API calls
- Progress logging every 50 messages helps track long-running jobs
- Consider adding checkpoint file for resume capability (future enhancement)

---

### PR 5.2: Create Demo FAQ Data Script

**Goal:** Build script to generate realistic demo data with intentional FAQ scenarios.

**Tasks:**
- [ ] Create file `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/seed_demo_data.py`
- [ ] Define demo FAQ pairs at top of file:
  ```python
  """
  Demo Data Seeding Script

  Creates realistic FAQ scenario with intentionally similar questions for testing.
  """

  DEMO_FAQ_SCENARIOS = [
      {
          "category": "Pricing",
          "question": "What are your rates for consulting?",
          "answer": "My rates are $500/hour for consulting, with a 3-hour minimum. I also offer package deals for long-term projects.",
          "similar_questions": [
              "How much do you charge for consulting?",
              "What do you charge per hour?",
              "What are your consulting fees?",
              "How much does it cost to hire you?"
          ]
      },
      {
          "category": "Meetings",
          "question": "When is the next team meeting?",
          "answer": "Next team meeting is Thursday at 2pm PST. We'll be discussing Q4 roadmap and priorities.",
          "similar_questions": [
              "What time is the team meeting?",
              "When do we meet next?",
              "When's the next standup?",
              "What day is our meeting?"
          ]
      },
      {
          "category": "Setup",
          "question": "How do I set up my development environment?",
          "answer": "You'll need to install Node.js 18+, Python 3.12+, and Docker. Follow the README.md in the repo for detailed setup instructions.",
          "similar_questions": [
              "How do I configure my dev environment?",
              "What do I need to install for development?",
              "How do I get started with the codebase?",
              "What are the setup requirements?"
          ]
      },
      {
          "category": "Deadlines",
          "question": "When is the project deadline?",
          "answer": "The final deadline is December 15th, but we have milestone check-ins every two weeks. Next checkpoint is November 30th.",
          "similar_questions": [
              "What's the due date for this project?",
              "When do we need to finish this?",
              "What's the timeline for completion?",
              "When is this due?"
          ]
      },
      {
          "category": "Documentation",
          "question": "Where can I find the API documentation?",
          "answer": "API docs are at https://docs.example.com/api. You can also run 'npm run docs' locally to view them.",
          "similar_questions": [
              "Where is the API reference?",
              "How do I access the documentation?",
              "Where are the docs?",
              "Is there API documentation available?"
          ]
      }
  ]
  ```
- [ ] Implement main seeding function:
  ```python
  import asyncio
  import logging
  import sys
  import os
  from typing import List
  import time

  sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

  from app.firebase_client import FirebaseClient

  async def seed_demo_faq_data(conversation_id: str) -> None:
      """
      Seed demo FAQ data into specified conversation.

      Args:
          conversation_id: Conversation to populate with demo data
      """
      logger = logging.getLogger(__name__)
      client = FirebaseClient()

      # Verify conversation exists and is AI-enabled
      conv = await client.get_conversation(conversation_id)
      if not conv:
          logger.error(f"Conversation {conversation_id} not found")
          return

      if not conv.get("aiEnabled"):
          logger.error(f"Conversation {conversation_id} is not AI-enabled")
          return

      participant_ids = conv.get("participantIds", [])
      if len(participant_ids) < 2:
          logger.error("Need at least 2 participants for demo")
          return

      user1_id = participant_ids[0]
      user2_id = participant_ids[1]

      logger.info(f"Seeding demo data into conversation: {conversation_id}")
      logger.info(f"Using participants: {user1_id}, {user2_id}")

      # Seed each FAQ scenario
      base_timestamp = int(time.time()) - 86400  # Start 24 hours ago

      for i, scenario in enumerate(DEMO_FAQ_SCENARIOS):
          logger.info(f"\nSeeding scenario {i+1}: {scenario['category']}")

          # Send original question
          timestamp_offset = i * 1800  # 30 minutes between scenarios
          question_time = base_timestamp + timestamp_offset

          logger.info(f"  Q: {scenario['question']}")
          await client.send_message(
              conversation_id=conversation_id,
              sender_id=user1_id,
              text=scenario['question'],
              participant_ids=participant_ids
          )
          await asyncio.sleep(0.5)

          # Send answer
          logger.info(f"  A: {scenario['answer'][:50]}...")
          await client.send_message(
              conversation_id=conversation_id,
              sender_id=user2_id,
              text=scenario['answer'],
              participant_ids=participant_ids
          )
          await asyncio.sleep(0.5)

          # Optional: Add some filler messages
          await client.send_message(
              conversation_id=conversation_id,
              sender_id=user1_id,
              text="Thanks! That's helpful.",
              participant_ids=participant_ids
          )
          await asyncio.sleep(0.5)

      logger.info(f"\n✅ Seeded {len(DEMO_FAQ_SCENARIOS)} FAQ scenarios")
      logger.info(f"You can now test with similar questions like:")
      for scenario in DEMO_FAQ_SCENARIOS[:2]:
          logger.info(f"  - {scenario['similar_questions'][0]}")

  if __name__ == "__main__":
      import argparse

      parser = argparse.ArgumentParser(description="Seed demo FAQ data")
      parser.add_argument("conversation_id", help="Conversation ID to seed")

      args = parser.parse_args()

      logging.basicConfig(
          level=logging.INFO,
          format='%(asctime)s - %(levelname)s - %(message)s'
      )

      asyncio.run(seed_demo_faq_data(args.conversation_id))
  ```

**What to Test:**
1. Create test conversation in Firestore with aiEnabled: true
2. Get conversation ID
3. Run demo seeding: `python -m scripts.seed_demo_data <conversation-id>`
4. Verify messages created in Firestore
5. Check conversation has Q&A pairs for each scenario
6. Run embedding script to embed demo data
7. Test FAQ detection with similar questions:
   - Ask: "How much do you charge?"
   - Should match: "What are your rates for consulting?"
8. Verify AI response includes FAQ reference
9. Test with multiple similar questions from different scenarios
10. Verify iOS app can display all FAQ links correctly

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/seed_demo_data.py` - NEW: Demo data generator

**Notes:**
- Demo scenarios cover common FAQ categories
- Similar questions test various phrasings of same intent
- Realistic answers provide context for references
- Script validates conversation exists and is AI-enabled
- Messages spaced 30 minutes apart for realistic timeline
- Can extend with more scenarios as needed
- Useful for demos, testing, and training

---

### PR 5.3: Create FAQ Accuracy Testing Script

**Goal:** Build validation script to test FAQ matching accuracy.

**Tasks:**
- [ ] Create file `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/test_faq_accuracy.py`
- [ ] Implement test script:
  ```python
  #!/usr/bin/env python3
  """
  FAQ Accuracy Testing Script

  Tests FAQ matching accuracy using known question pairs.
  Calculates precision, recall, and confidence score distribution.
  """

  import asyncio
  import logging
  import sys
  import os
  from typing import List, Dict, Tuple

  sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

  from app.embeddings import EmbeddingService
  from app.vector_store import VectorStore
  from scripts.seed_demo_data import DEMO_FAQ_SCENARIOS

  async def test_faq_accuracy() -> Dict[str, any]:
      """
      Test FAQ matching accuracy on known question pairs.

      Returns:
          Dict with accuracy metrics
      """
      logger = logging.getLogger(__name__)
      logger.info("Starting FAQ accuracy testing...")

      embedding_service = EmbeddingService()
      vector_store = VectorStore()

      # Test parameters
      test_conversation_id = "accuracy-test-conv"
      min_similarity = 0.85

      # Results tracking
      results = {
          "total_tests": 0,
          "correct_matches": 0,
          "false_positives": 0,
          "false_negatives": 0,
          "scores": []
      }

      # Step 1: Embed all original questions
      logger.info("Embedding original questions...")
      for i, scenario in enumerate(DEMO_FAQ_SCENARIOS):
          original_question = scenario["question"]
          embedding = await embedding_service.generate_embedding(original_question)

          vector_store.upsert_message_embedding(
              message_id=f"original-q{i}",
              conversation_id=test_conversation_id,
              text=original_question,
              embedding=embedding,
              is_question=True,
              is_answer=False,
              user_id="test-user",
              timestamp=1000 + i,
              participant_ids=["test-user"]
          )

      logger.info(f"Embedded {len(DEMO_FAQ_SCENARIOS)} original questions")

      # Step 2: Test each similar question
      logger.info("\nTesting similar questions...")
      for scenario_idx, scenario in enumerate(DEMO_FAQ_SCENARIOS):
          category = scenario["category"]
          original_question = scenario["question"]

          for similar_q in scenario["similar_questions"]:
              results["total_tests"] += 1

              # Generate embedding for similar question
              similar_embedding = await embedding_service.generate_embedding(similar_q)

              # Search for matches
              matches = vector_store.search_similar_questions(
                  query_vector=similar_embedding,
                  conversation_id=test_conversation_id,
                  top_k=1,
                  min_score=min_similarity
              )

              if matches and len(matches) > 0:
                  best_match = matches[0]
                  matched_text = best_match.payload.get("text")
                  match_score = best_match.score

                  # Check if it matched the correct original question
                  if matched_text == original_question:
                      results["correct_matches"] += 1
                      status = "✅ CORRECT"
                  else:
                      results["false_positives"] += 1
                      status = "❌ WRONG MATCH"

                  results["scores"].append(match_score)

                  logger.info(f"{status} [{category}] score={match_score:.3f}")
                  logger.info(f"  Query:   {similar_q}")
                  logger.info(f"  Matched: {matched_text}")
              else:
                  results["false_negatives"] += 1
                  logger.info(f"❌ NO MATCH [{category}]")
                  logger.info(f"  Query: {similar_q}")

      # Calculate metrics
      precision = results["correct_matches"] / max(1, results["correct_matches"] + results["false_positives"])
      recall = results["correct_matches"] / max(1, results["total_tests"])
      f1_score = 2 * (precision * recall) / max(0.001, precision + recall)

      avg_score = sum(results["scores"]) / max(1, len(results["scores"]))
      min_score = min(results["scores"]) if results["scores"] else 0
      max_score = max(results["scores"]) if results["scores"] else 0

      # Print summary
      logger.info("\n" + "="*60)
      logger.info("ACCURACY TEST RESULTS")
      logger.info("="*60)
      logger.info(f"Total tests: {results['total_tests']}")
      logger.info(f"Correct matches: {results['correct_matches']}")
      logger.info(f"False positives: {results['false_positives']}")
      logger.info(f"False negatives: {results['false_negatives']}")
      logger.info(f"\nPrecision: {precision:.1%}")
      logger.info(f"Recall: {recall:.1%}")
      logger.info(f"F1 Score: {f1_score:.1%}")
      logger.info(f"\nAverage similarity: {avg_score:.3f}")
      logger.info(f"Min similarity: {min_score:.3f}")
      logger.info(f"Max similarity: {max_score:.3f}")
      logger.info("="*60)

      # Determine pass/fail
      if precision >= 0.85 and recall >= 0.75:
          logger.info("✅ PASSED: Accuracy meets requirements")
      else:
          logger.info("❌ FAILED: Accuracy below threshold")

      return {
          "precision": precision,
          "recall": recall,
          "f1_score": f1_score,
          "avg_score": avg_score
      }

  if __name__ == "__main__":
      logging.basicConfig(
          level=logging.INFO,
          format='%(levelname)s - %(message)s'
      )

      asyncio.run(test_faq_accuracy())
  ```

**What to Test:**
1. Ensure Qdrant is running: `docker-compose up -d qdrant`
2. Run accuracy test: `python -m scripts.test_faq_accuracy`
3. Verify test completes without errors
4. Check results:
   - Precision should be >=85% (few wrong matches)
   - Recall should be >=75% (catches most similar questions)
   - F1 score should be >=80%
5. Review individual test results for patterns
6. Check similarity score distribution:
   - Most scores should be 0.85-0.95
   - Very high scores (>0.95) indicate near-duplicates
7. Investigate any false positives - why did it match wrong question?
8. Investigate false negatives - why didn't it find a match?
9. Consider adjusting threshold based on results
10. Run test multiple times - results should be consistent

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/test_faq_accuracy.py` - NEW: Accuracy validation script

**Notes:**
- Uses demo scenarios as ground truth for testing
- Precision >85% means low false positive rate (good UX)
- Recall >75% means catches most duplicates (good coverage)
- F1 score balances both metrics
- Can adjust thresholds based on observed performance
- Test should be re-run after any embedding model changes
- Consider adding to CI/CD pipeline for regression testing

---

### PR 5.4: Add README and Documentation

**Goal:** Document the FAQ detection system for future developers.

**Tasks:**
- [ ] Create `/Users/Gauntlet/gauntlet/CreatorLink/python-service/README.md` (or update existing)
- [ ] Add sections:
  ```markdown
  # CreatorLink AI Service

  Python FastAPI service for AI-powered features in CreatorLink iOS app.

  ## Features

  - **FAQ Detection**: Automatically detects when users ask questions that have been answered before
  - **Semantic Search**: Uses OpenAI embeddings and Qdrant vector database for similarity matching
  - **Firestore Integration**: Seamlessly integrates with Firebase backend

  ## Architecture

  - **API**: FastAPI (Python 3.12+)
  - **Vector DB**: Qdrant for embeddings storage and search
  - **Embeddings**: OpenAI text-embedding-3-small (1536 dimensions)
  - **Storage**: Firebase Firestore for messages and conversations

  ## Setup

  ### Prerequisites

  - Python 3.12+
  - Docker and Docker Compose
  - OpenAI API key
  - Firebase project with emulator

  ### Installation

  1. Install dependencies:
  ```bash
  cd python-service
  pip install -r requirements.txt
  ```

  2. Configure environment:
  ```bash
  cp .env.example .env
  # Edit .env and add your OPENAI_API_KEY
  ```

  3. Start Qdrant:
  ```bash
  docker-compose up -d qdrant
  ```

  4. Start Python service:
  ```bash
  python -m app.main
  ```

  ## Usage

  ### Running the Service

  ```bash
  # Development
  python -m app.main

  # Production
  uvicorn app.main:app --host 0.0.0.0 --port 8000
  ```

  ### Seeding Historical Data

  ```bash
  # Seed existing messages
  python -m scripts.seed_embeddings

  # Create demo FAQ data
  python -m scripts.seed_demo_data <conversation-id>

  # Test accuracy
  python -m scripts.test_faq_accuracy
  ```

  ## API Endpoints

  - `GET /` - Health check
  - `GET /health` - Detailed health status
  - `POST /process-message` - Process incoming message for FAQ detection

  ## Configuration

  Environment variables (in `.env`):

  - `OPENAI_API_KEY` - OpenAI API key (required)
  - `QDRANT_HOST` - Qdrant host (default: localhost)
  - `QDRANT_PORT` - Qdrant port (default: 6333)
  - `FIRESTORE_EMULATOR_HOST` - Firestore emulator (optional)

  ## How It Works

  1. **Message Received**: Cloud Function triggers on new message
  2. **Question Detection**: Text analysis determines if message is a question
  3. **Embedding Generation**: OpenAI creates 1536-dim vector
  4. **Similarity Search**: Qdrant finds similar questions (>0.85 threshold)
  5. **Answer Lookup**: Fetches original answer from Firestore
  6. **Response Creation**: AI message with FAQ reference created

  ## Cost Estimation

  - Embeddings: ~$0.02 per 1M tokens
  - Typical message: 50 tokens
  - 1,000 messages/day = 50K tokens = $0.001/day
  - Annual cost for 1K daily messages: ~$0.36

  ## Development

  ### Project Structure

  ```
  python-service/
  ├── app/
  │   ├── main.py              # FastAPI app
  │   ├── firebase_client.py   # Firestore operations
  │   ├── embeddings.py        # OpenAI embeddings
  │   ├── vector_store.py      # Qdrant operations
  │   ├── text_analysis.py     # Question detection
  │   └── faq_service.py       # Core FAQ logic
  ├── scripts/
  │   ├── seed_embeddings.py   # Historical data seeding
  │   ├── seed_demo_data.py    # Demo FAQ scenarios
  │   └── test_faq_accuracy.py # Accuracy validation
  ├── tests/                    # Unit tests
  ├── docker-compose.yml        # Local services
  └── requirements.txt          # Python dependencies
  ```

  ## Troubleshooting

  **Issue**: Qdrant connection failed
  - Solution: Ensure Docker container is running: `docker ps | grep qdrant`

  **Issue**: OpenAI rate limit
  - Solution: Upgrade API tier or reduce batch size

  **Issue**: FAQ not detecting similar questions
  - Solution: Check similarity threshold (default 0.85), run accuracy test

  ## Testing

  ```bash
  # Run accuracy tests
  python -m scripts.test_faq_accuracy

  # Expected results:
  # - Precision >= 85%
  # - Recall >= 75%
  # - F1 Score >= 80%
  ```

  ## License

  [Your License]
  ```
- [ ] Create `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/README.md`:
  ```markdown
  # FAQ Detection Scripts

  Utility scripts for managing FAQ detection system.

  ## Scripts

  ### seed_embeddings.py

  Processes existing messages and populates vector database.

  **Usage:**
  ```bash
  python -m scripts.seed_embeddings [options]

  Options:
    --batch-size N    Batch size for embeddings (default: 100)
    --dry-run         Don't actually insert (test mode)
    --verbose         Enable debug logging
  ```

  **Example:**
  ```bash
  # Dry run to see what would be processed
  python -m scripts.seed_embeddings --dry-run

  # Process with smaller batches
  python -m scripts.seed_embeddings --batch-size 50
  ```

  ### seed_demo_data.py

  Creates demo FAQ scenarios for testing.

  **Usage:**
  ```bash
  python -m scripts.seed_demo_data <conversation-id>
  ```

  ### test_faq_accuracy.py

  Validates FAQ matching accuracy.

  **Usage:**
  ```bash
  python -m scripts.test_faq_accuracy
  ```

  ## Workflow

  1. **First Time Setup**:
     - Create AI-enabled conversation
     - Run `seed_demo_data` to create test Q&A pairs
     - Run `seed_embeddings` to populate vector DB
     - Run `test_faq_accuracy` to validate

  2. **Production Deployment**:
     - Ensure all conversations have `aiEnabled` flag
     - Run `seed_embeddings` to process existing messages
     - Monitor accuracy metrics

  3. **Ongoing Maintenance**:
     - Re-run seeding after large data imports
     - Test accuracy periodically
     - Adjust similarity thresholds based on results
  ```

**What to Test:**
1. Read through README - verify all instructions are clear
2. Follow setup steps from scratch on clean system
3. Verify all commands work as documented
4. Check that configuration variables are explained
5. Test troubleshooting steps
6. Ensure cost estimates are accurate
7. Verify project structure matches reality
8. Check that links and references are correct
9. Test example commands
10. Have someone unfamiliar with project follow README

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/README.md` - NEW or UPDATED: Service documentation
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/README.md` - NEW: Scripts documentation

**Notes:**
- Documentation is critical for maintainability
- Include examples for all common tasks
- Explain architecture and design decisions
- Document cost implications clearly
- Provide troubleshooting for common issues
- Keep README updated as code evolves
- Consider adding diagrams for visual learners

---

## Success Criteria

Implementation is complete when all of the following are verified:

**Phase 3: FAQ Detection Service**
- [ ] Qdrant vector database running via Docker
- [ ] VectorStore module creates collections and manages embeddings
- [ ] EmbeddingService generates OpenAI embeddings correctly
- [ ] Text analysis correctly identifies questions (>80% accuracy)
- [ ] FAQService embeds messages and detects similar questions
- [ ] FAQ detection integrated with `/process-message` endpoint
- [ ] Similarity threshold (0.85) works as expected

**Phase 4: Firestore Integration**
- [ ] FirebaseClient can query conversations and messages
- [ ] Answer discovery finds appropriate follow-up messages
- [ ] FAQ response messages created with correct metadata
- [ ] Metadata keys match iOS expectations (faqReference, matchConfidence)
- [ ] Response text formatted based on confidence level
- [ ] User display names fetched and included in responses
- [ ] Edge cases handled (deleted messages, missing users)

**Phase 5: Historical Data Seeding**
- [ ] Historical embedding script processes existing messages
- [ ] Batch embedding generation works efficiently
- [ ] Cost estimation provided before processing
- [ ] Demo data script creates realistic FAQ scenarios
- [ ] Accuracy testing validates >85% precision, >75% recall
- [ ] README documentation comprehensive and accurate
- [ ] All scripts work as documented

**Overall Integration**
- [ ] Complete flow: message → embed → search → find answer → create response
- [ ] FAQ responses appear in iOS app with proper styling
- [ ] FAQ links scroll to referenced messages
- [ ] No crashes or unhandled errors in production
- [ ] Logging provides complete audit trail
- [ ] Performance acceptable (<500ms for FAQ detection)

---

## Testing Matrix

### End-to-End Testing Scenarios

#### Scenario 1: First-Time FAQ Match
1. Create AI-enabled conversation with 2 users
2. User A asks: "What are your consulting rates?"
3. User B answers: "My rates are $500/hour"
4. Wait for embedding (check logs)
5. User C asks: "How much do you charge for consulting?"
6. **Verify**: Python logs show similar question found (score >0.85)
7. **Verify**: FAQ response created in Firestore
8. **Verify**: iOS displays FAQ message with link
9. Tap FAQ link in iOS
10. **Verify**: Scrolls to User B's answer

#### Scenario 2: No Match (New Question)
1. User asks: "What's the weather like today?"
2. **Verify**: Python logs show "No similar questions found"
3. **Verify**: No FAQ response created
4. **Verify**: Message still embedded for future reference

#### Scenario 3: Historical Data Seeding
1. Create conversation with 50 messages
2. Enable AI on conversation
3. Run: `python -m scripts.seed_embeddings`
4. **Verify**: All 50 messages embedded (check logs)
5. **Verify**: Qdrant has 50 points in collection
6. Ask similar question to one from history
7. **Verify**: FAQ match found and response created

#### Scenario 4: Demo Data Testing
1. Create new AI-enabled conversation
2. Run: `python -m scripts.seed_demo_data <conv-id>`
3. **Verify**: 5 FAQ scenarios created (15 messages total)
4. Ask: "How much do you charge?"
5. **Verify**: Matches "What are your rates for consulting?"
6. **Verify**: References answer about $500/hour
7. Test all 5 demo scenarios with similar questions

#### Scenario 5: Accuracy Validation
1. Run: `python -m scripts.test_faq_accuracy`
2. **Verify**: Precision >= 85%
3. **Verify**: Recall >= 75%
4. **Verify**: F1 score >= 80%
5. **Verify**: Average similarity score in reasonable range
6. If tests fail, investigate and tune thresholds

#### Scenario 6: Edge Cases
1. Test with deleted answer message
2. **Verify**: FAQ response not created (graceful handling)
3. Test with AI sender
4. **Verify**: Message skipped entirely
5. Test with very long message (>8191 tokens)
6. **Verify**: Text truncated, embedding generated
7. Test with empty/whitespace message
8. **Verify**: Handled gracefully, no crash

---

## Common Issues and Solutions

### Issue: Qdrant connection failed
**Solution**:
- Check Docker is running: `docker ps`
- Start Qdrant: `docker-compose up -d qdrant`
- Verify port 6333 is not in use
- Check Qdrant logs: `docker logs <container-id>`

### Issue: OpenAI rate limit exceeded
**Solution**:
- Upgrade API tier at platform.openai.com
- Reduce batch size in seeding script
- Add retry logic with exponential backoff
- Monitor usage dashboard

### Issue: FAQ not finding similar questions
**Solution**:
- Check similarity threshold (try lowering to 0.80 for testing)
- Run accuracy test to validate embeddings
- Verify questions are being classified correctly
- Check Qdrant collection has embeddings: `curl localhost:6333/collections/message_embeddings`

### Issue: Embeddings cost more than expected
**Solution**:
- Check token counts in seeding logs
- Verify using text-embedding-3-small (not large)
- Don't re-embed messages (upsert is idempotent)
- Consider caching for frequently asked questions

### Issue: Firebase permission denied
**Solution**:
- Check Firestore rules allow AI service account
- Verify FIRESTORE_EMULATOR_HOST is set for local
- Ensure conversation has `aiEnabled: true`
- Check participantIds includes ai-assistant

### Issue: Slow FAQ detection (>2 seconds)
**Solution**:
- Check Qdrant response time (should be <50ms)
- Verify OpenAI embedding latency (<500ms)
- Reduce top_k in search (currently 1)
- Consider caching recent embeddings
- Check network latency to services

---

## Files Summary

### New Files Created

| File | Purpose |
|------|---------|
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/docker-compose.yml` | Qdrant service definition |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/vector_store.py` | Qdrant vector DB operations |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/embeddings.py` | OpenAI embedding generation |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/text_analysis.py` | Question/answer detection |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/faq_service.py` | Core FAQ detection logic |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/seed_embeddings.py` | Historical data seeding |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/seed_demo_data.py` | Demo FAQ scenarios |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/test_faq_accuracy.py` | Accuracy validation |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/README.md` | Service documentation |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/scripts/README.md` | Scripts documentation |

### Files Modified

| File | Changes |
|------|---------|
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/requirements.txt` | Add qdrant-client, openai, tiktoken |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.env.example` | Add Qdrant and OpenAI config |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py` | Integrate FAQ service |
| `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py` | Add query and FAQ methods |

---

## Next Steps

After completing Phases 3-5:

1. **Production Deployment**:
   - Deploy Qdrant to cloud (Qdrant Cloud or Kubernetes)
   - Update environment variables for production
   - Run historical seeding on production data
   - Monitor FAQ match rates and accuracy

2. **Optimization**:
   - Add Redis caching for frequent embeddings
   - Implement embedding batch queue for high volume
   - Add analytics tracking for FAQ effectiveness
   - Optimize Qdrant performance (quantization, indexing)

3. **Advanced Features**:
   - Multi-language support for embeddings
   - Contextual answer synthesis (combine multiple answers)
   - User feedback on FAQ matches ("Was this helpful?")
   - Admin dashboard for FAQ analytics

4. **Monitoring**:
   - Set up error alerting (Sentry, CloudWatch)
   - Track FAQ match rate metrics
   - Monitor OpenAI API costs
   - Log Qdrant performance metrics

---

**Document Version:** 1.0
**Last Updated:** 2025-10-23
**Status:** Ready for Implementation
**Dependencies:** iOS Phases 1-2 complete, Firebase Cloud Functions updated
