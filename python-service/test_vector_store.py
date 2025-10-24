"""
Simple test script for VectorStore functionality.
Tests initialization, upserting, and searching operations.
"""

import asyncio
import logging
from datetime import datetime
from app.vector_store import VectorStore

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def test_vector_store():
    """Test VectorStore basic operations."""

    logger.info("=== Starting VectorStore Test ===")

    try:
        # 1. Initialize VectorStore
        logger.info("1. Initializing VectorStore...")
        vector_store = VectorStore()

        # 2. Initialize collection
        logger.info("2. Initializing collection...")
        await vector_store.initialize_collection()

        # 3. Health check
        logger.info("3. Running health check...")
        health_status = await vector_store.health_check()
        logger.info(f"Health status: {health_status}")

        # 4. Create test embeddings (1536 dimensions, all zeros for testing)
        logger.info("4. Creating test embeddings...")
        test_embedding_1 = [0.1] * 1536  # Simulate embedding
        test_embedding_2 = [0.2] * 1536  # Different embedding
        test_embedding_3 = [0.1] * 1536  # Similar to first one

        # 5. Upsert test messages
        logger.info("5. Upserting test messages...")

        await vector_store.upsert_message_embedding(
            message_id="msg_001",
            conversation_id="conv_001",
            embedding=test_embedding_1,
            message_text="What are your office hours?",
            sender_id="user_123",
            timestamp=datetime.utcnow(),
            metadata={"test": True, "category": "faq"}
        )

        await vector_store.upsert_message_embedding(
            message_id="msg_002",
            conversation_id="conv_001",
            embedding=test_embedding_2,
            message_text="How do I reset my password?",
            sender_id="user_456",
            timestamp=datetime.utcnow(),
            metadata={"test": True, "category": "faq"}
        )

        await vector_store.upsert_message_embedding(
            message_id="msg_003",
            conversation_id="conv_002",  # Different conversation
            embedding=test_embedding_3,
            message_text="When are you open?",
            sender_id="user_789",
            timestamp=datetime.utcnow(),
            metadata={"test": True, "category": "faq"}
        )

        logger.info("Upserted 3 test messages")

        # 6. Search for similar messages in conversation
        logger.info("6. Searching for similar messages...")

        # Search in conv_001 with a query similar to msg_001
        query_embedding = [0.1] * 1536
        results = await vector_store.search_similar_questions(
            query_embedding=query_embedding,
            conversation_id="conv_001",
            limit=5,
            score_threshold=0.5  # Lower threshold for testing
        )

        logger.info(f"Found {len(results)} similar messages in conv_001:")
        for i, result in enumerate(results, 1):
            logger.info(f"  {i}. Message: '{result['message_text']}' (score: {result['score']:.4f})")

        # 7. Final health check to see collection stats
        logger.info("7. Final health check with collection stats...")
        final_health = await vector_store.health_check()
        logger.info(f"Final health status: {final_health}")

        # 8. Cleanup
        logger.info("8. Closing VectorStore...")
        await vector_store.close()

        logger.info("=== VectorStore Test Complete ===")
        logger.info("✅ All tests passed!")

    except Exception as e:
        logger.error(f"❌ Test failed: {e}", exc_info=True)
        raise


if __name__ == "__main__":
    asyncio.run(test_vector_store())
