# CreatorLink AI Service

## Status: Planned - Not Currently In Use

**This Python service is planned infrastructure for future AI/vector search features and is NOT currently active in the CreatorLink application.**

The service is designed to:
- Process messages using AI agents with vector similarity search
- Use **Qdrant** as an in-memory vector store for semantic search and context retrieval
- Integrate with Firebase (Firestore and Auth) for data persistence
- Serve as the AI processing layer when AI features are activated

This infrastructure is ready for future development and testing but is not part of the current production flow.

---

Python FastAPI service that processes messages using AI agents and integrates with Firebase.

## Architecture

This service receives HTTP requests from Firebase Cloud Functions, processes messages with AI agents, and writes responses back to Firestore. It uses Qdrant (an in-memory vector database) for semantic search and context retrieval to enhance AI responses.

## Setup

**Note:** These instructions are for future development when this service is integrated into the application.

### Prerequisites

- Python 3.9 or later (Python 3.12 recommended)
- Firebase emulators running (Auth, Firestore, Functions)
- Qdrant vector database (runs in-memory mode by default)

### Installation

1. Create and activate virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment variables:
```bash
cp .env.example .env
# Edit .env if needed (default values work with Firebase emulators)
```

## Running the Service

### Option 1: Using the startup script (recommended)
```bash
./run.sh
```

### Option 2: Manual start
```bash
source venv/bin/activate
export $(cat .env | xargs)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Endpoints

- `GET /` - Root endpoint (health check)
- `GET /health` - Detailed health check with Firebase connection status
- `POST /process-message` - Process incoming message and generate AI response

## Development

The service runs in development mode with auto-reload enabled. Edit code and the server will automatically restart.

## Testing

1. Start Firebase emulators
2. Start this Python service
3. Send a test request:
```bash
curl -X POST http://localhost:8000/process-message \
  -H "Content-Type: application/json" \
  -d '{
    "messageId": "test123",
    "conversationId": "conv123",
    "senderId": "user123",
    "text": "Hello AI",
    "timestamp": {"_seconds": 1234567890, "_nanoseconds": 0},
    "participantIds": ["user123", "ai-agent"]
  }'
```

## Environment Variables

See `.env.example` for all available configuration options.

Key variables:
- `FIRESTORE_EMULATOR_HOST` - Firestore emulator address
- `FIREBASE_AUTH_EMULATOR_HOST` - Auth emulator address
- `HOST` - Server bind address
- `PORT` - Server port (default: 8000)

## Qdrant Vector Store

The service uses Qdrant for semantic search and context retrieval:

- **Development Mode**: Runs in-memory (`:memory:`) - no external setup needed
- **Production Mode**: Can connect to a Qdrant server instance
- **Implementation**: See `QDRANT_IMPLEMENTATION.md` for detailed setup information
- **Version**: qdrant-client 1.13.0
- **Python Compatibility**: Fully compatible with Python 3.12

The vector store enables AI agents to:
- Store message embeddings for semantic search
- Retrieve relevant context from conversation history
- Filter results by conversation, user, or custom metadata
- Provide more informed and contextual AI responses

For technical details on the Qdrant integration, see `/Users/Gauntlet/gauntlet/CreatorLink/python-service/QDRANT_IMPLEMENTATION.md`.
