/**
 * Draft Generator
 * Uses OpenAI GPT-4o to generate personalized response drafts combining
 * knowledge retrieval, voice profiles, and conversation context.
 */

import {getOpenAIClient} from "../client";
import {
  DraftGenerationResult,
  MessageDraft,
  ConversationCategory,
} from "../types";
import {ConversationMessage, fetchConversationMessages} from "./message-fetcher";
import {loadVoiceProfile} from "./voice-profile-loader";
import {searchKnowledgeWithScores} from "./knowledge-retriever";

/**
 * Generate a personalized draft response for a user.
 *
 * Combines:
 * - User's voice profile (communication style)
 * - Relevant knowledge facts (semantic search)
 * - Recent conversation context (continuity)
 *
 * @param userId - User ID to generate draft for (the person who will respond)
 * @param conversationId - Conversation ID
 * @param incomingMessages - Recent messages that triggered draft generation
 * @param category - Conversation category
 * @returns Promise with draft generation result
 */
export async function generateDraft(
  userId: string,
  conversationId: string,
  incomingMessages: ConversationMessage[],
  category: ConversationCategory
): Promise<DraftGenerationResult> {
  try {
    // Fetch voice profile for user + category
    const voiceProfile = await loadVoiceProfile(userId, category);
    if (!voiceProfile) {
      return {
        success: false,
        reason: "No voice profile available for user and category",
      };
    }

    // Fetch conversation history for context-aware query transformation
    const conversationHistory = await fetchConversationMessages(conversationId, 10);

    // Extract latest message(s) as the prompt to respond to
    const latestMessages = incomingMessages.slice(-2); // Last 2 messages
    const promptText = latestMessages
      .map(msg => msg.text)
      .join(" ");

    // Search knowledge base for relevant facts with conversation context
    // Note: Threshold 0.45 calibrated for text-embedding-3-small model
    const knowledgeResults = await searchKnowledgeWithScores(promptText, userId, 5, conversationHistory);
    const relevantKnowledge = knowledgeResults.filter(result => result.similarity > 0.45);

    // Build LLM prompt
    const openai = getOpenAIClient();

    // Build conversation context
    const contextMessages = conversationHistory
      .map(msg => `${msg.senderId}: ${msg.text}`)
      .join("\n");

    // Build knowledge context
    let knowledgeContext = "";
    if (relevantKnowledge.length > 0) {
      knowledgeContext = "\nRELEVANT KNOWLEDGE FACTS:\n" +
        relevantKnowledge
          .map((result, index) => `${index + 1}. ${result.fact.text} (relevance: ${result.similarity.toFixed(2)})`)
          .join("\n");
    } else {
      knowledgeContext = "\nRELEVANT KNOWLEDGE FACTS:\n(No knowledge facts available - do not make up specific details)";
    }

    // Build voice profile context
    const styleRulesText = JSON.stringify(voiceProfile.styleRules, null, 2);

    const systemPrompt = `You are a writing assistant helping a user draft a response in their authentic communication style.

USER'S VOICE PROFILE (${category} category):
${styleRulesText}

YOUR TASK:
1. Write a response that sounds EXACTLY like this user would write it
2. Match their tone, formality, word choice, emoji usage, and sentence structure
3. Use ONLY information from the "RELEVANT KNOWLEDGE FACTS" section (if provided)
4. Keep the response authentic and conversational
5. Return ONLY the draft text - no explanations or meta-commentary

CRITICAL RULES - NEVER BREAK THESE:
- ONLY use facts explicitly listed in "RELEVANT KNOWLEDGE FACTS" section
- DO NOT make up, invent, or fabricate ANY personal details (names, numbers, dates, etc.)
- DO NOT add specific information that isn't in the knowledge facts
- If no knowledge facts are provided, keep responses generic or acknowledge not having specific info
- If asked about something with no knowledge facts, respond naturally without making up details

STYLE MATCHING:
- The response should be written AS IF the user wrote it themselves
- Match their communication style precisely (formal/casual, brief/detailed, etc.)
- Use their typical phrases, greetings, and sign-offs
- Include emojis ONLY if their profile shows they use them
- Keep it natural - don't sound robotic or overly formal unless that's their style`;

    const userPrompt = `RECENT CONVERSATION CONTEXT:
${contextMessages}
${knowledgeContext}

INCOMING MESSAGE(S) TO RESPOND TO:
${latestMessages.map(msg => `${msg.senderId}: ${msg.text}`).join("\n")}

Write a response as the user (${userId}) would write it, using their voice profile style.`;

    const completion = await openai.chat.completions.create({
      model: "gpt-5-mini",
      messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: userPrompt},
      ],
      reasoning_effort: "minimal",
      // max_completion_tokens: 300, // Reasonable response length
    });

    const draftText = completion.choices[0]?.message?.content;

    if (!draftText) {
      return {
        success: false,
        reason: "Empty response from AI model",
      };
    }

    // Create MessageDraft object
    const now = new Date();
    const draft: MessageDraft = {
      conversationId,
      userId,
      text: draftText.trim(),
      category,
      generatedAt: now,
      updatedAt: now,
    };

    return {
      success: true,
      draft,
      reason: "Draft generated successfully",
    };

  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
      reason: "Draft generation failed with error",
    };
  }
}
