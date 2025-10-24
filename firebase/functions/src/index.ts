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

// AI user constant - must match AIConstants.swift in iOS app
const AI_USER_ID = "ai-assistant";

/**
 * Triggered when a new message is created in Firestore
 * Sends the message to the Python AI service for processing
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

    logger.info("New message detected:", {
      messageId,
      senderId: messageData?.senderId,
      text: messageData?.text,
      conversationId: messageData?.conversationId,
    });

    // Fetch conversation to check if AI is enabled
    logger.info("Checking if AI is enabled for conversation", {
      conversationId: messageData?.conversationId,
    });

    const conversationRef = admin.firestore()
      .collection("conversations")
      .doc(messageData?.conversationId);

    const conversationDoc = await conversationRef.get();

    if (!conversationDoc.exists) {
      logger.warn("Conversation not found", {
        conversationId: messageData?.conversationId,
      });
      return null;
    }

    const conversationData = conversationDoc.data();

    // Only proceed if AI is enabled for this conversation
    if (!conversationData?.aiEnabled) {
      logger.info("AI not enabled for conversation - skipping", {
        conversationId: messageData?.conversationId,
        aiEnabled: conversationData?.aiEnabled,
      });
      return null;
    }

    // Check if FAQ detection is enabled (if aiConfig exists)
    if (conversationData?.aiConfig?.faqDetectionEnabled === false) {
      logger.info("FAQ detection disabled - skipping", {
        conversationId: messageData?.conversationId,
      });
      return null;
    }

    // Construct payload for Python service
    const payload = {
      messageId,
      conversationId: messageData?.conversationId,
      senderId: messageData?.senderId,
      text: messageData?.text,
      timestamp: messageData?.timestamp,
      participantIds: messageData?.participantIds,
      aiConfig: conversationData?.aiConfig || {
        faqDetectionEnabled: true,
        minimumSimilarity: 0.85,
      },
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
