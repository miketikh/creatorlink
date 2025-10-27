/**
 * Complete Seed File - Enhanced with Voice Profiles
 *
 * Creates realistic multi-turn conversations with authentic messaging styles.
 * - 5 conversations featuring Alice (business, collaboration, 2x social, fan)
 * - Multi-turn exchanges that feel natural and realistic
 *
 * Voice profiles are applied where available:
 * - Alice: business, collaboration, social
 * - Bob: social
 * - David: collaboration
 *
 * Categories and statusTags ARE pre-assigned for demonstration and filter functionality.
 *
 * Conversations:
 * - Business: Carol ↔ Alice (brand partnership, 3 messages)
 * - Collaboration: David ↔ Alice (creative project, 3 messages)
 * - Social: Alice ↔ Bob (casual hangout, 6 messages)
 * - Social: Emma ↔ Alice (catching up, 3 messages)
 * - Fan: Frank → Alice (fan appreciation, 1 message)
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
async function createMessage(db, conversationId, senderId, text, participantIds, minutesAgo = 0, participantsWhoHaveRead = []) {
  const messageId = db.collection('messages').doc().id;
  const timestamp = getTimestamp(0, 0, minutesAgo);

  // Create readBy map - includes sender and anyone who has sent messages before this
  const readBy = {};
  participantsWhoHaveRead.forEach(id => {
    readBy[id] = timestamp;
  });
  // Always include the current sender
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
 * Create a conversation with specific messages and tags for categorization testing
 * Categories and statusTags ARE pre-assigned for demonstration and filter functionality
 */
async function createCategorizationConversation(
  db,
  participantIds,
  messages,
  tagsByUser = {},
  primaryCategory = null,
  lastMessageMinutesAgo = 0
) {
  const conversationId = db.collection('conversations').doc().id;
  const sortedParticipantIds = [...participantIds].sort();

  // First pass: determine who has sent messages (they've read everything up to their last message)
  const participantLastMessageIndex = {};
  messages.forEach((msg, index) => {
    participantLastMessageIndex[msg.senderId] = index;
  });

  // Create all messages from oldest to newest
  let lastMessageData = null;
  const createdMessages = [];

  for (let i = 0; i < messages.length; i++) {
    const msg = messages[i];
    const minutesAgo = lastMessageMinutesAgo + (messages.length - 1 - i) * 5; // Space messages 5 minutes apart, offset by lastMessageMinutesAgo

    // Determine who has read this message:
    // Anyone who sends a message at or after this point has read this message
    const participantsWhoHaveRead = sortedParticipantIds.filter(participantId => {
      return participantLastMessageIndex[participantId] >= i;
    });

    const messageData = await createMessage(
      db,
      conversationId,
      msg.senderId,
      msg.text,
      sortedParticipantIds,
      minutesAgo,
      participantsWhoHaveRead.filter(id => id !== msg.senderId) // Exclude sender, they're added separately
    );

    createdMessages.push(messageData);
  }

  // Last message is the most recent one (last in array)
  lastMessageData = createdMessages[createdMessages.length - 1];

  // Prepare conversation data with category and status tags
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
    groupImageUrl: null,
    tagsByUser: tagsByUser
  };

  // Add conversation-level category fields if provided
  if (primaryCategory) {
    conversationData.primaryCategory = primaryCategory;
    conversationData.categoryTags = [primaryCategory];
  }

  // Set unread counts based on last participation
  sortedParticipantIds.forEach(id => {
    const lastParticipationIndex = participantLastMessageIndex[id];
    if (lastParticipationIndex !== undefined) {
      // Count messages sent after this participant's last message
      const unreadCount = messages.length - 1 - lastParticipationIndex;
      conversationData.unreadCounts[id] = unreadCount;
    } else {
      // Participant hasn't sent any messages, so all messages are unread
      conversationData.unreadCounts[id] = messages.length;
    }
  });

  await db.collection('conversations').doc(conversationId).set(conversationData);

  return conversationId;
}

async function seedCompleteSeed(auth, db) {
  console.log('🤖 Starting Enhanced AI Categorization seed process...\n');

  // Step 1: Create auth users and get UIDs
  const userIds = await createAuthUsers(auth, ALL_USERS, DEFAULT_PASSWORD);

  // Step 2: Create Firestore user profiles
  await createUserProfiles(db, ALL_USERS, userIds);

  // Map users for easy reference
  const [alice, bob, carol, david, emma, frank] = userIds;

  console.log('💬 Creating enhanced categorization test conversations...\n');

  // Conversation 1: Carol → Alice → Carol (Should detect: BUSINESS)
  // Carol reaches out about brand partnership, Alice responds professionally, Carol confirms
  await createCategorizationConversation(
    db,
    [alice, carol],
    [
      {
        senderId: carol,
        text: "Hi Alice! I'm reaching out from Luminex Beauty regarding a potential brand partnership. We've been following your work and think your aesthetic would be a perfect fit for our new product line. Would you be available for a quick call this week to discuss collaboration opportunities and compensation details?"
      },
      {
        senderId: alice,
        text: "Hi Carol! Thank you for reaching out. This sounds like a great opportunity and I'd definitely be interested in learning more about the partnership. I'm available Thursday or Friday afternoon if either of those work for your team. Looking forward to connecting!"
      },
      {
        senderId: carol,
        text: "Perfect! Thursday at 2pm works great. I'll send over a calendar invite with the Zoom link and some materials to review beforehand. Really excited about this!"
      }
    ],
    {
      [alice]: {
        categoryTags: ['business'],
        statusTags: ['needsResponse', 'urgent']
      },
      [carol]: {
        categoryTags: ['business'],
        statusTags: ['awaitingReply', 'urgent']
      }
    },
    'business',
    7 // Last message 7 minutes ago
  );
  console.log('  ✓ Carol ↔ Alice: Business partnership (3 messages, should detect: business, urgent)');

  // Conversation 2: David → Alice → David (Should detect: COLLABORATION)
  // David pitches creative project, Alice enthusiastically responds, David shares next steps
  await createCategorizationConversation(
    db,
    [alice, david],
    [
      {
        senderId: david,
        text: "Hey Alice! I'm working on a new photography series about urban architecture and I think your creative eye would be perfect for it. I'm envisioning something really unique - mixing street photography with architectural details. What do you think? Would love to collaborate on this!"
      },
      {
        senderId: alice,
        text: "Hey! Love this idea! 🎉 The urban architecture angle sounds really cool. I'm totally down to collaborate. Let me know what you're thinking for timeline and I can share some initial concepts. Excited about this!"
      },
      {
        senderId: david,
        text: "Awesome! I'm thinking we could start scouting locations next week. I'll put together a mood board and share it with you. This is going to be 🔥"
      }
    ],
    {
      [alice]: {
        categoryTags: ['collaboration'],
        statusTags: ['needsResponse']
      },
      [david]: {
        categoryTags: ['collaboration'],
        statusTags: ['awaitingReply']
      }
    },
    'collaboration',
    6 // Last message 6 minutes ago
  );
  console.log('  ✓ David ↔ Alice: Creative collaboration (3 messages, should detect: collaboration)');

  // Conversation 3: Alice → Bob → Alice (Should detect: SOCIAL)
  // Alice casually asks what Bob's up to, Bob responds laid-back, Alice continues
  await createCategorizationConversation(
    db,
    [alice, bob],
    [
      {
        senderId: alice,
        text: "hey"
      },
      {
        senderId: alice,
        text: "what are you doing today"
      },
      {
        senderId: bob,
        text: "yo not much just chilling"
      },
      {
        senderId: bob,
        text: "was thinking about grabbing food later"
      },
      {
        senderId: alice,
        text: "ooh sounds good"
      },
      {
        senderId: alice,
        text: "where u thinking"
      }
    ],
    {
      [alice]: {
        categoryTags: ['social'],
        statusTags: ['awaitingReply']
      },
      [bob]: {
        categoryTags: ['social'],
        statusTags: ['needsResponse']
      }
    },
    'social',
    4 // Last message 4 minutes ago
  );
  console.log('  ✓ Alice ↔ Bob: Casual hangout plans (6 messages, should detect: social)');

  // Conversation 4: Emma → Alice (Should detect: SOCIAL)
  // Emma reaches out to catch up, Alice responds warmly
  await createCategorizationConversation(
    db,
    [alice, emma],
    [
      {
        senderId: emma,
        text: "Hey! How's it going? Long time no see! We should totally catch up soon. How have you been?"
      },
      {
        senderId: alice,
        text: "hey!! i know it's been forever 😊"
      },
      {
        senderId: alice,
        text: "i've been good! how are you?"
      }
    ],
    {
      [alice]: {
        categoryTags: ['social'],
        statusTags: ['awaitingReply']
      },
      [emma]: {
        categoryTags: ['social'],
        statusTags: ['needsResponse']
      }
    },
    'social',
    3 // Last message 3 minutes ago
  );
  console.log('  ✓ Emma ↔ Alice: Catching up (3 messages, should detect: social)');

  // Conversation 5: Frank → Alice (Should detect: FAN)
  // Fan message with no response (realistic for creators)
  await createCategorizationConversation(
    db,
    [alice, frank],
    [
      {
        senderId: frank,
        text: "Hi Alice! I'm a huge fan of your work. I've been following you for a while and your content has really inspired me. Just wanted to reach out and say thank you for everything you create!"
      }
    ],
    {
      [alice]: {
        categoryTags: ['fan'],
        statusTags: ['needsResponse']
      },
      [frank]: {
        categoryTags: ['fan'],
        statusTags: ['awaitingReply']
      }
    },
    'fan',
    1 // Last message 1 minute ago (most recent)
  );
  console.log('  ✓ Frank → Alice: Fan appreciation (1 message, should detect: fan)\n');

  console.log('✅ Created 5 enhanced conversations with voice profiles\n');
  console.log('📊 Expected category detection:');
  console.log('  • Business: 1 conversation (Carol ↔ Alice) - 3 messages');
  console.log('  • Collaboration: 1 conversation (David ↔ Alice) - 3 messages');
  console.log('  • Social: 2 conversations (Alice ↔ Bob - 6 messages, Emma ↔ Alice - 3 messages)');
  console.log('  • Fan: 1 conversation (Frank → Alice) - 1 message\n');
  console.log('🎯 StatusTags already set:');
  console.log('  • Business conversation: Both users have "urgent" tag');
  console.log('  • All conversations: Proper needsResponse/awaitingReply tags\n');
  console.log('🎭 Voice profiles applied:');
  console.log('  • Alice: business (professional-friendly), collaboration (friendly-organized), social (warm-casual)');
  console.log('  • Bob: social (casual-laid-back, lowercase)');
  console.log('  • David: collaboration (creative-professional)\n');
  console.log('📝 Test plan:');
  console.log('  1. Log in as Alice (alice.johnson@test.com / password)');
  console.log('  2. AI should process messages and assign categories');
  console.log('  3. Check if categories appear correctly in inbox');
  console.log('  4. Verify statusTags show correctly (urgent, needsResponse, awaitingReply)');
  console.log('  5. Notice authentic conversation flow and voice differences\n');
  console.log('🎉 Enhanced AI Categorization seed complete!\n');
}

module.exports = seedCompleteSeed;
