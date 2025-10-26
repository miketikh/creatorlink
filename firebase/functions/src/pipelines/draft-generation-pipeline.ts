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
import {testLog} from "../ai/lib/test-logger";
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
    testLog("🚀 DRAFT GENERATION PIPELINE: Starting", {
      conversationId: context.conversationId,
      messageId: context.messageId,
    });

    // Check feature flag (default enabled)
    const draftGenerationEnabled = process.env.ENABLE_DRAFT_GENERATION !== "false";

    if (!draftGenerationEnabled) {
      testLog("⚠️ Draft Generation Pipeline: Disabled by feature flag", {
        conversationId: context.conversationId,
      });
      return;
    }

    // Filter 1: Skip if message from AI user
    if (context.senderId === AI_USER_ID) {
      testLog("⚠️ Draft Generation Pipeline: Skipping (AI message)", {
        messageId: context.messageId,
      });
      return;
    }

    // Filter 2: Skip if message from system
    if (context.senderId === "system") {
      testLog("⚠️ Draft Generation Pipeline: Skipping (system message)", {
        messageId: context.messageId,
      });
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

    // Fetch recent messages for context display
    const recentMessagesForLog = await fetchConversationMessages(context.conversationId, 5);
    testLog("💬 DRAFT GENERATION: Message received", {
      conversationId: context.conversationId,
      category,
      recipientCount: recipients.length,
      recentMessageCount: recentMessagesForLog.length,
      lastMessages: recentMessagesForLog.slice(-3).map(m => ({
        from: m.senderId,
        text: m.text.substring(0, 50) + (m.text.length > 50 ? '...' : '')
      }))
    });

    // Process each recipient
    for (const recipientId of recipients) {
      try {
        testLog("📥 MESSAGE RECEIVED for draft generation", {
          conversationId: context.conversationId,
          incomingMessage: context.messageText.substring(0, 100) + (context.messageText.length > 100 ? '...' : ''),
          sender: context.senderId,
          recipient: recipientId,
          category,
        });

        testLog("🔍 CHECKING: Should draft be generated?", {
          recipientId,
          category,
          messageText: context.messageText.substring(0, 100) + (context.messageText.length > 100 ? '...' : '')
        });

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
          testLog("❌ DECISION: No draft (prerequisites not met)", {
            recipientId,
            category,
          });
          continue; // Skip this recipient
        }

        // Get existing draft
        const existingDraft = await getDraft(context.conversationId, recipientId);

        // Check if should update draft (checks userTouched and age internally)
        const shouldUpdate = await shouldUpdateDraft(existingDraft);

        if (!shouldUpdate) {
          testLog("⏭️ DECISION: Draft already up-to-date", {
            recipientId,
            conversationId: context.conversationId,
          });
          continue;
        }
        const incomingMessages = recentMessages.filter(
          msg => msg.id === context.messageId || msg.senderId !== recipientId
        );

        // Generate draft
        testLog("🎨 GENERATING: Creating draft with voice profile", {
          recipientId,
          category,
          incomingMessageCount: incomingMessages.length,
        });

        const draftResult = await generateDraft(
          recipientId,
          context.conversationId,
          incomingMessages,
          category
        );

        if (!draftResult.success || !draftResult.draft) {
          testLog("❌ DECISION: Draft generation failed", {
            recipientId,
            reason: draftResult.reason,
            error: draftResult.error,
          });
          continue;
        }

        // Save draft to Firestore
        await saveDraft(draftResult.draft);

        testLog("✅ DECISION: Draft generated and saved", {
          recipientId,
          category,
          draftPreview: draftResult.draft.text.substring(0, 100) + '...',
          draftLength: draftResult.draft.text.length,
        });

      } catch (error) {
        logger.error("Draft Generation Pipeline: Error for recipient", {
          conversationId: context.conversationId,
          recipientId,
          error: error instanceof Error ? error.message : String(error),
        });
        // Continue to next recipient
      }
    }

    testLog("✅ DRAFT GENERATION PIPELINE: Complete", {
      conversationId: context.conversationId,
      recipientCount: recipients.length,
    });

  } catch (error) {
    // Catch all errors to prevent blocking other pipelines
    logger.error("Draft Generation Pipeline: Error occurred", {
      conversationId: context.conversationId,
      messageId: context.messageId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
