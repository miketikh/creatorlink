/**
 * Generic Seed File
 *
 * Creates a general-purpose test dataset with various conversation types.
 * Includes both 1:1 and group conversations, some with AI enabled.
 *
 * IMPORTANT: Always reference ../constants.js for shared user data.
 * See ../../db-types.md for current database schema standards.
 */

const {
  AI_USER,
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
  createMessages,
  generateTagsByUser
} = require('../utils');

async function seedGeneric(auth, db) {
  console.log('🌱 Starting generic seed process...\n');

  // Step 1: Create auth users and get UIDs
  const userIds = await createAuthUsers(auth, ALL_USERS, DEFAULT_PASSWORD);
  await createAIAuthUser(auth, AI_USER);

  // Step 2: Create Firestore user profiles
  await createUserProfiles(db, ALL_USERS, userIds);
  await createAIUserProfile(db, AI_USER);

  // Map users for easy reference (Alice and Bob are always first two)
  const [alice, bob, carol, david, emma, frank, grace, henry, iris, jack] = userIds;

  // Step 3: Create conversations
  console.log('💬 Creating conversations...');

  const conversations = [];

  // Alice's conversations
  const aliceBobConv = await createConversation(db, [alice, bob], false, null, null, 50);
  aliceBobConv.categoryTag = 'business'; // Business conversation
  conversations.push(aliceBobConv);
  console.log('  ✓ Alice ↔ Bob (50 messages) - Business');

  const aliceCarolConv = await createConversation(db, [alice, carol], false, null, null, 1);
  aliceCarolConv.categoryTag = 'social'; // Social conversation
  conversations.push(aliceCarolConv);
  console.log('  ✓ Alice ↔ Carol (1 message) - Social');

  const aliceDavidConv = await createConversation(db, [alice, david], false, null, null, 1);
  aliceDavidConv.categoryTag = 'fan'; // Fan conversation
  conversations.push(aliceDavidConv);
  console.log('  ✓ Alice ↔ David (1 message) - Fan');

  const aliceEmmaConv = await createConversation(db, [alice, emma], false, null, null, 50);
  aliceEmmaConv.categoryTag = 'collaboration'; // Collaboration conversation
  conversations.push(aliceEmmaConv);
  console.log('  ✓ Alice ↔ Emma (50 messages) - Collaboration');

  // Group 1: Study Group with AI enabled
  const studyGroupConv = await createConversation(
    db,
    [alice, bob, carol, david, AI_USER.uid],
    true,
    'Study Group',
    null,
    10,
    DEFAULT_AI_CONFIG
  );
  conversations.push(studyGroupConv);
  console.log('  ✓ Study Group (Alice, Bob, Carol, David + AI Assistant - 10 messages) - AI enabled');

  // Group 2: Weekend Plans (no AI)
  const weekendPlansConv = await createConversation(
    db,
    [alice, bob, emma, frank],
    true,
    'Weekend Plans',
    'https://ui-avatars.com/api/?name=Weekend+Plans&background=2196F3&color=fff&size=200',
    5
  );
  conversations.push(weekendPlansConv);
  console.log('  ✓ Weekend Plans (Alice, Bob, Emma, Frank - 5 messages) - generated avatar');

  // Group 3: City Explorers with AI enabled
  const cityExplorersConv = await createConversation(
    db,
    [alice, bob, grace, AI_USER.uid],
    true,
    'City Explorers',
    'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1544',
    8,
    DEFAULT_AI_CONFIG
  );
  conversations.push(cityExplorersConv);
  console.log('  ✓ City Explorers (Alice, Bob, Grace + AI Assistant - 8 messages) - AI enabled');

  // Bob's additional conversations
  const bobHenryConv = await createConversation(db, [bob, henry], false, null, null, 1);
  bobHenryConv.categoryTag = 'social'; // Social conversation
  conversations.push(bobHenryConv);
  console.log('  ✓ Bob ↔ Henry (1 message) - Social');

  const bobIrisConv = await createConversation(db, [bob, iris], false, null, null, 1);
  bobIrisConv.categoryTag = 'business'; // Business conversation
  conversations.push(bobIrisConv);
  console.log('  ✓ Bob ↔ Iris (1 message) - Business');

  const bobJackConv = await createConversation(db, [bob, jack], false, null, null, 50);
  bobJackConv.categoryTag = 'fan'; // Fan conversation
  conversations.push(bobJackConv);
  console.log('  ✓ Bob ↔ Jack (50 messages) - Fan');

  // Group 4: Gaming Squad with AI enabled
  const gamingSquadConv = await createConversation(
    db,
    [bob, jack, frank, henry, AI_USER.uid],
    true,
    'Gaming Squad',
    'https://ui-avatars.com/api/?name=Gaming+Squad&background=FF5722&color=fff&size=200',
    8,
    DEFAULT_AI_CONFIG
  );
  conversations.push(gamingSquadConv);
  console.log('  ✓ Gaming Squad (Bob, Jack, Frank, Henry + AI Assistant - 8 messages) - AI enabled');

  console.log(`\n✅ Created ${conversations.length} conversations\n`);

  // Step 4: Create messages
  console.log('📨 Creating messages...');

  for (const conv of conversations) {
    const lastMessage = await createMessages(db, conv.id, conv.participantIds, conv.messageCount);

    // Prepare update data
    const updateData = {
      lastMessage: lastMessage.text,
      lastMessageTime: lastMessage.timestamp,
      lastMessageSenderId: lastMessage.senderId,
      lastMessageStatus: lastMessage.status
    };

    // Add tags for 1:1 conversations only (not group chats)
    if (!conv.isGroup && conv.categoryTag) {
      updateData.tagsByUser = generateTagsByUser(
        conv.participantIds,
        conv.categoryTag,
        lastMessage.senderId
      );
      updateData.primaryCategory = conv.categoryTag;
      updateData.categoryTags = [conv.categoryTag];
    }

    // Update conversation with actual last message and tags
    await db.collection('conversations').doc(conv.id).update(updateData);

    console.log(`  ✓ Created ${conv.messageCount} messages for ${conv.name}`);
  }

  console.log(`\n✅ All messages created\n`);

  // Step 5: Add "urgent" status to Alice-Bob conversation for high priority testing
  console.log('🔥 Adding high priority status to Alice ↔ Bob conversation...');

  const aliceBobDoc = await db.collection('conversations').doc(aliceBobConv.id).get();
  const aliceBobData = aliceBobDoc.data();
  const lastSenderId = aliceBobData.lastMessageSenderId;

  // Add "urgent" status to whoever needs to respond
  const updatedTagsByUser = { ...aliceBobData.tagsByUser };

  if (lastSenderId === alice) {
    // Bob needs to respond - make it urgent for him
    updatedTagsByUser[bob].statusTags = ['needsResponse', 'urgent'];
    console.log('  ✓ Alice sent last message → Bob has urgent response needed');
  } else {
    // Alice needs to respond - make it urgent for her
    updatedTagsByUser[alice].statusTags = ['needsResponse', 'urgent'];
    console.log('  ✓ Bob sent last message → Alice has urgent response needed');
  }

  await db.collection('conversations').doc(aliceBobConv.id).update({
    tagsByUser: updatedTagsByUser
  });

  console.log('  ✓ High priority status added\n');
  console.log('🎉 Generic seed complete!\n');
}

module.exports = seedGeneric;
