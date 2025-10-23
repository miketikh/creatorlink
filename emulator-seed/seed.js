const admin = require('firebase-admin');
const { faker } = require('@faker-js/faker');

// Configure for emulator
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'creatorlink-c160a'
});

const auth = admin.auth();
const db = admin.firestore();

// Define our 10 test users
const USERS = [
  { displayName: 'Alice Johnson', email: 'alice.johnson@test.com' },
  { displayName: 'Bob Martinez', email: 'bob.martinez@test.com' },
  { displayName: 'Carol Williams', email: 'carol.williams@test.com' },
  { displayName: 'David Chen', email: 'david.chen@test.com' },
  { displayName: 'Emma Davis', email: 'emma.davis@test.com' },
  { displayName: 'Frank Garcia', email: 'frank.garcia@test.com' },
  { displayName: 'Grace Kim', email: 'grace.kim@test.com' },
  { displayName: 'Henry Taylor', email: 'henry.taylor@test.com' },
  { displayName: 'Iris Patel', email: 'iris.patel@test.com' },
  { displayName: 'Jack Wilson', email: 'jack.wilson@test.com' }
];

// Message templates for more natural conversations
const MESSAGE_TEMPLATES = [
  // Greetings
  () => faker.helpers.arrayElement(['Hey!', 'Hi!', 'Hello!', 'Hey there!', 'What\'s up?']),
  () => `How are you ${faker.helpers.arrayElement(['doing', 'today', 'feeling'])}?`,

  // Questions
  () => `Did you ${faker.helpers.arrayElement(['see', 'hear about', 'check out'])} ${faker.lorem.words(3)}?`,
  () => `What do you think about ${faker.lorem.words(2)}?`,
  () => `Have you ${faker.helpers.arrayElement(['finished', 'started', 'seen'])} ${faker.lorem.words(2)}?`,
  () => `Are you ${faker.helpers.arrayElement(['free', 'available', 'around'])} ${faker.helpers.arrayElement(['later', 'tomorrow', 'this weekend'])}?`,
  () => `Want to ${faker.helpers.arrayElement(['grab lunch', 'meet up', 'catch up', 'hang out'])}?`,

  // Responses
  () => faker.helpers.arrayElement(['Yeah!', 'Definitely!', 'For sure!', 'Absolutely!', 'Sounds good!']),
  () => faker.helpers.arrayElement(['No problem!', 'Of course!', 'Sure thing!', 'You got it!']),
  () => faker.helpers.arrayElement(['Thanks!', 'Thank you!', 'Thanks so much!', 'Appreciate it!']),
  () => `That's ${faker.helpers.arrayElement(['great', 'awesome', 'amazing', 'cool', 'perfect'])}!`,
  () => faker.helpers.arrayElement(['I agree', 'Makes sense', 'Good point', 'True', 'Exactly']),

  // Statements
  () => `I ${faker.helpers.arrayElement(['think', 'feel', 'believe'])} ${faker.lorem.sentence()}`,
  () => `Just ${faker.helpers.arrayElement(['finished', 'started', 'working on'])} ${faker.lorem.words(3)}`,
  () => faker.lorem.sentence(),
  () => `Let me know ${faker.helpers.arrayElement(['what you think', 'if you need anything', 'how it goes'])}`,
  () => `I'll ${faker.helpers.arrayElement(['check it out', 'look into it', 'get back to you', 'send you the details'])}`,

  // Time-based
  () => `See you ${faker.helpers.arrayElement(['later', 'tomorrow', 'soon', 'then'])}!`,
  () => faker.helpers.arrayElement(['Good morning!', 'Good afternoon!', 'Good evening!']),
  () => `Have a ${faker.helpers.arrayElement(['great', 'good', 'nice', 'wonderful'])} ${faker.helpers.arrayElement(['day', 'evening', 'weekend'])}!`,

  // Casual
  () => faker.helpers.arrayElement(['lol', 'haha', 'nice', 'cool', 'nice!', 'awesome']),
  () => faker.helpers.arrayElement(['👍', '😊', '🎉', '😂', '❤️', '🔥', '💯']),
  () => `${faker.helpers.arrayElement(['Btw', 'By the way', 'Also'])}, ${faker.lorem.sentence()}`
];

// Function to generate a random message
function generateMessage() {
  const template = faker.helpers.arrayElement(MESSAGE_TEMPLATES);
  return template();
}

// Helper to generate avatar URL
function generateAvatarURL(displayName, email) {
  const name = displayName || email.split('@')[0];
  const initials = name.split(' ').map(n => n[0]).join('').toUpperCase();
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=random&size=200&bold=true`;
}

// Helper to create timestamps (spread over last 3 days)
function getTimestamp(daysAgo, hoursAgo = 0, minutesAgo = 0) {
  const now = new Date();
  now.setDate(now.getDate() - daysAgo);
  now.setHours(now.getHours() - hoursAgo);
  now.setMinutes(now.getMinutes() - minutesAgo);
  return admin.firestore.Timestamp.fromDate(now);
}

async function seedData() {
  console.log('🌱 Starting seed process...\n');

  // Step 1: Create Auth users and get UIDs
  console.log('👥 Creating auth users...');
  const userIds = [];

  for (const user of USERS) {
    try {
      const userRecord = await auth.createUser({
        email: user.email,
        password: 'password',
        displayName: user.displayName
      });
      userIds.push(userRecord.uid);
      console.log(`  ✓ Created ${user.displayName} (${userRecord.uid})`);
    } catch (error) {
      console.error(`  ✗ Failed to create ${user.displayName}:`, error.message);
    }
  }

  console.log(`\n✅ Created ${userIds.length} auth users\n`);

  // Step 2: Create Firestore user profiles
  console.log('📝 Creating user profiles in Firestore...');

  for (let i = 0; i < USERS.length; i++) {
    const user = USERS[i];
    const userId = userIds[i];

    // Use Unsplash image for Alice, generated avatars for others
    let photoURL;
    if (user.displayName === 'Alice Johnson') {
      photoURL = 'https://images.unsplash.com/photo-1574158622682-e40e69881006?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1480';
    } else {
      photoURL = generateAvatarURL(user.displayName, user.email);
    }

    await db.collection('users').doc(userId).set({
      displayName: user.displayName,
      email: user.email,
      photoURL: photoURL,
      isOnline: i < 2, // Alice and Bob online, others offline
      lastSeen: getTimestamp(0)
    });
    console.log(`  ✓ Created profile for ${user.displayName}`);
  }

  console.log(`\n✅ Created ${USERS.length} user profiles\n`);

  // Map for easy reference
  const [alice, bob, carol, david, emma, frank, grace, henry, iris, jack] = userIds;

  // Step 3: Create conversations
  console.log('💬 Creating conversations...');

  const conversations = [];

  // Helper to create a conversation
  async function createConversation(participantIds, isGroup, groupName, groupImageUrl, messageCount) {
    const conversationId = db.collection('conversations').doc().id;
    const lastMessageTime = getTimestamp(0, 1);

    const conversationData = {
      participantIds,
      isGroupChat: isGroup,
      lastMessageTime,
      lastMessage: generateMessage(), // Will be updated after messages are created
      lastMessageSenderId: participantIds[0], // First participant sent last message
      lastMessageStatus: 'read', // Default to read
      unreadCounts: {},
      mutedBy: null  // Optional field - no conversations muted by default
    };

    // Set unread counts (all 0 for read messages)
    participantIds.forEach(id => {
      conversationData.unreadCounts[id] = 0;
    });

    if (isGroup) {
      conversationData.groupName = groupName;
      conversationData.groupImageUrl = groupImageUrl;
    } else {
      conversationData.groupName = null;
      conversationData.groupImageUrl = null;
    }

    await db.collection('conversations').doc(conversationId).set(conversationData);

    conversations.push({
      id: conversationId,
      participantIds,
      messageCount,
      isGroup,
      name: isGroup ? groupName : USERS.find((u, i) => userIds[i] === participantIds.find(p => p !== alice && p !== bob))?.displayName || 'Unknown'
    });

    return conversationId;
  }

  // Alice's conversations
  const aliceBobConv = await createConversation([alice, bob], false, null, null, 50);
  console.log('  ✓ Alice ↔ Bob (50 messages)');

  await createConversation([alice, carol], false, null, null, 1);
  console.log('  ✓ Alice ↔ Carol (1 message)');

  await createConversation([alice, david], false, null, null, 1);
  console.log('  ✓ Alice ↔ David (1 message)');

  const aliceEmmaConv = await createConversation([alice, emma], false, null, null, 50);
  console.log('  ✓ Alice ↔ Emma (50 messages)');

  // Group 1: No custom image (will use default/fallback)
  await createConversation([alice, bob, carol, david], true, 'Study Group', null, 10);
  console.log('  ✓ Study Group (Alice, Bob, Carol, David - 10 messages) - no custom image');

  // Group 2: Generated avatar
  await createConversation([alice, bob, emma, frank], true, 'Weekend Plans',
    'https://ui-avatars.com/api/?name=Weekend+Plans&background=2196F3&color=fff&size=200', 5);
  console.log('  ✓ Weekend Plans (Alice, Bob, Emma, Frank - 5 messages) - generated avatar');

  // Group 3: Unsplash image
  await createConversation([alice, bob, grace], true, 'City Explorers',
    'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1544', 8);
  console.log('  ✓ City Explorers (Alice, Bob, Grace - 8 messages) - Unsplash image');

  // Bob's additional conversations
  await createConversation([bob, henry], false, null, null, 1);
  console.log('  ✓ Bob ↔ Henry (1 message)');

  await createConversation([bob, iris], false, null, null, 1);
  console.log('  ✓ Bob ↔ Iris (1 message)');

  const bobJackConv = await createConversation([bob, jack], false, null, null, 50);
  console.log('  ✓ Bob ↔ Jack (50 messages)');

  await createConversation([bob, jack, frank, henry], true, 'Gaming Squad',
    'https://ui-avatars.com/api/?name=Gaming+Squad&background=FF5722&color=fff&size=200', 8);
  console.log('  ✓ Gaming Squad (Bob, Jack, Frank, Henry - 8 messages)');

  console.log(`\n✅ Created ${conversations.length} conversations\n`);

  // Step 4: Create messages
  console.log('📨 Creating messages...');

  async function createMessages(conversationId, participantIds, count) {
    const batch = db.batch();
    let lastMessageData = null;

    for (let i = 0; i < count; i++) {
      const messageId = db.collection('messages').doc().id;
      const senderIndex = i % participantIds.length;
      const senderId = participantIds[senderIndex];

      // Calculate status: top messages are read, bottom few are sent/delivered
      let status = 'read';
      if (i < 3) {
        // Bottom 3 messages have varying status
        status = i === 0 ? 'sent' : (i === 1 ? 'delivered' : 'delivered');
      }

      // Spread messages over time (most recent first in our array)
      const daysAgo = Math.floor(i / 20); // ~20 messages per day
      const hoursAgo = Math.floor((i % 20) / 3);
      const minutesAgo = (i % 3) * 10;

      const messageTimestamp = getTimestamp(daysAgo, hoursAgo, minutesAgo);

      // Create readBy map (userId -> timestamp)
      const readBy = {};
      if (status === 'read') {
        // All participants have read it
        participantIds.forEach(id => {
          readBy[id] = messageTimestamp;
        });
      } else {
        // Only sender has "read" it (sent it)
        readBy[senderId] = messageTimestamp;
      }

      const messageText = generateMessage();

      const messageData = {
        conversationId,
        senderId,
        text: messageText,
        timestamp: messageTimestamp,
        status,
        participantIds,
        readBy,
        imageUrl: null,  // Optional field
        metadata: null   // Optional field
      };

      batch.set(db.collection('messages').doc(messageId), messageData);

      // Track the last message (i = 0 is the most recent because timestamps go backwards)
      if (i === 0) {
        lastMessageData = {
          text: messageText,
          timestamp: messageTimestamp,
          senderId: senderId,
          status: status
        };
      }
    }

    await batch.commit();
    return lastMessageData;
  }

  for (const conv of conversations) {
    const lastMessage = await createMessages(conv.id, conv.participantIds, conv.messageCount);

    // Update conversation with actual last message
    await db.collection('conversations').doc(conv.id).update({
      lastMessage: lastMessage.text,
      lastMessageTime: lastMessage.timestamp,
      lastMessageSenderId: lastMessage.senderId,
      lastMessageStatus: lastMessage.status
    });

    console.log(`  ✓ Created ${conv.messageCount} messages for ${conv.name}`);
  }

  console.log(`\n✅ All messages created\n`);
  console.log('🎉 Seed complete! Now run:\n');
  console.log('   firebase emulators:export ./emulator-data\n');
}

// Run the seed
seedData()
  .then(() => {
    console.log('✨ Seeding completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Seeding failed:', error);
    process.exit(1);
  });
