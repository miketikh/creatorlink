/**
 * Vector Embedding Generator
 * Generates vector embeddings using OpenAI's text-embedding-3-small model.
 *
 * Uses OpenAI text-embedding-3-small:
 * - 1536 dimensions
 * - Cost: ~$0.02 per 1M tokens (very cheap)
 * - Good quality for semantic search
 *
 * Embeddings are stored directly in Firestore using FieldValue.vector()
 * for native Firestore vector search.
 */

import * as logger from "firebase-functions/logger";
import {getOpenAIClient} from "../client";

// Embedding model configuration
const EMBEDDING_MODEL = "text-embedding-3-small";
const EMBEDDING_DIMENSIONS = 1536;

/**
 * Generate vector embedding for a text string.
 *
 * @param text - The text to generate an embedding for
 * @returns Promise with 1536-dimensional vector array
 * @throws Error if embedding generation fails
 */
export async function generateEmbedding(text: string): Promise<number[]> {
  const startTime = Date.now();

  try {
    logger.info("Generating embedding", {
      textLength: text.length,
      model: EMBEDDING_MODEL,
    });

    const openai = getOpenAIClient();

    const response = await openai.embeddings.create({
      model: EMBEDDING_MODEL,
      input: text,
      encoding_format: "float",
    });

    const embedding = response.data[0].embedding;

    // Validate embedding dimensions
    if (embedding.length !== EMBEDDING_DIMENSIONS) {
      throw new Error(
        `Expected ${EMBEDDING_DIMENSIONS} dimensions, got ${embedding.length}`
      );
    }

    const duration = Date.now() - startTime;
    logger.info("Embedding generated successfully", {
      dimensions: embedding.length,
      durationMs: duration,
      tokensUsed: response.usage.total_tokens,
    });

    return embedding;

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Embedding generation failed", {
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
      textLength: text.length,
    });
    throw error;
  }
}

/**
 * Generate embeddings for multiple texts in batch.
 * More efficient than calling generateEmbedding multiple times.
 *
 * @param texts - Array of texts to generate embeddings for
 * @returns Promise with array of embeddings (same order as input)
 * @throws Error if batch embedding generation fails
 */
export async function generateEmbeddingsBatch(
  texts: string[]
): Promise<number[][]> {
  const startTime = Date.now();

  try {
    logger.info("Generating embeddings batch", {
      count: texts.length,
      model: EMBEDDING_MODEL,
    });

    const openai = getOpenAIClient();

    const response = await openai.embeddings.create({
      model: EMBEDDING_MODEL,
      input: texts,
      encoding_format: "float",
    });

    const embeddings = response.data.map(item => item.embedding);

    // Validate all embeddings
    for (let i = 0; i < embeddings.length; i++) {
      if (embeddings[i].length !== EMBEDDING_DIMENSIONS) {
        throw new Error(
          `Embedding ${i}: Expected ${EMBEDDING_DIMENSIONS} dimensions, got ${embeddings[i].length}`
        );
      }
    }

    const duration = Date.now() - startTime;
    logger.info("Batch embeddings generated successfully", {
      count: embeddings.length,
      dimensions: EMBEDDING_DIMENSIONS,
      durationMs: duration,
      tokensUsed: response.usage.total_tokens,
    });

    return embeddings;

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Batch embedding generation failed", {
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
      count: texts.length,
    });
    throw error;
  }
}

/**
 * Calculate cosine similarity between two vectors.
 * Used for deduplication and semantic search.
 *
 * @param vec1 - First vector
 * @param vec2 - Second vector
 * @returns Cosine similarity score (0.0 to 1.0, higher = more similar)
 */
export function cosineSimilarity(vec1: number[], vec2: number[]): number {
  if (vec1.length !== vec2.length) {
    throw new Error("Vectors must have same dimensions");
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
