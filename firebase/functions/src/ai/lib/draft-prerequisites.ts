/**
 * Draft Prerequisites Checker
 * Determines if sufficient data exists to generate a quality draft response.
 */

import {ConversationCategory} from "../types";
import {loadVoiceProfile} from "./voice-profile-loader";
import {detectIfQuestion} from "./question-detector";
import {searchKnowledgeWithScores} from "./knowledge-retriever";
import {testLog} from "./test-logger";
import {ConversationMessage} from "./message-fetcher";

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
 * @param conversationHistory - Recent conversation messages for context (default: empty)
 * @returns Promise<boolean> - true if all checks pass, false otherwise
 */
export async function checkDraftPrerequisites(
  userId: string,
  category: ConversationCategory,
  messageText: string,
  conversationHistory: ConversationMessage[] = []
): Promise<boolean> {
  try {
    // logger.info("Checking draft prerequisites", {
    //   userId,
    //   category,
    //   messageLength: messageText.length,
    // });

    // Check 1: Voice profile exists
    const voiceProfile = await loadVoiceProfile(userId, category);
    if (!voiceProfile) {
      testLog("  ❌ NO VOICE PROFILE", {
        userId,
        category,
      });
      return false;
    }
    testLog("  ✅ Voice profile found", {
      userId,
      category,
    });

    // Check 2: Message is a question or request
    const questionResult = await detectIfQuestion(messageText);
    if (!questionResult.isQuestion || questionResult.confidence < 0.6) {
      testLog("  ❌ NOT A QUESTION", {
        userId,
        isQuestion: questionResult.isQuestion,
        confidence: questionResult.confidence,
      });
      return false;
    }
    testLog("  ✅ Message is a question", {
      userId,
      confidence: questionResult.confidence,
    });

    // Check 3: Relevant knowledge available (search with similarity threshold)
    // IMPORTANT: We require relevant knowledge to generate a quality draft
    // Note: Threshold 0.45 calibrated for text-embedding-3-small model
    // Pass conversation history for context-aware query transformation (e.g., "u?" with context)
    const knowledgeResults = await searchKnowledgeWithScores(messageText, userId, 5, conversationHistory);
    const hasRelevantKnowledge = knowledgeResults.length > 0 &&
      knowledgeResults[0].similarity > 0.45;

    testLog("  📚 Knowledge check", {
      userId,
      hasRelevantKnowledge,
      resultsCount: knowledgeResults.length,
      topFacts: knowledgeResults.slice(0, 3).map(r => ({
        text: r.fact.text,
        similarity: r.similarity.toFixed(2)
      }))
    });

    // NEW: Require relevant knowledge to generate draft
    if (!hasRelevantKnowledge) {
      testLog("  ❌ INSUFFICIENT KNOWLEDGE", {
        userId,
        resultsCount: knowledgeResults.length,
        topSimilarity: knowledgeResults.length > 0 ? knowledgeResults[0].similarity : 0,
        threshold: 0.45,
        reason: knowledgeResults.length === 0 ?
          "No knowledge facts found for user" :
          `Top similarity (${knowledgeResults[0].similarity.toFixed(3)}) below threshold (0.45)`,
      });
      return false;
    }

    // All checks passed
    // const duration = Date.now() - startTime;
    // logger.info("Draft prerequisites check complete", {
    //   userId,
    //   category,
    //   passed: true,
    //   hasRelevantKnowledge,
    //   durationMs: duration,
    // });

    testLog("  ✅ Prerequisites met - proceeding to generate draft", {
      userId,
      category,
      hasRelevantKnowledge: true,
    });

    return true;

  } catch (error) {
    // const duration = Date.now() - startTime;
    // logger.error("Draft prerequisites check failed", {
    //   userId,
    //   category,
    //   error: error instanceof Error ? error.message : String(error),
    //   durationMs: duration,
    // });

    // Return false on error (don't generate draft if checks fail)
    return false;
  }
}
