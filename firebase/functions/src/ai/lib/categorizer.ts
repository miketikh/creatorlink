/**
 * Message Categorization Helper
 * Uses OpenAI GPT-4o-mini to categorize conversations based on content.
 */

import * as logger from "firebase-functions/logger";
import {getOpenAIClient} from "../client";
import {
  CategorizationResult,
  ConversationCategory,
  StatusTag,
  CategoryDetectionResult,
  StatusDetectionResult,
} from "../types";
import {ConversationMessage} from "./message-fetcher";
import {
  getCachedResult,
  setCachedResult,
  isGlobalRateLimitExceeded,
  incrementAPICallCounter,
  trackAPICall,
} from "./rate-limiter";

/**
 * Categorize a conversation based on message content and history.
 *
 * @param messageText - The current message text to analyze
 * @param conversationHistory - Recent messages for context (last 5-10)
 * @param existingCategory - Current category if any
 * @param conversationId - Conversation ID for caching
 * @param participantIds - Array of participant user IDs
 * @param lastMessageSenderId - ID of user who sent the last message
 * @returns Promise with categorization result including category and per-user status tags
 */
export async function categorizeConversation(
  messageText: string,
  conversationHistory: ConversationMessage[],
  existingCategory?: string,
  conversationId?: string,
  participantIds?: string[],
  lastMessageSenderId?: string
): Promise<CategorizationResult> {
  const startTime = Date.now();

  try {
    logger.info("Starting conversation categorization", {
      messageLength: messageText.length,
      historyCount: conversationHistory.length,
      existingCategory,
      conversationId,
    });

    // Check cache first
    if (conversationId) {
      const cachedResult = getCachedResult(conversationId);
      if (cachedResult) {
        logger.info("Returning cached categorization result", {
          conversationId,
          category: cachedResult.category.category,
        });
        return cachedResult;
      }
    }

    // Check global rate limit
    if (isGlobalRateLimitExceeded()) {
      logger.warn("Global rate limit exceeded - returning safe default", {
        conversationId,
      });
      return getSafeDefault();
    }

    // Increment counters
    incrementAPICallCounter();

    const openai = getOpenAIClient();

    // Build conversation context from history with clear user labels
    const contextMessages = conversationHistory
      .slice(-10) // Use last 10 messages for context
      .map(msg => `${msg.senderId}: ${msg.text}`)
      .join("\n");

    // Build participant mapping for clarity
    const participantMapping = participantIds && participantIds.length > 0 ?
      participantIds.map((id, index) => `- User ${String.fromCharCode(65 + index)} (ID: ${id})`).join("\n") : "";

    const systemPrompt = `You are a conversation classifier. Analyze conversations and assign tags based on category and each participant's perspective.

CATEGORIES (choose ONE):
- Business: brand deals, sponsorships, contracts, payments, partnerships
- Collaboration: creative projects, content ideas, joint ventures
- Social: casual conversation, personal updates, friendly chats
- Fan: fan messages, appreciation, content requests

IMPORTANT: If an existing category is provided, keep it UNLESS there's very strong evidence the category should change (confidence > 0.9). Categories should be stable - don't switch based on a single message.

STATUS TAGS (assign to each participant based on their perspective):
- "needsResponse": This person needs to reply to a question or request
- "awaitingReply": This person is waiting for someone else to respond
- "urgent": This person needs to respond quickly - immediate plans, time-sensitive questions, things happening soon (next hour or so)/now, or explicit urgency.  

IMPORTANT - Status Tag Rules:
- Only include participants whose tags should change
- Use empty array [] to clear all tags for that participant
- Omit participant ID if their tags should remain unchanged
- Analyze the status changes from both participants (ie. if someone was waiting for a reply then responded with a question, it should update statuses for both participants)
- Update contextually! If a message says "urgent," and the person responds to it, it should no longer be urgent for that person.

Examples:

Bob asks Alice: "What are you doing later?"
{
  "statusTagsByUser": {
    "bob123": ["awaitingReply"],
    "alice456": ["needsResponse"]
  }
}

Alice answers: "Going to the gym"
{
  "statusTagsByUser": {
    "bob123": [],
    "alice456": []
  }
}

Bob: "Are you coming? We're about to leave"
{
  "statusTagsByUser": {
    "bob123": ["awaitingReply"],
    "alice456": ["urgent", "needsResponse"]  // Immediate situation, needs quick response
  }
}

Respond with JSON:
{
  "category": {
    "category": "business" | "collaboration" | "social" | "fan",
    "confidence": 0-1,
    "reasoning": "brief explanation"
  },
  "status": {
    "statusTagsByUser": {
      "participantId1": ["tag1", "tag2"],
      "participantId2": [],
      "participantId3": ["tag1"]
    },
    "reasoning": "why these tags"
  }
}`;

    // Build participant info with clear mapping
    const participantSection = participantMapping ?
      `\nPARTICIPANTS IN THIS CONVERSATION:\n${participantMapping}` : "";
    const senderInfo = lastMessageSenderId ?
      `\nLast message sent by: ${lastMessageSenderId}` : "";

    const userPrompt = `${participantSection}

CONVERSATION HISTORY:
${contextMessages}

CURRENT MESSAGE: "${messageText}"
${senderInfo}

${existingCategory ? `EXISTING CATEGORY: ${existingCategory}` : "NO EXISTING CATEGORY"}

Analyze this conversation and update status tags based on participant perspective.
Only include participants whose tags should change. Use [] to clear tags, omit if unchanged.`;

    const completion = await openai.chat.completions.create({
      model: "gpt-4.1-mini",
      messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: userPrompt},
      ],
      response_format: {type: "json_object"},
      temperature: 0.3,
      max_tokens: 500,
    });

    const responseContent = completion.choices[0]?.message?.content;

    if (!responseContent) {
      logger.warn("Empty response from OpenAI");
      return getSafeDefault();
    }

    const result = JSON.parse(responseContent) as CategorizationResult;

    // Validate and normalize the result
    const normalizedResult = normalizeCategorizationResult(result);

    // Track cost
    trackAPICall();

    // Cache the result
    if (conversationId) {
      setCachedResult(conversationId, normalizedResult);
    }

    const duration = Date.now() - startTime;
    logger.info("Categorization complete", {
      conversationId,
      category: normalizedResult.category.category,
      categoryConfidence: normalizedResult.category.confidence,
      statusTagsByUser: normalizedResult.status.statusTagsByUser,
      durationMs: duration,
    });

    return normalizedResult;

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Categorization failed", {
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    // Return safe default on error
    return getSafeDefault();
  }
}

/**
 * Normalize and validate categorization result from OpenAI.
 */
function normalizeCategorizationResult(result: any): CategorizationResult {
  // Validate category
  const categoryStr = result.category?.category?.toLowerCase() || "social";
  const validCategory = Object.values(ConversationCategory)
    .find(c => c.toLowerCase() === categoryStr) || ConversationCategory.Social;

  const category: CategoryDetectionResult = {
    category: validCategory,
    confidence: Math.max(0, Math.min(1, result.category?.confidence || 0)),
    reasoning: result.category?.reasoning || "Default categorization",
  };

  // Validate per-user status tags
  const statusTagsByUser: { [userId: string]: StatusTag[] } = {};
  const rawStatusByUser = result.status?.statusTagsByUser || {};

  for (const [userId, tagsArray] of Object.entries(rawStatusByUser)) {
    if (!Array.isArray(tagsArray)) continue;

    const validTags = tagsArray
      .map((s: any) => {
        if (typeof s !== "string") return undefined;
        const lowerStatus = s.toLowerCase();
        return Object.values(StatusTag).find(st => st.toLowerCase() === lowerStatus);
      })
      .filter((s: any): s is StatusTag => s !== undefined);

    if (validTags.length > 0) {
      statusTagsByUser[userId] = validTags;
    }
  }

  const status: StatusDetectionResult = {
    statusTagsByUser,
    reasoning: result.status?.reasoning || "No specific status detected",
  };

  return {category, status};
}

/**
 * Return safe default categorization on error.
 */
function getSafeDefault(): CategorizationResult {
  return {
    category: {
      category: ConversationCategory.Social,
      confidence: 0,
      reasoning: "Error occurred, using default category",
    },
    status: {
      statusTagsByUser: {},
      reasoning: "Error occurred, no status assigned",
    },
  };
}
