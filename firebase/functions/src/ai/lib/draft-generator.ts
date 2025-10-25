/**
 * Draft Generator
 * Uses OpenAI GPT-4o to generate personalized response drafts combining
 * knowledge retrieval, voice profiles, and conversation context.
 */

import * as logger from "firebase-functions/logger";
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
  const startTime = Date.now();

  try {
    logger.info("Starting draft generation", {
      userId,
      conversationId,
      category,
      incomingMessageCount: incomingMessages.length,
    });

    // Fetch voice profile for user + category
    const voiceProfile = await loadVoiceProfile(userId, category);
    if (!voiceProfile) {
      logger.warn("Cannot generate draft: no voice profile", {
        userId,
        category,
      });
      return {
        success: false,
        reason: "No voice profile available for user and category",
      };
    }

    // Extract latest message(s) as the prompt to respond to
    const latestMessages = incomingMessages.slice(-2); // Last 2 messages
    const promptText = latestMessages
      .map(msg => msg.text)
      .join(" ");

    // Search knowledge base for relevant facts
    const knowledgeResults = await searchKnowledgeWithScores(promptText, userId, 5);
    const relevantKnowledge = knowledgeResults.filter(result => result.similarity > 0.7);

    // Fetch last 10 messages for conversation context
    const conversationHistory = await fetchConversationMessages(conversationId, 10);

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
    }

    // Build voice profile context
    const styleRulesText = JSON.stringify(voiceProfile.styleRules, null, 2);

    const systemPrompt = `You are a writing assistant helping a user draft a response in their authentic communication style.

USER'S VOICE PROFILE (${category} category):
${styleRulesText}

YOUR TASK:
1. Write a response that sounds EXACTLY like this user would write it
2. Match their tone, formality, word choice, emoji usage, and sentence structure
3. Incorporate relevant knowledge facts naturally (if provided)
4. Keep the response authentic and conversational
5. Return ONLY the draft text - no explanations or meta-commentary

IMPORTANT:
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

    logger.info("Calling OpenAI for draft generation", {
      userId,
      conversationId,
      model: "gpt-4o",
      knowledgeFactsCount: relevantKnowledge.length,
      contextMessagesCount: conversationHistory.length,
    });

    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: userPrompt},
      ],
      temperature: 0.7, // Creative but consistent
      max_tokens: 300, // Reasonable response length
    });

    const draftText = completion.choices[0]?.message?.content;

    if (!draftText) {
      logger.warn("Empty response from OpenAI draft generation");
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

    const duration = Date.now() - startTime;
    logger.info("Draft generation complete", {
      userId,
      conversationId,
      draftLength: draftText.length,
      knowledgeFactsFound: relevantKnowledge.length,
      durationMs: duration,
    });

    return {
      success: true,
      draft,
      reason: "Draft generated successfully",
    };

  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Draft generation failed", {
      userId,
      conversationId,
      category,
      error: error instanceof Error ? error.message : String(error),
      durationMs: duration,
    });

    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
      reason: "Draft generation failed with error",
    };
  }
}
