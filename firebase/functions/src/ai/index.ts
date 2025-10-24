/**
 * AI Helpers Module
 * Central export point for all AI-related functionality.
 */

export {getOpenAIClient} from "./client";
export {detectIfQuestion} from "./lib/question-detector";
export {fetchConversationMessages} from "./lib/message-fetcher";
export {findFAQMatch} from "./lib/faq-matcher";
export {writeAIResponse} from "./lib/response-writer";

export type {
  QuestionDetectionResult,
  AIOperationResult,
} from "./types";
export type {ConversationMessage} from "./lib/message-fetcher";
export type {FAQMatch} from "./lib/faq-matcher";
export type {WriteResponseResult} from "./lib/response-writer";
