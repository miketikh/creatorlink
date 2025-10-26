/**
 * Group FAQ Pipeline
 *
 * Handles FAQ detection and AI response generation for group chats.
 *
 * Flow:
 * 1. Filter: Only group chats with AI enabled and question messages
 * 2. Detect if message is a question
 * 3. Search FAQ for matching answer
 * 4. Generate and post AI response to group chat
 *
 * This pipeline runs independently and will not block other pipelines.
 */

import * as logger from "firebase-functions/logger";
import {/* detectIfQuestion, */ fetchConversationMessages, findFAQMatch, writeAIResponse} from "../ai";

const AI_USER_ID = "ai-assistant";

interface MessageContext {
  messageId: string;
  conversationId: string;
  messageText: string;
  participantIds: string[];
  senderId: string;
}

/**
 * Main pipeline entry point
 */
export async function runGroupFAQPipeline(context: MessageContext): Promise<void> {
  try {
    // Filter 1: Check if this is a group chat
    const isGroupChat = context.participantIds.length > 2;
    if (!isGroupChat) {
      logger.info("Group FAQ Pipeline: Skipping (not a group chat)", {
        conversationId: context.conversationId,
        participantCount: context.participantIds.length,
      });
      return;
    }

    // Filter 2: Check if AI is enabled (AI must be in participants)
    const isAIEnabled = context.participantIds.includes(AI_USER_ID);
    if (!isAIEnabled) {
      logger.info("Group FAQ Pipeline: Skipping (AI not enabled)", {
        conversationId: context.conversationId,
      });
      return;
    }

    // Filter 3: Check if message has text
    if (!context.messageText.trim()) {
      logger.info("Group FAQ Pipeline: Skipping (empty message)", {
        messageId: context.messageId,
      });
      return;
    }

    // Filter 4: Detect if message is a question
    // Orchestrator handles decision - if we're here, orchestrator already determined this is a question

    logger.info("Group FAQ Pipeline: Processing question for FAQ detection", {
      messageId: context.messageId,
      conversationId: context.conversationId,
    });

    // Fetch conversation messages for context
    const allMessages = await fetchConversationMessages(context.conversationId, 100);

    if (allMessages.length === 0) {
      logger.info("Group FAQ Pipeline: No conversation history found", {
        conversationId: context.conversationId,
      });
      return;
    }

    // Find current message index
    const currentMessageIndex = allMessages.findIndex(msg => msg.id === context.messageId);

    if (currentMessageIndex === -1) {
      logger.warn("Group FAQ Pipeline: Current message not found in history", {
        conversationId: context.conversationId,
        messageId: context.messageId,
      });
      return;
    }

    // Split messages into before and after current question
    const previousMessages = allMessages.slice(0, currentMessageIndex);
    const followingMessages = allMessages.slice(currentMessageIndex + 1);

    if (previousMessages.length === 0) {
      logger.info("Group FAQ Pipeline: No previous messages for context", {
        conversationId: context.conversationId,
      });
      return;
    }

    // Search for FAQ match
    const faqMatch = await findFAQMatch(
      context.messageText,
      previousMessages,
      followingMessages,
      0.85
    );

    if (!faqMatch.hasMatch) {
      logger.info("Group FAQ Pipeline: No FAQ match found", {
        conversationId: context.conversationId,
        confidence: faqMatch.confidence,
      });
      return;
    }

    logger.info("Group FAQ Pipeline: FAQ match found! Writing AI response", {
      conversationId: context.conversationId,
      messageId: context.messageId,
      confidence: faqMatch.confidence,
      matchedQuestionId: faqMatch.matchedQuestionMessageId,
      matchedAnswerId: faqMatch.matchedAnswerMessageId,
    });

    // Write AI response to group chat
    const writeResult = await writeAIResponse(
      context.conversationId,
      context.participantIds,
      faqMatch
    );

    if (writeResult.success) {
      logger.info("Group FAQ Pipeline: AI response written successfully", {
        conversationId: context.conversationId,
        aiMessageId: writeResult.messageId,
      });
    } else {
      logger.error("Group FAQ Pipeline: Failed to write AI response", {
        conversationId: context.conversationId,
        error: writeResult.error,
      });
    }

  } catch (error) {
    // Catch all errors to prevent blocking other pipelines
    logger.error("Group FAQ Pipeline: Error occurred", {
      conversationId: context.conversationId,
      messageId: context.messageId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
