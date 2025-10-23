# AI-Integrated Messaging Service Implementation Plan

## Project Context

CreatorLink is a **local test iOS messaging app** built with Swift/SwiftUI and Firebase backend. This plan implements an AI-integrated messaging system that allows the iOS app to communicate with AI agents running on a Python backend server. The entire system runs locally using Firebase emulators for development and testing.

## Current State

- iOS app "CreatorLink" configured for debug mode on local simulators
- Firebase emulators running from `/firebase` folder with:
  - Authentication (port 9099)
  - Firestore (port 8080)
  - Realtime Database (port 9000)
  - Storage (port 9199)
- App successfully connects to Firebase emulators
- Message model includes optional `metadata` field for AI features

## What This Approach Provides

### MVP Goals:
- iOS app sends messages to Firestore
- Firebase Cloud Functions detect new messages
- Cloud Functions trigger Python FastAPI server
- Python server processes messages using LangChain/LangGraph agents
- Python server writes responses back to Firestore
- iOS app receives AI responses via real-time listeners

### Architecture Benefits:
- **Fully local development**: All services run on localhost
- **End-to-end testable**: Complete flow from iOS to AI and back
- **Scalable foundation**: Easy to add more complex AI agents later
- **Emulator-first**: No production Firebase required

## Proposed Architecture

```
iOS App (Simulator)
    ↓ writes message
Firebase Firestore Emulator (localhost:8080)
    ↓ triggers
Cloud Function (localhost:5001)
    ↓ HTTP POST
Python FastAPI Server (localhost:8000)
    ↓ processes with
LangChain/LangGraph Agents
    ↓ optional query
Qdrant Vector DB (localhost:6333)
    ↓ writes response
Firebase Firestore Emulator (localhost:8080)
    ↓ real-time listener
iOS App (Simulator)
```

## Implementation Phases

### Phase 1: Firebase Cloud Functions Setup (1-2 hours)

**Goal**: Add Cloud Functions to Firebase emulator setup to detect new messages

#### 1.1 Initialize Cloud Functions

**Location**: `/firebase` folder

**Tasks**:
- Install Firebase Functions in the firebase directory
- Initialize TypeScript functions
- Configure functions to run in emulator
- Set up basic project structure

**Commands**:
```bash
cd /Users/Gauntlet/gauntlet/CreatorLink/firebase
npm install firebase-functions firebase-admin
# If functions not initialized: firebase init functions
```

**Expected Structure**:
```
/firebase
  /functions
    /src
      index.ts          # Main functions export
    package.json
    tsconfig.json
  firebase.json         # Update to include functions
```

#### 1.2 Configure firebase.json for Functions

**Location**: `/firebase/firebase.json`

**Update**: Add functions emulator configuration

**Add**:
```json
{
  "firestore": { ... },
  "storage": { ... },
  "database": { ... },
  "functions": {
    "source": "functions"
  },
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "database": { "port": 9000 },
    "storage": { "port": 9199 },
    "functions": {
      "port": 5001
    },
    "ui": {
      "enabled": true
    },
    "singleProjectMode": true
  }
}
```

#### 1.3 Create Message Trigger Function (MVP)

**Location**: `/firebase/functions/src/index.ts`

**Purpose**: Detect new messages and call Python server

**Implementation**:
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';

admin.initializeApp();

// Trigger on new messages in Firestore
export const onMessageCreated = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const messageId = context.params.messageId;

    console.log(`New message detected: ${messageId}`);
    console.log(`Message text: ${message.text}`);
    console.log(`Sender: ${message.senderId}`);

    // Check if message should trigger AI (could be based on metadata or keyword)
    // For MVP: trigger on all messages (can filter later)

    try {
      // Call Python FastAPI server
      const response = await axios.post('http://localhost:8000/process-message', {
        messageId: messageId,
        conversationId: message.conversationId,
        senderId: message.senderId,
        text: message.text,
        timestamp: message.timestamp,
        participantIds: message.participantIds
      }, {
        timeout: 30000 // 30 second timeout
      });

      console.log('Python server response:', response.data);

    } catch (error) {
      console.error('Failed to call Python server:', error);
      // Don't throw - we don't want to retry indefinitely
    }
  });
```

**Dependencies to Add**:
```bash
cd /Users/Gauntlet/gauntlet/CreatorLink/firebase/functions
npm install axios
```

#### 1.4 Test Functions Locally

**Commands**:
```bash
cd /Users/Gauntlet/gauntlet/CreatorLink/firebase
firebase emulators:start
```

**Verification**:
- Functions emulator appears in UI at http://localhost:4000
- Functions tab shows `onMessageCreated` function
- Console shows functions loaded successfully

### Phase 2: Python FastAPI Service Setup (2-3 hours)

**Goal**: Create Python server that receives function calls and connects to Firebase emulators

#### 2.1 Create Python Service Directory

**Location**: Create `/python-service` at project root

**Structure**:
```
/python-service
  /app
    __init__.py
    main.py              # FastAPI app
    firebase_client.py   # Firebase Admin SDK
    ai_agents.py         # LangChain/LangGraph logic
  requirements.txt
  .env                   # Environment variables
  README.md
```

**Create directories**:
```bash
mkdir -p /Users/Gauntlet/gauntlet/CreatorLink/python-service/app
```

#### 2.2 Create requirements.txt

**Location**: `/python-service/requirements.txt`

**Content**:
```
# FastAPI and server
fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.5.0
python-dotenv==1.0.0

# Firebase Admin
firebase-admin==6.4.0

# AI/ML (start minimal, add as needed)
langchain==0.1.0
langchain-openai==0.0.5
langgraph==0.0.20

# Optional: Vector DB client (for future)
# qdrant-client==1.7.0

# HTTP client
httpx==0.26.0
```

#### 2.3 Create .env Configuration

**Location**: `/python-service/.env`

**Content**:
```bash
# Firebase Emulator Configuration
FIRESTORE_EMULATOR_HOST=localhost:8080
FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
FIREBASE_DATABASE_EMULATOR_URL=http://localhost:9000
FIREBASE_STORAGE_EMULATOR_HOST=localhost:9199

# FastAPI Configuration
HOST=0.0.0.0
PORT=8000

# AI Configuration (for future)
# OPENAI_API_KEY=your-key-here
# QDRANT_URL=http://localhost:6333
```

#### 2.4 Implement FastAPI Server

**Location**: `/python-service/app/main.py`

**Implementation**:
```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import logging
from datetime import datetime

from .firebase_client import FirebaseClient
from .ai_agents import AIAgent

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="CreatorLink AI Service")

# Initialize Firebase client
firebase_client = FirebaseClient()

# Initialize AI agent (MVP: simple echo)
ai_agent = AIAgent()


# Request model
class MessageRequest(BaseModel):
    messageId: str
    conversationId: str
    senderId: str
    text: str
    timestamp: dict
    participantIds: List[str]


# Response model
class MessageResponse(BaseModel):
    success: bool
    message: str
    responseMessageId: Optional[str] = None


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "CreatorLink AI Service",
        "timestamp": datetime.now().isoformat()
    }


@app.post("/process-message", response_model=MessageResponse)
async def process_message(request: MessageRequest):
    """
    Process incoming message from Firebase Cloud Function

    MVP: Simply acknowledge and create a response message
    Future: Run through LangChain/LangGraph agents
    """
    logger.info(f"Received message {request.messageId}: {request.text}")

    try:
        # MVP: Simple acknowledgment
        # Future: ai_response = await ai_agent.process(request.text)
        ai_response = f"ACK: Received '{request.text}'"

        logger.info(f"AI Response: {ai_response}")

        # Write response back to Firestore
        response_message_id = await firebase_client.send_message(
            conversation_id=request.conversationId,
            sender_id="ai-agent",  # Special AI user ID
            text=ai_response,
            participant_ids=request.participantIds,
            metadata={
                "ai_generated": True,
                "original_message_id": request.messageId,
                "agent_type": "echo"
            }
        )

        return MessageResponse(
            success=True,
            message="Message processed successfully",
            responseMessageId=response_message_id
        )

    except Exception as e:
        logger.error(f"Error processing message: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health_check():
    """Detailed health check"""
    try:
        # Test Firebase connection
        firebase_status = firebase_client.check_connection()

        return {
            "status": "healthy",
            "firebase": firebase_status,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }
```

#### 2.5 Implement Firebase Client

**Location**: `/python-service/app/firebase_client.py`

**Implementation**:
```python
import os
import logging
from datetime import datetime
from typing import List, Dict, Optional
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter

logger = logging.getLogger(__name__)


class FirebaseClient:
    def __init__(self):
        """Initialize Firebase Admin SDK for emulator"""

        # Check if running against emulator
        if os.getenv('FIRESTORE_EMULATOR_HOST'):
            logger.info("Connecting to Firebase emulators")
            # For emulators, we don't need credentials
            if not firebase_admin._apps:
                firebase_admin.initialize_app()
        else:
            logger.info("Connecting to production Firebase")
            # For production, load credentials
            cred = credentials.ApplicationDefault()
            if not firebase_admin._apps:
                firebase_admin.initialize_app(cred)

        self.db = firestore.client()
        logger.info("Firebase client initialized")


    def check_connection(self) -> Dict[str, bool]:
        """Test Firebase connection"""
        try:
            # Try to read from conversations collection
            collections = list(self.db.collections())
            return {"connected": True, "collections_count": len(collections)}
        except Exception as e:
            logger.error(f"Firebase connection check failed: {e}")
            return {"connected": False, "error": str(e)}


    async def send_message(
        self,
        conversation_id: str,
        sender_id: str,
        text: str,
        participant_ids: List[str],
        metadata: Optional[Dict[str, any]] = None
    ) -> str:
        """
        Write a message to Firestore

        Returns: Message document ID
        """
        try:
            message_data = {
                "conversationId": conversation_id,
                "senderId": sender_id,
                "participantIds": participant_ids,
                "text": text,
                "timestamp": firestore.SERVER_TIMESTAMP,
                "status": "sent",
                "readBy": {},
                "imageUrl": None,
                "metadata": metadata or {}
            }

            # Add message to Firestore
            doc_ref = self.db.collection('messages').add(message_data)
            message_id = doc_ref[1].id

            logger.info(f"Created message {message_id} in conversation {conversation_id}")

            # Update conversation last message
            await self._update_conversation_last_message(
                conversation_id=conversation_id,
                last_message=text,
                sender_id=sender_id
            )

            return message_id

        except Exception as e:
            logger.error(f"Error sending message: {e}")
            raise


    async def _update_conversation_last_message(
        self,
        conversation_id: str,
        last_message: str,
        sender_id: str
    ):
        """Update conversation with last message info"""
        try:
            self.db.collection('conversations').document(conversation_id).update({
                "lastMessage": last_message,
                "lastMessageTime": firestore.SERVER_TIMESTAMP,
                "lastMessageSenderId": sender_id,
                "lastMessageStatus": "sent"
            })
        except Exception as e:
            logger.warning(f"Failed to update conversation: {e}")
            # Don't fail the whole operation if this fails
```

#### 2.6 Implement AI Agent (MVP)

**Location**: `/python-service/app/ai_agents.py`

**Implementation** (Simple echo for MVP):
```python
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)


class AIAgent:
    """
    AI Agent using LangChain/LangGraph

    MVP: Simple echo/acknowledgment
    Future: Complex multi-agent system
    """

    def __init__(self):
        logger.info("AI Agent initialized (MVP mode)")
        # Future: Initialize LangChain, LangGraph, vector DB connections


    async def process(self, message_text: str) -> str:
        """
        Process message and generate AI response

        MVP: Simple acknowledgment
        Future: LangGraph agent execution
        """
        logger.info(f"Processing message: {message_text}")

        # MVP: Simple echo
        response = f"ACK: Received '{message_text}'"

        # Future implementation:
        # 1. Parse intent using LangChain
        # 2. Route to appropriate agent using LangGraph
        # 3. Query vector DB if needed
        # 4. Generate contextual response
        # 5. Return formatted response

        return response


    def get_agent_info(self) -> Dict[str, Any]:
        """Get agent metadata"""
        return {
            "name": "EchoAgent",
            "version": "0.1.0",
            "capabilities": ["echo", "acknowledge"],
            "mode": "MVP"
        }
```

#### 2.7 Create Startup Script

**Location**: `/python-service/run.sh`

**Content**:
```bash
#!/bin/bash

# Load environment variables
export $(cat .env | xargs)

# Start FastAPI server
uvicorn app.main:app --host $HOST --port $PORT --reload
```

**Make executable**:
```bash
chmod +x /Users/Gauntlet/gauntlet/CreatorLink/python-service/run.sh
```

### Phase 3: iOS App Integration (1 hour)

**Goal**: Ensure iOS app can display AI-generated responses

#### 3.1 Create AI User Profile

**Location**: Firebase emulator seed script OR manual creation

**Task**: Create a special "AI Agent" user in Firestore

**Option A - Manual** (via Emulator UI):
```json
// Add to users collection
{
  "uid": "ai-agent",
  "email": "ai@creatorlink.local",
  "displayName": "AI Assistant",
  "photoURL": null,
  "createdAt": <current timestamp>
}
```

**Option B - Update seed script**:
```javascript
// In emulator-seed/seed.js, add AI user
const aiUser = {
  uid: 'ai-agent',
  email: 'ai@creatorlink.local',
  displayName: 'AI Assistant',
  photoURL: null,
  createdAt: admin.firestore.FieldValue.serverTimestamp()
};

await db.collection('users').doc('ai-agent').set(aiUser);
```

#### 3.2 Verify Message Listener Handles AI Messages

**Location**: iOS app message listeners (already implemented)

**Verification Tasks**:
- Confirm `MessageService.listenToMessages()` receives AI messages
- Confirm AI messages appear in chat UI
- Confirm AI sender name displays as "AI Assistant"

**No code changes required** - existing listeners should work automatically!

#### 3.3 Add AI Message Styling (Optional Enhancement)

**Location**: `CreatorLink/Views/Chats/MessageBubble.swift` (or similar)

**Optional**: Style AI messages differently

**Example**:
```swift
// Check if message is from AI
let isAIMessage = message.metadata?["ai_generated"] == "true"

// Apply different background color
.background(isAIMessage ? Color.purple.opacity(0.1) : userColor)
```

### Phase 4: End-to-End Testing (1 hour)

**Goal**: Verify complete message flow from iOS → AI → iOS

#### 4.1 Startup Checklist

**Services to start** (in order):

1. **Firebase Emulators**:
   ```bash
   cd /Users/Gauntlet/gauntlet/CreatorLink/firebase
   firebase emulators:start
   ```
   - Verify all emulators running at http://localhost:4000

2. **Python FastAPI Server**:
   ```bash
   cd /Users/Gauntlet/gauntlet/CreatorLink/python-service
   source venv/bin/activate  # If using virtual environment
   ./run.sh
   ```
   - Verify server running at http://localhost:8000
   - Test health endpoint: `curl http://localhost:8000/health`

3. **iOS App**:
   ```
   Open Xcode → Run in simulator
   ```

#### 4.2 Test Scenarios

**Test 1: Basic Message Flow**
1. Log into iOS app with test user (e.g., alice.johnson@test.com)
2. Send a message: "Hello AI"
3. Observe:
   - Firebase Functions logs show trigger
   - Python server logs show message received
   - Python server logs show ACK response
   - iOS app shows AI response: "ACK: Received 'Hello AI'"

**Test 2: Conversation Context**
1. Send multiple messages in same conversation
2. Verify AI responds to each
3. Verify conversation lastMessage updates correctly

**Test 3: Error Handling**
1. Stop Python server
2. Send message from iOS
3. Verify:
   - Function logs show error
   - iOS app still works (message sent to Firestore)
   - No crash or hang

**Test 4: Concurrent Messages**
1. Send 3 messages rapidly
2. Verify AI responds to all 3
3. Verify responses appear in correct order

#### 4.3 Debugging Tools

**Monitor Cloud Function Logs**:
```bash
# In Firebase emulator terminal
# Watch for: "New message detected", "Python server response"
```

**Monitor Python Server Logs**:
```bash
# In python-service terminal
# Watch for: "Received message", "AI Response", "Created message"
```

**Monitor Firestore**:
- Open http://localhost:4000
- Navigate to Firestore tab
- Watch messages collection in real-time

### Phase 5: Optional Enhancements (Future)

**Goal**: Prepare for advanced AI features (not required for MVP)

#### 5.1 Add Qdrant Vector Database (Optional)

**Setup**:
```bash
docker run -p 6333:6333 qdrant/qdrant
```

**Integration**:
- Add `qdrant-client` to requirements.txt
- Create vector embeddings of messages
- Query for relevant context before AI response

#### 5.2 Add LangGraph Multi-Agent System (Optional)

**Agents to consider**:
- **Router Agent**: Determines which agent to use
- **RAG Agent**: Retrieves context from vector DB
- **Conversational Agent**: Generates responses
- **Tool Agent**: Executes actions (e.g., create tasks, search)

#### 5.3 Add Conversation Metadata (Optional)

**Track AI state**:
```python
metadata = {
    "ai_generated": True,
    "agent_type": "conversational",
    "confidence_score": 0.95,
    "retrieved_docs": ["doc1", "doc2"],
    "reasoning_steps": ["step1", "step2"]
}
```

## Directory Structure

```
/CreatorLink (parent directory)
│
├── /CreatorLink (iOS app)
│   ├── /Models
│   │   └── Message.swift          # Already has metadata field ✅
│   ├── /Services
│   │   └── MessageService.swift   # Already has listeners ✅
│   └── /Views
│       └── Chats/
│           └── ChatDetailView.swift
│
├── /firebase
│   ├── /functions                 # NEW - Cloud Functions
│   │   ├── /src
│   │   │   └── index.ts          # Message trigger function
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── firebase.json              # MODIFY - Add functions emulator
│   ├── firestore.rules
│   ├── storage.rules
│   └── database.rules.json
│
├── /python-service                # NEW - Python AI service
│   ├── /app
│   │   ├── __init__.py
│   │   ├── main.py               # FastAPI application
│   │   ├── firebase_client.py    # Firebase Admin SDK
│   │   └── ai_agents.py          # LangChain/LangGraph agents
│   ├── requirements.txt
│   ├── .env                       # Environment configuration
│   ├── run.sh                     # Startup script
│   └── README.md
│
├── /emulator-seed                 # MODIFY - Add AI user
│   └── seed.js                    # Update to create AI user
│
└── /docker-compose.yml            # OPTIONAL - For Qdrant
```

## Service Startup Order

**Critical**: Start services in this order for proper initialization:

1. **Firebase Emulators** (port 8080, 9099, 9000, 9199, 5001)
   ```bash
   cd firebase && firebase emulators:start
   ```

2. **Qdrant** (OPTIONAL - port 6333)
   ```bash
   docker run -p 6333:6333 qdrant/qdrant
   ```

3. **Python FastAPI Server** (port 8000)
   ```bash
   cd python-service && ./run.sh
   ```

4. **iOS App** (via Xcode)
   ```
   Open Xcode → Build and Run
   ```

## Configuration Requirements

### Firebase Functions

**Location**: `/firebase/functions/package.json`

**Required dependencies**:
```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0",
    "axios": "^1.6.0"
  }
}
```

### Python Service

**Environment Variables** (`.env`):
```bash
FIRESTORE_EMULATOR_HOST=localhost:8080
FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
FIREBASE_DATABASE_EMULATOR_URL=http://localhost:9000
FIREBASE_STORAGE_EMULATOR_HOST=localhost:9199
HOST=0.0.0.0
PORT=8000
```

**Python Version**: 3.9+

**Virtual Environment**:
```bash
cd python-service
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### iOS App

**No changes required** - existing Message model and listeners already support:
- `metadata` field for AI-specific data
- Real-time Firestore listeners
- Message display from any sender (including AI)

## Advantages of This Approach

### Development Benefits
- **Fully Local**: No cloud dependencies, no API costs
- **Fast Iteration**: Change code, restart service, test immediately
- **Easy Debugging**: All logs visible in terminals
- **No Secrets Required**: No API keys needed for MVP

### Technical Benefits
- **Scalable Foundation**: Easy to add more AI agents
- **Firebase Integration**: Leverages existing Firestore structure
- **Real-time**: iOS app gets responses instantly via listeners
- **Type Safety**: TypeScript functions + Python type hints

### Cost Benefits
- **Zero Firebase Costs**: Emulators are free
- **Zero AI Costs**: MVP uses simple logic (no LLM calls)
- **Zero Infrastructure**: No servers to deploy

## Timeline Estimate

- **Phase 1** (Cloud Functions Setup): 1-2 hours
- **Phase 2** (Python FastAPI Service): 2-3 hours
- **Phase 3** (iOS Integration): 1 hour
- **Phase 4** (End-to-End Testing): 1 hour

**Total**: ~5-7 hours for MVP

## Success Criteria

MVP is complete when:

- ✅ iOS app sends message to Firestore
- ✅ Cloud Function detects new message
- ✅ Cloud Function calls Python server
- ✅ Python server receives message data
- ✅ Python server creates response message in Firestore
- ✅ iOS app displays AI response in chat
- ✅ AI messages show metadata (ai_generated: true)
- ✅ All services run on localhost
- ✅ Complete flow works end-to-end in <2 seconds

## Common Issues and Solutions

### Issue: Cloud Function doesn't trigger
**Symptoms**: Message sent from iOS, no function logs
**Solutions**:
- Verify functions emulator running on port 5001
- Check firebase.json has functions configured
- Rebuild functions: `cd firebase/functions && npm run build`
- Check emulator UI Functions tab

### Issue: Python server connection refused
**Symptoms**: Function logs show "ECONNREFUSED localhost:8000"
**Solutions**:
- Verify Python server is running: `curl http://localhost:8000`
- Check .env has correct configuration
- Check port 8000 is not in use: `lsof -i :8000`
- Check firewall settings

### Issue: AI message doesn't appear in iOS
**Symptoms**: Python logs show message sent, iOS doesn't display
**Solutions**:
- Check message listener is active in iOS
- Verify AI user ID is in participantIds array
- Check Firestore UI to confirm message was written
- Verify iOS app is listening to correct conversation

### Issue: Firebase Admin SDK can't connect
**Symptoms**: Python server logs show Firestore errors
**Solutions**:
- Verify FIRESTORE_EMULATOR_HOST is set: `echo $FIRESTORE_EMULATOR_HOST`
- Restart Python server after changing .env
- Check emulators are running before starting Python server

## Next Steps After MVP

Once MVP is working, consider these enhancements:

1. **Smart AI Routing**
   - Only trigger AI for messages starting with "@ai" or similar
   - Add conversation-level AI enable/disable flag

2. **Context-Aware Responses**
   - Load conversation history before generating response
   - Use LangChain memory to maintain context
   - Query vector DB for relevant documents

3. **Multi-Agent System**
   - Router agent to classify intent
   - Specialized agents for different tasks
   - LangGraph to orchestrate agent flow

4. **Production Deployment**
   - Deploy Cloud Functions to Firebase
   - Deploy Python service to Cloud Run or similar
   - Set up Qdrant in production
   - Add authentication/authorization

5. **Advanced Features**
   - Streaming responses (character by character)
   - Message suggestions
   - Sentiment analysis
   - Automatic summarization

## Files Summary

### Files to Create

**Firebase Functions**:
1. `/firebase/functions/src/index.ts` - Message trigger function
2. `/firebase/functions/package.json` - Dependencies
3. `/firebase/functions/tsconfig.json` - TypeScript config

**Python Service**:
1. `/python-service/app/__init__.py` - Package init
2. `/python-service/app/main.py` - FastAPI application
3. `/python-service/app/firebase_client.py` - Firebase Admin SDK client
4. `/python-service/app/ai_agents.py` - AI agent logic
5. `/python-service/requirements.txt` - Python dependencies
6. `/python-service/.env` - Environment configuration
7. `/python-service/run.sh` - Startup script
8. `/python-service/README.md` - Service documentation

### Files to Modify

1. `/firebase/firebase.json` - Add functions emulator configuration
2. `/emulator-seed/seed.js` - Add AI user creation (optional)

### No Changes Required

- ✅ iOS Message model (already has metadata field)
- ✅ iOS MessageService (already has real-time listeners)
- ✅ iOS ChatDetailView (already displays messages from any sender)
- ✅ Firestore rules (AI user ID can be handled like any user)

## Ready to Implement?

Start with Phase 1 (Cloud Functions) and work through sequentially. Each phase can be tested independently before moving to the next.

Key principle: **Keep it simple for MVP**. Get the basic flow working end-to-end, then add complexity iteratively.
