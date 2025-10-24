/**
 * CreatorLink AI Messaging Service - Cloud Functions
 *
 * This function triggers when new messages are created in Firestore.
 * OpenAI calls temporarily disabled for testing.
 */

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

// AI user constant - must match AIConstants.swift in iOS app
const AI_USER_ID = "ai-assistant";

/**
 * Triggered when a new message is created in Firestore
 * Currently just logs the message (OpenAI calls disabled for testing)
 */
export const onMessageCreated = onDocumentCreated(
  "messages/{messageId}",
  async (event) => {
    const messageId = event.params.messageId;
    const messageData = event.data?.data();

    // Skip processing if this is an AI-generated message to prevent infinite loops
    if (messageData?.senderId === AI_USER_ID) {
      logger.info("Skipping AI-generated message", {
        messageId,
        senderId: messageData.senderId,
      });
      return null;
    }

    // Log the message (no OpenAI calls)
    logger.info("Message received (OpenAI disabled for testing):", {
      messageId,
      senderId: messageData?.senderId,
      text: messageData?.text,
      conversationId: messageData?.conversationId,
    });

    return null;
  }
);
