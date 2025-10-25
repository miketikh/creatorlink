/**
 * Conversation Context Fetcher
 * Fetches recent conversation messages for AI categorization context.
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {ConversationMessage} from "./message-fetcher";
import {clearCachedResult} from "./rate-limiter";

// AI user constant - must match AIConstants.swift in iOS app
const AI_USER_ID = "ai-assistant";

/**
 * Fetch recent conversation messages for AI context analysis.
 *
 * @param conversationId - The conversation ID to fetch messages from
 * @param messageLimit - Maximum number of messages to fetch (default 10)
 * @returns Array of message objects with id, text, senderId, timestamp
 */
export async function fetchConversationContext(
  conversationId: string,
  messageLimit: number = 10
): Promise<ConversationMessage[]> {
  const startTime = Date.now();

  try {
    logger.info("Fetching conversation context", {
      conversationId,
      messageLimit,
    });

    const messagesSnapshot = await admin.firestore()
      .collection("messages")
      .where("conversationId", "==", conversationId)
      .orderBy("timestamp", "desc")
      .limit(messageLimit)
      .get();

    if (messagesSnapshot.empty) {
      logger.info("No messages found for conversation", {
        conversationId,
      });
      return [];
    }

    const messages: ConversationMessage[] = messagesSnapshot.docs
      .map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          senderId: data.senderId || "",
          text: data.text || "",
          timestamp: data.timestamp,
        };
      })
      .reverse(); // Reverse to chronological order (oldest to newest)

    const duration = Date.now() - startTime;
    logger.info("Fetched conversation context", {
      conversationId,
      messageCount: messages.length,
      durationMs: duration,
    });

    return messages;

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Failed to fetch conversation context", {
      conversationId,
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    // Return empty array on error - don't throw
    return [];
  }
}

/**
 * Check if a message should be analyzed for categorization.
 *
 * IMPORTANT: Skips cooldown if message sender changed (allows real-time status tag updates).
 * Applies 60-second cooldown only for rapid messages from the same sender.
 *
 * @param messageData - The message document data
 * @param conversationId - The conversation ID
 * @returns Boolean indicating whether to analyze this message
 */
export async function shouldAnalyzeMessage(
  messageData: any,
  conversationId: string
): Promise<boolean> {
  // Skip AI-generated messages to prevent categorizing AI responses
  if (messageData?.senderId === AI_USER_ID) {
    logger.info("Skipping AI message", {
      conversationId,
      senderId: messageData.senderId,
    });
    return false;
  }

  // Fetch conversation document to check flags
  try {
    const conversationDoc = await admin.firestore()
      .collection("conversations")
      .doc(conversationId)
      .get();

    const conversationData = conversationDoc.data();

    if (!conversationData) {
      logger.warn("Conversation not found", {conversationId});
      return false;
    }

    // Respect user overrides - never re-categorize manually tagged conversations
    if (conversationData.userOverrideTags === true) {
      logger.info("Skipping - user has manually set tags", {
        conversationId,
      });
      return false;
    }

    const currentSenderId = messageData?.senderId;
    const lastMessageSenderId = conversationData.lastMessageSenderId;

    // Clear cache if sender changed to force fresh analysis
    if (lastMessageSenderId && currentSenderId !== lastMessageSenderId) {
      clearCachedResult(conversationId);
      logger.info("Sender changed - clearing cache for fresh analysis", {
        conversationId,
        previousSender: lastMessageSenderId,
        currentSender: currentSenderId,
      });
    }

    // Analyze every message - no cooldown
    logger.info("Message should be analyzed", {
      conversationId,
      senderId: currentSenderId,
    });
    return true;

  } catch (error) {
    logger.error("Error checking if message should be analyzed", {
      conversationId,
      error: error instanceof Error ? error.message : String(error),
    });
    // On error, don't analyze (fail safe)
    return false;
  }
}
