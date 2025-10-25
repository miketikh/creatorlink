/**
 * AI Helpers Module
 * Central export point for all AI-related functionality.
 */

export {getOpenAIClient} from "./client";
export {detectIfQuestion} from "./lib/question-detector";
export {fetchConversationMessages} from "./lib/message-fetcher";
export {findFAQMatch} from "./lib/faq-matcher";
export {writeAIResponse} from "./lib/response-writer";
export {categorizeConversation} from "./lib/categorizer";
export {fetchConversationContext, shouldAnalyzeMessage} from "./lib/conversation-context";
export {updateConversationTags} from "./lib/tag-writer";
export {extractKnowledge} from "./lib/knowledge-extractor";
export {generateEmbedding, generateEmbeddingsBatch, cosineSimilarity} from "./lib/embedding-generator";
export {storeKnowledgeFact, getKnowledgeByUserId} from "./lib/knowledge-store";
export {searchKnowledge, searchKnowledgeWithScores} from "./lib/knowledge-retriever";
export {
  getCachedResult,
  setCachedResult,
  isGlobalRateLimitExceeded,
  incrementAPICallCounter,
  trackAPICall,
  getCostStats,
  CATEGORIZATION_CONFIG,
} from "./lib/rate-limiter";

export type {
  QuestionDetectionResult,
  AIOperationResult,
  ConversationCategory,
  StatusTag,
  CategoryDetectionResult,
  StatusDetectionResult,
  CategorizationResult,
  TagUpdatePayload,
  KnowledgeFact,
  KnowledgeExtractionResult,
} from "./types";
export type {ConversationMessage} from "./lib/message-fetcher";
export type {FAQMatch} from "./lib/faq-matcher";
export type {WriteResponseResult} from "./lib/response-writer";
