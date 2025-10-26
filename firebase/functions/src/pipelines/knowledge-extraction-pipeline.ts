/**
 * Knowledge Extraction Pipeline
 *
 * Extracts factual knowledge from user messages and stores it with embeddings.
 *
 * Flow:
 * 1. Filter: Only non-question statements from real users (not AI/system)
 * 2. Fetch recent messages for context
 * 3. Extract facts from message
 * 4. Generate embeddings for facts
 * 5. Store facts with deduplication
 *
 * This pipeline runs independently and will not block other pipelines.
 */

import * as logger from "firebase-functions/logger";
import {testLog} from "../ai/lib/test-logger";
import {
  detectIfQuestion,
  fetchConversationMessages,
  extractKnowledge,
  storeKnowledgeFact,
} from "../ai";

const AI_USER_ID = "ai-assistant";

interface MessageContext {
  messageId: string;
  conversationId: string;
  messageText: string;
  senderId: string;
}

/**
 * Main pipeline entry point
 */
export async function runKnowledgeExtractionPipeline(context: MessageContext): Promise<void> {
  try {
    // Check feature flag (default enabled)
    const knowledgeExtractionEnabled = process.env.ENABLE_KNOWLEDGE_EXTRACTION !== "false";

    if (!knowledgeExtractionEnabled) {
      logger.info("Knowledge Extraction Pipeline: Disabled by feature flag", {
        conversationId: context.conversationId,
      });
      return;
    }

    // Filter 1: Skip if message from AI user
    if (context.senderId === AI_USER_ID) {
      logger.info("Knowledge Extraction Pipeline: Skipping (AI message)", {
        messageId: context.messageId,
      });
      return;
    }

    // Filter 2: Skip if message from system
    if (context.senderId === "system") {
      logger.info("Knowledge Extraction Pipeline: Skipping (system message)", {
        messageId: context.messageId,
      });
      return;
    }

    // Filter 3: Skip if message is a question (we want statements with facts)
    if (!context.messageText.trim()) {
      return;
    }

    const questionResult = await detectIfQuestion(context.messageText);
    if (questionResult.isQuestion) {
      logger.info("Knowledge Extraction Pipeline: Skipping (question)", {
        messageId: context.messageId,
        confidence: questionResult.confidence,
      });
      return;
    }

    // Fetch recent messages for context
    const recentMessages = await fetchConversationMessages(context.conversationId, 5);

    if (recentMessages.length === 0) {
      logger.info("Knowledge Extraction Pipeline: No conversation history for context", {
        conversationId: context.conversationId,
      });
      return;
    }

    testLog("🧠 KNOWLEDGE EXTRACTION: Processing message for user", {
      userId: context.senderId,
    });

    // Extract knowledge from message with context
    const extractionResult = await extractKnowledge(
      context.messageText,
      recentMessages,
      context.senderId
    );

    if (!extractionResult.success) {
      testLog("❌ KNOWLEDGE EXTRACTION: Failed", {
        userId: context.senderId,
        error: extractionResult.error,
      });
      return;
    }

    if (extractionResult.facts.length === 0) {
      testLog("ℹ️ KNOWLEDGE EXTRACTION: No facts found", {
        userId: context.senderId,
      });
      return;
    }

    testLog("📝 KNOWLEDGE EXTRACTION: Facts extracted", {
      userId: context.senderId,
      factCount: extractionResult.facts.length,
    });

    // Store each extracted fact
    let storedCount = 0;
    let skippedCount = 0;

    for (const fact of extractionResult.facts) {
      try {
        const factId = await storeKnowledgeFact(fact);

        if (factId) {
          storedCount++;
          testLog("✅ STORED KNOWLEDGE", {
            userId: fact.userId,
            fact: fact.text,
          });
        } else {
          skippedCount++;
          testLog("⏭️ SKIPPED (too similar to existing)", {
            userId: fact.userId,
            fact: fact.text,
          });
        }
      } catch (error) {
        logger.error("Knowledge Extraction Pipeline: Failed to store fact", {
          text: fact.text,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    testLog("📊 KNOWLEDGE EXTRACTION COMPLETE", {
      userId: context.senderId,
      stored: storedCount,
      skipped: skippedCount,
    });

  } catch (error) {
    // Catch all errors to prevent blocking other pipelines
    logger.error("Knowledge Extraction Pipeline: Error occurred", {
      conversationId: context.conversationId,
      messageId: context.messageId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
