/**
 * AI Group Seed File
 *
 * Creates a test group conversation demonstrating the AI FAQ detection feature.
 * This is for TESTING ONLY - the backend AI functionality is NOT implemented yet,
 * so we're manually simulating what an AI response would look like.
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
  createConversation,
  generateMessage,
  getTimestamp
} = require('../utils');

async function seedAIGroup(auth, db) {
  console.log('🌱 Starting AI Group seed process...\n');

  // Step 1: Create auth users and get UIDs
  const userIds = await createAuthUsers(auth, ALL_USERS, DEFAULT_PASSWORD);
  await createAIAuthUser(auth, AI_USER);

  // Step 2: Create Firestore user profiles
  await createUserProfiles(db, ALL_USERS, userIds);
  await createAIUserProfile(db, AI_USER);

  // Map users for easy reference
  const [alice, bob, carol, david] = userIds;

  console.log('💬 Creating AI-enabled group conversation...');

  // Step 3: Create the conversation with AI enabled
  const participantIds = [alice, bob, carol, david, AI_USER.uid];
  const sortedParticipantIds = [...participantIds].sort();

  const conversationId = db.collection('conversations').doc().id;
  const lastMessageTime = getTimestamp(0, 0, 1); // 1 minute ago

  const conversationData = {
    participantIds: sortedParticipantIds,
    isGroupChat: true,
    lastMessageTime,
    lastMessage: 'Placeholder', // Will be updated after messages are created
    lastMessageSenderId: alice,
    lastMessageStatus: 'read',
    unreadCounts: {},
    mutedBy: null,
    groupName: 'Brand Partnerships',
    groupImageUrl: 'https://ui-avatars.com/api/?name=Brand+Partnerships&background=9C27B0&color=fff&size=200',
    aiEnabled: true,
    aiConfig: DEFAULT_AI_CONFIG
  };

  // Set unread counts (all 0 for read messages)
  sortedParticipantIds.forEach(id => {
    conversationData.unreadCounts[id] = 0;
  });

  await db.collection('conversations').doc(conversationId).set(conversationData);
  console.log('  ✓ Created "Brand Partnerships" group with AI enabled');
  console.log(`  ✓ Participants: Alice, Bob, Carol, David + AI Assistant`);
  console.log(`  ✓ Conversation ID: ${conversationId}\n`);

  // Step 4: Create messages manually for precise control
  console.log('📨 Creating messages with FAQ demonstration...');

  const messages = [];
  const messageCount = 50;

  // We'll track the FAQ answer message ID to reference it later
  let faqAnswerMessageId = null;
  let faqQuestionText = null;

  // Create messages in reverse order (newest first, oldest last)
  // This matches the timestamp ordering in the app
  for (let i = 0; i < messageCount; i++) {
    const messageId = db.collection('messages').doc().id;

    // Determine sender (rotate through participants, excluding AI for now)
    const humanParticipants = [alice, bob, carol, david];
    const senderIndex = i % humanParticipants.length;
    const senderId = humanParticipants[senderIndex];

    // Calculate timestamp (spread messages over ~2 days, most recent first)
    const daysAgo = Math.floor(i / 25); // ~25 messages per day
    const hoursAgo = Math.floor((i % 25) / 4);
    const minutesAgo = (i % 4) * 15;
    const messageTimestamp = getTimestamp(daysAgo, hoursAgo, minutesAgo);

    // Determine message text and metadata based on position
    let messageText;
    let metadata = null;

    if (i === 0) {
      // Message 50 (index 0): AI response with FAQ metadata
      const aiMessageId = messageId;
      messageText = ''; // Empty text - UI will show "previous answer might exist" based on metadata
      metadata = {
        'ai_generated': 'true',
        'faqReference': faqAnswerMessageId, // Will be set after we create message 32
        'matchConfidence': '0.92',
        'matchedQuestion': faqQuestionText,
        'suggestedAnswer': 'Typically $750 per post, up to $1000 for video content.'
      };

      messages.push({
        id: aiMessageId,
        conversationId,
        senderId: AI_USER.uid, // AI Assistant
        text: messageText,
        timestamp: messageTimestamp,
        status: 'sent',
        participantIds: sortedParticipantIds,
        readBy: {
          [AI_USER.uid]: messageTimestamp
        },
        imageUrl: null,
        metadata
      });
      continue;

    } else if (i === 1) {
      // Message 49 (index 1): Bob asks similar question
      messageText = 'Hey, what are your rates for sponsored posts?';

    } else if (i >= 2 && i <= 17) {
      // Messages 48-33 (index 2-17): Normal conversation
      messageText = generateMessage();

    } else if (i === 18) {
      // Message 32 (index 18): Carol's answer - THIS IS THE FAQ ANSWER
      faqAnswerMessageId = messageId;
      messageText = 'I typically charge around $750 per post for my audience size, sometimes up to $1000 for video content.';

    } else if (i === 19) {
      // Message 31 (index 19): David's question - ORIGINAL QUESTION
      faqQuestionText = 'What do you charge for sponsored Instagram posts?';
      messageText = faqQuestionText;

    } else {
      // Messages 30-1 (index 20-49): Normal conversation
      messageText = generateMessage();
    }

    // Create readBy map (all messages are read for simplicity)
    const readBy = {};
    sortedParticipantIds.forEach(id => {
      readBy[id] = messageTimestamp;
    });

    const messageData = {
      id: messageId,
      conversationId,
      senderId,
      text: messageText,
      timestamp: messageTimestamp,
      status: 'read',
      participantIds: sortedParticipantIds,
      readBy,
      imageUrl: null,
      metadata
    };

    messages.push(messageData);
  }

  // Now that we have the FAQ answer message ID, update the AI message metadata
  if (faqAnswerMessageId && faqQuestionText) {
    messages[0].metadata.faqReference = faqAnswerMessageId;
    messages[0].metadata.matchedQuestion = faqQuestionText;
  }

  // Write all messages to Firestore
  console.log('  ✓ Writing 50 messages to Firestore...');
  const batch = db.batch();
  messages.forEach(msg => {
    const { id, ...messageData } = msg;
    batch.set(db.collection('messages').doc(id), messageData);
  });
  await batch.commit();

  console.log('  ✓ Messages created with FAQ demonstration:');
  console.log('    - Message 31 (David): "What do you charge for sponsored Instagram posts?"');
  console.log('    - Message 32 (Carol): "I typically charge around $750 per post..."');
  console.log('    - Messages 33-48: Normal conversation');
  console.log('    - Message 49 (Bob): "Hey, what are your rates for sponsored posts?"');
  console.log('    - Message 50 (AI): FAQ response with reference to message 32');

  // Step 5: Update conversation with actual last message (AI message)
  const lastMessage = messages[0];
  await db.collection('conversations').doc(conversationId).update({
    lastMessage: lastMessage.text,
    lastMessageTime: lastMessage.timestamp,
    lastMessageSenderId: lastMessage.senderId,
    lastMessageStatus: lastMessage.status
  });

  console.log(`\n✅ AI Group conversation created successfully`);
  console.log(`\n📋 Testing Instructions:`);
  console.log(`  1. Login as Alice (alice.johnson@test.com / password)`);
  console.log(`  2. Open "Brand Partnerships" group`);
  console.log(`  3. Scroll to see the AI message at the bottom (most recent)`);
  console.log(`  4. The AI message should have purple styling and FAQ link`);
  console.log(`  5. Tap the FAQ link to scroll to Carol's original answer`);
  console.log(`  6. Verify highlight animation appears on the referenced message\n`);

  console.log('🎉 AI Group seed complete!\n');
}

module.exports = seedAIGroup;
