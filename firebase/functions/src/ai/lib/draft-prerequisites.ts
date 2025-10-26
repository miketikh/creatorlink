/**
 * Draft Prerequisites Checker
 * Determines if sufficient data exists to generate a quality draft response.
 */

import {ConversationCategory} from "../types";
import {loadVoiceProfile} from "./voice-profile-loader";
// import {detectIfQuestion} from "./question-detector";
import {searchKnowledgeWithScores} from "./knowledge-retriever";
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
    // Check 1: Voice profile exists
    const voiceProfile = await loadVoiceProfile(userId, category);
    if (!voiceProfile) {
      return false;
    }

    // Check 2: Message is a question or request
    // Orchestrator handles decision - if we're here, orchestrator already determined this needs a draft response
    // const questionResult = await detectIfQuestion(messageText);
    // if (!questionResult.isQuestion || questionResult.confidence < 0.6) {
    //   testLog("  ❌ NOT A QUESTION", {
    //     userId,
    //     isQuestion: questionResult.isQuestion,
    //     confidence: questionResult.confidence,
    //   });
    //   return false;
    // }
    // testLog("  ✅ Message is a question", {
    //   userId,
    //   confidence: questionResult.confidence,
    // });

    // Check 3: Relevant knowledge available (search with similarity threshold)
    // IMPORTANT: We require relevant knowledge to generate a quality draft
    // Note: Threshold 0.45 calibrated for text-embedding-3-small model
    // Pass conversation history for context-aware query transformation (e.g., "u?" with context)
    const knowledgeResults = await searchKnowledgeWithScores(messageText, userId, 5, conversationHistory);
    const hasRelevantKnowledge = knowledgeResults.length > 0 &&
      knowledgeResults[0].similarity > 0.45;

    // NEW: Require relevant knowledge to generate draft
    if (!hasRelevantKnowledge) {
      return false;
    }

    return true;

  } catch (error) {
    // Return false on error (don't generate draft if checks fail)
    return false;
  }
}
