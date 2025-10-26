/**
 * Knowledge Extraction from User Messages
 *
 * PURPOSE: Extract factual information ABOUT the message sender and store it in their knowledge base.
 *
 * IMPORTANT DISTINCTION:
 * - This extracts facts ABOUT the sender (the person who sent the message)
 * - NOT about the recipient or other people mentioned
 *
 * Example Scenario:
 * - Alice says: "I have three pets"
 * - Knowledge extraction stores about ALICE: "User has three pets"
 *
 * Another Example:
 * - Bob says: "I have three dogs, what about you?"
 * - Knowledge extraction stores about BOB: "User has three dogs"
 * - (The question part is ignored here - that's handled by query-transformer.ts)
 *
 * Uses last 5 messages as context to handle:
 * - Incomplete answers: Q: "Do you have pets?" A: "Yes, one dog" → "User has one dog"
 * - Follow-up questions: Q: "What's his name?" A: "Max" → "User's dog is named Max"
 *
 * Normalization Format (shared with query-transformer.ts):
 * - Use "User" as subject (represents the sender whose facts we're storing)
 * - Remove pronouns, use third person
 * - Present tense
 * - Concise and factual
 * - Self-contained (readable without conversation context)
 */

import * as logger from "firebase-functions/logger";
import {getOpenAIClient} from "../client";
import {KnowledgeExtractionResult} from "../types";
import {ConversationMessage} from "./message-fetcher";
import {testLog} from "./test-logger";

/**
 * Extract knowledge facts from a message using recent conversation context.
 *
 * This function focuses ONLY on extracting facts ABOUT the sender.
 * It uses conversation context to normalize incomplete answers into complete facts.
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
  try {
    // logger.info("Starting knowledge extraction", {
    //   messageLength: messageText.length,
    //   contextMessages: recentMessages.length,
    //   senderId,
    // });

    const openai = getOpenAIClient();

    // Build conversation context from recent messages
    const conversationContext = recentMessages
      .map((msg, idx) => {
        const isTargetUser = msg.senderId === senderId;
        const prefix = isTargetUser ? "USER" : "OTHER";
        return `${prefix}: ${msg.text}`;
      })
      .join("\n");

    const systemPrompt = `You are a fact extraction assistant for personal knowledge storage.

YOUR PURPOSE:
Extract factual information ABOUT the user (message sender) from their messages.
Store facts in their knowledge base for future retrieval.

FORMATTING RULES (match query transformation format):
- Use "User" as subject (represents the sender whose facts we're storing)
- Convert to complete, self-contained statements
- Remove pronouns, use third person
- Use present tense
- Be concise and factual

EXAMPLES:
Input: "I have three pets"
Output: "User has three pets"

Input: Q: "Do you have pets?" A: "Yes, one dog"
Output: "User has one dog"

Input: Q: "What's his name?" A: "Max"
Output: "User's dog is named Max"

Input: "I charge $500/hour for consulting"
Output: "User charges $500/hour for consulting"

Input: "I'm staying in tonight, do you have any plans?"
Output: "User is staying in tonight"

IGNORE:
- Greetings and pleasantries
- Questions the user asks others
- General conversational filler
- Opinions about topics (unless it's a personal preference/belief)

KEY PRINCIPLE:
Only extract facts ABOUT the user themselves, not about others they mention.

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

    // logger.info("Knowledge extraction complete", {
    //   factsExtracted: facts.length,
    //   durationMs: Date.now() - startTime,
    //   senderId,
    // });

    if (facts.length > 0) {
      testLog("📝 EXTRACTED FACTS", {
        userId: senderId,
        facts: facts.map(f => f.text),
      });
    }

    return {
      success: true,
      facts,
    };

  } catch (error) {
    // logger.error("Knowledge extraction failed", {
    //   error: error instanceof Error ? error.message : String(error),
    //   durationMs: Date.now() - startTime,
    //   senderId,
    // });

    return {
      success: false,
      facts: [],
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
