"""
Q+A Detector Module using GPT-4o-mini for intelligent question-answer pairing.
Analyzes conversation context to detect when a message answers a previous question.
"""

import os
import logging
import asyncio
import json
from typing import List, Optional, Dict, Any
from dataclasses import dataclass
from datetime import datetime

from openai import AsyncOpenAI, APIError, RateLimitError, APIConnectionError

logger = logging.getLogger(__name__)


@dataclass
class ContextMessage:
    """Represents a message in conversation context."""
    messageId: str
    senderId: str
    text: str
    timestamp: Dict[str, int]  # Firebase timestamp with _seconds and _nanoseconds


@dataclass
class QAPair:
    """Represents a detected question-answer pair."""
    question_text: str
    question_message_id: str
    question_sender_id: str
    answer_text: str
    answer_message_id: str
    answer_sender_id: str
    confidence: float
    reasoning: Optional[str] = None


class QADetector:
    """Service for detecting Q+A pairs using GPT-4o-mini context analysis."""

    def __init__(self):
        """
        Initialize OpenAI client for Q+A detection.
        Uses GPT-4o-mini for cost-effective context analysis.
        """
        self.api_key = os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            logger.warning("OPENAI_API_KEY not set - Q+A detection will fail")

        self.model = os.getenv("OPENAI_CHAT_MODEL", "gpt-4o-mini")
        self.confidence_threshold = float(os.getenv("QA_CONFIDENCE_THRESHOLD", "0.7"))

        # Initialize AsyncOpenAI client
        self.client = AsyncOpenAI(api_key=self.api_key)

        # Configuration
        self.max_retries = 3
        self.initial_retry_delay = 1.0  # seconds
        self.max_context_length = 5  # Maximum number of context messages to analyze

        logger.info(
            f"QADetector initialized with model={self.model}, "
            f"confidence_threshold={self.confidence_threshold}"
        )

    def _format_context_for_prompt(self, messages: List[ContextMessage]) -> str:
        """
        Format context messages for GPT prompt.
        Limits to last 5 messages, truncates long messages.

        Args:
            messages: List of context messages (ordered oldest to newest)

        Returns:
            Formatted string representation of context
        """
        # Take only last 5 messages
        recent_messages = messages[-self.max_context_length:]

        formatted_lines = []
        for idx, msg in enumerate(recent_messages):
            # Truncate long messages to 200 characters for context
            text = msg.text[:200] + "..." if len(msg.text) > 200 else msg.text
            formatted_lines.append(f"[{idx}] {msg.senderId}: {text}")

        return "\n".join(formatted_lines)

    async def detect_qa_pair(
        self,
        new_message: ContextMessage,
        context: List[ContextMessage],
        retry_count: int = 0
    ) -> Optional[QAPair]:
        """
        Detect if new message answers any question in the conversation context.

        Uses GPT-4o-mini to analyze semantic relationships between messages,
        detecting both explicit and implicit question-answer pairs.

        Args:
            new_message: The incoming message to analyze
            context: Previous messages in conversation (ordered oldest to newest)
            retry_count: Current retry attempt (used internally)

        Returns:
            QAPair if a valid Q+A pair is detected (confidence >= threshold), None otherwise

        Raises:
            APIError: If OpenAI API call fails after retries
        """
        # Skip if no context
        if not context:
            logger.debug("No context available for Q+A detection")
            return None

        # Skip if message is too short (likely not an answer)
        if len(new_message.text.strip()) < 2:
            logger.debug("Message too short for Q+A detection")
            return None

        try:
            # Format context for prompt
            context_str = self._format_context_for_prompt(context)

            # Create system prompt
            system_prompt = """You are an expert at analyzing conversations to detect question-answer pairs.
Your task is to determine if a new message answers any question in the conversation context.

Consider:
- Explicit questions (containing '?')
- Implicit questions ('anyone free?', 'thoughts?', 'ideas?')
- Short answers ('$30', '7pm', 'yes', 'tomorrow')
- Semantic relationships, not just keywords

Return your analysis in JSON format."""

            # Create user prompt
            user_prompt = f"""Conversation context (ordered oldest to newest):
{context_str}

New message:
{new_message.senderId}: {new_message.text}

Does this new message answer any question in the context?

Respond with JSON:
{{
    "is_answer": true/false,
    "question_index": 0-4 (which context message is the question, or null if not an answer),
    "confidence": 0.0-1.0 (your confidence in this assessment),
    "reasoning": "brief explanation of your decision"
}}"""

            # Call GPT-4o-mini with JSON mode
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.3,  # Lower temperature for more consistent analysis
                max_tokens=200  # Short response needed
            )

            # Parse response
            response_text = response.choices[0].message.content
            result = json.loads(response_text)

            # Extract fields
            is_answer = result.get("is_answer", False)
            question_index = result.get("question_index")
            confidence = float(result.get("confidence", 0.0))
            reasoning = result.get("reasoning", "")

            logger.info(
                f"Q+A detection: is_answer={is_answer}, "
                f"confidence={confidence:.2f}, reasoning={reasoning}"
            )

            # Check if it's a valid answer with sufficient confidence
            if not is_answer or confidence < self.confidence_threshold:
                logger.debug(
                    f"No valid Q+A pair detected (is_answer={is_answer}, "
                    f"confidence={confidence:.2f} < {self.confidence_threshold})"
                )
                return None

            # Validate question index
            if question_index is None or question_index < 0 or question_index >= len(context):
                logger.warning(
                    f"Invalid question_index={question_index} for context length {len(context)}"
                )
                return None

            # Get the question message from context
            # Note: context is last N messages, so we need to index from the limited context
            recent_context = context[-self.max_context_length:]
            question_message = recent_context[question_index]

            # Create QAPair
            qa_pair = QAPair(
                question_text=question_message.text,
                question_message_id=question_message.messageId,
                question_sender_id=question_message.senderId,
                answer_text=new_message.text,
                answer_message_id=new_message.messageId,
                answer_sender_id=new_message.senderId,
                confidence=confidence,
                reasoning=reasoning
            )

            logger.info(
                f"Q+A pair detected: Q='{question_message.text[:50]}...' "
                f"A='{new_message.text[:50]}...' (confidence={confidence:.2f})"
            )

            return qa_pair

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse GPT response as JSON: {e}, response: {response_text}")
            return None

        except RateLimitError as e:
            # Rate limit hit - retry with exponential backoff
            if retry_count < self.max_retries:
                delay = self.initial_retry_delay * (2 ** retry_count)
                logger.warning(
                    f"Rate limit hit, retrying in {delay}s (attempt {retry_count + 1}/{self.max_retries})"
                )
                await asyncio.sleep(delay)
                return await self.detect_qa_pair(new_message, context, retry_count + 1)
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
                return await self.detect_qa_pair(new_message, context, retry_count + 1)
            else:
                logger.error(f"API connection failed after {self.max_retries} retries")
                raise

        except APIError as e:
            logger.error(f"OpenAI API error during Q+A detection: {e}")
            raise

        except Exception as e:
            logger.error(f"Unexpected error in Q+A detection: {e}", exc_info=True)
            raise

    def estimate_cost_per_detection(self, context_length: int = 5) -> Dict[str, Any]:
        """
        Estimate the cost of a single Q+A detection call.

        Args:
            context_length: Number of context messages (default 5)

        Returns:
            Dict with estimated tokens and cost
        """
        # Rough estimates for GPT-4o-mini
        # System prompt: ~100 tokens
        # Context: ~40 tokens per message (truncated to 200 chars)
        # New message: ~20 tokens (average)
        # Total input: ~100 + (40 * context_length) + 20
        estimated_input_tokens = 100 + (40 * context_length) + 20

        # Response: ~50 tokens (JSON output)
        estimated_output_tokens = 50

        # GPT-4o-mini pricing (as of 2025):
        # $0.15 per 1M input tokens
        # $0.60 per 1M output tokens
        input_cost = (estimated_input_tokens / 1_000_000) * 0.15
        output_cost = (estimated_output_tokens / 1_000_000) * 0.60
        total_cost = input_cost + output_cost

        return {
            "estimated_input_tokens": estimated_input_tokens,
            "estimated_output_tokens": estimated_output_tokens,
            "cost_usd": total_cost,
            "model": self.model
        }
