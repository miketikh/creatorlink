/**
 * FAQ Matcher
 * Uses OpenAI to analyze conversation history and find matching Q&A pairs.
 */

import * as logger from "firebase-functions/logger";
import {getOpenAIClient} from "../client";
import type {ConversationMessage} from "./message-fetcher";

export interface FAQMatch {
  hasMatch: boolean;
  confidence: number;
  matchedQuestionMessageId?: string;
  matchedQuestionText?: string;
  matchedAnswerMessageId?: string;
  matchedAnswerText?: string;
}

/**
 * Use OpenAI to analyze conversation history and find if the question
 * has been answered before. AI handles everything - finding similar
 * questions, extracting answers, and determining match confidence.
 */
export async function findFAQMatch(
  currentQuestion: string,
  previousMessages: ConversationMessage[],
  followingMessages: ConversationMessage[],
  minimumSimilarity: number = 0.85
): Promise<FAQMatch> {
  const startTime = Date.now();

  try {
    logger.info("Starting FAQ match analysis", {
      currentQuestion: currentQuestion.substring(0, 100),
      previousMessageCount: previousMessages.length,
      followingMessageCount: followingMessages.length,
      minimumSimilarity,
    });

    const openai = getOpenAIClient();

    // Build separate contexts
    const previousContext = previousMessages
      .map(msg => `[${msg.id}] User ${msg.senderId}: ${msg.text}`)
      .join("\n");

    const followingContext = followingMessages.length > 0
      ? followingMessages
        .map(msg => `[${msg.id}] User ${msg.senderId}: ${msg.text}`)
        .join("\n")
      : "No messages after current question yet.";

    const systemPrompt = `You are an FAQ detection system for group chat conversations.

Your task: Determine if current question should receive an AI response pointing to previous answer.

RULES:
1. ONLY respond if question was asked AND answered in previousMessages
2. Do NOT respond if replies exist in followingMessages
3. Find semantically similar questions (not exact matches)
4. Verify answer came from DIFFERENT user than question
5. Calculate confidence (0.0-1.0) based on semantic similarity
6. Return hasMatch: true only if confidence >= ${minimumSimilarity}

RESPONSE FORMAT (JSON only):
{
  "hasMatch": boolean,
  "confidence": number,
  "matchedQuestionMessageId": "msg_id or null",
  "matchedQuestionText": "text or null",
  "matchedAnswerMessageId": "msg_id or null",
  "matchedAnswerText": "text or null"
}`;

    const userPrompt = `CURRENT QUESTION:
"${currentQuestion}"

PREVIOUS MESSAGES (search for similar Q&A here):
${previousContext}

FOLLOWING MESSAGES (check if already answered):
${followingContext}

Only return hasMatch: true if similar question was asked and answered in PREVIOUS messages AND no FOLLOWING messages.`;

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
      logger.warn("Empty response from OpenAI FAQ matcher");
      return {
        hasMatch: false,
        confidence: 0,
      };
    }

    const result = JSON.parse(responseContent) as FAQMatch;

    const duration = Date.now() - startTime;
    logger.info("FAQ match analysis complete", {
      hasMatch: result.hasMatch,
      confidence: result.confidence,
      matchedQuestionId: result.matchedQuestionMessageId,
      matchedAnswerId: result.matchedAnswerMessageId,
      durationMs: duration,
    });

    return result;

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("FAQ match analysis failed", {
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    // Return safe default on error
    return {
      hasMatch: false,
      confidence: 0,
    };
  }
}
