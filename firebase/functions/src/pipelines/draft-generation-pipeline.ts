/**
 * Draft Generation Pipeline
 *
 * Generates personalized response drafts using AI voice profiles and knowledge.
 *
 * Flow:
 * 1. Filter: Only real user messages (not AI/system)
 * 2. For each recipient in conversation:
 *    a. Check if voice profile exists
 *    b. Check if knowledge is available
 *    c. Check if existing draft is stale
 *    d. Generate draft with voice profile
 *    e. Save draft to Firestore
 *
 * This pipeline runs independently and will not block other pipelines.
 */

import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  fetchConversationMessages,
  checkDraftPrerequisites,
  getDraft,
  shouldUpdateDraft,
  generateDraft,
  saveDraft,
} from "../ai";

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
export async function runDraftGenerationPipeline(context: MessageContext): Promise<void> {
  try {
    // Check feature flag (default enabled)
    const draftGenerationEnabled = process.env.ENABLE_DRAFT_GENERATION !== "false";

    if (!draftGenerationEnabled) {
      return;
    }

    // Filter 1: Skip if message from AI user
    if (context.senderId === AI_USER_ID) {
      return;
    }

    // Filter 2: Skip if message from system
    if (context.senderId === "system") {
      return;
    }

    // Get conversation document to determine category
    const conversationDoc = await admin.firestore()
      .collection("conversations")
      .doc(context.conversationId)
      .get();

    const conversationData = conversationDoc.data();
    const category = conversationData?.primaryCategory || "social"; // Default to social if no category

    // Identify recipients (excluding sender and AI)
    const recipients = context.participantIds.filter(
      (userId: string) => userId !== context.senderId && userId !== AI_USER_ID
    );

    // Process each recipient
    for (const recipientId of recipients) {
      try {
        // Fetch recent messages for context (needed for prerequisite check and draft generation)
        const recentMessages = await fetchConversationMessages(context.conversationId, 10);

        // Check prerequisites (voice profile exists, knowledge available, etc.)
        // Pass conversation history for context-aware query transformation
        const prerequisitesMet = await checkDraftPrerequisites(
          recipientId,
          category,
          context.messageText,
          recentMessages
        );

        if (!prerequisitesMet) {
          continue; // Skip this recipient
        }

        // Get existing draft
        const existingDraft = await getDraft(context.conversationId, recipientId);

        // Check if should update draft (checks userTouched and age internally)
        const shouldUpdate = await shouldUpdateDraft(existingDraft);

        if (!shouldUpdate) {
          continue;
        }
        const incomingMessages = recentMessages.filter(
          msg => msg.id === context.messageId || msg.senderId !== recipientId
        );

        const draftResult = await generateDraft(
          recipientId,
          context.conversationId,
          incomingMessages,
          category
        );

        if (!draftResult.success || !draftResult.draft) {
          continue;
        }

        // Save draft to Firestore
        await saveDraft(draftResult.draft);

      } catch (error) {
        logger.error("Draft Generation Pipeline: Error for recipient", {
          conversationId: context.conversationId,
          recipientId,
          error: error instanceof Error ? error.message : String(error),
        });
        // Continue to next recipient
      }
    }

  } catch (error) {
    // Catch all errors to prevent blocking other pipelines
    logger.error("Draft Generation Pipeline: Error occurred", {
      conversationId: context.conversationId,
      messageId: context.messageId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
