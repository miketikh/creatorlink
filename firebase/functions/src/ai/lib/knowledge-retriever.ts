/**
 * Knowledge Retrieval Service
 * Performs semantic search on knowledge facts using Firestore native vector search.
 *
 * Uses Firestore's findNearest() method with:
 * - COSINE distance measure (best for normalized embeddings)
 * - Pre-filtering by userId
 * - Automatic similarity-based sorting
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {KnowledgeFact} from "../types";
import {generateEmbedding} from "./embedding-generator";
import {testLog} from "./test-logger";
import {transformQuery} from "./query-transformer";
import {ConversationMessage} from "./message-fetcher";

// Minimum similarity threshold for results (0.45 = calibrated for text-embedding-3-small)
// Note: text-embedding-3-small produces lower scores than ada-002 (0.45 vs 0.7)
const MIN_SIMILARITY_THRESHOLD = 0.45;

/**
 * Search for relevant knowledge facts using semantic vector search.
 *
 * @param queryText - The query text to search for
 * @param userId - User ID to filter results to
 * @param topK - Number of top results to return (default: 5)
 * @returns Array of relevant facts, sorted by relevance (most relevant first)
 */
export async function searchKnowledge(
  queryText: string,
  userId: string,
  topK: number = 5
): Promise<KnowledgeFact[]> {
  const startTime = Date.now();

  try {
    logger.info("Starting knowledge search", {
      queryLength: queryText.length,
      userId,
      topK,
    });

    // Generate embedding for query text
    const queryEmbedding = await generateEmbedding(queryText);

    const db = admin.firestore();

    // Use Firestore native vector search
    // Note: findNearest() is the method for vector search in Firestore
    const results = await db.collection("knowledge")
      .where("userId", "==", userId)
      .findNearest({
        vectorField: "embedding",
        queryVector: admin.firestore.FieldValue.vector(queryEmbedding),
        limit: topK,
        distanceMeasure: "COSINE",
      })
      .get();

    if (results.empty) {
      logger.info("No knowledge facts found", {
        userId,
        queryText: queryText.substring(0, 50),
      });
      return [];
    }

    // Convert results to KnowledgeFact format
    const facts: KnowledgeFact[] = results.docs.map(doc => {
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

    // Optional: Filter by minimum similarity threshold
    // Note: Firestore returns results sorted by similarity, but doesn't expose the similarity score
    // For now, we trust that findNearest returns relevant results
    // If we need explicit similarity scores, we'd need to calculate them manually

    const duration = Date.now() - startTime;
    logger.info("Knowledge search complete", {
      userId,
      resultsFound: facts.length,
      durationMs: duration,
    });

    if (facts.length > 0) {
      logger.info("Top search results:", {
        facts: facts.map(f => ({
          id: f.id,
          text: f.text.substring(0, 50),
        })),
      });
    }

    return facts;

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Knowledge search failed", {
      userId,
      queryText: queryText.substring(0, 50),
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    // Return empty array on error (graceful degradation)
    return [];
  }
}

/**
 * Search for knowledge facts and return with similarity scores.
 * This is a helper that manually calculates cosine similarity for each result.
 *
 * MULTI-QUERY SUPPORT:
 * - Generates 1-3 queries from the input message
 * - Searches for each query separately
 * - Merges results using deduplication (keeps highest similarity per fact)
 * - Returns combined ranked results
 *
 * @param queryText - The query text to search for
 * @param userId - User ID to filter results to
 * @param topK - Number of top results to return (default: 5)
 * @param conversationHistory - Recent conversation messages for context (default: empty)
 * @returns Array of facts with similarity scores
 */
export async function searchKnowledgeWithScores(
  queryText: string,
  userId: string,
  topK: number = 5,
  conversationHistory: ConversationMessage[] = []
): Promise<Array<{fact: KnowledgeFact; similarity: number}>> {
  try {
    logger.info("Starting knowledge search with scores (multi-query)", {
      queryLength: queryText.length,
      userId,
      topK,
    });

    // Transform query into normalized fact format for better semantic matching
    // Example: "Do you have pets?" → ["User has pets"]
    // Example: "I like dancing, do you have pets?" → ["User has pets", "User likes dancing"]
    // Uses conversation history for context (e.g., "u?" → ["User has pets"] if discussing pets)
    const transformedQueries = await transformQuery(queryText, conversationHistory);

    testLog("🔍 MULTI-QUERY SEARCH: Starting", {
      userId,
      originalQuery: queryText.substring(0, 100),
      queriesGenerated: transformedQueries.length,
      queries: transformedQueries,
    });

    // Get all facts for user once (we'll search against them for each query)
    const db = admin.firestore();
    const snapshot = await db.collection("knowledge")
      .where("userId", "==", userId)
      .get();

    if (snapshot.empty) {
      logger.info("No knowledge facts found for user", {userId});

      // Diagnostic: Query ALL documents to check if any exist
      const allDocsSnapshot = await db.collection("knowledge").limit(10).get();

      testLog("🚨 KNOWLEDGE RETRIEVAL: ZERO results for userId", {
        userId,
        originalQuery: queryText.substring(0, 100),
        queries: transformedQueries,
        totalDocsInCollection: allDocsSnapshot.size,
        sampleDocs: allDocsSnapshot.docs.slice(0, 5).map(d => ({
          docId: d.id,
          userId: d.data().userId,
          text: d.data().text?.substring(0, 50),
        })),
      });

      return [];
    }

    testLog("✅ KNOWLEDGE RETRIEVAL: Found documents for userId", {
      userId,
      originalQuery: queryText.substring(0, 100),
      queries: transformedQueries,
      totalDocuments: snapshot.size,
      sampleFacts: snapshot.docs.slice(0, 3).map(d => ({
        docId: d.id,
        text: d.data().text.substring(0, 50),
      })),
    });

    // Process each query and collect results
    const allQueryResults: Array<{
      query: string;
      results: Array<{fact: KnowledgeFact; similarity: number}>;
    }> = [];

    for (const query of transformedQueries) {
      // Generate embedding for this query
      const queryEmbedding = await generateEmbedding(query);

      logger.info("🔍 Processing query", {
        userId,
        query: query.substring(0, 100),
        embeddingDimensions: queryEmbedding.length,
      });

      // Calculate similarity for each fact
      const queryResults: Array<{fact: KnowledgeFact; similarity: number}> = [];

      for (const doc of snapshot.docs) {
        const data = doc.data();

        // Extract embedding
        let embedding: number[];
        if (data.embedding && typeof data.embedding.toArray === 'function') {
          embedding = data.embedding.toArray();
        } else if (Array.isArray(data.embedding)) {
          embedding = data.embedding;
        } else {
          continue; // Skip facts without valid embeddings
        }

        // Calculate cosine similarity
        const similarity = cosineSimilarity(queryEmbedding, embedding);

        // Only include if above threshold
        if (similarity >= MIN_SIMILARITY_THRESHOLD) {
          queryResults.push({
            fact: {
              id: doc.id,
              userId: data.userId,
              text: data.text,
              embedding,
              createdAt: data.createdAt?.toDate() || new Date(),
              updatedAt: data.updatedAt?.toDate() || new Date(),
            },
            similarity,
          });
        }
      }

      // Sort by similarity (highest first)
      queryResults.sort((a, b) => b.similarity - a.similarity);

      allQueryResults.push({
        query,
        results: queryResults,
      });

      testLog(`  📊 Query ${allQueryResults.length}/${transformedQueries.length} results`, {
        query: query.substring(0, 100),
        resultsFound: queryResults.length,
        topResults: queryResults.slice(0, 3).map(r => ({
          text: r.fact.text.substring(0, 60),
          similarity: r.similarity.toFixed(3),
        })),
      });
    }

    // Merge results using simple deduplication (keep highest similarity per fact)
    const mergedResults = new Map<string, {fact: KnowledgeFact; similarity: number}>();

    for (const queryResult of allQueryResults) {
      for (const result of queryResult.results) {
        const existing = mergedResults.get(result.fact.id);
        if (!existing || result.similarity > existing.similarity) {
          mergedResults.set(result.fact.id, result);
        }
      }
    }

    // Convert to array and sort by similarity
    const finalResults = Array.from(mergedResults.values())
      .sort((a, b) => b.similarity - a.similarity)
      .slice(0, topK);

    testLog("🔍 MULTI-QUERY SEARCH: Complete", {
      userId,
      originalQuery: queryText.substring(0, 100),
      queriesProcessed: transformedQueries.length,
      totalResultsBeforeMerge: allQueryResults.reduce((sum, qr) => sum + qr.results.length, 0),
      uniqueResultsAfterMerge: mergedResults.size,
      finalTopK: finalResults.length,
      topResults: finalResults.slice(0, 5).map(r => ({
        text: r.fact.text.substring(0, 60),
        similarity: r.similarity.toFixed(3),
      })),
    });

    return finalResults;

  } catch (error) {
    logger.error("Knowledge search with scores failed", {
      userId,
      error: error instanceof Error ? error.message : String(error),
    });
    return [];
  }
}

/**
 * Calculate cosine similarity between two vectors.
 * Copied from embedding-generator for convenience.
 */
function cosineSimilarity(vec1: number[], vec2: number[]): number {
  if (vec1.length !== vec2.length) {
    return 0;
  }

  let dotProduct = 0;
  let norm1 = 0;
  let norm2 = 0;

  for (let i = 0; i < vec1.length; i++) {
    dotProduct += vec1[i] * vec2[i];
    norm1 += vec1[i] * vec1[i];
    norm2 += vec2[i] * vec2[i];
  }

  const magnitude = Math.sqrt(norm1) * Math.sqrt(norm2);

  if (magnitude === 0) {
    return 0;
  }

  return dotProduct / magnitude;
}
