/**
 * Message Orchestrator
 *
 * Uses AI to decide which pipelines should run based on message content and context.
 * This decision-first approach replaces unconditional parallel pipeline execution.
 *
 * The orchestrator considers:
 * - Message content and recent conversation context
 * - Conversation metadata (participant count, AI enabled status)
 * - Whether the message is a question or contains factual information
 *
 * Returns decisions for:
 * - needsGroupAnswer: Should Group FAQ Pipeline run?
 * - hasNewInformation: Should Knowledge Extraction Pipeline run?
 * - needsDraftResponse: Should Draft Generation Pipeline run?
 */

import * as logger from "firebase-functions/logger";
import {getOpenAIClient} from "../client";
import {ConversationMessage} from "./message-fetcher";
import {OrchestrationDecision} from "../types";
import {testLog} from "./test-logger";

/**
 * Orchestrate which pipelines should run for a given message.
 *
 * @param messageText - The text content of the new message
 * @param conversationContext - Recent messages from the conversation (5-10 messages)
 * @param participantCount - Number of participants in the conversation
 * @param isAIEnabled - Whether AI user is in the conversation participants
 * @returns Promise with decisions for each pipeline
 */
export async function orchestrateMessage(
  messageText: string,
  conversationContext: ConversationMessage[],
  participantCount: number,
  isAIEnabled: boolean
): Promise<OrchestrationDecision> {
  const startTime = Date.now();

  try {
    logger.info("Starting message orchestration", {
      messageLength: messageText.length,
      contextMessageCount: conversationContext.length,
      participantCount,
      isAIEnabled,
    });

    testLog("🎯 ORCHESTRATOR FLOW STARTED", {
      messageText,
      contextMessageCount: conversationContext.length,
      participantCount,
      isAIEnabled,
    });

    const openai = getOpenAIClient();

    // Build conversation context string for the AI
    const contextString = conversationContext
      .map((msg) => `[${msg.senderId}]: ${msg.text}`)
      .join("\n");

    testLog("📜 CONVERSATION CONTEXT", {
      contextMessages: conversationContext.map((msg) => ({
        senderId: msg.senderId,
        text: msg.text,
        timestamp: msg.timestamp,
      })),
      contextString,
    });

    const systemPrompt = `You are a message routing orchestrator for an AI-powered messaging app.
Your job is to decide which processing pipelines should run for a new incoming message.

Context:
- Participant count: ${participantCount}
- Is group chat: ${participantCount > 2 ? "yes" : "no"}
- AI assistant enabled: ${isAIEnabled ? "yes" : "no"}

You must decide three things:

1. **needsGroupAnswer**: Should the Group FAQ Pipeline run?
   - ONLY true if ALL conditions met:
     * Participant count > 2, not counting the AI assistant (is a group chat)
     * AI assistant is enabled
     * The message is a genuine question that needs answering
   - Questions like "how are you?", "what's up?", "how's everyone?" should be FALSE
   - Greetings, rhetorical questions, or casual check-ins should be FALSE

2. **hasNewInformation**: Should the Knowledge Extraction Pipeline run?
   - True if the message contains factual information about the sender
   - Examples: preferences, facts about their life, activities, opinions
   - False if it's just a question, greeting, or generic statement
   - Should use previous messages for context, so if previous messages say "do you enjoy dance?" and current message is just "yep!", that implies new information on the last message.

   Example: "Hey, what're you doing later? I'm going to a show in the evening." - True. It is a question, AND contains new information about the sender's plans.

3. **needsDraftResponse**: Should the Draft Generation Pipeline run?
   - True if this is a question or message that other participants might want to respond to
   - Consider if recipients would benefit from a suggested response draft
   - False for greetings, rhetorical questions, or statements that don't need responses

Respond with JSON only: {
  "needsGroupAnswer": boolean,
  "hasNewInformation": boolean,
  "needsDraftResponse": boolean
}`;

    const userPrompt = `Recent conversation context:
${contextString}

New incoming message: "${messageText}"

Analyze this message and decide which pipelines should run.`;

    const completion = await openai.chat.completions.create({
      model: "gpt-5-mini",
      messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: userPrompt},
      ],
      response_format: {type: "json_object"},
      reasoning_effort: "minimal",
      // max_completion_tokens: 150,
    });

    const responseContent = completion.choices[0]?.message?.content;

    if (!responseContent) {
      logger.warn("Empty response from OpenAI orchestrator");

      testLog("⚠️ ORCHESTRATOR EMPTY RESPONSE - FALLBACK TO ALL PIPELINES", {
        reason: "Empty response from OpenAI",
        fallbackDecision: {
          needsGroupAnswer: true,
          hasNewInformation: true,
          needsDraftResponse: true,
        },
      });

      // Return safe default: run all pipelines
      return {
        needsGroupAnswer: true,
        hasNewInformation: true,
        needsDraftResponse: true,
      };
    }

    const decision = JSON.parse(responseContent) as OrchestrationDecision;

    const duration = Date.now() - startTime;
    logger.info("Message orchestration complete", {
      needsGroupAnswer: decision.needsGroupAnswer,
      hasNewInformation: decision.hasNewInformation,
      needsDraftResponse: decision.needsDraftResponse,
      durationMs: duration,
    });

    testLog("✅ ORCHESTRATOR OUTPUT", {
      needsGroupAnswer: decision.needsGroupAnswer,
      hasNewInformation: decision.hasNewInformation,
      needsDraftResponse: decision.needsDraftResponse,
      durationMs: duration,
    });

    return decision;

  } catch (error) {
    const duration = Date.now() - startTime;
    const errorMessage = error instanceof Error ? error.message : String(error);

    logger.error("Message orchestration failed", {
      error: errorMessage,
      durationMs: duration,
    });

    testLog("❌ ORCHESTRATOR FAILED - FALLBACK TO ALL PIPELINES", {
      error: errorMessage,
      durationMs: duration,
      fallbackDecision: {
        needsGroupAnswer: true,
        hasNewInformation: true,
        needsDraftResponse: true,
      },
    });

    // Return safe default on error: run all pipelines
    return {
      needsGroupAnswer: true,
      hasNewInformation: true,
      needsDraftResponse: true,
    };
  }
}
