/**
 * CreatorLink AI Messaging Service - Cloud Functions
 *
 * This function triggers when new messages are created in Firestore.
 * Routes messages to three independent pipelines:
 * 1. Group FAQ Pipeline - Detects questions in group chats and posts AI responses
 * 2. Knowledge Extraction Pipeline - Extracts and stores facts from messages
 * 3. Draft Generation Pipeline - Generates personalized response drafts
 *
 * Each pipeline runs independently and will not block others.
 */

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  categorizeConversation,
  fetchConversationContext,
  shouldAnalyzeMessage,
  updateConversationTags,
} from "./ai";
import {runGroupFAQPipeline} from "./pipelines/group-faq-pipeline";
import {runKnowledgeExtractionPipeline} from "./pipelines/knowledge-extraction-pipeline";
import {runDraftGenerationPipeline} from "./pipelines/draft-generation-pipeline";

// Initialize Firebase Admin SDK
admin.initializeApp();

// AI user constant - must match AIConstants.swift in iOS app
const AI_USER_ID = "ai-assistant";

/**
 * Triggered when a new message is created in Firestore
 * Routes messages to applicable pipelines
 */
export const onMessageCreated = onDocumentCreated(
  "messages/{messageId}",
  async (event) => {
    const messageId = event.params.messageId;
    const messageData = event.data?.data();

    // Early return if no message data
    if (!messageData) {
      logger.warn("No message data found", {messageId});
      return null;
    }

    // Skip processing if this is an AI-generated message to prevent infinite loops
    if (messageData.senderId === AI_USER_ID) {
      logger.info("Skipping AI-generated message", {
        messageId,
        senderId: messageData.senderId,
      });
      return null;
    }

    // Log incoming message
    logger.info("Message received:", {
      messageId,
      senderId: messageData.senderId,
      text: messageData.text,
      conversationId: messageData.conversationId,
    });

    // Extract common message context for routing
    const messageContext = {
      messageId,
      conversationId: messageData.conversationId || "",
      messageText: messageData.text || "",
      participantIds: messageData.participantIds || [],
      senderId: messageData.senderId || "",
    };

    // Route to all applicable pipelines (run independently)
    // Using Promise.allSettled to ensure one pipeline failure doesn't affect others
    const results = await Promise.allSettled([
      runGroupFAQPipeline(messageContext),
      runKnowledgeExtractionPipeline(messageContext),
      runDraftGenerationPipeline(messageContext),
    ]);

    // Log any pipeline failures (for monitoring)
    results.forEach((result, index) => {
      const pipelineNames = ["Group FAQ", "Knowledge Extraction", "Draft Generation"];
      if (result.status === "rejected") {
        logger.error(`${pipelineNames[index]} Pipeline failed`, {
          messageId,
          error: result.reason,
        });
      }
    });

    // LEGACY FEATURE: AI Auto-Tagging (categorization)
    // This runs independently and is kept separate as it's an older feature
    // TODO: Consider moving to its own pipeline in future refactor
    try {
      // Check feature flag (default enabled)
      const categorizationEnabled = process.env.ENABLE_AUTO_CATEGORIZATION !== "false";

      if (!categorizationEnabled) {
        logger.info("Auto-categorization disabled by feature flag", {
          conversationId: messageContext.conversationId,
        });
        return null;
      }

      // Check if this message should be analyzed
      const shouldAnalyze = await shouldAnalyzeMessage(messageData, messageContext.conversationId);

      if (!shouldAnalyze) {
        logger.info("Skipping categorization based on analysis rules", {
          conversationId: messageContext.conversationId,
          messageId,
        });
        return null;
      }

      logger.info("Starting conversation categorization", {
        conversationId: messageContext.conversationId,
        messageId,
      });

      // Fetch conversation context (last 10 messages)
      const conversationContext = await fetchConversationContext(messageContext.conversationId, 10);

      if (conversationContext.length === 0) {
        logger.info("No conversation context found, skipping categorization", {
          conversationId: messageContext.conversationId,
        });
        return null;
      }

      // Fetch existing category and tags from conversation document
      const conversationDoc = await admin.firestore()
        .collection("conversations")
        .doc(messageContext.conversationId)
        .get();

      const existingCategory = conversationDoc.data()?.primaryCategory;
      const existingTagsByUser = conversationDoc.data()?.tagsByUser;

      // Categorize the conversation
      const categorizationResult = await categorizeConversation(
        messageContext.messageText,
        conversationContext,
        existingCategory,
        messageContext.conversationId,
        messageContext.participantIds,
        messageData.senderId,
        existingTagsByUser
      );

      logger.info("Categorization result", {
        conversationId: messageContext.conversationId,
        category: categorizationResult.category.category,
        confidence: categorizationResult.category.confidence,
        statusTagsByUser: categorizationResult.status.statusTagsByUser,
      });

      // Update conversation tags in Firestore
      const updateSuccess = await updateConversationTags(
        messageContext.conversationId,
        categorizationResult,
        messageData.senderId,
        messageContext.participantIds
      );

      if (updateSuccess) {
        logger.info("Conversation tags updated successfully", {
          conversationId: messageContext.conversationId,
          category: categorizationResult.category.category,
          statusTagsByUser: categorizationResult.status.statusTagsByUser,
        });
      } else {
        logger.info("Tag update skipped (low confidence or other reason)", {
          conversationId: messageContext.conversationId,
          confidence: categorizationResult.category.confidence,
        });
      }

    } catch (error) {
      logger.error("Error during conversation categorization", {
        conversationId: messageContext.conversationId,
        messageId,
        error: error instanceof Error ? error.message : String(error),
      });
      // Don't throw - categorization errors shouldn't fail the entire function
    }

    return null;
  }
);
