"""
Embeddings Module for generating OpenAI embeddings.
Handles embedding generation with retry logic, token counting, and cost estimation.
"""

import os
import logging
import time
from typing import List, Optional, Dict
import asyncio

import tiktoken
from openai import AsyncOpenAI, APIError, RateLimitError, APIConnectionError

logger = logging.getLogger(__name__)


class EmbeddingService:
    """Service for generating embeddings using OpenAI API."""

    def __init__(self):
        """
        Initialize OpenAI client and configuration.
        Reads model and dimensions from environment variables.
        """
        self.api_key = os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            logger.warning("OPENAI_API_KEY not set - embedding generation will fail")

        self.model = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
        self.dimensions = int(os.getenv("OPENAI_EMBEDDING_DIMENSIONS", "1536"))

        # Initialize AsyncOpenAI client
        self.client = AsyncOpenAI(api_key=self.api_key)

        # Initialize tokenizer for the embedding model
        # text-embedding-3-small uses cl100k_base encoding
        try:
            self.tokenizer = tiktoken.get_encoding("cl100k_base")
        except Exception as e:
            logger.warning(f"Failed to load tokenizer, token counting will be approximate: {e}")
            self.tokenizer = None

        # Configuration
        self.max_tokens = 8191  # Max tokens for text-embedding-3-small
        self.max_retries = 3
        self.initial_retry_delay = 1.0  # seconds

        logger.info(
            f"EmbeddingService initialized with model={self.model}, "
            f"dimensions={self.dimensions}, max_tokens={self.max_tokens}"
        )

    def count_tokens(self, text: str) -> int:
        """
        Count the number of tokens in a text string.

        Args:
            text: Input text to count tokens for

        Returns:
            Number of tokens (approximate if tokenizer unavailable)
        """
        if not text:
            return 0

        if self.tokenizer:
            try:
                return len(self.tokenizer.encode(text))
            except Exception as e:
                logger.warning(f"Error counting tokens: {e}, using approximation")

        # Fallback: approximate 1 token per 4 characters
        return len(text) // 4

    def truncate_text(self, text: str, max_tokens: Optional[int] = None) -> str:
        """
        Truncate text to fit within token limit.

        Args:
            text: Input text to truncate
            max_tokens: Maximum number of tokens (defaults to self.max_tokens)

        Returns:
            Truncated text that fits within token limit
        """
        if not text:
            return text

        max_tokens = max_tokens or self.max_tokens
        token_count = self.count_tokens(text)

        if token_count <= max_tokens:
            return text

        # If we have a tokenizer, use it for precise truncation
        if self.tokenizer:
            try:
                tokens = self.tokenizer.encode(text)
                truncated_tokens = tokens[:max_tokens]
                truncated_text = self.tokenizer.decode(truncated_tokens)
                logger.info(
                    f"Truncated text from {token_count} tokens to {max_tokens} tokens"
                )
                return truncated_text
            except Exception as e:
                logger.warning(f"Error truncating with tokenizer: {e}, using character-based truncation")

        # Fallback: character-based truncation (approximate)
        # Estimate: 1 token ≈ 4 characters
        max_chars = max_tokens * 4
        truncated_text = text[:max_chars]
        logger.info(
            f"Truncated text from ~{token_count} tokens to ~{max_tokens} tokens (approximate)"
        )
        return truncated_text

    async def generate_embedding(
        self,
        text: str,
        retry_count: int = 0
    ) -> List[float]:
        """
        Generate embedding vector for input text with retry logic.

        Args:
            text: Input text to embed
            retry_count: Current retry attempt (used internally)

        Returns:
            Embedding vector (list of floats with self.dimensions length)

        Raises:
            ValueError: If text is empty or invalid
            APIError: If OpenAI API call fails after retries
        """
        # Validate input
        if not text or not text.strip():
            raise ValueError("Cannot generate embedding for empty text")

        # Truncate if necessary
        text = self.truncate_text(text)

        try:
            # Call OpenAI API
            response = await self.client.embeddings.create(
                model=self.model,
                input=text,
                dimensions=self.dimensions
            )

            # Extract embedding vector
            embedding = response.data[0].embedding

            logger.debug(
                f"Generated embedding for text (length={len(text)}, "
                f"tokens={self.count_tokens(text)})"
            )

            return embedding

        except RateLimitError as e:
            # Rate limit hit - retry with exponential backoff
            if retry_count < self.max_retries:
                delay = self.initial_retry_delay * (2 ** retry_count)
                logger.warning(
                    f"Rate limit hit, retrying in {delay}s (attempt {retry_count + 1}/{self.max_retries})"
                )
                await asyncio.sleep(delay)
                return await self.generate_embedding(text, retry_count + 1)
            else:
                logger.error(f"Rate limit exceeded after {self.max_retries} retries")
                raise

        except APIConnectionError as e:
            # Connection error - retry with exponential backoff
            if retry_count < self.max_retries:
                delay = self.initial_retry_delay * (2 ** retry_count)
                logger.warning(
                    f"API connection error, retrying in {delay}s (attempt {retry_count + 1}/{self.max_retries}): {e}"
                )
                await asyncio.sleep(delay)
                return await self.generate_embedding(text, retry_count + 1)
            else:
                logger.error(f"API connection failed after {self.max_retries} retries")
                raise

        except APIError as e:
            # Other API errors - log and raise
            logger.error(f"OpenAI API error: {e}")
            raise

        except Exception as e:
            # Unexpected errors
            logger.error(f"Unexpected error generating embedding: {e}", exc_info=True)
            raise

    async def batch_generate_embeddings(
        self,
        texts: List[str],
        batch_size: int = 100
    ) -> List[List[float]]:
        """
        Generate embeddings for multiple texts in batches.
        Maintains order of input texts in output embeddings.

        Args:
            texts: List of input texts to embed
            batch_size: Maximum number of texts per API call (OpenAI limit is 100)

        Returns:
            List of embedding vectors in same order as input texts

        Raises:
            ValueError: If any text is empty or invalid
            APIError: If OpenAI API call fails
        """
        if not texts:
            return []

        # Validate batch size
        if batch_size > 100:
            logger.warning(f"Batch size {batch_size} exceeds OpenAI limit of 100, using 100")
            batch_size = 100

        all_embeddings = []

        # Process in batches
        for i in range(0, len(texts), batch_size):
            batch = texts[i:i + batch_size]

            # Truncate each text in batch
            truncated_batch = [self.truncate_text(text) for text in batch]

            # Validate batch
            if any(not text.strip() for text in truncated_batch):
                raise ValueError("Cannot generate embeddings for empty texts in batch")

            try:
                # Call OpenAI API for batch
                response = await self.client.embeddings.create(
                    model=self.model,
                    input=truncated_batch,
                    dimensions=self.dimensions
                )

                # Extract embeddings in order
                batch_embeddings = [data.embedding for data in response.data]
                all_embeddings.extend(batch_embeddings)

                logger.info(
                    f"Generated {len(batch_embeddings)} embeddings "
                    f"(batch {i // batch_size + 1}/{(len(texts) - 1) // batch_size + 1})"
                )

            except Exception as e:
                logger.error(f"Error generating batch embeddings for batch starting at index {i}: {e}")
                raise

        return all_embeddings

    def estimate_cost(self, texts: List[str]) -> Dict[str, float]:
        """
        Estimate the cost of embedding generation for a list of texts.

        Args:
            texts: List of texts to estimate cost for

        Returns:
            Dict with total_tokens, cost_usd, and cost_per_text
        """
        # Count total tokens
        total_tokens = sum(self.count_tokens(text) for text in texts)

        # Cost for text-embedding-3-small: $0.02 per 1M tokens
        cost_per_million_tokens = 0.02
        cost_usd = (total_tokens / 1_000_000) * cost_per_million_tokens

        # Calculate per-text cost
        cost_per_text = cost_usd / len(texts) if texts else 0

        return {
            "total_tokens": total_tokens,
            "cost_usd": cost_usd,
            "cost_per_text": cost_per_text,
            "model": self.model
        }
