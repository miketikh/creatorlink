/**
 * AI Categorization Seed File
 *
 * Creates test data specifically for AI message categorization.
 * - 4 conversations TO Alice (one for each category type)
 * - 1 conversation between Alice and Bob (Alice initiates, Bob needs to respond)
 *
 * NO categories are pre-assigned - the AI should detect and assign them based on message content.
 *
 * Expected categories:
 * - Business
 * - Collaboration
 * - Social
 * - Fan
 */

const admin = require('firebase-admin');
const {
  ALL_USERS,
  DEFAULT_PASSWORD
} = require('../constants');
const {
  createAuthUsers,
  createUserProfiles,
  getTimestamp
} = require('../utils');

/**
 * Create a specific message in Firestore
 */
async function createMessage(db, conversationId, senderId, text, participantIds, minutesAgo = 0) {
  const messageId = db.collection('messages').doc().id;
  const timestamp = getTimestamp(0, 0, minutesAgo);

  // Create readBy map - only sender has read it initially
  const readBy = {};
  readBy[senderId] = timestamp;

  const messageData = {
    conversationId,
    senderId,
    text,
    timestamp,
    status: 'delivered',
    participantIds,
    readBy,
    imageUrl: null,
    metadata: null
  };

  await db.collection('messages').doc(messageId).set(messageData);

  return {
    text,
    timestamp,
    senderId,
    status: 'delivered'
  };
}

/**
 * Create a conversation with specific messages for categorization testing
 * NO categories are pre-assigned - let the AI detect them
 */
async function createCategorizationConversation(
  db,
  participantIds,
  messages
) {
  const conversationId = db.collection('conversations').doc().id;
  const sortedParticipantIds = [...participantIds].sort();

  // Create all messages
  let lastMessageData = null;
  for (let i = messages.length - 1; i >= 0; i--) {
    const msg = messages[i];
    const minutesAgo = (messages.length - 1 - i) * 5; // Space messages 5 minutes apart
    lastMessageData = await createMessage(
      db,
      conversationId,
      msg.senderId,
      msg.text,
      sortedParticipantIds,
      minutesAgo
    );
  }

  // Prepare conversation data - NO category fields
  const conversationData = {
    participantIds: sortedParticipantIds,
    isGroupChat: false,
    lastMessageTime: lastMessageData.timestamp,
    lastMessage: lastMessageData.text,
    lastMessageSenderId: lastMessageData.senderId,
    lastMessageStatus: lastMessageData.status,
    unreadCounts: {},
    mutedBy: null,
    groupName: null,
    groupImageUrl: null
  };

  // Set unread counts
  sortedParticipantIds.forEach(id => {
    if (id === lastMessageData.senderId) {
      conversationData.unreadCounts[id] = 0; // Sender has read their own message
    } else {
      conversationData.unreadCounts[id] = 1; // Recipient hasn't read it yet
    }
  });

  await db.collection('conversations').doc(conversationId).set(conversationData);

  return conversationId;
}

async function seedAICategorization(auth, db) {
  console.log('🤖 Starting AI Categorization seed process...\n');

  // Step 1: Create auth users and get UIDs
  const userIds = await createAuthUsers(auth, ALL_USERS, DEFAULT_PASSWORD);

  // Step 2: Create Firestore user profiles
  await createUserProfiles(db, ALL_USERS, userIds);

  // Map users for easy reference
  const [alice, bob, carol, david, emma, frank] = userIds;

  console.log('💬 Creating categorization test conversations...\n');

  // Conversation 1: Carol → Alice (Should detect: BUSINESS)
  await createCategorizationConversation(
    db,
    [alice, carol],
    [
      {
        senderId: carol,
        text: "Hi Alice! I'm reaching out regarding a potential business partnership. I've been following your work and think there's a great opportunity for us to collaborate on a project. Would you be available for a call this week to discuss revenue sharing and terms?"
      }
    ]
  );
  console.log('  ✓ Carol → Alice: Business inquiry (should detect: business)');

  // Conversation 2: David → Alice (Should detect: COLLABORATION)
  await createCategorizationConversation(
    db,
    [alice, david],
    [
      {
        senderId: david,
        text: "Hey Alice! I'm working on a new creative project and I think your expertise would be perfect for it. Would you be interested in collaborating? I'd love to hear your thoughts and see if we can work together on this!"
      }
    ]
  );
  console.log('  ✓ David → Alice: Collaboration proposal (should detect: collaboration)');

  // Conversation 3: Emma → Alice (Should detect: SOCIAL)
  await createCategorizationConversation(
    db,
    [alice, emma],
    [
      {
        senderId: emma,
        text: "Hey! How's it going? Long time no see! We should catch up sometime soon. How have you been?"
      }
    ]
  );
  console.log('  ✓ Emma → Alice: Social chat (should detect: social)');

  // Conversation 4: Frank → Alice (Should detect: FAN)
  await createCategorizationConversation(
    db,
    [alice, frank],
    [
      {
        senderId: frank,
        text: "Hi Alice! I'm a huge fan of your work. I've been following you for a while and your content has really inspired me. Just wanted to reach out and say thank you for everything you create!"
      }
    ]
  );
  console.log('  ✓ Frank → Alice: Fan message (should detect: fan)');

  // Conversation 5: Alice → Bob (Should detect: SOCIAL + needsResponse for Bob)
  await createCategorizationConversation(
    db,
    [alice, bob],
    [
      {
        senderId: alice,
        text: "What are you doing today?"
      }
    ]
  );
  console.log('  ✓ Alice → Bob: Needs response (should detect: social)');

  console.log('\n✅ Created 5 conversations for AI categorization testing\n');
  console.log('📊 Expected category detection:');
  console.log('  • Business: 1 conversation (Carol → Alice)');
  console.log('  • Collaboration: 1 conversation (David → Alice)');
  console.log('  • Social: 2 conversations (Emma → Alice, Alice → Bob)');
  console.log('  • Fan: 1 conversation (Frank → Alice)\n');
  console.log('🎯 Test plan:');
  console.log('  1. Log in as Alice (alice.johnson@test.com / password)');
  console.log('  2. AI should process incoming messages and assign categories');
  console.log('  3. Check if categories appear correctly in the inbox');
  console.log('  4. Bob should see "needsResponse" for Alice → Bob conversation\n');
  console.log('🎉 AI Categorization seed complete!\n');
}

module.exports = seedAICategorization;
