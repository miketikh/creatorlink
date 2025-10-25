/**
 * Draft Seed File
 *
 * Creates a simple 1:1 conversation with a draft message for testing
 * the draft UI components.
 *
 * Scenario:
 * - Alice and Bob conversation with Bob as last sender
 * - AI-generated draft response for Alice to respond
 * - Tests draft display, editing, and sending flows
 *
 * IMPORTANT: Always reference ../constants.js for shared user data.
 * See ../../db-types.md for current database schema standards.
 */

const {
  PRIMARY_USERS,
  DEFAULT_PASSWORD
} = require('../constants');
const {
  createAuthUsers,
  createUserProfiles,
  createConversation,
  getTimestamp
} = require('../utils');

async function seedTestDraft(auth, db) {
  console.log('🌱 Starting test draft seed process...\n');

  // Step 1: Create or fetch auth users
  console.log('👥 Creating auth users...');
  const userIds = await createAuthUsers(auth, PRIMARY_USERS, DEFAULT_PASSWORD);

  // Step 2: Create Firestore user profiles
  await createUserProfiles(db, PRIMARY_USERS, userIds);

  // Map users for reference
  const [alice, bob] = userIds;
  console.log(`\n✅ Setup complete: Alice (${alice}) and Bob (${bob})\n`);

  // Step 3: Create conversation between Alice and Bob
  console.log('💬 Creating conversation...');
  const conversationData = await createConversation(
    db,
    [alice, bob],
    false,        // Not a group chat
    null,         // No group name
    null,         // No group image
    0,            // Don't use createMessages utility - we'll create manually
    null          // No AI config
  );
  const conversationId = conversationData.id;
  console.log(`  ✓ Created conversation: ${conversationId}\n`);

  // Step 4: Create messages manually (last one must be from Bob)
  console.log('📨 Creating messages...');

  const messages = [
    { sender: alice, text: 'Hey Bob, do you have a moment to discuss the project?' },
    { sender: bob, text: 'Sure! What did you want to talk about?' },
    { sender: alice, text: 'I wanted to get your feedback on the proposal' },
    { sender: bob, text: 'I\'d be happy to review it. Send it over when you can!' }
  ];

  // Manually create messages with specific senders and order
  const participantIds = [alice, bob].sort(); // Sort as per Firestore convention
  let lastMessageData = null;

  for (let i = 0; i < messages.length; i++) {
    const messageId = db.collection('messages').doc().id;
    const { sender: senderId, text } = messages[i];

    // Spread messages over the past 20 minutes
    const minutesAgo = 20 - (i * 5);
    const messageTimestamp = getTimestamp(0, 0, minutesAgo);

    // Create readBy map (all participants have read)
    const readBy = {};
    participantIds.forEach(id => {
      readBy[id] = messageTimestamp;
    });

    const messageData = {
      conversationId,
      senderId,
      text,
      timestamp: messageTimestamp,
      status: 'read',
      participantIds,
      readBy,
      imageUrl: null,
      metadata: null
    };

    await db.collection('messages').doc(messageId).set(messageData);

    // Track the last message (most recent = last in array)
    if (i === messages.length - 1) {
      lastMessageData = {
        text,
        timestamp: messageTimestamp,
        senderId,
        status: 'read'
      };
    }

    console.log(`  ✓ Message ${i + 1}: ${senderId === alice ? 'Alice' : 'Bob'}`);
  }

  // Step 5: Update conversation with last message data
  console.log('\n📝 Updating conversation metadata...');
  await db.collection('conversations').doc(conversationId).update({
    lastMessage: lastMessageData.text,
    lastMessageTime: lastMessageData.timestamp,
    lastMessageSenderId: lastMessageData.senderId,
    lastMessageStatus: lastMessageData.status,
    primaryCategory: 'business',
    categoryTags: ['business'],
    tagsByUser: {
      [alice]: {
        categoryTags: ['business'],
        statusTags: ['needsResponse']  // Alice needs to respond to Bob
      },
      [bob]: {
        categoryTags: ['business'],
        statusTags: ['awaitingReply']  // Bob is awaiting Alice's reply
      }
    }
  });
  console.log(`  ✓ Updated with tags and metadata\n`);

  // Step 6: Create draft for Alice
  console.log('✍️  Creating draft for Alice...');

  const draftTimestamp = getTimestamp(0, 0, 5); // Generated 5 minutes ago
  const draft = {
    conversationId,
    userId: alice,
    text: 'Thanks for offering to review! I really appreciate your input. The proposal covers the main deliverables, timeline, and budget. Let me know what you think once you\'ve had a chance to look it over.',
    category: 'business',
    generatedAt: draftTimestamp,
    updatedAt: draftTimestamp,
    userTouched: false
  };

  await db.collection('conversations')
    .doc(conversationId)
    .collection('drafts')
    .doc(alice)
    .set(draft);

  console.log(`  ✓ Created draft for Alice\n`);

  // Step 7: Summary and verification info
  console.log('=====================================');
  console.log('✅ Test Draft Seed Complete!\n');
  console.log('📋 Details:');
  console.log(`  Conversation ID: ${conversationId}`);
  console.log(`  Participants: Alice (${alice}) & Bob (${bob})`);
  console.log(`  Last message from: Bob`);
  console.log(`  Draft for: Alice`);
  console.log(`  Category: business`);
  console.log(`\n📂 Database paths:`);
  console.log(`  Conversation: /conversations/${conversationId}`);
  console.log(`  Messages: /messages?conversationId=${conversationId}`);
  console.log(`  Draft: /conversations/${conversationId}/drafts/${alice}`);
  console.log(`\n🧪 Testing Instructions:`);
  console.log(`  1. Log in as Alice`);
  console.log(`  2. Open chat with Bob`);
  console.log(`  3. See the 4-message conversation`);
  console.log(`  4. Draft should appear in reply field`);
  console.log(`  5. Test edit, discard, and send flows`);
  console.log('=====================================\n');
}

module.exports = seedTestDraft;
