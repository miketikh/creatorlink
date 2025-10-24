/**
 * Question Detection Helper
 * Uses OpenAI GPT-4o-mini to detect if a message is a question.
 */

import * as logger from "firebase-functions/logger";
import {getOpenAIClient} from "../client";
import {QuestionDetectionResult} from "../types";

/**
 * Detect if a message text is a question that expects an answer.
 *
 * @param messageText - The text content of the message to analyze
 * @returns Promise with isQuestion boolean and confidence score (0.0-1.0)
 */
export async function detectIfQuestion(
  messageText: string
): Promise<QuestionDetectionResult> {
  const startTime = Date.now();

  try {
    logger.info("Starting question detection", {
      messageLength: messageText.length,
    });

    const openai = getOpenAIClient();

    const systemPrompt = `You are a message classifier. Analyze messages to determine if they are questions expecting an answer.

Consider as questions:
- Direct questions (who, what, when, where, why, how)
- Indirect questions (wondering about, curious if, anyone know)
- Requests for information or help
- Questions with question marks
- Also ignore questions like "how are you / how is everyone?", "what's up?", "how's it going?", "how's everyone doing?". We want to detect questions that need a response.

Do NOT consider as questions:
- Greetings (hi, hello, hey)
- Statements or declarations
- Commands or instructions
- Rhetorical questions

Respond with JSON only: {"isQuestion": boolean, "confidence": number between 0 and 1}`;

    const userPrompt = `Analyze this message: "${messageText}"`;

    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: userPrompt},
      ],
      response_format: {type: "json_object"},
      temperature: 0.3,
      max_tokens: 100,
    });

    const responseContent = completion.choices[0]?.message?.content;

    if (!responseContent) {
      logger.warn("Empty response from OpenAI");
      return {isQuestion: false, confidence: 0};
    }

    const result = JSON.parse(responseContent) as QuestionDetectionResult;

    const duration = Date.now() - startTime;
    logger.info("Question detection complete", {
      isQuestion: result.isQuestion,
      confidence: result.confidence,
      durationMs: duration,
    });

    return result;

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Question detection failed", {
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    // Return safe default on error
    return {isQuestion: false, confidence: 0};
  }
}
