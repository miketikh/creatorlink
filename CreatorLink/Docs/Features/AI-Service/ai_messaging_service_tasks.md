# AI Messaging Service Implementation Tasks (Phases 1-3)

## Context

This document provides step-by-step implementation tasks for integrating an AI messaging service into CreatorLink, a Swift/SwiftUI iOS messaging app with Firebase backend. The approach creates a complete AI-powered messaging pipeline that runs entirely on localhost for development and testing.

**What this provides:**
- Firebase Cloud Functions that trigger on new Firestore messages
- Python FastAPI service that processes messages using AI agents
- Integration with LangChain/LangGraph for future AI capabilities
- Seamless iOS app integration via existing Firestore listeners
- Complete local development environment using Firebase emulators

**Architecture Overview:**
```
iOS App (Simulator)
    ↓ writes message to Firestore
Firebase Firestore Emulator (localhost:8080)
    ↓ triggers onCreate function
Cloud Function (localhost:5001)
    ↓ HTTP POST to Python server
Python FastAPI Server (localhost:8000)
    ↓ processes with AI agents
    ↓ writes response back to Firestore
iOS App receives response via real-time listener
```

**Current State:**
- iOS app successfully connects to Firebase emulators
- Message model includes optional `metadata` field for AI features
- Firebase emulators running from `/firebase` folder (Auth, Firestore, Realtime DB, Storage)
- No Cloud Functions setup yet
- No Python service yet

This implementation is broken into 3 phases that build on each other. Each phase can be tested independently before moving to the next.

---

## Instructions for AI Agent

When implementing these tasks:
1. **Work sequentially** - Complete Phase 1 before Phase 2, etc.
2. **Test after each PR** - Follow the "What to Test" instructions to verify functionality
3. **Validate environment** - Ensure Firebase emulators are running before testing
4. **Use absolute paths** - All file paths are absolute for consistency
5. **Follow existing patterns** - Reference the plan document for implementation details
6. **Don't skip validation** - Each phase has critical validation steps
7. **CRITICAL: Rebuild Firebase Functions after changes** - After modifying any TypeScript code in `/firebase/functions/src/`, you MUST run `npm run build` in the functions directory. The Firebase emulator does NOT always auto-reload function changes. If functions aren't behaving as expected, rebuild and restart the emulator.

**File path conventions:**
- Firebase Functions: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/`
- Python Service: `/Users/Gauntlet/gauntlet/CreatorLink/python-service/`
- iOS App: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/`

---

## Phase 1: Firebase Cloud Functions Setup

**Estimated Time:** 1-2 hours

This phase adds Cloud Functions to the Firebase emulator setup to detect new messages and trigger the Python AI service.

### PR 1.1: Initialize Firebase Functions Directory

**Goal:** Set up the Firebase Functions directory structure and install required dependencies.

**Tasks:**
- [ ] Navigate to `/Users/Gauntlet/gauntlet/CreatorLink/firebase` directory
- [ ] Check if `functions` directory already exists
  - If it exists, verify it has proper structure (src/, package.json, tsconfig.json)
  - If it doesn't exist, initialize it using `firebase init functions`
- [ ] Install required npm packages in functions directory:
  - `firebase-functions` (Cloud Functions SDK)
  - `firebase-admin` (Firebase Admin SDK for Firestore access)
  - `axios` (HTTP client for calling Python server)
- [ ] Verify TypeScript configuration is present (tsconfig.json)
- [ ] Verify package.json has correct scripts for building and serving
- [ ] Create basic directory structure:
  - `/functions/src/` for TypeScript source files
  - `/functions/lib/` will be generated for compiled JavaScript

**What to Test:**
1. Verify functions directory exists at `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions`
2. Run `npm install` in functions directory and verify no errors
3. Verify node_modules directory is created
4. Check package.json contains firebase-functions, firebase-admin, and axios dependencies
5. Verify tsconfig.json exists and is properly configured
6. Run `npm run build` to ensure TypeScript compilation works
7. Verify lib/ directory is created with compiled JavaScript

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/package.json` - NEW or UPDATED: Dependencies and scripts
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/tsconfig.json` - NEW: TypeScript configuration
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/.gitignore` - NEW: Ignore node_modules and lib directories

**Notes:**
- If firebase init prompts for language choice, select TypeScript
- If prompted to install dependencies, choose Yes
- If prompted to use ESLint, you can skip it for MVP
- Firebase Functions v2 is recommended but v1 is acceptable for local development
- Keep dependencies up to date - use latest stable versions

---

### PR 1.2: Update firebase.json for Functions Emulator

**Goal:** Configure Firebase emulators to include Cloud Functions support.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/firebase/firebase.json`
- [ ] Add `functions` configuration section if not present:
  - Set `"source": "functions"` to point to functions directory
- [ ] Add functions emulator configuration to `emulators` section:
  - Set functions emulator port to `5001`
- [ ] Verify existing emulator configurations remain unchanged:
  - Auth: 9099
  - Firestore: 8080
  - Database: 9000
  - Storage: 9199
- [ ] Ensure `singleProjectMode: true` is set for emulator coordination
- [ ] Verify UI emulator is enabled for debugging

**What to Test:**
1. Open `/Users/Gauntlet/gauntlet/CreatorLink/firebase/firebase.json`
2. Verify `functions` section exists with `"source": "functions"`
3. Verify `emulators.functions` section exists with `"port": 5001`
4. Run `firebase emulators:start` and verify functions emulator starts
5. Access Firebase Emulator UI at http://localhost:4000
6. Verify Functions tab appears in the UI
7. Stop emulators and verify graceful shutdown

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/firebase.json` - Add functions configuration and emulator settings

**Notes:**
- Port 5001 is the standard port for Cloud Functions emulator
- singleProjectMode ensures all emulators use the same project ID
- Functions emulator automatically connects to other running emulators (Firestore, Auth, etc.)
- If port 5001 is in use, choose an alternative and document it

---

### PR 1.3: Create Message Trigger Cloud Function

**Goal:** Implement a Cloud Function that triggers on new messages and calls the Python server.

**Tasks:**
- [ ] Create or open `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts`
- [ ] Import required modules:
  - `firebase-functions` for function triggers
  - `firebase-admin` for Firestore access
  - `axios` for HTTP requests
- [ ] Initialize Firebase Admin SDK (call `admin.initializeApp()` once)
- [ ] Create `onMessageCreated` function:
  - Use `functions.firestore.document('messages/{messageId}').onCreate()` trigger
  - Extract message data from snapshot
  - Extract messageId from context parameters
  - Log message details (messageId, text, senderId) for debugging
- [ ] Implement Python server call logic:
  - Construct request payload with all message fields:
    - messageId, conversationId, senderId, text, timestamp, participantIds
  - Make POST request to `http://localhost:8000/process-message`
  - Set 30-second timeout for the request
  - Log response from Python server
- [ ] Add error handling:
  - Catch axios errors and log them
  - Don't throw errors (prevents infinite retry loops)
  - Return success even if Python server is unavailable
- [ ] Export the function so Firebase can discover it

**What to Test:**
1. Build functions with `npm run build` - verify no TypeScript errors
2. Start Firebase emulators with `firebase emulators:start`
3. Verify function appears in Emulator UI Functions tab
4. Check emulator logs show "Function onMessageCreated deployed"
5. Create a test message in Firestore via Emulator UI:
   - Collection: `messages`
   - Add fields: conversationId, senderId, participantIds, text, timestamp, status, readBy
6. Watch function logs for trigger activation
7. Verify log shows "New message detected: {messageId}"
8. Verify log shows attempt to call Python server (will fail - Python server not running yet)
9. Verify function completes without crashing despite Python server error

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts` - NEW: Message trigger function implementation

**Notes:**
- Use `console.log` for debugging - logs appear in emulator terminal
- The onCreate trigger fires only for new documents, not updates
- Participant IDs should be passed to Python server for context
- Error handling is critical - function should never crash and retry endlessly
- The 30-second timeout prevents hanging if Python server is slow or down
- Message metadata field can be used to determine if message should trigger AI

---

### PR 1.4: Test Functions Locally with Emulator

**Goal:** Validate that Cloud Functions trigger correctly when messages are created.

**Tasks:**
- [ ] Start Firebase emulators with `firebase emulators:start` from firebase directory
- [ ] Verify all emulators start successfully:
  - Auth, Firestore, Database, Storage, Functions emulators
- [ ] Open Firebase Emulator UI at http://localhost:4000
- [ ] Navigate to Functions tab and verify `onMessageCreated` is listed
- [ ] Use Firestore tab to create a test message document:
  - Collection: `messages`
  - Sample data structure matching Message model
- [ ] Monitor Functions logs tab in Emulator UI
- [ ] Verify function triggers and logs appear
- [ ] Test with multiple messages to verify each triggers the function
- [ ] Test error scenarios:
  - Message with missing fields
  - Malformed data
- [ ] Verify functions remain stable and don't crash

**What to Test:**
1. Emulators start without errors
2. Functions emulator is running on port 5001
3. Emulator UI is accessible at http://localhost:4000
4. Function `onMessageCreated` appears in Functions tab
5. Creating a message in Firestore triggers the function
6. Function logs show message data correctly
7. Function attempts to call Python server (expect connection refused error - this is OK)
8. Function completes and doesn't retry
9. Multiple messages trigger multiple function calls
10. Invalid messages are handled gracefully (logged but don't crash)

**Files Changed:**
- None - this is a testing/validation PR

**Notes:**
- Keep emulator terminal window open to see live logs
- Emulator UI logs are easier to read than terminal logs
- Connection refused errors are expected since Python server isn't running yet
- Each message should trigger exactly once
- If function triggers twice, check for duplicate onCreate listeners

---

## Phase 2: Python FastAPI Service Setup

**Estimated Time:** 2-3 hours

This phase creates the Python FastAPI server that receives function calls, processes messages with AI agents, and writes responses back to Firestore.

### PR 2.1: Create Python Service Directory Structure

**Goal:** Set up the Python service directory with proper structure and package files.

**Tasks:**
- [ ] Create directory `/Users/Gauntlet/gauntlet/CreatorLink/python-service`
- [ ] Create subdirectory `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app`
- [ ] Create `__init__.py` files:
  - `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/__init__.py` (can be empty)
- [ ] Create placeholder files for main components:
  - `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py` (empty for now)
  - `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py` (empty for now)
  - `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/ai_agents.py` (empty for now)
- [ ] Create `.gitignore` file in python-service directory:
  - Ignore `venv/`, `__pycache__/`, `.env`, `*.pyc`, `.DS_Store`
- [ ] Create `README.md` with basic setup instructions
- [ ] Initialize Python virtual environment (optional but recommended):
  - Run `python3 -m venv venv` in python-service directory

**What to Test:**
1. Verify directory structure exists at `/Users/Gauntlet/gauntlet/CreatorLink/python-service`
2. Verify `app/` subdirectory contains `__init__.py`
3. Verify placeholder files exist (main.py, firebase_client.py, ai_agents.py)
4. Verify .gitignore file is created
5. If venv created, verify `venv/` directory exists
6. Activate venv and verify Python version (should be 3.9+)
7. Check README.md is readable and informative

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/__init__.py` - NEW: Package initialization
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py` - NEW: Placeholder for FastAPI app
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py` - NEW: Placeholder for Firebase client
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/ai_agents.py` - NEW: Placeholder for AI agents
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.gitignore` - NEW: Git ignore rules
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/README.md` - NEW: Setup and usage documentation

**Notes:**
- Use Python 3.9 or later for compatibility with Firebase Admin SDK
- Virtual environment is highly recommended to avoid dependency conflicts
- Keep directory structure flat and simple for MVP
- README should include commands for setup, installation, and running

---

### PR 2.2: Create requirements.txt with Dependencies

**Goal:** Define all Python dependencies needed for the AI messaging service.

**Tasks:**
- [ ] Create `/Users/Gauntlet/gauntlet/CreatorLink/python-service/requirements.txt`
- [ ] Add FastAPI and server dependencies:
  - `fastapi==0.109.0` (or latest stable)
  - `uvicorn[standard]==0.27.0` (ASGI server with websocket support)
  - `pydantic==2.5.0` (data validation)
  - `python-dotenv==1.0.0` (environment variable management)
- [ ] Add Firebase dependencies:
  - `firebase-admin==6.4.0` (or latest stable)
- [ ] Add AI/ML dependencies (start minimal):
  - `langchain==0.1.0` (or latest stable)
  - `langchain-openai==0.0.5` (OpenAI integration for future)
  - `langgraph==0.0.20` (graph-based agent orchestration)
- [ ] Add HTTP client:
  - `httpx==0.26.0` (async HTTP client)
- [ ] Add comments explaining each dependency category
- [ ] Pin versions for reproducibility

**What to Test:**
1. Verify requirements.txt exists at correct path
2. Activate Python virtual environment (if using one)
3. Run `pip install -r requirements.txt` from python-service directory
4. Verify all packages install without errors
5. Check for dependency conflicts
6. Verify installation with `pip list` - all packages should appear
7. Test imports in Python REPL:
   - `import fastapi`
   - `import firebase_admin`
   - `import langchain`
8. Verify no version conflicts or warnings

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/requirements.txt` - NEW: Python dependencies

**Notes:**
- Pin exact versions to ensure reproducibility across environments
- Use latest stable versions as of 2025 (check PyPI for current versions)
- LangChain ecosystem updates frequently - versions may differ
- Consider adding `# comments` to group dependencies logically
- If installation fails, check Python version compatibility

---

### PR 2.3: Create .env Configuration File

**Goal:** Set up environment variables for connecting to Firebase emulators and configuring the service.

**Tasks:**
- [ ] Create `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.env`
- [ ] Add Firebase emulator connection variables:
  - `FIRESTORE_EMULATOR_HOST=localhost:8080`
  - `FIREBASE_AUTH_EMULATOR_HOST=localhost:9099`
  - `FIREBASE_DATABASE_EMULATOR_URL=http://localhost:9000`
  - `FIREBASE_STORAGE_EMULATOR_HOST=localhost:9199`
- [ ] Add FastAPI server configuration:
  - `HOST=0.0.0.0` (bind to all interfaces for container compatibility)
  - `PORT=8000`
- [ ] Add placeholder for future AI configuration:
  - `# OPENAI_API_KEY=your-key-here` (commented out for MVP)
  - `# QDRANT_URL=http://localhost:6333` (commented out for MVP)
- [ ] Add comments explaining each variable
- [ ] Create `.env.example` file with same structure but placeholder values

**What to Test:**
1. Verify .env file exists at `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.env`
2. Verify all required environment variables are present
3. Verify Firebase emulator ports match firebase.json configuration
4. Verify HOST is set to `0.0.0.0` for proper network binding
5. Verify PORT is set to `8000`
6. Verify .env.example exists for documentation
7. Verify .env is in .gitignore (don't commit secrets)
8. Test loading environment variables:
   - Create test Python script that loads .env
   - Use `python-dotenv` to load variables
   - Print variables to verify they're accessible

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.env` - NEW: Environment configuration (not committed to git)
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.env.example` - NEW: Example configuration (committed to git)

**Notes:**
- .env file should NEVER be committed to git
- .env.example serves as documentation for required variables
- Firebase emulator environment variables tell SDK to connect to emulators instead of production
- HOST=0.0.0.0 allows access from other containers/machines if needed
- For production, these would point to real Firebase project

---

### PR 2.4: Implement Firebase Client

**Goal:** Create a Firebase Admin SDK client that connects to emulators and can write messages to Firestore.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py`
- [ ] Import required modules:
  - `os` for environment variables
  - `logging` for debug output
  - `datetime` for timestamps
  - `typing` for type hints
  - `firebase_admin` and `firebase_admin.credentials`
  - `firebase_admin.firestore`
- [ ] Create `FirebaseClient` class with initialization logic:
  - Check for `FIRESTORE_EMULATOR_HOST` environment variable
  - If present, initialize Firebase Admin without credentials (emulator mode)
  - If not present, use application default credentials (production mode)
  - Initialize Firestore client: `self.db = firestore.client()`
  - Add logging to indicate emulator vs production mode
- [ ] Implement `check_connection()` method:
  - Attempt to list Firestore collections
  - Return dict with connection status and collection count
  - Handle and log errors gracefully
- [ ] Implement `send_message()` async method:
  - Accept parameters: conversationId, senderId, text, participantIds, metadata
  - Create message data dictionary matching Message model structure:
    - All required fields: conversationId, senderId, participantIds, text, status, readBy, imageUrl, metadata
    - Use `firestore.SERVER_TIMESTAMP` for timestamp
    - Default status to "sent"
    - Initialize readBy as empty dict
  - Write to Firestore `messages` collection
  - Return message document ID
- [ ] Implement `_update_conversation_last_message()` helper method:
  - Accept conversationId, lastMessage text, and senderId
  - Update conversation document with lastMessage, lastMessageTime, lastMessageSenderId, lastMessageStatus
  - Handle errors gracefully (don't fail message send if conversation update fails)

**What to Test:**
1. Start Firebase emulators
2. Create test Python script in python-service directory
3. Import FirebaseClient from app.firebase_client
4. Set environment variables (load from .env)
5. Initialize FirebaseClient instance
6. Call check_connection() and verify returns success
7. Test send_message() with sample data
8. Check Firestore emulator UI to verify message was created
9. Verify conversation document was updated with lastMessage
10. Test error handling with invalid data
11. Verify logging output is helpful and informative

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py` - Implement Firebase Admin SDK client

**Notes:**
- Firebase Admin SDK automatically detects emulator mode via environment variables
- No credentials needed when connecting to emulators
- For production, would need service account JSON file
- The `send_message` method should match the Message model structure exactly
- Conversation updates should be "best effort" - don't fail if they don't work
- Use async/await for future scalability even though Firebase Admin SDK is sync

---

### PR 2.5: Implement AI Agent (MVP Echo)

**Goal:** Create a simple AI agent class that echoes messages (MVP implementation - real AI in future).

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/ai_agents.py`
- [ ] Import required modules:
  - `logging` for debug output
  - `typing` for type hints
- [ ] Create `AIAgent` class:
  - Add `__init__` method with initialization logging
  - Add TODO comments for future LangChain/LangGraph integration
- [ ] Implement `process()` async method:
  - Accept `message_text: str` parameter
  - For MVP: return simple acknowledgment: `f"ACK: Received '{message_text}'"`
  - Add logging to track message processing
  - Add TODO comments for future implementation:
    - Parse intent using LangChain
    - Route to appropriate agent using LangGraph
    - Query vector DB if needed
    - Generate contextual response
  - Return response string
- [ ] Implement `get_agent_info()` method:
  - Return dictionary with agent metadata:
    - name: "EchoAgent"
    - version: "0.1.0"
    - capabilities: ["echo", "acknowledge"]
    - mode: "MVP"
  - Useful for debugging and future expansion

**What to Test:**
1. Create test Python script
2. Import AIAgent from app.ai_agents
3. Initialize AIAgent instance
4. Call process() with various test messages
5. Verify responses are formatted correctly: "ACK: Received '{text}'"
6. Call get_agent_info() and verify metadata is returned
7. Verify logging output is visible
8. Test with empty strings, long messages, special characters
9. Verify async method works correctly (can be awaited)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/ai_agents.py` - Implement MVP echo agent

**Notes:**
- Echo agent is intentionally simple for MVP - validates pipeline works
- Real AI implementation will replace this logic
- Keep structure flexible for future multi-agent systems
- Async is used for future compatibility with LLM API calls
- get_agent_info() is useful for health checks and debugging

---

### PR 2.6: Implement FastAPI Application

**Goal:** Create the FastAPI server with endpoints for processing messages and health checks.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py`
- [ ] Import required modules:
  - FastAPI, HTTPException from fastapi
  - BaseModel from pydantic
  - List, Optional from typing
  - logging for debug output
  - datetime for timestamps
- [ ] Import local modules:
  - FirebaseClient from .firebase_client
  - AIAgent from .ai_agents
- [ ] Configure logging (INFO level)
- [ ] Create FastAPI app instance: `app = FastAPI(title="CreatorLink AI Service")`
- [ ] Initialize Firebase client: `firebase_client = FirebaseClient()`
- [ ] Initialize AI agent: `ai_agent = AIAgent()`
- [ ] Define Pydantic models:
  - `MessageRequest` with fields: messageId, conversationId, senderId, text, timestamp (dict), participantIds (list)
  - `MessageResponse` with fields: success (bool), message (str), responseMessageId (optional str)
- [ ] Implement `GET /` endpoint (root/health check):
  - Return dict with status="healthy", service name, and timestamp
- [ ] Implement `POST /process-message` endpoint:
  - Accept MessageRequest body
  - Log received message details
  - Call `ai_agent.process(request.text)` to get AI response
  - Call `firebase_client.send_message()` with:
    - conversationId from request
    - senderId = "ai-agent" (special AI user)
    - text = AI response
    - participantIds from request
    - metadata = {"ai_generated": True, "original_message_id": messageId, "agent_type": "echo"}
  - Return MessageResponse with success=True and response message ID
  - Handle errors with try/except, raise HTTPException on failure
- [ ] Implement `GET /health` endpoint (detailed health check):
  - Check Firebase connection using firebase_client.check_connection()
  - Return dict with status, firebase connection info, timestamp
  - Return "unhealthy" status if Firebase connection fails

**What to Test:**
1. Start Firebase emulators
2. Set environment variables (source .env or use python-dotenv)
3. Start FastAPI server: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload`
4. Verify server starts without errors
5. Access root endpoint: `curl http://localhost:8000/`
6. Verify returns healthy status and service name
7. Access health endpoint: `curl http://localhost:8000/health`
8. Verify Firebase connection status is reported
9. Test process-message endpoint:
   - Use curl or Postman to POST to `/process-message`
   - Send valid MessageRequest JSON
   - Verify response contains success=True
10. Check Firestore emulator UI - verify AI response message was created
11. Verify message has metadata with ai_generated=True
12. Test with invalid request data - verify error handling
13. Test with Firebase emulators stopped - verify graceful error handling

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py` - Implement FastAPI application with all endpoints

**Notes:**
- Use --reload flag during development for auto-restart on code changes
- Logging is critical for debugging - log all major operations
- AI user ID "ai-agent" must match what iOS app expects
- Metadata field enables iOS app to identify AI-generated messages
- Error handling prevents server crashes on bad requests
- Health endpoint is useful for monitoring and debugging

---

### PR 2.7: Create Startup Script

**Goal:** Create a convenience script to start the Python service with proper environment configuration.

**Tasks:**
- [ ] Create `/Users/Gauntlet/gauntlet/CreatorLink/python-service/run.sh`
- [ ] Add shebang line: `#!/bin/bash`
- [ ] Add comments explaining what the script does
- [ ] Add environment variable loading:
  - Check if .env file exists
  - Export variables from .env using `export $(cat .env | xargs)`
  - Add error message if .env doesn't exist
- [ ] Add uvicorn command to start server:
  - `uvicorn app.main:app --host $HOST --port $PORT --reload`
  - Use environment variables for host and port
  - Include --reload for development auto-restart
- [ ] Make script executable: `chmod +x run.sh`
- [ ] Add option to pass additional uvicorn arguments
- [ ] Add helpful output messages (server starting, listening on port, etc.)

**What to Test:**
1. Verify run.sh file exists and has correct permissions (chmod +x)
2. Verify shebang line is correct
3. Start Firebase emulators first
4. Run `./run.sh` from python-service directory
5. Verify .env file is loaded (check environment variables are set)
6. Verify server starts on port 8000
7. Verify can access http://localhost:8000/
8. Verify --reload works (edit code and see auto-restart)
9. Stop server with Ctrl+C and verify graceful shutdown
10. Test error case: rename .env file and verify error message
11. Test with custom port: `PORT=8001 ./run.sh`

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/run.sh` - NEW: Startup script for Python service

**Notes:**
- Script should be run from python-service directory
- Ensure virtual environment is activated before running (if using venv)
- Script makes it easy to start service with one command
- Environment variables from .env override any existing shell variables
- --reload is only for development, remove for production

---

## Phase 3: iOS App Integration

**Estimated Time:** 1 hour

This phase ensures the iOS app can receive and display AI-generated responses. Most functionality already exists via Firestore listeners.

### PR 3.1: Create AI User Profile in Seed Data

**Goal:** Add a special "AI Agent" user to the Firebase emulator seed data.

**Tasks:**
- [ ] Open `/Users/Gauntlet/gauntlet/CreatorLink/emulator-seed/seed.js`
- [ ] Locate the USERS array definition at the top of the file
- [ ] After the seedData() function starts, add AI user creation:
  - After existing user creation loop
  - Create auth user with email "ai@creatorlink.local"
  - Use fixed UID: "ai-agent" (use `auth.createUser()` with uid parameter)
  - Set displayName to "AI Assistant"
  - Set password to "password" (for consistency)
- [ ] Add Firestore user profile creation for AI user:
  - Collection: `users`
  - Document ID: "ai-agent"
  - Fields:
    - displayName: "AI Assistant"
    - email: "ai@creatorlink.local"
    - photoURL: Generate using UI Avatars API with "AI" text, use robot/bot color
    - isOnline: false (AI doesn't have online status)
    - lastSeen: current timestamp
- [ ] Add logging to confirm AI user creation
- [ ] Update README if needed to document AI user credentials

**What to Test:**
1. Stop Firebase emulators if running
2. Clear emulator data (delete firebase/emulator-data if exists)
3. Start Firebase emulators
4. Run seed script: `node emulator-seed/seed.js`
5. Verify script completes without errors
6. Verify logs show AI user creation
7. Open Firebase Emulator UI → Authentication tab
8. Verify "ai@creatorlink.local" user exists with UID "ai-agent"
9. Open Firestore tab → users collection
10. Verify ai-agent document exists with all fields
11. Verify photoURL is generated and displays correctly
12. Optional: Try signing in as AI user (should work but not necessary)

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/emulator-seed/seed.js` - Add AI agent user creation

**Notes:**
- AI user UID must be exactly "ai-agent" to match Python service
- AI user appears as a regular user in the system
- iOS app needs no changes to display messages from AI user
- Consider using a distinct photoURL (robot icon or special color) to visually identify AI
- AI user won't sign in to iOS app - only sends messages via Python service

---

### PR 3.2: Verify Message Listeners Handle AI Messages

**Goal:** Confirm existing iOS message listeners receive and display AI-generated messages.

**Tasks:**
- [ ] Open Xcode and navigate to iOS app project
- [ ] Locate message listening code (likely in MessageService or ChatDetailView)
- [ ] Review `listenToMessages()` or equivalent Firestore listener
- [ ] Verify listener doesn't filter messages by sender
  - Should receive messages from any senderId, including "ai-agent"
- [ ] Verify message display code handles all senders
  - Should fetch and display sender profile for any userId
- [ ] Check if metadata field is preserved through listener
  - AI messages have metadata.ai_generated = true
- [ ] Add logging to message listener for debugging (optional)
- [ ] No code changes should be needed - just verification

**What to Test:**
1. Start Firebase emulators
2. Run seed script to create AI user
3. Build and run iOS app in simulator
4. Sign in as test user (e.g., alice.johnson@test.com)
5. Open a conversation
6. Using Firestore Emulator UI, manually create a message:
   - Collection: messages
   - senderId: "ai-agent"
   - conversationId: [existing conversation ID]
   - participantIds: [include current user ID and ai-agent]
   - text: "Hello, I am the AI assistant!"
   - timestamp: current time
   - status: "sent"
   - readBy: {}
   - imageUrl: null
   - metadata: {"ai_generated": "true"}
7. Verify message appears in iOS app conversation view
8. Verify sender name shows "AI Assistant"
9. Verify AI user's photo appears (if avatars shown)
10. Verify message is indistinguishable from normal messages (except sender)

**Files Changed:**
- None - this is a verification PR, no code changes needed

**Notes:**
- Existing Firestore listeners should automatically receive AI messages
- iOS app already fetches user profiles by senderId
- Message metadata is optional and doesn't affect display
- If messages don't appear, check participantIds includes current user
- If sender name doesn't appear, check UserService fetches ai-agent profile

---

### PR 3.3: Optional - Add Visual Indicator for AI Messages

**Goal:** Optionally style AI messages differently to distinguish them from human messages.

**Tasks:**
- [ ] Decide if AI messages should be visually distinct (optional enhancement)
- [ ] If yes, locate MessageBubbleView or equivalent component
- [ ] Add check for AI-generated messages:
  - Check `message.metadata?["ai_generated"]` exists and equals "true"
  - Store in local variable `let isAIMessage = ...`
- [ ] Apply different styling if AI message:
  - Different background color (e.g., light purple or blue tint)
  - Optional: Add small "AI" badge or icon
  - Optional: Different text color or font style
- [ ] Ensure styling doesn't reduce readability
- [ ] Test with light and dark mode
- [ ] Keep changes minimal - should integrate with existing message bubble design

**What to Test:**
1. Start complete pipeline (Firebase emulators + Python service)
2. Send message from iOS app that triggers AI response
3. Wait for AI response to appear
4. Verify AI message has different visual styling
5. Verify styling looks good in light mode
6. Verify styling looks good in dark mode
7. Verify AI indicator (badge/icon) is visible but not obtrusive
8. Verify human messages retain original styling
9. Compare with/without AI indicator to ensure it adds value
10. Test with long AI messages to ensure styling scales

**Files Changed:**
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/MessageBubbleView.swift` - OPTIONAL: Add AI message styling
- OR similar message display component

**Notes:**
- This PR is completely optional - AI messages work fine without special styling
- Subtle styling (tinted background) is better than dramatic changes
- Consider accessibility - ensure color contrast meets standards
- AI badge/icon should be small and unobtrusive
- Could use SF Symbols for AI icon (brain, sparkles, etc.)
- Styling should match app's overall design language

---

## End-to-End Testing Checklist

After completing all three phases, verify the complete pipeline works:

### Complete Flow Test

**Setup:**
1. Start Firebase emulators: `cd firebase && firebase emulators:start`
2. Verify all emulators running (Auth, Firestore, Database, Storage, Functions)
3. Start Python service: `cd python-service && ./run.sh`
4. Verify Python service running at http://localhost:8000
5. Check Python service health: `curl http://localhost:8000/health`
6. Run seed script if fresh emulator data: `node emulator-seed/seed.js`
7. Build and run iOS app in simulator

**Test Scenario 1: Basic AI Response**
1. Open iOS app and sign in as Alice (alice.johnson@test.com / password)
2. Open or create a conversation
3. Send a message: "Hello AI"
4. Wait a few seconds
5. **Expected Results:**
   - Cloud Function triggers (check emulator logs)
   - Python service logs show message received
   - Python service logs show response created
   - AI response appears in iOS app: "ACK: Received 'Hello AI'"
   - Response shows sender "AI Assistant"
   - Response has different styling if PR 3.3 completed

**Test Scenario 2: Multiple Messages**
1. Send 3 messages in quick succession:
   - "First message"
   - "Second message"
   - "Third message"
2. **Expected Results:**
   - All 3 messages trigger Cloud Function
   - Python service receives all 3 calls
   - 3 AI responses appear in iOS app
   - Each response acknowledges correct original message
   - No duplicate responses
   - Responses appear in correct order

**Test Scenario 3: Group Conversation**
1. Create or open a group conversation with 3+ participants
2. Send a message in the group
3. **Expected Results:**
   - Cloud Function triggers
   - Python service receives message
   - AI response appears in group conversation
   - All group participants see AI response (test with multiple simulators if possible)
   - AI response includes all participantIds

**Test Scenario 4: Error Handling**
1. Stop Python service (Ctrl+C)
2. Send message from iOS app
3. **Expected Results:**
   - Message still appears in Firestore
   - Cloud Function logs show error calling Python service
   - No AI response appears (expected)
   - No crash or infinite retry
4. Restart Python service
5. Send another message
6. **Expected Results:**
   - AI response appears normally
   - System recovers gracefully

**Test Scenario 5: Metadata Verification**
1. Send message from iOS app
2. Wait for AI response
3. Open Firestore Emulator UI → messages collection
4. Find the AI response message
5. **Expected Results:**
   - senderId is "ai-agent"
   - metadata field exists
   - metadata.ai_generated is true
   - metadata.original_message_id matches original message ID
   - metadata.agent_type is "echo"

### Performance Verification

**Latency Test:**
1. Send message from iOS app
2. Start timer
3. Wait for AI response to appear
4. **Expected:** Total time < 2 seconds (typically 500ms-1000ms)

**Load Test:**
1. Send 10 messages rapidly (one per second)
2. **Expected:** All messages processed, all responses appear
3. No errors in logs
4. No significant slowdown

---

## Common Issues and Solutions

### Issue: Cloud Function doesn't trigger

**Symptoms:**
- Message appears in Firestore but no function logs
- Function not visible in Emulator UI Functions tab

**Solutions:**
- Verify functions emulator is running on port 5001
- Check firebase.json has functions configuration
- Rebuild functions: `cd firebase/functions && npm run build`
- Restart emulators
- Check function is exported in index.ts

---

### Issue: Python service connection refused

**Symptoms:**
- Cloud Function logs show "ECONNREFUSED localhost:8000"
- Function completes but no AI response

**Solutions:**
- Verify Python service is running: `curl http://localhost:8000`
- Check .env file has correct configuration
- Verify port 8000 is not in use: `lsof -i :8000` (Mac/Linux)
- Check firewall settings
- Verify Python service started without errors

---

### Issue: AI message doesn't appear in iOS app

**Symptoms:**
- Python logs show message sent
- Firestore shows AI message
- iOS app doesn't display it

**Solutions:**
- Verify AI user "ai-agent" exists in Firestore users collection
- Check message participantIds includes current user
- Verify iOS message listener is active
- Check conversation listener is running
- Restart iOS app to refresh listeners

---

### Issue: Firebase Admin SDK can't connect

**Symptoms:**
- Python service logs show Firestore errors
- "Failed to connect to Firestore" errors

**Solutions:**
- Verify `FIRESTORE_EMULATOR_HOST=localhost:8080` is set
- Check environment variables are loaded from .env
- Restart Python service after changing .env
- Verify Firebase emulators are running before starting Python service
- Check emulator ports match .env configuration

---

### Issue: Duplicate AI responses

**Symptoms:**
- One message triggers multiple AI responses
- Same message processed multiple times

**Solutions:**
- Check Cloud Function onCreate trigger only fires once
- Verify no duplicate function deployments
- Check Python service logs - should show one request per message
- Ensure no message retry loops
- Verify message IDs are unique

---

## Files Summary

### New Files Created

**Firebase Functions:**
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts` - Cloud Function message trigger
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/package.json` - Dependencies
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/tsconfig.json` - TypeScript config
- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/.gitignore` - Ignore build artifacts

**Python Service:**
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/__init__.py` - Package init
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py` - FastAPI application
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/firebase_client.py` - Firebase Admin client
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/ai_agents.py` - AI agent logic
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/requirements.txt` - Python dependencies
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.env` - Environment config (not committed)
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.env.example` - Example config
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/.gitignore` - Python ignore rules
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/run.sh` - Startup script
- `/Users/Gauntlet/gauntlet/CreatorLink/python-service/README.md` - Documentation

### Files Modified

- `/Users/Gauntlet/gauntlet/CreatorLink/firebase/firebase.json` - Add functions emulator config
- `/Users/Gauntlet/gauntlet/CreatorLink/emulator-seed/seed.js` - Add AI user creation

### No Changes Required

- iOS Message model (already has metadata field)
- iOS MessageService (already has real-time listeners)
- iOS chat views (already display messages from any sender)
- Firestore rules (AI user handled like any user)

---

## Success Criteria

Implementation is complete when:

- [ ] Firebase Functions emulator runs on port 5001
- [ ] Cloud Function triggers on new Firestore messages
- [ ] Cloud Function calls Python service successfully
- [ ] Python FastAPI service runs on port 8000
- [ ] Python service connects to Firestore emulator
- [ ] Python service processes messages and creates responses
- [ ] AI responses appear in iOS app conversation
- [ ] AI responses show sender "AI Assistant"
- [ ] Complete flow works end-to-end in <2 seconds
- [ ] System handles errors gracefully (no crashes)
- [ ] All services can be started with simple commands
- [ ] All services log helpful debugging information

---

## Next Steps

After completing Phases 1-3:

1. **Test thoroughly** using the End-to-End Testing Checklist above
2. **Gather feedback** on AI response behavior
3. **Consider Phase 4** (Testing and Debugging) from plan document
4. **Enhance AI agent** with real LLM integration:
   - Add OpenAI API key
   - Replace echo agent with LangChain LLM
   - Implement conversation context awareness
5. **Add vector database** for RAG (Retrieval Augmented Generation):
   - Set up Qdrant locally
   - Index conversation history
   - Retrieve relevant context for AI responses
6. **Implement multi-agent system** with LangGraph:
   - Router agent for intent classification
   - Specialized agents for different tasks
   - Agent orchestration and handoff

---

## Estimated Timeline

- **Phase 1** (Firebase Functions): 1-2 hours
  - PR 1.1: 15 minutes
  - PR 1.2: 15 minutes
  - PR 1.3: 30 minutes
  - PR 1.4: 15 minutes

- **Phase 2** (Python Service): 2-3 hours
  - PR 2.1: 15 minutes
  - PR 2.2: 15 minutes
  - PR 2.3: 15 minutes
  - PR 2.4: 45 minutes
  - PR 2.5: 20 minutes
  - PR 2.6: 45 minutes
  - PR 2.7: 15 minutes

- **Phase 3** (iOS Integration): 1 hour
  - PR 3.1: 30 minutes
  - PR 3.2: 15 minutes
  - PR 3.3: 15 minutes (optional)

**Total Implementation Time:** 4-6 hours for complete MVP

**Testing Time:** 1-2 hours for comprehensive end-to-end validation

---

**Document Version:** 1.0
**Last Updated:** 2025-10-23
**Status:** Ready for Implementation
