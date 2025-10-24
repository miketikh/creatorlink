/**
 * OpenAI Client Initialization
 * Provides a singleton OpenAI client instance for all AI operations.
 */

import OpenAI from "openai";
import * as logger from "firebase-functions/logger";

let openaiClient: OpenAI | null = null;

/**
 * Get or initialize the OpenAI client.
 * Uses OPENAI_API_KEY from environment variables.
 */
export function getOpenAIClient(): OpenAI {
  if (!openaiClient) {
    const apiKey = process.env.OPENAI_API_KEY;

    if (!apiKey) {
      logger.error("OPENAI_API_KEY not found in environment variables");
      throw new Error("OpenAI API key not configured");
    }

    openaiClient = new OpenAI({
      apiKey: apiKey,
    });

    logger.info("OpenAI client initialized successfully");
  }

  return openaiClient;
}
