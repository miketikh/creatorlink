/**
 * Knowledge Storage Service
 * Stores and retrieves knowledge facts with vector embeddings in Firestore.
 *
 * Features:
 * - Vector similarity-based deduplication (threshold: 0.95)
 * - Native Firestore vector storage using FieldValue.vector()
 * - Automatic timestamp management
 */

import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {KnowledgeFact} from "../types";
import {generateEmbedding, cosineSimilarity} from "./embedding-generator";
import {testLog} from "./test-logger";

// Deduplication threshold - facts with similarity > 0.95 are considered duplicates
const DEDUPLICATION_THRESHOLD = 0.95;

/**
 * Store a knowledge fact with embedding to Firestore.
 * Performs deduplication check using vector similarity.
 *
 * @param fact - Partial fact (id and embedding will be generated)
 * @returns Document ID if stored, null if skipped as duplicate
 */
export async function storeKnowledgeFact(
  fact: Partial<KnowledgeFact>
): Promise<string | null> {
  try {
    if (!fact.userId || !fact.text) {
      throw new Error("userId and text are required");
    }

    // logger.info("Storing knowledge fact", {
    //   userId: fact.userId,
    //   textLength: fact.text.length,
    //   textPreview: fact.text.substring(0, 50),
    // });

    // Generate embedding for the fact
    const embedding = await generateEmbedding(fact.text);

    // Check for duplicates using vector similarity
    const isDuplicate = await checkForDuplicate(
      fact.userId,
      embedding,
      fact.text
    );

    if (isDuplicate) {
      // logger.info("Fact is duplicate, skipping storage", {
      //   userId: fact.userId,
      //   textPreview: fact.text.substring(0, 50),
      // });
      return null;
    }

    // Store in Firestore
    const db = admin.firestore();
    const docRef = db.collection("knowledge").doc();

    const factData = {
      userId: fact.userId,
      text: fact.text,
      embedding: FieldValue.vector(embedding),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    await docRef.set(factData);

    // logger.info("Knowledge fact stored successfully", {
    //   factId: docRef.id,
    //   userId: fact.userId,
    // });

    return docRef.id;

  } catch (error) {
    // logger.error("Failed to store knowledge fact", {
    //   userId: fact.userId,
    //   error: error instanceof Error ? error.message : String(error),
    // });
    throw error;
  }
}

/**
 * Check if a fact is a duplicate by comparing embeddings with existing facts.
 *
 * @param userId - User ID to check facts for
 * @param newEmbedding - Embedding of the new fact
 * @param newText - Text of the new fact (for logging)
 * @returns true if duplicate found (similarity > threshold), false otherwise
 */
async function checkForDuplicate(
  userId: string,
  newEmbedding: number[],
  newText: string
): Promise<boolean> {
  try {
    const db = admin.firestore();

    // Fetch all existing facts for this user
    const existingFacts = await db.collection("knowledge")
      .where("userId", "==", userId)
      .get();

    if (existingFacts.empty) {
      // logger.info("No existing facts for user, not a duplicate", {userId});
      return false;
    }

    // Check similarity with each existing fact
    for (const doc of existingFacts.docs) {
      const existingFact = doc.data();

      // Extract embedding array from Firestore VectorValue
      // The embedding is stored as a VectorValue object with a toArray() method
      let existingEmbedding: number[];

      if (existingFact.embedding && typeof existingFact.embedding.toArray === 'function') {
        existingEmbedding = existingFact.embedding.toArray();
      } else if (Array.isArray(existingFact.embedding)) {
        existingEmbedding = existingFact.embedding;
      } else {
        // logger.warn("Invalid embedding format, skipping comparison", {
        //   factId: doc.id,
        // });
        continue;
      }

      const similarity = cosineSimilarity(newEmbedding, existingEmbedding);

      // Only log high similarity scores (> 0.90) to reduce noise
      if (similarity > 0.90) {
        testLog("🔍 SIMILARITY CHECK", {
          userId,
          similarity: similarity.toFixed(3),
          existingFact: existingFact.text,
          newFact: newText,
        });
      }

      if (similarity > DEDUPLICATION_THRESHOLD) {
        testLog("🎯 DUPLICATE DETECTED (similarity > 0.95)", {
          userId,
          similarity: similarity.toFixed(3),
        });
        return true;
      }
    }

    // logger.info("No duplicates found, fact is unique", {
    //   userId,
    //   checkedCount: existingFacts.size,
    // });
    return false;

  } catch (error) {
    // logger.error("Error checking for duplicates", {
    //   userId,
    //   error: error instanceof Error ? error.message : String(error),
    // });
    // On error, assume not duplicate (better to store than lose data)
    return false;
  }
}

/**
 * Get all knowledge facts for a user.
 *
 * @param userId - User ID to fetch facts for
 * @param limit - Maximum number of facts to return (default: 100)
 * @returns Array of knowledge facts, ordered by creation time (newest first)
 */
export async function getKnowledgeByUserId(
  userId: string,
  limit: number = 100
): Promise<KnowledgeFact[]> {
  try {
    // logger.info("Fetching knowledge facts", {userId, limit});

    const db = admin.firestore();
    const snapshot = await db.collection("knowledge")
      .where("userId", "==", userId)
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    const facts: KnowledgeFact[] = snapshot.docs.map(doc => {
      const data = doc.data();

      // Extract embedding array
      let embedding: number[];
      if (data.embedding && typeof data.embedding.toArray === 'function') {
        embedding = data.embedding.toArray();
      } else if (Array.isArray(data.embedding)) {
        embedding = data.embedding;
      } else {
        embedding = [];
      }

      return {
        id: doc.id,
        userId: data.userId,
        text: data.text,
        embedding,
        createdAt: data.createdAt?.toDate() || new Date(),
        updatedAt: data.updatedAt?.toDate() || new Date(),
      };
    });

    // logger.info("Knowledge facts fetched", {
    //   userId,
    //   count: facts.length,
    // });

    return facts;

  } catch (error) {
    // logger.error("Failed to fetch knowledge facts", {
    //   userId,
    //   error: error instanceof Error ? error.message : String(error),
    // });
    throw error;
  }
}
