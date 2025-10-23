"""
Firebase Admin SDK client for Firestore operations.
Handles connection to Firebase emulators and message operations.
"""

import os
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any

import firebase_admin
from firebase_admin import credentials, firestore

logger = logging.getLogger(__name__)


class FakeCredential(credentials.Base):
    """Fake credential class for Firebase emulator usage.

    This bypasses the need for real credentials when connecting to Firebase emulators.
    The emulator doesn't validate credentials, so this allows local development
    without distributing service account files.
    """
    def get_credential(self):
        return {}


class FirebaseClient:
    """Client for interacting with Firebase Firestore."""

    def __init__(self):
        """Initialize Firebase Admin SDK and Firestore client."""
        # Check if running in emulator mode
        emulator_host = os.getenv("FIRESTORE_EMULATOR_HOST")

        if emulator_host:
            logger.info(f"Initializing Firebase in EMULATOR mode: {emulator_host}")
            # For emulator, use FakeCredential to bypass authentication requirements
            if not firebase_admin._apps:
                # Get project ID from environment
                project_id = os.getenv("GCLOUD_PROJECT", "creatorlink-c160a")

                # Initialize with fake credentials for emulator
                firebase_admin.initialize_app(
                    FakeCredential(),
                    options={"projectId": project_id}
                )
        else:
            logger.info("Initializing Firebase in PRODUCTION mode")
            # For production, use application default credentials or service account
            if not firebase_admin._apps:
                firebase_admin.initialize_app()

        # Initialize Firestore client
        self.db = firestore.client()
        logger.info("Firestore client initialized successfully")

    def check_connection(self) -> Dict[str, Any]:
        """
        Check Firestore connection by listing collections.

        Returns:
            Dict with connection status and collection count
        """
        try:
            collections = list(self.db.collections())
            collection_count = len(collections)
            logger.info(f"Firestore connection successful. Found {collection_count} collections")
            return {
                "status": "connected",
                "collection_count": collection_count,
                "collections": [col.id for col in collections]
            }
        except Exception as e:
            logger.error(f"Firestore connection failed: {e}")
            return {
                "status": "disconnected",
                "error": str(e)
            }

    async def send_message(
        self,
        conversation_id: str,
        sender_id: str,
        text: str,
        participant_ids: List[str],
        metadata: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        Send a message to Firestore.

        Args:
            conversation_id: ID of the conversation
            sender_id: ID of the message sender (e.g., "ai-agent")
            text: Message text content
            participant_ids: List of participant user IDs
            metadata: Optional metadata dict (e.g., {"ai_generated": True})

        Returns:
            Document ID of the created message
        """
        try:
            # Create message data matching the Message model structure
            message_data = {
                "conversationId": conversation_id,
                "senderId": sender_id,
                "participantIds": participant_ids,
                "text": text,
                "timestamp": firestore.SERVER_TIMESTAMP,
                "status": "sent",
                "readBy": {},  # Empty dict - no one has read it yet
                "imageUrl": None,  # No image for AI messages (for now)
                "metadata": metadata or {}
            }

            # Add message to Firestore
            message_ref = self.db.collection("messages").add(message_data)
            message_id = message_ref[1].id

            logger.info(f"Message created successfully: {message_id}")

            # Update conversation with last message info (best effort - don't fail if it doesn't work)
            try:
                self._update_conversation_last_message(
                    conversation_id=conversation_id,
                    last_message=text,
                    sender_id=sender_id
                )
            except Exception as conv_error:
                logger.warning(f"Failed to update conversation lastMessage: {conv_error}")

            return message_id

        except Exception as e:
            logger.error(f"Failed to send message: {e}")
            raise

    def _update_conversation_last_message(
        self,
        conversation_id: str,
        last_message: str,
        sender_id: str
    ) -> None:
        """
        Update conversation document with last message info.

        Args:
            conversation_id: ID of the conversation to update
            last_message: Text of the last message
            sender_id: ID of the sender
        """
        try:
            conversation_ref = self.db.collection("conversations").document(conversation_id)

            # Update conversation with last message details
            conversation_ref.update({
                "lastMessage": last_message,
                "lastMessageTime": firestore.SERVER_TIMESTAMP,
                "lastMessageSenderId": sender_id,
                "lastMessageStatus": "sent"
            })

            logger.info(f"Updated conversation {conversation_id} with last message")

        except Exception as e:
            logger.error(f"Failed to update conversation {conversation_id}: {e}")
            raise
