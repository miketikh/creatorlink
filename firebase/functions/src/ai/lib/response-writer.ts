/**
 * Response Writer
 * Creates and writes AI response messages with FAQ metadata to Firestore.
 */

import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import type {FAQMatch} from "./faq-matcher";

const AI_USER_ID = "ai-assistant";

export interface WriteResponseResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

/**
 * Creates an AI response message with FAQ metadata and writes it to Firestore.
 * Also updates the conversation's lastMessage fields.
 */
export async function writeAIResponse(
  conversationId: string,
  participantIds: string[],
  faqMatch: FAQMatch
): Promise<WriteResponseResult> {
  const startTime = Date.now();

  try {
    logger.info("Writing AI response message", {
      conversationId,
      hasMatch: faqMatch.hasMatch,
      confidence: faqMatch.confidence,
    });

    const db = admin.firestore();
    const messageId = db.collection("messages").doc().id;
    const timestamp = FieldValue.serverTimestamp();

    // AI response text should be empty - iOS will render based on metadata
    const responseText = "";

    // Build metadata (all values must be strings!)
    const metadata: Record<string, string> = {
      ai_generated: "true",
      matchConfidence: faqMatch.confidence.toFixed(2),
    };

    if (faqMatch.matchedQuestionMessageId) {
      metadata.faqReference = faqMatch.matchedAnswerMessageId || "";
      metadata.matchedQuestion = faqMatch.matchedQuestionText || "";
      metadata.suggestedAnswer = faqMatch.matchedAnswerText || "";
    }

    // Create message document
    const messageData = {
      conversationId,
      senderId: AI_USER_ID,
      participantIds: participantIds.sort(),
      text: responseText,
      timestamp,
      status: "sent",
      readBy: {
        [AI_USER_ID]: timestamp,
      },
      imageUrl: null,
      metadata,
    };

    // Use batch to write message and update conversation atomically
    const batch = db.batch();

    // Write message
    batch.set(db.collection("messages").doc(messageId), messageData);

    // Update conversation lastMessage
    batch.update(db.collection("conversations").doc(conversationId), {
      lastMessage: responseText,
      lastMessageTime: timestamp,
      lastMessageSenderId: AI_USER_ID,
      lastMessageStatus: "sent",
    });

    await batch.commit();

    const duration = Date.now() - startTime;
    logger.info("AI response written successfully", {
      conversationId,
      messageId,
      durationMs: duration,
    });

    return {
      success: true,
      messageId,
    };

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Failed to write AI response", {
      conversationId,
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
