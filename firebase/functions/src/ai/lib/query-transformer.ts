/**
 * Query Transformation for Knowledge Retrieval
 *
 * PURPOSE: Transform questions into normalized fact format for semantic search against the RECIPIENT's knowledge base.
 *
 * IMPORTANT DISTINCTION:
 * - This is NOT for extracting facts about the sender
 * - This is ONLY for transforming questions to retrieve facts about the RECIPIENT
 *
 * Example Scenario:
 * - Bob asks Alice: "I have three dogs, what about you?"
 * - Knowledge extraction (separate process) stores about BOB: "User has three dogs"
 * - Query transformation (THIS function) transforms to search ALICE's facts: "User has pets"
 *
 * Another Example:
 * - Bob asks Alice: "Do you have any pets?"
 * - Query transformation: "User has pets" (to search Alice's knowledge base)
 *
 * The transformation uses the same normalization format as knowledge extraction:
 * - Use "User" as subject (represents the recipient being queried)
 * - Remove pronouns, use third person
 * - Present tense
 * - Concise and factual
 */

import {getOpenAIClient} from "../client";
import {testLog} from "./test-logger";
import {ConversationMessage} from "./message-fetcher";

/**
 * Transform a question into normalized fact format for semantic search.
 *
 * This function focuses ONLY on the question being asked ABOUT the recipient.
 * It ignores any sender context and transforms the query to match how facts
 * are stored in the recipient's knowledge base.
 *
 * Uses conversation history to understand ambiguous queries like "u?", "wbu?", etc.
 *
 * MULTI-QUERY SUPPORT:
 * Returns 1-3 queries to support multi-topic messages like:
 * - "I like dancing, do you have pets?" → ["User has pets", "User likes dancing"]
 * - "Do you have pets?" → ["User has pets"]
 *
 * @param queryText - The original question/query from the sender
 * @param conversationHistory - Recent conversation messages for context (default: empty)
 * @returns Array of 1-3 normalized queries in "User..." format to search recipient's facts
 */
export async function transformQuery(
  queryText: string,
  conversationHistory: ConversationMessage[] = []
): Promise<string[]> {
  try {
    const openai = getOpenAIClient();

    // Build conversation context if available
    let conversationContext = "";
    if (conversationHistory.length > 0) {
      const recentMessages = conversationHistory.slice(-5); // Last 5 messages
      conversationContext = "\nRECENT CONVERSATION CONTEXT:\n" +
        recentMessages.map(msg => `${msg.senderId}: ${msg.text}`).join("\n") + "\n";
    }

    const systemPrompt = `You are a query transformation assistant for knowledge retrieval.

YOUR PURPOSE:
Transform questions into normalized fact format to search the RECIPIENT's knowledge base.
Focus ONLY on what information is being requested ABOUT the recipient.

**MULTI-QUERY SUPPORT:**
Extract ALL distinct topics or questions from the message. Return 1-3 queries maximum.
- If message asks about ONE topic: return 1 query
- If message asks about MULTIPLE topics: return 2-3 queries (one per topic)
- DO NOT create more than 3 queries

**IMPORTANT - USE CONTEXT FOR AMBIGUOUS QUERIES:**
When the query is ambiguous (like "u?", "wbu?", "you too?", "?"), use the conversation context to understand what topic is being discussed.

REASONING PROCESS:
1. Look at the conversation context to identify the current topic
2. Identify ALL distinct questions/topics in the latest message about the recipient
3. Format each as a separate query (max 3)

MULTI-QUERY EXAMPLES:

Input: "I like dancing, do you have pets?"
Output: ["User has pets", "User likes dancing"]
(Two distinct topics: pets and dancing)

Input: "I have 3 dogs and a cat, do you like pets and what are your hobbies?"
Output: ["User has pets", "User likes animals", "User's hobbies"]
(Three topics: pets, animals, hobbies - max 3 reached)

Input: "Do you have pets?"
Output: ["User has pets"]
(Single topic)

Input: "Do you have any pets? What kind?"
Output: ["User has pets"]
(Same topic asked twice - combine into one query)

EXAMPLES WITH CONTEXT:

Context:
  Alice: I love salsa dancing
  Bob: That's cool!
Latest: "wbu?"
Reasoning: Context is about dancing/salsa. "wbu?" means "what about you?" asking if user likes dancing.
Output: ["User likes dancing"]

Context:
  Alice: I have three pets
  Bob: Nice!
Latest: "u?"
Reasoning: Context is about pets. "u?" means "you?" asking if user has pets.
Output: ["User has pets"]

Context:
  Alice: I'm going to a play tonight
  Bob: Cool
Latest: "You have plans too?"
Reasoning: Context is about evening plans. Asking if user has plans for tonight.
Output: ["User has plans tonight"]

EXAMPLES WITHOUT CONTEXT:

Input: "I have three dogs, what about you?"
Output: ["User has pets"]
(Ignore sender's "I have three dogs", focus on question "what about you?")

Input: "I'm staying in tonight, do you have any plans?"
Output: ["User has plans tonight"]
(Ignore sender's "I'm staying in", focus on question about recipient's plans)

FORMATTING RULES (match knowledge storage format):
- Use "User" as subject (represents the recipient being searched)
- Convert questions to statement form
- Remove pronouns, use third person
- Use present tense
- Be concise and factual
- Each query should focus on ONE distinct piece of information

KEY PRINCIPLES:
1. Extract ALL distinct topics/questions from the message
2. Maximum 3 queries - prioritize the most important topics if there are more
3. Each query should be focused and self-contained
4. Use context to resolve ambiguity

Respond with JSON only: {"queries": ["query1", "query2", "query3"]}`;

    const userPrompt = `${conversationContext}
LATEST MESSAGE TO TRANSFORM:
${queryText}

Transform the latest message into queries to search the recipient's knowledge base. Extract ALL distinct topics (max 3). Use the conversation context if the message is ambiguous.`;

    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: userPrompt},
      ],
      response_format: {type: "json_object"},
      temperature: 0.3,
      max_tokens: 150, // Increased for multiple queries
    });

    const responseContent = completion.choices[0]?.message?.content;

    if (!responseContent) {
      // Fallback: return original query in array if transformation fails
      testLog("⚠️ QUERY TRANSFORMATION: Failed to transform, using original", {
        originalQuery: queryText,
      });
      return [queryText];
    }

    const parsed = JSON.parse(responseContent) as {queries: string[]};
    const transformedQueries = parsed.queries && parsed.queries.length > 0
      ? parsed.queries.slice(0, 3) // Ensure max 3 queries
      : [queryText]; // Fallback to original

    testLog("🔄 QUERY TRANSFORMATION (Multi-Query)", {
      original: queryText,
      queriesGenerated: transformedQueries.length,
      queries: transformedQueries,
    });

    return transformedQueries;

  } catch (error) {
    // Fallback: return original query in array on error
    testLog("❌ QUERY TRANSFORMATION: Error occurred, using original query", {
      originalQuery: queryText,
      error: error instanceof Error ? error.message : String(error),
    });
    return [queryText];
  }
}
