/**
 * TypeScript types for AI helper functions.
 */

/**
 * Result from question detection.
 */
export interface QuestionDetectionResult {
  isQuestion: boolean;
  confidence: number;
}

/**
 * Base result type for AI operations.
 */
export interface AIOperationResult {
  success: boolean;
  error?: string;
}

// Add more types here as we expand AI functionality
// Example future types:
// - ContextDetectionResult
// - SentimentAnalysisResult
// - TopicClassificationResult
