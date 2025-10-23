# CreatorLink AI Service

Python FastAPI service that processes messages using AI agents and integrates with Firebase.

## Architecture

This service receives HTTP requests from Firebase Cloud Functions, processes messages with AI agents, and writes responses back to Firestore.

## Setup

### Prerequisites

- Python 3.9 or later
- Firebase emulators running (Auth, Firestore, Functions)

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

## Project Structure

```
python-service/
├── app/
│   ├── __init__.py          # Package initialization
│   ├── main.py              # FastAPI application
│   ├── firebase_client.py   # Firebase Admin SDK client
│   └── ai_agents.py         # AI agent logic
├── requirements.txt         # Python dependencies
├── .env                     # Environment configuration (not committed)
├── .env.example            # Example environment configuration
├── run.sh                  # Startup script
└── README.md               # This file
```

## Environment Variables

See `.env.example` for all available configuration options.

Key variables:
- `FIRESTORE_EMULATOR_HOST` - Firestore emulator address
- `FIREBASE_AUTH_EMULATOR_HOST` - Auth emulator address
- `HOST` - Server bind address
- `PORT` - Server port (default: 8000)
