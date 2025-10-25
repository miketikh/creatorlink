/**
 * Tag Update Writer
 * Writes AI-suggested tags to Firestore conversations safely.
 */

import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {CategorizationResult, ConversationCategory} from "../types";

// Minimum confidence threshold to apply AI tags
const DEFAULT_CONFIDENCE_THRESHOLD = 0.75;

/**
 * Update conversation tags based on AI categorization result.
 *
 * @param conversationId - The conversation ID to update
 * @param categorizationResult - The categorization result from AI
 * @param lastMessageSenderId - The ID of the user who sent the last message
 * @param participantIds - Array of all participant IDs in the conversation
 * @param minimumConfidence - Minimum confidence to apply tags (default 0.75)
 * @returns Promise indicating success/failure
 */
export async function updateConversationTags(
  conversationId: string,
  categorizationResult: CategorizationResult,
  lastMessageSenderId?: string,
  participantIds?: string[],
  minimumConfidence: number = DEFAULT_CONFIDENCE_THRESHOLD
): Promise<boolean> {
  const startTime = Date.now();

  try {
    const categoryConfidence = categorizationResult.category.confidence;

    logger.info("Processing tag update", {
      conversationId,
      category: categorizationResult.category.category,
      categoryConfidence: categoryConfidence,
      statusTagsByUser: categorizationResult.status.statusTagsByUser,
    });

    const db = admin.firestore();
    const conversationRef = db.collection("conversations").doc(conversationId);

    // Use transaction for atomic updates
    const success = await db.runTransaction(async (transaction) => {
      const conversationDoc = await transaction.get(conversationRef);

      if (!conversationDoc.exists) {
        logger.warn("Conversation not found", {conversationId});
        return false;
      }

      const conversationData = conversationDoc.data();

      // Extra safety check - respect user overrides
      if (conversationData?.userOverrideTags === true) {
        logger.info("Skipping tag update - user has overridden tags", {
          conversationId,
        });
        return false;
      }

      // Build update payload
      // IMPORTANT: Field names must match Swift Conversation.swift model:
      // - categoryTags (not categories)
      // - tagMetadata (not aiTagMetadata)
      // - Status tags go in tagsByUser (per-user), NOT at conversation level
      const updateData: any = {};

      // Category updates - ONLY if confidence meets threshold
      if (categoryConfidence >= minimumConfidence) {
        // Calculate primary category (considers existing category for stability)
        const primaryCategory = calculatePrimaryCategory(
          categorizationResult.category.category,
          conversationData?.primaryCategory,
          categorizationResult.category.confidence
        );

        updateData.primaryCategory = primaryCategory;
        updateData.categoryTags = [primaryCategory];

        logger.info("Updating category", {
          conversationId,
          category: primaryCategory,
          confidence: categoryConfidence,
        });
      } else {
        logger.info("Skipping category update - confidence below threshold", {
          conversationId,
          confidence: categoryConfidence,
          threshold: minimumConfidence,
          keepingExisting: conversationData?.primaryCategory,
        });
      }

      // Always update tagMetadata for tracking (even if category unchanged)
      updateData.tagMetadata = {
        aiSuggestedCategory: categorizationResult.category.category.toString(),
        aiConfidenceScore: categorizationResult.category.confidence,
        userOverrideCategory: false,
        userOverrideStatus: false,
        lastAIAnalysisTime: FieldValue.serverTimestamp(),
      };

      // Build per-user status tags from AI result (NO manual logic!)
      // AI determines which users' tags should change:
      // - [] = clear tags for that user
      // - ["tag1", "tag2"] = set tags for that user
      // - user not in response = no change, keep existing tags
      const statusTagsByUser = categorizationResult.status.statusTagsByUser;
      if (statusTagsByUser && Object.keys(statusTagsByUser).length > 0) {
        // Get existing tagsByUser or initialize empty object
        const existingTagsByUser = conversationData?.tagsByUser || {};
        const updatedTagsByUser: any = {...existingTagsByUser};

        for (const [userId, statusTags] of Object.entries(statusTagsByUser)) {
          if (Array.isArray(statusTags)) {
            if (statusTags.length === 0) {
              // Empty array [] = clear all tags for this user
              delete updatedTagsByUser[userId];
              logger.info("Clearing tags for user", {userId});
            } else {
              // Tags array = set/update tags for this user
              updatedTagsByUser[userId] = {
                statusTags: statusTags.map(tag => tag.toString()),
              };
              logger.info("Setting tags for user", {userId, tags: statusTags});
            }
          }
        }

        updateData.tagsByUser = updatedTagsByUser;

        logger.info("Per-user status tags updated", {
          conversationId,
          aiChanges: statusTagsByUser,
          finalTagsByUser: updatedTagsByUser,
        });
      } else {
        // No status changes from AI - keep existing tags
        logger.info("No status tag changes from AI - keeping existing tags", {
          conversationId,
        });
      }

      // Only perform update if we have fields to update
      if (Object.keys(updateData).length > 0) {
        transaction.update(conversationRef, updateData);

        logger.info("Transaction prepared - tags will be updated", {
          conversationId,
          updatingCategory: !!updateData.primaryCategory,
          category: updateData.primaryCategory,
          updatingStatusTags: !!updateData.tagsByUser,
          tagsByUser: updateData.tagsByUser,
        });

        return true;
      } else {
        logger.info("No updates to apply", {conversationId});
        return false;
      }
    });

    const duration = Date.now() - startTime;

    if (success) {
      const updatedCategory = categoryConfidence >= minimumConfidence;
      const updatedStatus = categorizationResult.status.statusTagsByUser &&
        Object.keys(categorizationResult.status.statusTagsByUser).length > 0;

      logger.info("✅ Conversation tags updated successfully", {
        conversationId,
        updatedCategory,
        updatedStatus,
        categoryConfidence,
        statusTagsByUser: categorizationResult.status.statusTagsByUser,
        durationMs: duration,
      });
    }

    return success;

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Failed to update conversation tags", {
      conversationId,
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    // Don't throw - let function complete gracefully
    return false;
  }
}

/**
 * Calculate primary category, considering existing category for stability.
 * If existing category and new category have similar confidence, keep existing.
 *
 * @param newCategory - New category from AI
 * @param existingCategory - Current category if any
 * @param newConfidence - Confidence score of new category
 * @returns The category to use as primary
 */
function calculatePrimaryCategory(
  newCategory: ConversationCategory,
  existingCategory: string | undefined,
  newConfidence: number
): string {
  // If no existing category, use new category
  if (!existingCategory) {
    return newCategory.toString();
  }

  // If existing category matches new category, keep it (stability)
  if (existingCategory === newCategory.toString()) {
    logger.info("Category unchanged - matches existing", {
      category: existingCategory,
      confidence: newConfidence,
    });
    return existingCategory;
  }

  // If new confidence is high (>0.80), switch to new category
  // Lowered from 0.85 to be more responsive to explicit category changes
  if (newConfidence > 0.80) {
    logger.info("Switching category - high confidence", {
      from: existingCategory,
      to: newCategory,
      confidence: newConfidence,
    });
    return newCategory.toString();
  }

  // Otherwise keep existing category for stability (prevents constant switching)
  logger.info("Keeping existing category - not enough confidence to switch", {
    existing: existingCategory,
    suggested: newCategory,
    confidence: newConfidence,
    threshold: 0.80,
  });
  return existingCategory;
}
