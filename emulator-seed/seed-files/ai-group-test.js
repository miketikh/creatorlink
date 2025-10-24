/**
 * AI Group Test Seed File
 *
 * Creates a small test group conversation with 10 messages to test
 * Firebase Cloud Functions AI question detection.
 *
 * This seed WILL TRIGGER FUNCTIONS to test the OpenAI question detection flow.
 *
 * IMPORTANT: Always reference ../constants.js for shared user data.
 * See ../../db-types.md for current database schema standards.
 */

const {
  AI_USER,
  PRIMARY_USERS,
  ALL_USERS,
  DEFAULT_PASSWORD,
  DEFAULT_AI_CONFIG
} = require('../constants');
const {
  createAuthUsers,
  createAIAuthUser,
  createUserProfiles,
  createAIUserProfile,
  getTimestamp
} = require('../utils');

async function seedAIGroupTest(auth, db) {
  console.log('🌱 Starting AI Group Test seed process...\n');

  // Step 1: Create auth users and get UIDs
  const userIds = await createAuthUsers(auth, ALL_USERS, DEFAULT_PASSWORD);
  await createAIAuthUser(auth, AI_USER);

  // Step 2: Create Firestore user profiles
  await createUserProfiles(db, ALL_USERS, userIds);
  await createAIUserProfile(db, AI_USER);

  // Map users for easy reference
  const [alice, bob, carol, david] = userIds;

  console.log('💬 Creating AI-enabled group conversation with 10 messages...');

  // Step 3: Create the conversation with AI enabled
  const participantIds = [alice, bob, carol, david, AI_USER.uid];
  const sortedParticipantIds = [...participantIds].sort();

  const conversationId = db.collection('conversations').doc().id;
  // Most recent message will be at 3 minutes ago (60 - 19*3 = 3)
  const lastMessageTime = getTimestamp(0, 0, 3);

  const conversationData = {
    participantIds: sortedParticipantIds,
    isGroupChat: true,
    lastMessageTime,
    lastMessage: 'Placeholder', // Will be updated after messages are created
    lastMessageSenderId: alice,
    lastMessageStatus: 'read',
    unreadCounts: {},
    mutedBy: null,
    groupName: 'Event Planning',
    groupImageUrl: 'https://ui-avatars.com/api/?name=Event+Planning&background=FF5722&color=fff&size=200',
    aiEnabled: true,
    aiConfig: DEFAULT_AI_CONFIG
  };

  // Set unread counts (all 0 for read messages)
  sortedParticipantIds.forEach(id => {
    conversationData.unreadCounts[id] = 0;
  });

  await db.collection('conversations').doc(conversationId).set(conversationData);
  console.log('  ✓ Created "Event Planning" group with AI enabled');
  console.log(`  ✓ Participants: Alice, Bob, Carol, David + AI Assistant`);
  console.log(`  ✓ Conversation ID: ${conversationId}\n`);

  // Step 4: Create 20 messages that will trigger functions
  console.log('📨 Creating 20 messages (functions ENABLED)...');

  // Define messages explicitly for testing
  const messageTexts = [
    // Original 10 messages
    { senderId: alice, text: 'Hi everyone! How\'s everyone doing?' },
    { senderId: bob, text: 'Doing great! Excited for the event.' },
    { senderId: carol, text: 'Same here! Can\'t wait.' },
    { senderId: david, text: 'Hey team!' },
    { senderId: alice, text: 'So I wanted to ask something...' },
    { senderId: alice, text: 'What time is the event today?' }, // QUESTION 1
    { senderId: bob, text: '7:00 PM at the downtown venue' }, // ANSWER 1
    { senderId: carol, text: 'Perfect, thanks!' },
    { senderId: david, text: 'See you all there!' },
    { senderId: bob, text: 'Looking forward to it!' },

    // Additional 10 messages with non-sequential Q&A pairs
    { senderId: carol, text: 'How much does it cost to get in?' }, // QUESTION 2
    { senderId: david, text: 'Yo, this sounds great!' },
    { senderId: alice, text: 'I\'m so excited!' },
    { senderId: bob, text: `@Carol it's $7.50 if you get there early, $10 if you arrive past 8 PM` }, // ANSWER 2
    { senderId: carol, text: 'Thanks!' },
    { senderId: david, text: 'Can I bring my dog?' }, // QUESTION 3
    { senderId: alice, text: 'Man, I\'ve been looking forward to this all week!' },
    { senderId: bob, text: 'Same here, can\'t wait!' },
    { senderId: carol, text: 'Yep, it\'s pet-friendly! Just keep them on a leash.' }, // ANSWER 3
    { senderId: david, text: 'Awesome, thanks!' }
  ];

  const batch = db.batch();
  let lastMessage = null;

  for (let i = 0; i < messageTexts.length; i++) {
    const messageId = db.collection('messages').doc().id;
    const { senderId, text } = messageTexts[i];

    // Calculate timestamp (messages spread over ~60 minutes, oldest to newest)
    const minutesAgo = 60 - (i * 3); // Most recent message is 3 minutes ago
    const messageTimestamp = getTimestamp(0, 0, minutesAgo);

    // Create readBy map (all messages are read for simplicity)
    const readBy = {};
    sortedParticipantIds.forEach(id => {
      readBy[id] = messageTimestamp;
    });

    const messageData = {
      conversationId,
      senderId,
      text,
      timestamp: messageTimestamp,
      status: 'read',
      participantIds: sortedParticipantIds,
      readBy,
      imageUrl: null,
      metadata: null
    };

    // Keep track of last message for conversation update
    if (i === messageTexts.length - 1) {
      lastMessage = {
        text,
        timestamp: messageTimestamp,
        senderId,
        status: 'read'
      };
    }

    batch.set(db.collection('messages').doc(messageId), messageData);
  }

  await batch.commit();
  console.log('  ✓ Created 20 messages with 3 Q&A pairs:');
  console.log('    Q&A Pair 1:');
  console.log('      - Question (msg 6): "What time is the event today?"');
  console.log('      - Answer (msg 7): "7:00 PM at the downtown venue"');
  console.log('    Q&A Pair 2 (non-sequential):');
  console.log('      - Question (msg 11): "How much does it cost to get in?"');
  console.log('      - Unrelated messages (12-13)');
  console.log('      - Answer (msg 14): "$7.50 early, $10 after 8 PM"');
  console.log('    Q&A Pair 3 (non-sequential):');
  console.log('      - Question (msg 16): "Can I bring my dog?"');
  console.log('      - Unrelated messages (17-18)');
  console.log('      - Answer (msg 19): "Yep, pet-friendly! Just keep them on a leash."');

  // Step 5: Update conversation with last message
  await db.collection('conversations').doc(conversationId).update({
    lastMessage: lastMessage.text,
    lastMessageTime: lastMessage.timestamp,
    lastMessageSenderId: lastMessage.senderId,
    lastMessageStatus: lastMessage.status
  });

  console.log(`\n✅ AI Group Test conversation created successfully`);
  console.log(`\n📋 Testing Instructions:`);
  console.log(`  1. Check Firebase Functions logs for question detection`);
  console.log(`  2. Three questions should be detected:`);
  console.log(`     - "What time is the event today?"`);
  console.log(`     - "How much does it cost to get in?"`);
  console.log(`     - "Can I bring my dog?"`);
  console.log(`  3. AI should handle non-sequential Q&A pairs (questions and answers not adjacent)`);
  console.log(`  4. Look for logs with "✅ Group chat QUESTION detected" and "✅ FAQ match found!"`);
  console.log(`  5. Verify AI responses are created with proper metadata\n`);

  console.log('🎉 AI Group Test seed complete!\n');
}

module.exports = seedAIGroupTest;
