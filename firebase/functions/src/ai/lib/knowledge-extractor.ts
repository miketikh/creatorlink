/**
 * Knowledge Extraction Helper
 * Uses OpenAI GPT-4o-mini to extract normalized, self-contained facts from user messages.
 *
 * Key Design Principles:
 * - Facts must be self-contained (readable without conversation context)
 * - Facts should be ABOUT the user (not about others)
 * - Uses last 5 messages as context to handle multi-message answers
 * - Normalizes pronouns and incomplete statements into complete facts
 *
 * Examples:
 * - Q: "Do you have pets?" A: "Yes, one dog" → "User has one dog"
 * - Q: "What's his name?" A: "Max" → "User's dog is named Max"
 * - "I charge $500/hour for consulting" → "User charges $500/hour for consulting"
 * - "I'm vegan" → "User is vegan"
 * - "How are you doing?" → No facts (just greeting)
 */

import * as logger from "firebase-functions/logger";
import {getOpenAIClient} from "../client";
import {KnowledgeExtractionResult} from "../types";
import {ConversationMessage} from "./message-fetcher";

/**
 * Extract knowledge facts from a message using recent conversation context.
 *
 * @param messageText - The current message text to analyze
 * @param recentMessages - Last 5 messages for context (oldest first)
 * @param senderId - ID of the message sender (the user we're extracting facts about)
 * @returns Promise with extracted facts or empty array if none found
 */
export async function extractKnowledge(
  messageText: string,
  recentMessages: ConversationMessage[],
  senderId: string
): Promise<KnowledgeExtractionResult> {
  const startTime = Date.now();

  try {
    logger.info("Starting knowledge extraction", {
      messageLength: messageText.length,
      contextMessages: recentMessages.length,
      senderId,
    });

    const openai = getOpenAIClient();

    // Build conversation context from recent messages
    const conversationContext = recentMessages
      .map((msg, idx) => {
        const isTargetUser = msg.senderId === senderId;
        const prefix = isTargetUser ? "USER" : "OTHER";
        return `${prefix}: ${msg.text}`;
      })
      .join("\n");

    const systemPrompt = `You are a fact extraction assistant. Your job is to extract factual information ABOUT the user from their messages.

CRITICAL RULES:
1. **Self-contained facts**: Each fact must be a complete, standalone sentence that makes sense without reading the conversation
2. **Normalize facts**: Convert pronouns, incomplete answers, and context-dependent statements into complete facts
3. **About the user**: Only extract facts ABOUT the user themselves (not facts they mention about others)
4. **Factual only**: Ignore greetings, questions, opinions, and general conversation
5. **Use context**: Use the conversation history to understand incomplete answers (e.g., "Yes" or "Max" as answers to questions)

NORMALIZATION EXAMPLES:
- Q: "Do you have pets?" A: "Yes, one dog" → Extract: "User has one dog"
- Q: "What's his name?" A: "Max" → Extract: "User's dog is named Max"
- Q: "How old?" A: "He's 3" → Extract: "User's dog Max is three years old"
- "I charge $500/hour" → Extract: "User charges $500/hour for consulting"
- "I'm vegan" → Extract: "User is vegan"
- "My wife's name is Sarah" → Extract: "User's wife is named Sarah"

IGNORE THESE:
- Greetings: "How are you?", "What's up?", "Good morning"
- Questions asking others
- General conversation: "That's interesting", "I agree"
- Opinions about topics (unless about user's preference/belief)

Respond with JSON only: {"facts": [{"text": "normalized fact text"}]}

If no facts found, return: {"facts": []}`;

    const userPrompt = `CONVERSATION CONTEXT (last 5 messages):
${conversationContext}

CURRENT MESSAGE TO ANALYZE:
USER: ${messageText}

Extract all factual information ABOUT the user from the current message, using the conversation context to normalize incomplete answers.`;

    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
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
      logger.warn("Empty response from OpenAI during knowledge extraction");
      return {success: true, facts: []};
    }

    const parsed = JSON.parse(responseContent) as {facts: Array<{text: string}>};

    // Convert to KnowledgeFact format (without id/embedding yet - those are added during storage)
    const facts = parsed.facts.map(f => ({
      id: "", // Will be set by Firestore
      userId: senderId,
      text: f.text,
      embedding: [], // Will be generated during storage
      createdAt: new Date(),
      updatedAt: new Date(),
    }));

    const duration = Date.now() - startTime;
    logger.info("Knowledge extraction complete", {
      factsExtracted: facts.length,
      durationMs: duration,
      senderId,
    });

    if (facts.length > 0) {
      logger.info("Extracted facts:", {
        facts: facts.map(f => f.text),
      });
    }

    return {
      success: true,
      facts,
    };

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Knowledge extraction failed", {
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
      senderId,
    });

    return {
      success: false,
      facts: [],
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
