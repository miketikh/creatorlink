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
from .embeddings import EmbeddingService
from .qa_detector import QADetector, ContextMessage as QAContextMessage

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

# Services that will be initialized in startup event
vector_store = None
embedding_service = None
qa_detector = None

logger.info("Application initialization complete (services will initialize on startup)")


# Startup and shutdown event handlers
@app.on_event("startup")
async def startup_event():
    """
    Initialize services on application startup.
    Sets up vector store, embedding service, and Q+A detector.
    """
    global vector_store, embedding_service, qa_detector

    try:
        logger.info("Starting application initialization...")

        # Initialize vector store
        logger.info("Initializing vector store...")
        vector_store = VectorStore()

        # Create collection if it doesn't exist
        await vector_store.initialize_collection()

        # Initialize embedding service
        logger.info("Initializing embedding service...")
        embedding_service = EmbeddingService()

        # Initialize Q+A detector
        logger.info("Initializing Q+A detector...")
        qa_detector = QADetector()

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


class ContextMessage(BaseModel):
    """
    Context message for Q+A detection.
    Represents a previous message in the conversation.
    """
    messageId: str
    senderId: str
    text: str
    timestamp: Dict[str, int]  # Firebase timestamp object with _seconds and _nanoseconds


class MessageRequest(BaseModel):
    """
    Request model for incoming messages from Cloud Functions.

    The context field contains recent messages for Q+A pair detection.
    Firebase Cloud Function should fetch the last 5 messages and include them here.
    """
    messageId: str
    conversationId: str
    senderId: str
    text: str
    timestamp: Dict[str, int]  # Firebase timestamp object with _seconds and _nanoseconds
    participantIds: List[str]
    aiConfig: Optional[AIConfig] = None
    context: List[ContextMessage] = []  # Last 5 messages for Q+A detection (backward compatible)


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
    Detects Q+A pairs and creates embeddings for FAQ matching.
    Called by Firebase Cloud Function when new messages are created.

    Args:
        request: Message data from Cloud Function including conversation context

    Returns:
        Processing result with response message ID

    Raises:
        HTTPException: If message processing fails
    """
    import time as time_module
    start_time = time_module.time()

    try:
        logger.info(f"Received message request: {request.messageId} from {request.senderId}")
        logger.info(f"Message text: '{request.text}'")
        logger.info(f"Context messages: {len(request.context)}")

        # Skip Q+A detection if sender is AI assistant (prevent loops)
        if request.senderId == "ai-assistant":
            logger.info("Skipping Q+A detection - message from AI assistant")
            return MessageResponse(
                success=True,
                message="Skipped AI-generated message",
                responseMessageId=None
            )

        # Check if AI is enabled for this conversation
        conversation = await firebase_client.get_conversation(request.conversationId)
        ai_enabled = firebase_client.is_ai_enabled(conversation)

        if not ai_enabled:
            logger.info("Skipping Q+A detection - AI not enabled for this conversation")
            return MessageResponse(
                success=True,
                message="Skipped - AI not enabled",
                responseMessageId=None
            )

        # Q+A Detection Pipeline
        qa_pair = None
        detection_time = 0.0
        embedding_time = 0.0
        storage_time = 0.0

        if request.context and qa_detector and embedding_service and vector_store:
            # Step 1: Detect Q+A pair using GPT-4o-mini
            detection_start = time_module.time()
            try:
                # Convert Pydantic ContextMessage to QADetector ContextMessage
                context_messages = [
                    QAContextMessage(
                        messageId=msg.messageId,
                        senderId=msg.senderId,
                        text=msg.text,
                        timestamp=msg.timestamp
                    )
                    for msg in request.context
                ]

                # Create current message as ContextMessage
                current_message = QAContextMessage(
                    messageId=request.messageId,
                    senderId=request.senderId,
                    text=request.text,
                    timestamp=request.timestamp
                )

                # Detect Q+A pair
                qa_pair = await qa_detector.detect_qa_pair(current_message, context_messages)
                detection_time = time_module.time() - detection_start

                logger.info(f"Q+A detection completed in {detection_time:.3f}s")

            except Exception as e:
                logger.error(f"Q+A detection failed: {e}", exc_info=True)
                # Continue without Q+A embedding if detection fails

            # Step 2: If Q+A pair detected, create embedding and store
            if qa_pair:
                logger.info(
                    f"Q+A pair detected (confidence={qa_pair.confidence:.2f}): "
                    f"Q='{qa_pair.question_text[:50]}...' A='{qa_pair.answer_text[:50]}...'"
                )

                try:
                    # Step 2a: Generate embedding for Q+A pair
                    embedding_start = time_module.time()

                    # Format combined text: "Question: {q}\nAnswer: {a}"
                    combined_text = f"Question: {qa_pair.question_text}\nAnswer: {qa_pair.answer_text}"

                    # Generate embedding
                    embedding_vector = await embedding_service.generate_embedding(combined_text)
                    embedding_time = time_module.time() - embedding_start

                    logger.info(f"Embedding generated in {embedding_time:.3f}s")

                    # Step 2b: Store in vector database
                    storage_start = time_module.time()

                    # Prepare metadata for Q+A pair
                    qa_metadata = {
                        "is_pair": True,
                        "question_message_id": qa_pair.question_message_id,
                        "question_text": qa_pair.question_text,
                        "question_sender_id": qa_pair.question_sender_id,
                        "answer_message_id": qa_pair.answer_message_id,
                        "answer_text": qa_pair.answer_text,
                        "answer_sender_id": qa_pair.answer_sender_id,
                        "confidence": qa_pair.confidence,
                        "reasoning": qa_pair.reasoning or ""
                    }

                    # Upsert to vector store
                    await vector_store.upsert_message_embedding(
                        message_id=qa_pair.answer_message_id,  # Use answer message ID as primary
                        conversation_id=request.conversationId,
                        embedding=embedding_vector,
                        message_text=combined_text,
                        sender_id=qa_pair.answer_sender_id,
                        timestamp=datetime.now(),
                        metadata=qa_metadata
                    )

                    storage_time = time_module.time() - storage_start
                    logger.info(f"Q+A pair stored in vector database in {storage_time:.3f}s")

                except Exception as e:
                    logger.error(f"Failed to embed/store Q+A pair: {e}", exc_info=True)
                    # Continue even if embedding/storage fails
            else:
                logger.info("No Q+A pair detected - skipping embedding")

        else:
            logger.debug("Q+A detection skipped - no context or services not initialized")

        # Calculate total time and log performance metrics
        total_time = time_module.time() - start_time
        logger.info(
            f"Message processing complete in {total_time:.3f}s "
            f"(detection={detection_time:.3f}s, embedding={embedding_time:.3f}s, "
            f"storage={storage_time:.3f}s)"
        )

        # Log cost metrics if Q+A pair was detected
        if qa_pair:
            # Estimate GPT-4o-mini cost for detection
            detection_cost_info = qa_detector.estimate_cost_per_detection(len(request.context))

            # Estimate embedding cost
            embedding_cost_info = embedding_service.estimate_cost([
                f"Question: {qa_pair.question_text}\nAnswer: {qa_pair.answer_text}"
            ])

            total_cost = detection_cost_info["cost_usd"] + embedding_cost_info["cost_usd"]

            logger.info(
                f"Cost metrics: detection=${detection_cost_info['cost_usd']:.6f}, "
                f"embedding=${embedding_cost_info['cost_usd']:.6f}, "
                f"total=${total_cost:.6f}"
            )

        # For now, still send echo response (FAQ search will be implemented in Phase 3)
        ai_response_text = await ai_agent.process(request.text)

        # Create metadata for AI-generated message
        response_metadata = {
            "ai_generated": "true",
            "original_message_id": request.messageId,
            "agent_type": "faq_detector",
            "agent_version": "0.3.0",
        }

        # Send AI response back to Firestore
        response_message_id = await firebase_client.send_message(
            conversation_id=request.conversationId,
            sender_id="ai-assistant",
            text=ai_response_text,
            participant_ids=request.participantIds,
            metadata=response_metadata
        )

        logger.info(f"AI response sent successfully: {response_message_id}")

        return MessageResponse(
            success=True,
            message="Message processed and Q+A pair embedded" if qa_pair else "Message processed",
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
