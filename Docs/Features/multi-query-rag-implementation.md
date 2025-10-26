# Multi-Query RAG Implementation

**Status**: ✅ Complete
**Date**: 2025-10-25

## Overview

Implemented multi-query expansion for RAG retrieval to support messages containing multiple distinct topics or questions. The system now generates up to 3 queries from a single message and retrieves relevant knowledge for ALL queries, then merges the results.

## What Changed

### Before
- **Single Query**: "I like dancing, do you have pets?" → 1 query: "User has pets"
- Retrieved only pet-related facts
- Missed information about dancing

### After
- **Multi-Query**: "I like dancing, do you have pets?" → 2 queries: ["User has pets", "User likes dancing"]
- Retrieves facts for BOTH topics
- Merges results using deduplication (keeps highest similarity score per fact)

## Implementation Details

### Files Modified

1. **`query-transformer.ts`**
   - Changed return type from `string` to `string[]`
   - Updated prompt to extract ALL distinct topics (max 3)
   - Returns 1-3 queries depending on message complexity
   - Added multi-query examples to prompt

2. **`knowledge-retriever.ts`**
   - Updated `searchKnowledgeWithScores()` to handle multiple queries internally
   - For each query:
     - Generates embedding
     - Searches against user's knowledge base
     - Collects results
   - Merges results using simple deduplication:
     - Same fact appearing in multiple queries → keep highest similarity
     - Sorts by similarity score (highest first)
     - Returns top K results

3. **No changes needed**:
   - `draft-prerequisites.ts` - Already compatible
   - `draft-generator.ts` - Already compatible
   - Multi-query logic is transparent to callers

### Merging Algorithm

**Simple Deduplication (Implemented)**:
```typescript
// Collect results from all queries
for each query:
  - Generate embedding
  - Search knowledge base
  - Collect results

// Deduplicate by fact.id (keep highest similarity)
const mergedResults = new Map<factId, {fact, similarity}>();
for each result:
  if (not in map OR higher similarity):
    mergedResults.set(factId, result)

// Sort by similarity and return top K
return sorted(mergedResults).slice(0, topK)
```

## Testing

### Test Scenarios

**Test 1: Multi-topic message**
```
Input: "I have 3 pets, do you like dancing?"
Expected: ["User has pets", "User likes dancing"]
Result: Retrieves facts about BOTH topics
```

**Test 2: Single topic**
```
Input: "Do you have any pets?"
Expected: ["User has pets"]
Result: Works same as before (backward compatible)
```

**Test 3: Context-aware multi-query**
```
Context: Alice says "I love salsa dancing"
Input: "wbu? do u have pets?"
Expected: ["User likes dancing", "User has pets"]
Result: Retrieves both dance facts AND pet facts
```

### Logging

Added comprehensive `testLog()` statements:
- Number of queries generated from message
- Each query's individual results
- Total results before merge
- Unique results after deduplication
- Final top K results with similarity scores

## Technical Notes

1. **Query Limit**: Maximum 3 queries to prevent over-generation
2. **Similarity Threshold**: Maintained at 0.45 (calibrated for text-embedding-3-small)
3. **Backward Compatible**: Single-topic messages work exactly as before
4. **Performance**: Slightly slower due to multiple embeddings, but retrieval is still fast (all queries search same snapshot)
5. **Error Handling**: Falls back to single query `[originalText]` on transformation errors

## Success Criteria

✅ Query transformer returns array of 1-3 queries (not just 1)
✅ Multi-query retrieval works and merges results correctly
✅ Deduplication ensures same fact not returned multiple times
✅ Ranking keeps most relevant facts at top
✅ Backward compatible - no caller updates needed
✅ No TypeScript errors after rebuild
✅ Added testLog() statements for debugging

## How to Test

1. **Start emulators** (if not running):
   ```bash
   cd /Users/Gauntlet/gauntlet/CreatorLink/firebase
   npm run emulators
   ```

2. **Seed test data** with multi-topic messages:
   ```bash
   cd /Users/Gauntlet/gauntlet/CreatorLink/emulator-seed
   node seed.js
   ```

3. **Send multi-topic messages** from the iOS app:
   - "I like dancing, do you have pets?"
   - "I have 3 dogs, what about you and what are your hobbies?"
   - "Do you like music and dancing?"

4. **Check logs** in Firebase Emulator UI:
   - Look for "🔄 QUERY TRANSFORMATION (Multi-Query)"
   - Should show 2-3 queries generated
   - Look for "🔍 MULTI-QUERY SEARCH: Complete"
   - Should show merged results

## Example Log Output

```
🔄 QUERY TRANSFORMATION (Multi-Query)
  original: "I like dancing, do you have pets?"
  queriesGenerated: 2
  queries: ["User has pets", "User likes dancing"]

🔍 MULTI-QUERY SEARCH: Starting
  queriesGenerated: 2
  queries: ["User has pets", "User likes dancing"]

📊 Query 1/2 results
  query: "User has pets"
  resultsFound: 3
  topResults: [{text: "User has a dog named Max", similarity: "0.847"}, ...]

📊 Query 2/2 results
  query: "User likes dancing"
  resultsFound: 2
  topResults: [{text: "User enjoys salsa dancing", similarity: "0.821"}, ...]

🔍 MULTI-QUERY SEARCH: Complete
  queriesProcessed: 2
  totalResultsBeforeMerge: 5
  uniqueResultsAfterMerge: 5
  finalTopK: 5
  topResults: [
    {text: "User has a dog named Max", similarity: "0.847"},
    {text: "User enjoys salsa dancing", similarity: "0.821"},
    ...
  ]
```

## Future Enhancements

If needed, could implement **Reciprocal Rank Fusion (RRF)** instead of simple deduplication:
```typescript
// RRF formula: score = Σ(1/(k + rank_i)) where k=60
// Gives better ranking when same fact appears in multiple query results
```

Currently using simple deduplication which is sufficient for most cases.
