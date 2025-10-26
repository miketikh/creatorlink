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
 * @param existingTagsByUser - Current status tags per user
 * @returns Promise with categorization result including category and per-user status tags
 */
export async function categorizeConversation(
  messageText: string,
  conversationHistory: ConversationMessage[],
  existingCategory?: string,
  conversationId?: string,
  participantIds?: string[],
  lastMessageSenderId?: string,
  existingTagsByUser?: { [userId: string]: { statusTags: string[] } }
): Promise<CategorizationResult> {
  const startTime = Date.now();

  try {
    logger.info("Starting conversation categorization", {
      messageLength: messageText.length,
      historyCount: conversationHistory.length,
      existingCategory,
      existingTagsByUser,
      conversationId,
    });

    // Check cache first (skip cache if we have existing tags - cache doesn't account for tag context)
    if (conversationId && !existingTagsByUser) {
      const cachedResult = getCachedResult(conversationId);
      if (cachedResult) {
        logger.info("Returning cached categorization result", {
          conversationId,
          category: cachedResult.category.category,
        });
        return cachedResult;
      }
    } else if (conversationId && existingTagsByUser) {
      logger.info("Skipping cache - analyzing with existing tags context", {
        conversationId,
      });
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

    // Build existing tags display
    let existingTagsSection = "";
    if (existingTagsByUser && Object.keys(existingTagsByUser).length > 0) {
      const tagLines = Object.entries(existingTagsByUser).map(([userId, data]) => {
        const tags = data.statusTags || [];
        const tagList = tags.length > 0 ? JSON.stringify(tags) : "[] (no tags)";
        return `- ${userId}: ${tagList}`;
      }).join("\n");
      existingTagsSection = `\n\nCURRENT STATUS TAGS:\n${tagLines}`;
    } else if (participantIds && participantIds.length > 0) {
      // Show that all participants have no tags
      const tagLines = participantIds.map(id => `- ${id}: [] (no tags)`).join("\n");
      existingTagsSection = `\n\nCURRENT STATUS TAGS:\n${tagLines}`;
    }

    const systemPrompt = `You are a conversation classifier. Analyze conversations and assign tags based on category and each participant's perspective.

CATEGORIES (choose ONE):
- Business: brand deals, sponsorships, contracts, payments, partnerships
- Collaboration: creative projects, content ideas, joint ventures
- Social: casual conversation, personal updates, friendly chats
- Fan: fan messages, appreciation, content requests

CATEGORY UPDATE RULES:
1. If the message EXPLICITLY states a category change (e.g., "we're no longer collaborating", "this is now business", "just social contact"), change the category immediately with high confidence (>0.85)
2. If the conversation naturally shifts topics without explicit statements, require very strong evidence to change (confidence > 0.9) - maintain stability
3. Look for clear relationship changes: "let's work together" → collaboration, "brand deal" → business, "just friends" → social
4. If in doubt between keeping existing vs changing, favor the existing category for stability

STATUS TAGS (assign to each participant based on their perspective):
- "needsResponse": This person needs to reply to a question or request
- "awaitingReply": This person is waiting for someone else to respond
- "urgent": This person needs to respond quickly - immediate plans, time-sensitive questions, things happening soon (next hour or so)/now, or explicit urgency.

IMPORTANT - Status Tag Rules:
- You are UPDATING existing tags, not creating from scratch
- Review the CURRENT STATUS TAGS carefully - they show what's already set
- Only include participants whose tags should CHANGE from their current state
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

    const userPrompt = `${participantSection}${existingTagsSection}

CONVERSATION HISTORY:
${contextMessages}

CURRENT MESSAGE: "${messageText}"
${senderInfo}

${existingCategory ? `EXISTING CATEGORY: ${existingCategory}` : "NO EXISTING CATEGORY"}

Review the CURRENT STATUS TAGS above. Based on the new message, determine which tags should change.
Return ONLY the participants whose tags need updating. Use [] to clear all tags, omit if unchanged.`;

    const completion = await openai.chat.completions.create({
      model: "gpt-4.1-mini",
      messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: userPrompt},
      ],
      response_format: {type: "json_object"},
      // max_completion_tokens: 500,
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

    // Always include the user, even with empty array (empty = clear tags)
    statusTagsByUser[userId] = validTags;
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
