/**
 * Voice Profile Loader
 * Loads user voice profiles from Firestore for use in draft generation.
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import type {VoiceProfile, ConversationCategory} from "../types";

/**
 * Loads a user's voice profile for a specific conversation category.
 * Returns null if the profile doesn't exist (graceful degradation).
 *
 * @param userId - The user ID to load the profile for
 * @param category - The conversation category (business, collaboration, social, fan)
 * @returns VoiceProfile if found, null if not found
 */
export async function loadVoiceProfile(
  userId: string,
  category: ConversationCategory
): Promise<VoiceProfile | null> {
  try {
    const db = admin.firestore();

    // Fetch voice profile from subcollection
    const profileDoc = await db
      .collection("users")
      .doc(userId)
      .collection("voiceProfiles")
      .doc(category)
      .get();

    if (!profileDoc.exists) {
      logger.info("Voice profile not found", {
        userId,
        category,
      });
      return null;
    }

    const data = profileDoc.data();
    if (!data) {
      logger.warn("Voice profile document exists but has no data", {
        userId,
        category,
      });
      return null;
    }

    // Parse document data into VoiceProfile type
    const profile: VoiceProfile = {
      userId: data.userId,
      category: data.category,
      styleRules: data.styleRules,
      createdAt: data.createdAt?.toDate() || new Date(),
      lastUpdated: data.lastUpdated?.toDate() || new Date(),
    };

    logger.info("Voice profile loaded successfully", {
      userId,
      category,
      hasStyleRules: !!profile.styleRules,
    });

    return profile;

  } catch (error) {
    logger.error("Failed to load voice profile", {
      userId,
      category,
      error: error instanceof Error ? error.message : String(error),
    });

    // Return null on error for graceful degradation
    return null;
  }
}
