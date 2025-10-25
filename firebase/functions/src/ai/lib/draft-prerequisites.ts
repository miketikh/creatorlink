/**
 * Draft Prerequisites Checker
 * Determines if sufficient data exists to generate a quality draft response.
 */

import * as logger from "firebase-functions/logger";
import {ConversationCategory} from "../types";
import {loadVoiceProfile} from "./voice-profile-loader";
import {detectIfQuestion} from "./question-detector";
import {searchKnowledgeWithScores} from "./knowledge-retriever";

/**
 * Check if prerequisites are met for draft generation.
 *
 * Prerequisites:
 * 1. Voice profile exists for user + category
 * 2. Message is a question or request (using question detector)
 * 3. Relevant knowledge available (optional - some questions don't need facts)
 *
 * @param userId - User ID to check prerequisites for
 * @param category - Conversation category
 * @param messageText - Message text to analyze
 * @returns Promise<boolean> - true if all checks pass, false otherwise
 */
export async function checkDraftPrerequisites(
  userId: string,
  category: ConversationCategory,
  messageText: string
): Promise<boolean> {
  const startTime = Date.now();

  try {
    logger.info("Checking draft prerequisites", {
      userId,
      category,
      messageLength: messageText.length,
    });

    // Check 1: Voice profile exists
    const voiceProfile = await loadVoiceProfile(userId, category);
    if (!voiceProfile) {
      logger.info("Draft prerequisites NOT met: no voice profile", {
        userId,
        category,
        check: "voice_profile",
        passed: false,
      });
      return false;
    }
    logger.info("Voice profile check passed", {
      userId,
      category,
      check: "voice_profile",
      passed: true,
    });

    // Check 2: Message is a question or request
    const questionResult = await detectIfQuestion(messageText);
    if (!questionResult.isQuestion || questionResult.confidence < 0.6) {
      logger.info("Draft prerequisites NOT met: not a question", {
        userId,
        category,
        check: "is_question",
        passed: false,
        isQuestion: questionResult.isQuestion,
        confidence: questionResult.confidence,
      });
      return false;
    }
    logger.info("Question detection check passed", {
      userId,
      category,
      check: "is_question",
      passed: true,
      confidence: questionResult.confidence,
    });

    // Check 3: Relevant knowledge available (search with similarity threshold)
    // Note: This is optional - some questions can be answered without specific knowledge
    // We'll search but won't fail if no knowledge found, just log it
    const knowledgeResults = await searchKnowledgeWithScores(messageText, userId, 5);
    const hasRelevantKnowledge = knowledgeResults.length > 0 &&
      knowledgeResults[0].similarity > 0.7;

    logger.info("Knowledge availability check", {
      userId,
      category,
      check: "knowledge_available",
      hasRelevantKnowledge,
      resultsCount: knowledgeResults.length,
      topSimilarity: knowledgeResults.length > 0 ? knowledgeResults[0].similarity : 0,
    });

    // All checks passed
    const duration = Date.now() - startTime;
    logger.info("Draft prerequisites check complete", {
      userId,
      category,
      passed: true,
      hasRelevantKnowledge,
      durationMs: duration,
    });

    return true;

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Draft prerequisites check failed", {
      userId,
      category,
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    // Return false on error (don't generate draft if checks fail)
    return false;
  }
}
