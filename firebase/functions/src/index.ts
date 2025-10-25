/**
 * CreatorLink AI Messaging Service - Cloud Functions
 *
 * This function triggers when new messages are created in Firestore.
 * Detects if messages in group chats are questions that need AI responses.
 */

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {detectIfQuestion} from "./ai";
import {fetchConversationMessages} from "./ai/lib/message-fetcher";
import {findFAQMatch} from "./ai/lib/faq-matcher";
import {writeAIResponse} from "./ai/lib/response-writer";
import {
  categorizeConversation,
  fetchConversationContext,
  shouldAnalyzeMessage,
  updateConversationTags,
  extractKnowledge,
  storeKnowledgeFact,
} from "./ai";

// Initialize Firebase Admin SDK
admin.initializeApp();

// AI user constant - must match AIConstants.swift in iOS app
const AI_USER_ID = "ai-assistant";

/**
 * Triggered when a new message is created in Firestore
 * Detects if the message is from a group chat and if it's a question
 */
export const onMessageCreated = onDocumentCreated(
  "messages/{messageId}",
  async (event) => {
    const messageId = event.params.messageId;
    const messageData = event.data?.data();

    // Skip processing if this is an AI-generated message to prevent infinite loops
    if (messageData?.senderId === AI_USER_ID) {
      logger.info("Skipping AI-generated message", {
        messageId,
        senderId: messageData.senderId,
      });
      return null;
    }

    // Log incoming message
    logger.info("Message received:", {
      messageId,
      senderId: messageData?.senderId,
      text: messageData?.text,
      conversationId: messageData?.conversationId,
    });

    // Extract common message data
    const participantIds = messageData?.participantIds || [];
    const conversationId = messageData?.conversationId || "";
    const messageText = messageData?.text || "";
    const isGroupChat = participantIds.length > 2;

    // FEATURE 1: Group Chat FAQ Detection (only for group chats with AI enabled)
    if (isGroupChat) {
      logger.info("Group chat message detected, checking if it's a question", {
        messageId,
        conversationId,
        participantCount: participantIds.length,
      });

      // Detect if the message is a question
      if (!messageText.trim()) {
        logger.info("Empty message text, skipping question detection", {
          messageId,
        });
      } else {
        const questionResult = await detectIfQuestion(messageText);

        logger.info("Question detection result", {
          messageId,
          conversationId,
          isQuestion: questionResult.isQuestion,
          confidence: questionResult.confidence,
          messageText: messageText.substring(0, 100), // Log first 100 chars
        });

        if (questionResult.isQuestion) {
          logger.info("✅ Group chat QUESTION detected", {
            messageId,
            conversationId,
            confidence: questionResult.confidence,
            messagePreview: messageText.substring(0, 50),
          });

          // Check if AI is enabled (AI assistant must be a participant)
          const isAIEnabled = participantIds.includes(AI_USER_ID);

          if (!isAIEnabled) {
            logger.info("AI not enabled for this conversation, skipping FAQ detection", {
              messageId,
              conversationId,
            });
          } else {
            logger.info("AI enabled, processing question for FAQ detection", {
              messageId,
              conversationId,
            });

            try {
              // Fetch all conversation messages
              const allMessages = await fetchConversationMessages(
                conversationId,
                100
              );

              if (allMessages.length === 0) {
                logger.info("No conversation history found, skipping FAQ detection", {
                  conversationId,
                  messageId,
                });
              } else {
                // Find current message index
                const currentMessageIndex = allMessages.findIndex(msg => msg.id === messageId);

                if (currentMessageIndex === -1) {
                  logger.warn("Current message not found in conversation history", {
                    conversationId,
                    messageId,
                  });
                } else {
                  // Split messages into before and after current question
                  const previousMessages = allMessages.slice(0, currentMessageIndex);
                  const followingMessages = allMessages.slice(currentMessageIndex + 1);

                  if (previousMessages.length === 0) {
                    logger.info("No previous messages, skipping FAQ detection", {
                      conversationId,
                      messageId,
                    });
                  } else {
                    // Let AI analyze with separate before/after contexts
                    const faqMatch = await findFAQMatch(
                      messageText,
                      previousMessages,
                      followingMessages,
                      0.85
                    );

                    if (!faqMatch.hasMatch) {
                      logger.info("No FAQ match found", {
                        conversationId,
                        messageId,
                        confidence: faqMatch.confidence,
                      });
                    } else {
                      logger.info("✅ FAQ match found! Writing AI response", {
                        conversationId,
                        messageId,
                        confidence: faqMatch.confidence,
                        matchedQuestionId: faqMatch.matchedQuestionMessageId,
                        matchedAnswerId: faqMatch.matchedAnswerMessageId,
                      });

                      // Write AI response
                      const writeResult = await writeAIResponse(
                        conversationId,
                        participantIds,
                        faqMatch
                      );

                      if (writeResult.success) {
                        logger.info("🎉 AI response written successfully", {
                          conversationId,
                          aiMessageId: writeResult.messageId,
                        });
                      } else {
                        logger.error("Failed to write AI response", {
                          conversationId,
                          error: writeResult.error,
                        });
                      }
                    }
                  }
                }
              }
            } catch (error) {
              logger.error("Error processing FAQ detection", {
                conversationId,
                messageId,
                error: error instanceof Error ? error.message : String(error),
              });
            }
          }
        } else {
          logger.info("ℹ️ Group chat message is NOT a question", {
            messageId,
            conversationId,
            confidence: questionResult.confidence,
          });
        }
      }
    } else {
      logger.info("Not a group chat, skipping FAQ detection", {
        messageId,
        conversationId,
        participantCount: participantIds.length,
      });
    }

    // PHASE 5: AI Auto-Tagging - Categorize all conversations (not just group chats)
    // This runs independently of FAQ detection and question checking
    try {
      // Check feature flag (default enabled)
      const categorizationEnabled = process.env.ENABLE_AUTO_CATEGORIZATION !== "false";

      if (!categorizationEnabled) {
        logger.info("Auto-categorization disabled by feature flag", {
          conversationId,
        });
        return null;
      }

      // Check if this message should be analyzed
      const shouldAnalyze = await shouldAnalyzeMessage(messageData, conversationId);

      if (!shouldAnalyze) {
        logger.info("Skipping categorization based on analysis rules", {
          conversationId,
          messageId,
        });
        return null;
      }

      logger.info("Starting conversation categorization", {
        conversationId,
        messageId,
      });

      // Fetch conversation context (last 10 messages)
      const conversationContext = await fetchConversationContext(conversationId, 10);

      if (conversationContext.length === 0) {
        logger.info("No conversation context found, skipping categorization", {
          conversationId,
        });
        return null;
      }

      // Fetch existing category and tags from conversation document
      const conversationDoc = await admin.firestore()
        .collection("conversations")
        .doc(conversationId)
        .get();

      const existingCategory = conversationDoc.data()?.primaryCategory;
      const existingTagsByUser = conversationDoc.data()?.tagsByUser;

      // Categorize the conversation
      // Pass participant info so AI can assign per-user status tags
      const categorizationResult = await categorizeConversation(
        messageText,
        conversationContext,
        existingCategory,
        conversationId,
        participantIds,
        messageData?.senderId,
        existingTagsByUser
      );

      logger.info("Categorization result", {
        conversationId,
        category: categorizationResult.category.category,
        confidence: categorizationResult.category.confidence,
        statusTagsByUser: categorizationResult.status.statusTagsByUser,
      });

      // Update conversation tags in Firestore
      // Pass message sender and participants for per-user status tags
      const updateSuccess = await updateConversationTags(
        conversationId,
        categorizationResult,
        messageData?.senderId,
        participantIds
      );

      if (updateSuccess) {
        logger.info("✅ Conversation tags updated successfully", {
          conversationId,
          category: categorizationResult.category.category,
          statusTagsByUser: categorizationResult.status.statusTagsByUser,
          lastMessageSender: messageData?.senderId,
        });
      } else {
        logger.info("Tag update skipped (low confidence or other reason)", {
          conversationId,
          confidence: categorizationResult.category.confidence,
        });
      }

    } catch (error) {
      logger.error("Error during conversation categorization", {
        conversationId,
        messageId,
        error: error instanceof Error ? error.message : String(error),
      });
      // Don't throw - categorization errors shouldn't fail the entire function
    }

    // PHASE 1: Knowledge Extraction - Extract facts from user messages
    try {
      // Check feature flag (default enabled)
      const knowledgeExtractionEnabled = process.env.ENABLE_KNOWLEDGE_EXTRACTION !== "false";

      if (!knowledgeExtractionEnabled) {
        logger.info("Knowledge extraction disabled by feature flag", {
          conversationId,
        });
        return null;
      }

      // Skip if message from AI user
      if (messageData?.senderId === AI_USER_ID) {
        logger.info("Skipping knowledge extraction for AI message", {
          messageId,
        });
        return null;
      }

      // Skip if message from system
      if (messageData?.senderId === "system") {
        logger.info("Skipping knowledge extraction for system message", {
          messageId,
        });
        return null;
      }

      // Skip if message is a question (we want statements with facts)
      if (messageText.trim()) {
        const questionResult = await detectIfQuestion(messageText);
        if (questionResult.isQuestion) {
          logger.info("Skipping knowledge extraction for question", {
            messageId,
            confidence: questionResult.confidence,
          });
          return null;
        }
      }

      logger.info("Starting knowledge extraction", {
        conversationId,
        messageId,
        senderId: messageData?.senderId,
      });

      // Fetch last 5 messages for context
      const recentMessages = await fetchConversationMessages(conversationId, 5);

      if (recentMessages.length === 0) {
        logger.info("No conversation history for context, skipping knowledge extraction", {
          conversationId,
        });
        return null;
      }

      // Extract knowledge from message with context
      const extractionResult = await extractKnowledge(
        messageText,
        recentMessages,
        messageData?.senderId
      );

      if (!extractionResult.success) {
        logger.warn("Knowledge extraction failed", {
          conversationId,
          messageId,
          error: extractionResult.error,
        });
        return null;
      }

      if (extractionResult.facts.length === 0) {
        logger.info("No facts extracted from message", {
          conversationId,
          messageId,
        });
        return null;
      }

      logger.info("Facts extracted, storing to Firestore", {
        conversationId,
        messageId,
        factCount: extractionResult.facts.length,
      });

      // Store each extracted fact
      let storedCount = 0;
      let skippedCount = 0;

      for (const fact of extractionResult.facts) {
        try {
          const factId = await storeKnowledgeFact(fact);

          if (factId) {
            storedCount++;
            logger.info("Fact stored", {
              factId,
              text: fact.text,
            });
          } else {
            skippedCount++;
            logger.info("Fact skipped (duplicate)", {
              text: fact.text,
            });
          }
        } catch (error) {
          logger.error("Failed to store fact", {
            text: fact.text,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }

      logger.info("✅ Knowledge extraction complete", {
        conversationId,
        messageId,
        extracted: extractionResult.facts.length,
        stored: storedCount,
        skipped: skippedCount,
      });

    } catch (error) {
      logger.error("Error during knowledge extraction", {
        conversationId,
        messageId,
        error: error instanceof Error ? error.message : String(error),
      });
      // Don't throw - knowledge extraction errors shouldn't fail the entire function
    }

    return null;
  }
);
