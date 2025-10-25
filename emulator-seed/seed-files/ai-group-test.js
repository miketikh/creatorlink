/**
 * AI Group Test Seed File
 *
 * Creates multiple test group conversations with messages to test
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

// Helper function to add delay between message creations
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function seedAIGroupTest(auth, db) {
  console.log('🌱 Starting AI Group Test seed process...\n');

  // Get existing user UIDs (users should already be created)
  console.log('👥 Fetching existing user UIDs...');
  let userIds = [];
  try {
    // Try to get existing users
    const userRecords = await auth.listUsers();
    const userMap = {};
    userRecords.users.forEach(user => {
      userMap[user.email] = user.uid;
    });

    // Map to our expected users in order
    userIds = ALL_USERS.map(user => userMap[user.email]);

    // Verify we have all users
    if (userIds.some(id => !id)) {
      console.log('⚠️  Some users not found, creating missing users...');
      userIds = await createAuthUsers(auth, ALL_USERS, DEFAULT_PASSWORD);
      await createUserProfiles(db, ALL_USERS, userIds);
    } else {
      console.log('  ✓ All users found');
    }

    // Ensure AI user exists
    const aiUser = userMap[AI_USER.email];
    if (!aiUser) {
      await createAIAuthUser(auth, AI_USER);
      await createAIUserProfile(db, AI_USER);
    }
  } catch (error) {
    console.log('⚠️  Error fetching users, creating new ones...');
    userIds = await createAuthUsers(auth, ALL_USERS, DEFAULT_PASSWORD);
    await createAIAuthUser(auth, AI_USER);
    await createUserProfiles(db, ALL_USERS, userIds);
    await createAIUserProfile(db, AI_USER);
  }

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

    await db.collection('messages').doc(messageId).set(messageData);

    // Add 100ms delay between messages to avoid flooding AI
    await delay(100);
  }
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

  console.log(`\n✅ Group 1: "Event Planning" created successfully\n`);

  // ============================================================================
  // GROUP 2: Music Festival June
  // ============================================================================
  console.log('💬 Creating "Music Festival June" group conversation...');

  const festivalParticipantIds = [alice, bob, carol, david, AI_USER.uid];
  const festivalSortedIds = [...festivalParticipantIds].sort();
  const festivalConversationId = db.collection('conversations').doc().id;
  const festivalLastMessageTime = getTimestamp(0, 0, 2);

  const festivalConversationData = {
    participantIds: festivalSortedIds,
    isGroupChat: true,
    lastMessageTime: festivalLastMessageTime,
    lastMessage: 'Placeholder',
    lastMessageSenderId: alice,
    lastMessageStatus: 'read',
    unreadCounts: {},
    mutedBy: null,
    groupName: 'Music Festival June',
    groupImageUrl: 'https://ui-avatars.com/api/?name=Music+Festival&background=9C27B0&color=fff&size=200',
    aiEnabled: true,
    aiConfig: DEFAULT_AI_CONFIG
  };

  festivalSortedIds.forEach(id => {
    festivalConversationData.unreadCounts[id] = 0;
  });

  await db.collection('conversations').doc(festivalConversationId).set(festivalConversationData);
  console.log('  ✓ Created "Music Festival June" group with AI enabled');
  console.log(`  ✓ Participants: Alice, Bob, Carol, David + AI Assistant`);
  console.log(`  ✓ Conversation ID: ${festivalConversationId}\n`);

  console.log('📨 Creating messages for Music Festival June...');

  const festivalMessages = [
    { senderId: alice, text: 'Hey everyone! So excited for the festival in June!' },
    { senderId: bob, text: 'Same! Been waiting all year for this' },
    { senderId: carol, text: 'Anyone know the lineup yet?' }, // QUESTION 1
    { senderId: david, text: 'I heard rumors about some great acts' },
    { senderId: alice, text: 'The headliners are The Midnight, Glass Animals, and Tame Impala!' }, // ANSWER 1
    { senderId: bob, text: 'No way! That\'s incredible!' },
    { senderId: carol, text: 'Amazing lineup!' },
    { senderId: david, text: 'What time does it start on Saturday?' }, // QUESTION 2
    { senderId: alice, text: 'Can\'t wait to see Glass Animals live' },
    { senderId: bob, text: 'Gates open at 2 PM, first act starts at 3 PM' }, // ANSWER 2
    { senderId: carol, text: 'Perfect, gives us time to get there' },
    { senderId: david, text: 'Is there parking at the venue?' }, // QUESTION 3
    { senderId: alice, text: 'We should get there early to get a good spot' },
    { senderId: carol, text: 'Yeah, there\'s a lot across the street, $20 for the day' }, // ANSWER 3
    { senderId: bob, text: 'Or we could take the shuttle from downtown' },
    { senderId: david, text: 'Good to know, thanks!' },
    { senderId: alice, text: 'Should we coordinate carpooling?' },
    { senderId: bob, text: 'I can drive, have room for 3 more' },
    { senderId: carol, text: 'That would be great!' },
    { senderId: david, text: 'Count me in!' }
  ];

  let festivalLastMessage = null;

  for (let i = 0; i < festivalMessages.length; i++) {
    const messageId = db.collection('messages').doc().id;
    const { senderId, text } = festivalMessages[i];

    const minutesAgo = 90 - (i * 4);
    const messageTimestamp = getTimestamp(0, 0, minutesAgo);

    const readBy = {};
    festivalSortedIds.forEach(id => {
      readBy[id] = messageTimestamp;
    });

    const messageData = {
      conversationId: festivalConversationId,
      senderId,
      text,
      timestamp: messageTimestamp,
      status: 'read',
      participantIds: festivalSortedIds,
      readBy,
      imageUrl: null,
      metadata: null
    };

    if (i === festivalMessages.length - 1) {
      festivalLastMessage = {
        text,
        timestamp: messageTimestamp,
        senderId,
        status: 'read'
      };
    }

    await db.collection('messages').doc(messageId).set(messageData);
    await delay(100);
  }

  await db.collection('conversations').doc(festivalConversationId).update({
    lastMessage: festivalLastMessage.text,
    lastMessageTime: festivalLastMessage.timestamp,
    lastMessageSenderId: festivalLastMessage.senderId,
    lastMessageStatus: festivalLastMessage.status
  });

  console.log('  ✓ Created 20 messages with 3 Q&A pairs');
  console.log(`\n✅ Group 2: "Music Festival June" created successfully\n`);

  // ============================================================================
  // GROUP 3: Mexico Trip
  // ============================================================================
  console.log('💬 Creating "Mexico Trip" group conversation...');

  const mexicoParticipantIds = [alice, bob, carol, david, AI_USER.uid];
  const mexicoSortedIds = [...mexicoParticipantIds].sort();
  const mexicoConversationId = db.collection('conversations').doc().id;
  const mexicoLastMessageTime = getTimestamp(0, 0, 1);

  const mexicoConversationData = {
    participantIds: mexicoSortedIds,
    isGroupChat: true,
    lastMessageTime: mexicoLastMessageTime,
    lastMessage: 'Placeholder',
    lastMessageSenderId: alice,
    lastMessageStatus: 'read',
    unreadCounts: {},
    mutedBy: null,
    groupName: 'Mexico Trip',
    groupImageUrl: 'https://ui-avatars.com/api/?name=Mexico+Trip&background=FF9800&color=fff&size=200',
    aiEnabled: true,
    aiConfig: DEFAULT_AI_CONFIG
  };

  mexicoSortedIds.forEach(id => {
    mexicoConversationData.unreadCounts[id] = 0;
  });

  await db.collection('conversations').doc(mexicoConversationId).set(mexicoConversationData);
  console.log('  ✓ Created "Mexico Trip" group with AI enabled');
  console.log(`  ✓ Participants: Alice, Bob, Carol, David + AI Assistant`);
  console.log(`  ✓ Conversation ID: ${mexicoConversationId}\n`);

  console.log('📨 Creating messages for Mexico Trip...');

  const mexicoMessages = [
    { senderId: bob, text: 'Alright everyone, Mexico trip planning time!' },
    { senderId: alice, text: 'So excited! When are we going?' },
    { senderId: carol, text: 'First week of March, right?' },
    { senderId: david, text: 'Yep, March 1-7' },
    { senderId: alice, text: 'What\'s the weather expected to be like?' }, // QUESTION 1
    { senderId: bob, text: 'I need to know what to pack!' },
    { senderId: carol, text: 'Should be mid-70s to low 80s, perfect beach weather!' }, // ANSWER 1
    { senderId: david, text: 'Sounds perfect!' },
    { senderId: alice, text: 'Do we need to get our passports renewed?' }, // QUESTION 2
    { senderId: bob, text: 'I haven\'t been to Mexico in years' },
    { senderId: carol, text: 'As long as they\'re not expired, you\'re good. Mexico just needs 6 months validity' }, // ANSWER 2
    { senderId: david, text: 'Mine\'s good until 2027' },
    { senderId: alice, text: 'Where are we staying exactly?' }, // QUESTION 3
    { senderId: bob, text: 'Can\'t wait to get some tacos and hit the beach' },
    { senderId: david, text: 'We booked an Airbnb in Playa del Carmen, right on 5th Avenue' }, // ANSWER 3
    { senderId: carol, text: 'Perfect location!' },
    { senderId: alice, text: 'Should we rent a car or just use taxis?' },
    { senderId: bob, text: 'Taxis and Uber are super cheap there, probably easier' },
    { senderId: david, text: 'Agreed, no need for a rental' },
    { senderId: carol, text: 'Can\'t wait! Only a few weeks away!' }
  ];

  let mexicoLastMessage = null;

  for (let i = 0; i < mexicoMessages.length; i++) {
    const messageId = db.collection('messages').doc().id;
    const { senderId, text } = mexicoMessages[i];

    const minutesAgo = 120 - (i * 5);
    const messageTimestamp = getTimestamp(0, 0, minutesAgo);

    const readBy = {};
    mexicoSortedIds.forEach(id => {
      readBy[id] = messageTimestamp;
    });

    const messageData = {
      conversationId: mexicoConversationId,
      senderId,
      text,
      timestamp: messageTimestamp,
      status: 'read',
      participantIds: mexicoSortedIds,
      readBy,
      imageUrl: null,
      metadata: null
    };

    if (i === mexicoMessages.length - 1) {
      mexicoLastMessage = {
        text,
        timestamp: messageTimestamp,
        senderId,
        status: 'read'
      };
    }

    await db.collection('messages').doc(messageId).set(messageData);
    await delay(100);
  }

  await db.collection('conversations').doc(mexicoConversationId).update({
    lastMessage: mexicoLastMessage.text,
    lastMessageTime: mexicoLastMessage.timestamp,
    lastMessageSenderId: mexicoLastMessage.senderId,
    lastMessageStatus: mexicoLastMessage.status
  });

  console.log('  ✓ Created 20 messages with 3 Q&A pairs');
  console.log(`\n✅ Group 3: "Mexico Trip" created successfully\n`);

  // ============================================================================
  // Summary
  // ============================================================================
  console.log(`\n✅ All AI Group Test conversations created successfully`);
  console.log(`\n📋 Summary:`);
  console.log(`  • Event Planning: 20 messages, 3 Q&A pairs`);
  console.log(`  • Music Festival June: 20 messages, 3 Q&A pairs`);
  console.log(`  • Mexico Trip: 20 messages, 3 Q&A pairs`);
  console.log(`\n📋 Testing Instructions:`);
  console.log(`  1. Check Firebase Functions logs for question detection`);
  console.log(`  2. Each group should detect 3 questions`);
  console.log(`  3. AI should handle non-sequential Q&A pairs`);
  console.log(`  4. Look for logs with "✅ Group chat QUESTION detected" and "✅ FAQ match found!"`);
  console.log(`  5. Verify AI responses are created with proper metadata\n`);

  console.log('🎉 AI Group Test seed complete!\n');
}

module.exports = seedAIGroupTest;
