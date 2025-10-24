/**
 * Message Fetcher
 * Fetches recent messages from a conversation for FAQ analysis.
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

export interface ConversationMessage {
  id: string;
  senderId: string;
  text: string;
  timestamp: admin.firestore.Timestamp;
}

/**
 * Fetch recent messages from a conversation for FAQ analysis.
 * Returns up to {limit} messages, ordered by timestamp (oldest first).
 */
export async function fetchConversationMessages(
  conversationId: string,
  limit: number = 100
): Promise<ConversationMessage[]> {
  const startTime = Date.now();

  try {
    logger.info("Fetching conversation messages", {
      conversationId,
      limit,
    });

    const messagesSnapshot = await admin.firestore()
      .collection("messages")
      .where("conversationId", "==", conversationId)
      .orderBy("timestamp", "desc")  // Most recent first
      .limit(limit)
      .get();

    const messages: ConversationMessage[] = messagesSnapshot.docs
      .map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          senderId: data.senderId,
          text: data.text || "",
          timestamp: data.timestamp,
        };
      })
      .reverse();  // Reverse to get oldest first for AI context

    const duration = Date.now() - startTime;
    logger.info("Fetched conversation messages", {
      conversationId,
      messageCount: messages.length,
      durationMs: duration,
    });

    return messages;

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Failed to fetch conversation messages", {
      conversationId,
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });
    throw error;
  }
}
