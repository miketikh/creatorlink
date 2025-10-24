"""
CreatorLink AI Service - FastAPI Application
Main application entry point with endpoints for message processing.
"""

import logging
import os
import sys
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from .firebase_client import FirebaseClient
from .ai_agents import AIAgent
from .vector_store import VectorStore

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="CreatorLink AI Service",
    description="AI-powered messaging service for CreatorLink iOS app",
    version="0.1.0"
)

# Initialize Firebase client and AI agent
logger.info("Initializing Firebase client...")
firebase_client = FirebaseClient()

logger.info("Initializing AI agent...")
ai_agent = AIAgent()

# Vector store will be initialized in startup event
vector_store = None

logger.info("Application initialization complete (vector store will initialize on startup)")


# Startup and shutdown event handlers
@app.on_event("startup")
async def startup_event():
    """
    Initialize services on application startup.
    Sets up vector store and creates necessary collections.
    """
    global vector_store

    try:
        logger.info("Starting application initialization...")

        # Initialize vector store
        logger.info("Initializing vector store...")
        vector_store = VectorStore()

        # Create collection if it doesn't exist
        await vector_store.initialize_collection()

        logger.info("Application startup complete - all services initialized")

    except Exception as e:
        logger.error(f"Failed to initialize application: {e}", exc_info=True)
        raise


@app.on_event("shutdown")
async def shutdown_event():
    """
    Cleanup services on application shutdown.
    Closes vector store connections and releases resources.
    """
    global vector_store

    try:
        logger.info("Starting application shutdown...")

        # Close vector store connection
        if vector_store:
            logger.info("Closing vector store connection...")
            await vector_store.close()

        logger.info("Application shutdown complete")

    except Exception as e:
        logger.error(f"Error during application shutdown: {e}", exc_info=True)


# Pydantic models for request/response validation
class AIConfig(BaseModel):
    """AI configuration for conversation."""
    faqDetectionEnabled: bool = True
    minimumSimilarity: float = 0.85


class MessageRequest(BaseModel):
    """Request model for incoming messages from Cloud Functions."""
    messageId: str
    conversationId: str
    senderId: str
    text: str
    timestamp: Dict[str, int]  # Firebase timestamp object with _seconds and _nanoseconds
    participantIds: List[str]
    aiConfig: Optional[AIConfig] = None


class MessageResponse(BaseModel):
    """Response model for message processing results."""
    success: bool
    message: str
    responseMessageId: Optional[str] = None


# Endpoints
@app.get("/")
async def root() -> Dict[str, Any]:
    """
    Root endpoint - basic health check.

    Returns:
        Status information
    """
    return {
        "status": "healthy",
        "service": "CreatorLink AI Service",
        "version": "0.1.0",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


@app.get("/health")
async def health_check() -> Dict[str, Any]:
    """
    Detailed health check endpoint.
    Checks Firebase, vector store connections and returns service status.

    Returns:
        Detailed health status including all service components
    """
    # Check Firebase connection
    firebase_status = firebase_client.check_connection()

    # Check vector store connection
    vector_store_status = None
    if vector_store:
        vector_store_status = await vector_store.health_check()
    else:
        vector_store_status = {
            "status": "not_initialized",
            "error": "Vector store not initialized"
        }

    # Determine overall health status
    is_firebase_healthy = firebase_status.get("status") == "connected"
    is_vector_store_healthy = vector_store_status.get("status") == "connected"
    is_healthy = is_firebase_healthy and is_vector_store_healthy

    # Get agent info
    agent_info = ai_agent.get_agent_info()

    return {
        "status": "healthy" if is_healthy else "unhealthy",
        "service": "CreatorLink AI Service",
        "version": "0.1.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "firebase": firebase_status,
        "vector_store": vector_store_status,
        "ai_agent": agent_info
    }


@app.post("/process-message", response_model=MessageResponse)
async def process_message(request: MessageRequest) -> MessageResponse:
    """
    Process incoming message and generate AI response.
    Called by Firebase Cloud Function when new messages are created.

    Args:
        request: Message data from Cloud Function

    Returns:
        Processing result with response message ID

    Raises:
        HTTPException: If message processing fails
    """
    try:
        logger.info(f"Received message request: {request.messageId} from {request.senderId}")
        logger.info(f"Message text: '{request.text}'")
        logger.info(f"AI Config: faqDetection={request.aiConfig.faqDetectionEnabled if request.aiConfig else True}, "
                    f"similarity={request.aiConfig.minimumSimilarity if request.aiConfig else 0.85}")

        # Process message with AI agent
        ai_response_text = await ai_agent.process(request.text)

        # Create metadata for AI-generated message
        # Note: All values must be strings to match iOS Message model [String: String]
        response_metadata = {
            "ai_generated": "true",  # Keep for backward compatibility
            "original_message_id": request.messageId,
            "agent_type": "faq_detector",  # Changed from "echo"
            "agent_version": "0.2.0",  # Bumped version
        }

        # TODO Phase 5: Implement FAQ detection
        # 1. Fetch recent messages from conversation
        # 2. Use embedding/similarity search to find matches
        # 3. If match found above minimumSimilarity threshold:
        #    - Add faqReference to metadata
        #    - Add matchConfidence to metadata
        #    - Add matchedQuestion to metadata
        #    - Format response text to reference original answer

        # Send AI response back to Firestore
        response_message_id = await firebase_client.send_message(
            conversation_id=request.conversationId,
            sender_id="ai-assistant",  # Changed from "ai-agent"
            text=ai_response_text,
            participant_ids=request.participantIds,
            metadata=response_metadata
        )

        logger.info(f"AI response sent successfully: {response_message_id}")

        return MessageResponse(
            success=True,
            message="Message processed and AI response created",
            responseMessageId=response_message_id
        )

    except Exception as e:
        logger.error(f"Error processing message {request.messageId}: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to process message: {str(e)}"
        )


# Optional: Agent info endpoint for debugging
@app.get("/agent-info")
async def get_agent_info() -> Dict[str, Any]:
    """
    Get information about the current AI agent.

    Returns:
        Agent metadata and capabilities
    """
    return ai_agent.get_agent_info()


if __name__ == "__main__":
    # This allows running the app directly with `python -m app.main`
    # In production, use uvicorn command instead
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
