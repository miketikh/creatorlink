/**
 * Draft Manager
 * Handles saving, retrieving, updating, and deleting draft messages in Firestore.
 */

import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {MessageDraft} from "../types";

/**
 * Save or update a draft in Firestore.
 * Uses set with merge to overwrite existing drafts.
 *
 * @param draft - Draft to save
 * @returns Promise<string> - Document ID of saved draft
 */
export async function saveDraft(draft: MessageDraft): Promise<string> {
  const startTime = Date.now();

  try {
    logger.info("Saving draft", {
      conversationId: draft.conversationId,
      userId: draft.userId,
    });

    const db = admin.firestore();
    const draftRef = db
      .collection("conversations")
      .doc(draft.conversationId)
      .collection("drafts")
      .doc(draft.userId);

    // Prepare draft data for Firestore
    const draftData = {
      conversationId: draft.conversationId,
      userId: draft.userId,
      text: draft.text,
      category: draft.category,
      generatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      userTouched: draft.userTouched || false,
    };

    // Use set with merge to overwrite existing draft
    await draftRef.set(draftData, {merge: true});

    const duration = Date.now() - startTime;
    logger.info("Draft saved successfully", {
      conversationId: draft.conversationId,
      userId: draft.userId,
      draftId: draft.userId,
      durationMs: duration,
    });

    return draft.userId; // Document ID is the userId

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Failed to save draft", {
      conversationId: draft.conversationId,
      userId: draft.userId,
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    throw error;
  }
}

/**
 * Get an existing draft for a user in a conversation.
 *
 * @param conversationId - Conversation ID
 * @param userId - User ID
 * @returns Promise<MessageDraft | null> - Draft if exists, null otherwise
 */
export async function getDraft(
  conversationId: string,
  userId: string
): Promise<MessageDraft | null> {
  const startTime = Date.now();

  try {
    logger.info("Fetching draft", {
      conversationId,
      userId,
    });

    const db = admin.firestore();
    const draftDoc = await db
      .collection("conversations")
      .doc(conversationId)
      .collection("drafts")
      .doc(userId)
      .get();

    if (!draftDoc.exists) {
      logger.info("No draft found", {
        conversationId,
        userId,
      });
      return null;
    }

    const data = draftDoc.data();
    if (!data) {
      return null;
    }

    const draft: MessageDraft = {
      id: draftDoc.id,
      conversationId: data.conversationId,
      userId: data.userId,
      text: data.text,
      category: data.category,
      generatedAt: data.generatedAt?.toDate() || new Date(),
      updatedAt: data.updatedAt?.toDate() || new Date(),
      userTouched: data.userTouched || false,
    };

    const duration = Date.now() - startTime;
    logger.info("Draft fetched successfully", {
      conversationId,
      userId,
      durationMs: duration,
    });

    return draft;

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Failed to fetch draft", {
      conversationId,
      userId,
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    return null;
  }
}

/**
 * Delete a draft from Firestore.
 *
 * @param conversationId - Conversation ID
 * @param userId - User ID
 * @returns Promise<void>
 */
export async function deleteDraft(
  conversationId: string,
  userId: string
): Promise<void> {
  const startTime = Date.now();

  try {
    logger.info("Deleting draft", {
      conversationId,
      userId,
    });

    const db = admin.firestore();
    await db
      .collection("conversations")
      .doc(conversationId)
      .collection("drafts")
      .doc(userId)
      .delete();

    const duration = Date.now() - startTime;
    logger.info("Draft deleted successfully", {
      conversationId,
      userId,
      durationMs: duration,
    });

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Failed to delete draft", {
      conversationId,
      userId,
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    throw error;
  }
}

/**
 * Determine if an existing draft should be updated.
 * Simplified logic: update if no existing draft, not touched by user, and not too old.
 *
 * @param existingDraft - Existing draft (or null if none)
 * @returns boolean - true if should update, false if skip
 */
export async function shouldUpdateDraft(
  existingDraft: MessageDraft | null
): Promise<boolean> {
  // No existing draft -> create new one
  if (!existingDraft) {
    logger.info("No existing draft - should create new");
    return true;
  }

  // If draft was touched by user, don't auto-update
  if (existingDraft.userTouched) {
    logger.info("Draft marked as touched by user - skip auto-update", {
      conversationId: existingDraft.conversationId,
      userId: existingDraft.userId,
    });
    return false;
  }

  // Check draft age (don't update drafts older than MAX_DRAFT_AGE_MINUTES)
  const maxAgeMinutes = parseInt(process.env.MAX_DRAFT_AGE_MINUTES || "60");
  const draftAgeMinutes = (Date.now() - existingDraft.updatedAt.getTime()) / 1000 / 60;

  if (draftAgeMinutes > maxAgeMinutes) {
    logger.info("Draft too old - skip auto-update", {
      conversationId: existingDraft.conversationId,
      userId: existingDraft.userId,
      draftAgeMinutes: draftAgeMinutes.toFixed(1),
      maxAgeMinutes,
    });
    return false;
  }

  // All checks passed - should update
  logger.info("Should update draft", {
    conversationId: existingDraft.conversationId,
    userId: existingDraft.userId,
    draftAgeMinutes: draftAgeMinutes.toFixed(1),
  });
  return true;
}

/**
 * Mark a draft as touched by the user (prevents auto-updates).
 * Adds userTouched metadata field to draft.
 *
 * @param conversationId - Conversation ID
 * @param userId - User ID
 * @returns Promise<void>
 */
export async function markDraftTouched(
  conversationId: string,
  userId: string
): Promise<void> {
  const startTime = Date.now();

  try {
    logger.info("Marking draft as touched", {
      conversationId,
      userId,
    });

    const db = admin.firestore();
    await db
      .collection("conversations")
      .doc(conversationId)
      .collection("drafts")
      .doc(userId)
      .update({
        userTouched: true,
        updatedAt: FieldValue.serverTimestamp(),
      });

    const duration = Date.now() - startTime;
    logger.info("Draft marked as touched", {
      conversationId,
      userId,
      durationMs: duration,
    });

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Failed to mark draft as touched", {
      conversationId,
      userId,
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    throw error;
  }
}
