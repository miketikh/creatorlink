"""
Vector Store Module for message embeddings using Qdrant.
Handles storage and retrieval of message embeddings for FAQ detection.
"""

import os
import logging
import hashlib
from typing import Dict, List, Optional, Any
from datetime import datetime, timezone

from qdrant_client import QdrantClient, AsyncQdrantClient
from qdrant_client.models import (
    Distance,
    VectorParams,
    PointStruct,
    Filter,
    FieldCondition,
    MatchValue
)

logger = logging.getLogger(__name__)


class VectorStore:
    """Vector store for managing message embeddings in Qdrant."""

    @staticmethod
    def _message_id_to_point_id(message_id: str) -> int:
        """
        Convert message ID string to integer point ID for Qdrant.
        Uses SHA256 hash to ensure consistent, unique integer IDs.

        Args:
            message_id: String message identifier

        Returns:
            Integer point ID (positive 64-bit integer)
        """
        # Hash the message_id to get a consistent integer
        hash_digest = hashlib.sha256(message_id.encode()).digest()
        # Convert first 8 bytes to integer and ensure it's positive
        return int.from_bytes(hash_digest[:8], byteorder='big') & 0x7FFFFFFFFFFFFFFF

    def __init__(self):
        """
        Initialize Qdrant client.

        Uses in-memory mode for development (configured via QDRANT_HOST=:memory:)
        or connects to Qdrant server for production.
        """
        qdrant_host = os.getenv("QDRANT_HOST", ":memory:")
        self.collection_name = os.getenv("QDRANT_COLLECTION_NAME", "message_embeddings")
        self.embedding_dimensions = int(os.getenv("OPENAI_EMBEDDING_DIMENSIONS", "1536"))

        logger.info(f"Initializing VectorStore with Qdrant host: {qdrant_host}")

        try:
            # Initialize async client for in-memory or server mode
            if qdrant_host == ":memory:":
                logger.info("Using in-memory Qdrant (data will not persist)")
                self.client = AsyncQdrantClient(location=":memory:")
            else:
                # Parse host and port for server mode
                # Format: "host:port" or just "host" (default port 6333)
                if ":" in qdrant_host:
                    host, port = qdrant_host.split(":")
                    port = int(port)
                else:
                    host = qdrant_host
                    port = 6333

                logger.info(f"Connecting to Qdrant server at {host}:{port}")
                self.client = AsyncQdrantClient(host=host, port=port)

            logger.info("VectorStore client initialized successfully")

        except Exception as e:
            logger.error(f"Failed to initialize Qdrant client: {e}")
            raise

    async def initialize_collection(self) -> None:
        """
        Initialize the Qdrant collection for message embeddings.
        Creates collection with proper vector configuration if it doesn't exist.

        Raises:
            Exception: If collection creation fails
        """
        try:
            # Check if collection already exists
            collections = await self.client.get_collections()
            collection_exists = any(
                col.name == self.collection_name
                for col in collections.collections
            )

            if collection_exists:
                logger.info(f"Collection '{self.collection_name}' already exists")
                return

            # Create collection with vector configuration
            logger.info(f"Creating collection '{self.collection_name}' with {self.embedding_dimensions} dimensions")

            await self.client.create_collection(
                collection_name=self.collection_name,
                vectors_config=VectorParams(
                    size=self.embedding_dimensions,
                    distance=Distance.COSINE
                )
            )

            logger.info(f"Collection '{self.collection_name}' created successfully")

        except Exception as e:
            logger.error(f"Failed to initialize collection '{self.collection_name}': {e}")
            raise

    async def upsert_message_embedding(
        self,
        message_id: str,
        conversation_id: str,
        embedding: List[float],
        message_text: str,
        sender_id: str,
        timestamp: Optional[datetime] = None,
        metadata: Optional[Dict[str, Any]] = None
    ) -> None:
        """
        Store or update a message embedding in the vector database.

        Args:
            message_id: Unique identifier for the message
            conversation_id: ID of the conversation this message belongs to
            embedding: Vector embedding of the message (1536 dimensions)
            message_text: Original message text
            sender_id: ID of the message sender
            timestamp: Message timestamp (defaults to now)
            metadata: Additional metadata to store with the embedding

        Raises:
            Exception: If upsert operation fails
        """
        try:
            # Prepare payload with message metadata
            payload = {
                "message_id": message_id,
                "conversation_id": conversation_id,
                "message_text": message_text,
                "sender_id": sender_id,
                "timestamp": (timestamp or datetime.now(timezone.utc)).isoformat(),
                "metadata": metadata or {}
            }

            # Convert message_id to integer point ID
            point_id = self._message_id_to_point_id(message_id)

            # Create point for insertion
            point = PointStruct(
                id=point_id,
                vector=embedding,
                payload=payload
            )

            # Upsert point into collection
            await self.client.upsert(
                collection_name=self.collection_name,
                points=[point]
            )

            logger.info(f"Upserted embedding for message {message_id} in conversation {conversation_id}")

        except Exception as e:
            logger.error(f"Failed to upsert embedding for message {message_id}: {e}")
            raise

    async def search_similar_questions(
        self,
        query_embedding: List[float],
        conversation_id: str,
        limit: int = 5,
        score_threshold: float = 0.85
    ) -> List[Dict[str, Any]]:
        """
        Search for similar messages within a conversation.

        Args:
            query_embedding: Vector embedding of the query message
            conversation_id: ID of the conversation to search within
            limit: Maximum number of results to return
            score_threshold: Minimum similarity score (0-1, cosine similarity)

        Returns:
            List of similar messages with scores and metadata
            Each item contains: id, score, message_text, sender_id, timestamp, metadata

        Raises:
            Exception: If search operation fails
        """
        try:
            # Create filter for conversation_id
            conversation_filter = Filter(
                must=[
                    FieldCondition(
                        key="conversation_id",
                        match=MatchValue(value=conversation_id)
                    )
                ]
            )

            # Perform similarity search
            search_results = await self.client.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                query_filter=conversation_filter,
                limit=limit,
                score_threshold=score_threshold
            )

            # Format results
            results = []
            for hit in search_results:
                results.append({
                    "id": hit.id,
                    "score": hit.score,
                    "message_text": hit.payload.get("message_text"),
                    "sender_id": hit.payload.get("sender_id"),
                    "timestamp": hit.payload.get("timestamp"),
                    "metadata": hit.payload.get("metadata", {})
                })

            logger.info(
                f"Found {len(results)} similar messages in conversation {conversation_id} "
                f"(threshold: {score_threshold})"
            )

            return results

        except Exception as e:
            logger.error(f"Failed to search similar messages in conversation {conversation_id}: {e}")
            raise

    async def health_check(self) -> Dict[str, Any]:
        """
        Check the health status of the vector store connection.

        Returns:
            Dict with connection status and collection info
        """
        try:
            # Get collection info
            collections = await self.client.get_collections()
            collection_exists = any(
                col.name == self.collection_name
                for col in collections.collections
            )

            # Get collection stats if it exists
            collection_info = None
            if collection_exists:
                info = await self.client.get_collection(self.collection_name)
                collection_info = {
                    "name": self.collection_name,
                    "vectors_count": info.vectors_count,
                    "points_count": info.points_count,
                    "status": info.status.value if hasattr(info.status, 'value') else str(info.status)
                }

            logger.info("Vector store health check successful")

            return {
                "status": "connected",
                "collection_exists": collection_exists,
                "collection_info": collection_info,
                "total_collections": len(collections.collections)
            }

        except Exception as e:
            logger.error(f"Vector store health check failed: {e}")
            return {
                "status": "disconnected",
                "error": str(e)
            }

    async def close(self) -> None:
        """
        Close the Qdrant client connection and cleanup resources.
        """
        try:
            await self.client.close()
            logger.info("VectorStore client closed successfully")
        except Exception as e:
            logger.error(f"Error closing VectorStore client: {e}")
