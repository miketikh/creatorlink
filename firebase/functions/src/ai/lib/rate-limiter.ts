/**
 * Rate Limiter and Cost Tracking
 * Implements caching, rate limiting, and cost tracking for AI categorization.
 */

import * as logger from "firebase-functions/logger";
import {CategorizationResult} from "../types";

/**
 * Configuration for rate limiting and cost tracking
 */
export const CATEGORIZATION_CONFIG = {
  // Cache TTL in seconds (60 seconds - allows fresh analysis on sender change)
  CACHE_TTL_SECONDS: parseInt(process.env.CACHE_TTL_SECONDS || "60", 10),

  // Per-conversation cooldown in seconds (60 seconds for same sender only)
  PER_CONVERSATION_COOLDOWN_SECONDS: parseInt(
    process.env.PER_CONVERSATION_COOLDOWN_SECONDS || "60",
    10
  ),

  // Global rate limit (calls per minute)
  GLOBAL_RATE_LIMIT_PER_MINUTE: parseInt(
    process.env.GLOBAL_RATE_LIMIT_PER_MINUTE || "60",
    10
  ),

  // Maximum context messages to fetch
  MAX_CONTEXT_MESSAGES: parseInt(process.env.MAX_CONTEXT_MESSAGES || "10", 10),

  // Confidence threshold for applying tags
  CONFIDENCE_THRESHOLD: parseFloat(process.env.CONFIDENCE_THRESHOLD || "0.75"),

  // Estimated tokens per categorization (for cost tracking)
  ESTIMATED_TOKENS_PER_CALL: 500,

  // GPT-4o-mini pricing (as of 2025)
  // Input: $0.150 per 1M tokens, Output: $0.600 per 1M tokens
  // Approximate cost per call (assuming 500 tokens input, 200 tokens output)
  COST_PER_CALL_USD: 0.00015,
};

/**
 * In-memory cache for recent categorization results
 */
interface CacheEntry {
  result: CategorizationResult;
  timestamp: number;
}

const categorizationCache = new Map<string, CacheEntry>();

/**
 * Get cached categorization result if available and not expired.
 *
 * @param conversationId - The conversation ID to check
 * @returns Cached result or undefined if not found/expired
 */
export function getCachedResult(
  conversationId: string
): CategorizationResult | undefined {
  const entry = categorizationCache.get(conversationId);

  if (!entry) {
    return undefined;
  }

  const now = Date.now();
  const ageMs = now - entry.timestamp;
  const maxAgeMs = CATEGORIZATION_CONFIG.CACHE_TTL_SECONDS * 1000;

  if (ageMs > maxAgeMs) {
    // Cache expired - remove it
    categorizationCache.delete(conversationId);
    logger.info("Cache entry expired", {
      conversationId,
      ageMs,
      maxAgeMs,
    });
    return undefined;
  }

  logger.info("Cache hit - returning cached result", {
    conversationId,
    ageMs,
    category: entry.result.category.category,
  });

  return entry.result;
}

/**
 * Store categorization result in cache.
 *
 * @param conversationId - The conversation ID
 * @param result - The categorization result to cache
 */
export function setCachedResult(
  conversationId: string,
  result: CategorizationResult
): void {
  categorizationCache.set(conversationId, {
    result,
    timestamp: Date.now(),
  });

  logger.info("Cached categorization result", {
    conversationId,
    category: result.category.category,
    cacheSize: categorizationCache.size,
  });

  // Cleanup old entries to prevent memory leaks
  cleanupExpiredCache();
}

/**
 * Clear cached result for a conversation (used when sender changes).
 *
 * @param conversationId - The conversation ID
 */
export function clearCachedResult(conversationId: string): void {
  if (categorizationCache.has(conversationId)) {
    categorizationCache.delete(conversationId);
    logger.info("Cache cleared for conversation", {
      conversationId,
      reason: "sender changed",
    });
  }
}

/**
 * Remove expired entries from cache.
 */
function cleanupExpiredCache(): void {
  const now = Date.now();
  const maxAgeMs = CATEGORIZATION_CONFIG.CACHE_TTL_SECONDS * 1000;
  let removedCount = 0;

  for (const [conversationId, entry] of categorizationCache.entries()) {
    const ageMs = now - entry.timestamp;
    if (ageMs > maxAgeMs) {
      categorizationCache.delete(conversationId);
      removedCount++;
    }
  }

  if (removedCount > 0) {
    logger.info("Cleaned up expired cache entries", {
      removedCount,
      remainingSize: categorizationCache.size,
    });
  }
}

/**
 * Global rate limiting state
 */
interface RateLimitWindow {
  count: number;
  windowStart: number;
}

const globalRateLimit: RateLimitWindow = {
  count: 0,
  windowStart: Date.now(),
};

/**
 * Check if global rate limit is exceeded.
 *
 * @returns True if rate limit is exceeded, false otherwise
 */
export function isGlobalRateLimitExceeded(): boolean {
  const now = Date.now();
  const windowDurationMs = 60 * 1000; // 1 minute window

  // Reset window if expired
  if (now - globalRateLimit.windowStart > windowDurationMs) {
    globalRateLimit.count = 0;
    globalRateLimit.windowStart = now;
  }

  // Check if limit exceeded
  if (globalRateLimit.count >= CATEGORIZATION_CONFIG.GLOBAL_RATE_LIMIT_PER_MINUTE) {
    logger.warn("Global rate limit exceeded", {
      count: globalRateLimit.count,
      limit: CATEGORIZATION_CONFIG.GLOBAL_RATE_LIMIT_PER_MINUTE,
      windowStart: globalRateLimit.windowStart,
    });
    return true;
  }

  return false;
}

/**
 * Increment the global API call counter.
 */
export function incrementAPICallCounter(): void {
  globalRateLimit.count++;

  logger.info("API call counter incremented", {
    count: globalRateLimit.count,
    limit: CATEGORIZATION_CONFIG.GLOBAL_RATE_LIMIT_PER_MINUTE,
  });
}

/**
 * Cost tracking state
 */
interface CostTracker {
  totalCalls: number;
  totalCostUSD: number;
  lastResetTimestamp: number;
}

const costTracker: CostTracker = {
  totalCalls: 0,
  totalCostUSD: 0,
  lastResetTimestamp: Date.now(),
};

/**
 * Track an API call and estimate cost.
 */
export function trackAPICall(): void {
  costTracker.totalCalls++;
  costTracker.totalCostUSD += CATEGORIZATION_CONFIG.COST_PER_CALL_USD;

  // Log cost summary every 10 calls
  if (costTracker.totalCalls % 10 === 0) {
    const hoursSinceReset = (Date.now() - costTracker.lastResetTimestamp) / (1000 * 60 * 60);

    logger.info("Cost tracking summary", {
      totalCalls: costTracker.totalCalls,
      totalCostUSD: costTracker.totalCostUSD.toFixed(4),
      costPerCall: CATEGORIZATION_CONFIG.COST_PER_CALL_USD,
      hoursSinceReset: hoursSinceReset.toFixed(2),
      estimatedMonthlyCost: (
        (costTracker.totalCostUSD / hoursSinceReset) * 24 * 30
      ).toFixed(2),
    });
  }

  // Warn if approaching budget threshold ($10/month = $0.014/hour)
  const hoursSinceReset = (Date.now() - costTracker.lastResetTimestamp) / (1000 * 60 * 60);
  const costPerHour = costTracker.totalCostUSD / Math.max(hoursSinceReset, 0.1);

  if (costPerHour > 0.014) {
    logger.warn("⚠️ Cost per hour exceeds $10/month threshold", {
      costPerHour: costPerHour.toFixed(4),
      projectedMonthlyCost: (costPerHour * 24 * 30).toFixed(2),
    });
  }
}

/**
 * Reset cost tracking (for testing or periodic resets).
 */
export function resetCostTracking(): void {
  logger.info("Resetting cost tracking", {
    previousTotalCalls: costTracker.totalCalls,
    previousTotalCost: costTracker.totalCostUSD.toFixed(4),
  });

  costTracker.totalCalls = 0;
  costTracker.totalCostUSD = 0;
  costTracker.lastResetTimestamp = Date.now();
}

/**
 * Get current cost tracking statistics.
 */
export function getCostStats(): CostTracker {
  return {...costTracker};
}
