/**
 * CreatorLink AI Messaging Service - Cloud Functions
 *
 * This function triggers when new messages are created in Firestore
 * and forwards them to the Python AI service for processing.
 */

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import axios from "axios";

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Triggered when a new message is created in Firestore
 * Sends the message to the Python AI service for processing
 */
export const onMessageCreated = onDocumentCreated(
  "messages/{messageId}",
  async (event) => {
    const messageId = event.params.messageId;
    const messageData = event.data?.data();

    // DIAGNOSTIC: Log full message data to debug infinite loop
    logger.info("DIAGNOSTIC - Message data structure:", {
      messageId,
      messageData: JSON.stringify(messageData),
      senderId: messageData?.senderId,
      senderIdType: typeof messageData?.senderId,
      isAI: messageData?.senderId === "ai-agent",
    });

    // Skip processing if this is an AI-generated message to prevent infinite loops
    if (messageData?.senderId === "ai-agent") {
      logger.info("Skipping AI-generated message", {
        messageId,
        senderId: messageData.senderId,
      });
      return null;
    }

    logger.info("New message detected:", {
      messageId,
      senderId: messageData?.senderId,
      text: messageData?.text,
      conversationId: messageData?.conversationId,
    });

    // Construct payload for Python service
    const payload = {
      messageId,
      conversationId: messageData?.conversationId,
      senderId: messageData?.senderId,
      text: messageData?.text,
      timestamp: messageData?.timestamp,
      participantIds: messageData?.participantIds,
    };

    try {
      // Call Python AI service
      const response = await axios.post(
        "http://localhost:8000/process-message",
        payload,
        {
          timeout: 30000, // 30 second timeout
          headers: {
            "Content-Type": "application/json",
          },
        }
      );

      logger.info("Python service response:", {
        messageId,
        success: response.data.success,
        responseMessageId: response.data.responseMessageId,
      });
    } catch (error) {
      // Log error but don't throw - prevents infinite retry loops
      if (axios.isAxiosError(error)) {
        logger.error("Error calling Python service:", {
          messageId,
          error: error.message,
          code: error.code,
          status: error.response?.status,
        });
      } else {
        logger.error("Unexpected error:", {
          messageId,
          error,
        });
      }
    }

    // Always return success to prevent retries
    return null;
  }
);
