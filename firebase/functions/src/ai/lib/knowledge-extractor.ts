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
- Be concise and factual
- Use previous messages context
- You may extract multiple facts

EXAMPLES:
Input: "I have three pets"
Output: "User has three pets"

Input: Q: "Do you have pets?" A: "Yes, one dog"
Output: "User has one dog"

Input: previous messages: "What kind of movies do you like? I like action movies.", current message: "I prefer drama, I acted in a drama play last year."
Output: Using previous context, you can determine that the conversations is about movie preferences, so based on the last message, two new facts are extracted: "User likes drama movies" and "User acted in a drama play last year".

IGNORE:
- Greetings and pleasantries
- Questions the user asks others
- General conversational filler

KEY PRINCIPLE:
Use the previous messages for context, but do not extract facts from previous messages. You are only extracting facts from the current message.

Respond with JSON only: {"facts": ["fact text 1", "fact text 2", ...]}
Return facts as an array of strings.
If no facts found, return: {"facts": []}`;

    const userPrompt = `CONVERSATION CONTEXT (last 5 messages):
${conversationContext}

CURRENT MESSAGE TO ANALYZE:
USER: ${messageText}

Extract all factual information ABOUT the user from the current message, using the conversation context to normalize incomplete answers.`;

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
      logger.warn("Empty response from OpenAI during knowledge extraction");
      return {success: true, facts: []};
    }

    const parsed = JSON.parse(responseContent) as {facts: Array<string>};

    // Convert to KnowledgeFact format (without id/embedding yet - those are added during storage)
    const facts = parsed.facts.map((factText, index) => {
      return {
        id: "", // Will be set by Firestore
        userId: senderId,
        text: factText,
        embedding: [], // Will be generated during storage
        createdAt: new Date(),
        updatedAt: new Date(),
      };
    });

    return {
      success: true,
      facts,
    };

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);

    logger.error("Knowledge extraction failed", {
      error: errorMessage,
      senderId,
    });

    return {
      success: false,
      facts: [],
      error: errorMessage,
    };
  }
}
