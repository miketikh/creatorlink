/**
 * CreatorLink AI Messaging Service - Cloud Functions
 *
 * This function triggers when new messages are created in Firestore.
 * Detects if messages in group chats are questions that need AI responses.
 */

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {detectIfQuestion} from "./ai";
import {fetchConversationMessages} from "./ai/lib/message-fetcher";
import {findFAQMatch} from "./ai/lib/faq-matcher";
import {writeAIResponse} from "./ai/lib/response-writer";

// Initialize Firebase Admin SDK
admin.initializeApp();

// AI user constant - must match AIConstants.swift in iOS app
const AI_USER_ID = "ai-assistant";

/**
 * Triggered when a new message is created in Firestore
 * Detects if the message is from a group chat and if it's a question
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

    // Log incoming message
    logger.info("Message received:", {
      messageId,
      senderId: messageData?.senderId,
      text: messageData?.text,
      conversationId: messageData?.conversationId,
    });

    // Check if it's a group chat using denormalized participantIds
    // Group chats have 3+ participants (one-on-one chats have exactly 2)
    const participantIds = messageData?.participantIds || [];
    const conversationId = messageData?.conversationId || "";
    const isGroupChat = participantIds.length > 2;

    if (!isGroupChat) {
      logger.info("Not a group chat, skipping AI processing", {
        messageId,
        conversationId,
        participantCount: participantIds.length,
      });
      return null;
    }

    logger.info("Group chat message detected, checking if it's a question", {
      messageId,
      conversationId,
      participantCount: participantIds.length,
    });

    // Detect if the message is a question
    const messageText = messageData?.text || "";
    if (!messageText.trim()) {
      logger.info("Empty message text, skipping question detection", {
        messageId,
      });
      return null;
    }

    const questionResult = await detectIfQuestion(messageText);

    logger.info("Question detection result", {
      messageId,
      conversationId,
      isQuestion: questionResult.isQuestion,
      confidence: questionResult.confidence,
      messageText: messageText.substring(0, 100), // Log first 100 chars
    });

    if (questionResult.isQuestion) {
      logger.info("✅ Group chat QUESTION detected", {
        messageId,
        conversationId,
        confidence: questionResult.confidence,
        messagePreview: messageText.substring(0, 50),
      });

      // Check if AI is enabled (AI assistant must be a participant)
      const isAIEnabled = participantIds.includes(AI_USER_ID);

      if (!isAIEnabled) {
        logger.info("AI not enabled for this conversation, skipping FAQ detection", {
          messageId,
          conversationId,
        });
        return null;
      }

      logger.info("AI enabled, processing question for FAQ detection", {
        messageId,
        conversationId,
      });

      try {
        // Fetch all conversation messages
        const allMessages = await fetchConversationMessages(
          conversationId,
          100
        );

        if (allMessages.length === 0) {
          logger.info("No conversation history found, skipping FAQ detection", {
            conversationId,
            messageId,
          });
          return null;
        }

        // Find current message index
        const currentMessageIndex = allMessages.findIndex(msg => msg.id === messageId);

        if (currentMessageIndex === -1) {
          logger.warn("Current message not found in conversation history", {
            conversationId,
            messageId,
          });
          return null;
        }

        // Split messages into before and after current question
        const previousMessages = allMessages.slice(0, currentMessageIndex);
        const followingMessages = allMessages.slice(currentMessageIndex + 1);

        if (previousMessages.length === 0) {
          logger.info("No previous messages, skipping FAQ detection", {
            conversationId,
            messageId,
          });
          return null;
        }

        // Let AI analyze with separate before/after contexts
        const faqMatch = await findFAQMatch(
          messageText,
          previousMessages,
          followingMessages,
          0.85
        );

        if (!faqMatch.hasMatch) {
          logger.info("No FAQ match found", {
            conversationId,
            messageId,
            confidence: faqMatch.confidence,
          });
          return null;
        }

        logger.info("✅ FAQ match found! Writing AI response", {
          conversationId,
          messageId,
          confidence: faqMatch.confidence,
          matchedQuestionId: faqMatch.matchedQuestionMessageId,
          matchedAnswerId: faqMatch.matchedAnswerMessageId,
        });

        // Write AI response
        const writeResult = await writeAIResponse(
          conversationId,
          participantIds,
          faqMatch
        );

        if (writeResult.success) {
          logger.info("🎉 AI response written successfully", {
            conversationId,
            aiMessageId: writeResult.messageId,
          });
        } else {
          logger.error("Failed to write AI response", {
            conversationId,
            error: writeResult.error,
          });
        }

      } catch (error) {
        logger.error("Error processing FAQ detection", {
          conversationId,
          messageId,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    } else {
      logger.info("ℹ️ Group chat message is NOT a question", {
        messageId,
        conversationId,
        confidence: questionResult.confidence,
      });
    }

    return null;
  }
);
