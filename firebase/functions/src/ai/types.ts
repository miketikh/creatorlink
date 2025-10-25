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

/**
 * Conversation category enum matching Swift ConversationTag
 */
export enum ConversationCategory {
  Business = "business",
  Collaboration = "collaboration",
  Social = "social",
  Fan = "fan",
}

/**
 * Status tag enum matching Swift StatusTag
 */
export enum StatusTag {
  Urgent = "urgent",
  NeedsResponse = "needsResponse",
  AwaitingReply = "awaitingReply",
  Resolved = "resolved",
}

/**
 * Category detection result with confidence and reasoning
 */
export interface CategoryDetectionResult {
  category: ConversationCategory;
  confidence: number;
  reasoning: string;
}

/**
 * Status detection result with per-user status tags
 * The AI determines which status tags each participant should see based on their perspective
 */
export interface StatusDetectionResult {
  // Map of userId -> array of status tags for that user
  statusTagsByUser: { [userId: string]: StatusTag[] };
  reasoning: string;
}

/**
 * Combined categorization result
 */
export interface CategorizationResult {
  category: CategoryDetectionResult;
  status: StatusDetectionResult;
}

/**
 * Tag update payload for Firestore
 * IMPORTANT: Field names must match Swift Conversation.swift model
 */
export interface TagUpdatePayload {
  primaryCategory: string;
  categoryTags: string[];  // Changed from 'categories' to match Swift model
  statusTags: string[];
  tagMetadata: {  // Changed from 'aiTagMetadata' to match Swift model
    aiSuggestedCategory: string;
    aiConfidenceScore: number;
    userOverrideCategory: boolean;
    userOverrideStatus: boolean;
    lastAIAnalysisTime: FirebaseFirestore.Timestamp;
  };
}

/**
 * Type guard for valid conversation category
 */
export function isCategoryValid(category: string): category is ConversationCategory {
  return Object.values(ConversationCategory).includes(category as ConversationCategory);
}

/**
 * Type guard for valid status tag
 */
export function isStatusValid(status: string): status is StatusTag {
  return Object.values(StatusTag).includes(status as StatusTag);
}

/**
 * Knowledge fact with vector embedding for semantic search.
 * Used to store factual information extracted from user messages.
 */
export interface KnowledgeFact {
  id: string; // Firestore document ID
  userId: string; // Owner of this knowledge
  text: string; // Normalized, self-contained fact (e.g., "User has a dog named Max")
  embedding: number[]; // Vector representation (1536 dimensions from OpenAI text-embedding-3-small)
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Result from knowledge extraction operation.
 */
export interface KnowledgeExtractionResult {
  success: boolean;
  facts: KnowledgeFact[];
  error?: string;
}

// Add more types here as we expand AI functionality
// Example future types:
// - ContextDetectionResult
// - SentimentAnalysisResult
// - TopicClassificationResult
