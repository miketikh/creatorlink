/**
 * Shared utility functions for all seed files
 *
 * IMPORTANT: Always use these utilities for consistency across seed files.
 * See ../db-types.md for current database schema standards.
 */

const admin = require('firebase-admin');
const { faker } = require('@faker-js/faker');

/**
 * Generate avatar URL using UI Avatars API
 * @param {string} displayName - User's display name
 * @param {string} email - User's email (fallback if no display name)
 * @returns {string} Avatar URL
 */
function generateAvatarURL(displayName, email) {
  const name = displayName || email.split('@')[0];
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=random&size=200&bold=true`;
}

/**
 * Create a Firestore timestamp for a past date/time
 * @param {number} daysAgo - Number of days in the past
 * @param {number} hoursAgo - Additional hours in the past
 * @param {number} minutesAgo - Additional minutes in the past
 * @returns {admin.firestore.Timestamp} Firestore timestamp
 */
function getTimestamp(daysAgo = 0, hoursAgo = 0, minutesAgo = 0) {
  const now = new Date();
  now.setDate(now.getDate() - daysAgo);
  now.setHours(now.getHours() - hoursAgo);
  now.setMinutes(now.getMinutes() - minutesAgo);
  return admin.firestore.Timestamp.fromDate(now);
}

/**
 * Message templates for generating natural-sounding conversations
 */
const MESSAGE_TEMPLATES = [
  // Greetings
  () => faker.helpers.arrayElement(['Hey!', 'Hi!', 'Hello!', 'Hey there!', 'What\'s up?']),
  () => `How are you ${faker.helpers.arrayElement(['doing', 'today', 'feeling'])}?`,

  // Questions
  () => `Did you ${faker.helpers.arrayElement(['see', 'hear about', 'check out'])} ${faker.helpers.arrayElement(['the news', 'that video', 'the game', 'the update', 'that post'])}?`,
  () => `What do you think about ${faker.helpers.arrayElement(['this', 'that', 'the idea', 'the plan', 'it'])}?`,
  () => `Have you ${faker.helpers.arrayElement(['finished', 'started', 'seen'])} ${faker.helpers.arrayElement(['the project', 'that thing', 'your work', 'the assignment', 'it'])}?`,
  () => `Are you ${faker.helpers.arrayElement(['free', 'available', 'around'])} ${faker.helpers.arrayElement(['later', 'tomorrow', 'this weekend'])}?`,
  () => `Want to ${faker.helpers.arrayElement(['grab lunch', 'meet up', 'catch up', 'hang out'])}?`,

  // Responses
  () => faker.helpers.arrayElement(['Yeah!', 'Definitely!', 'For sure!', 'Absolutely!', 'Sounds good!']),
  () => faker.helpers.arrayElement(['No problem!', 'Of course!', 'Sure thing!', 'You got it!']),
  () => faker.helpers.arrayElement(['Thanks!', 'Thank you!', 'Thanks so much!', 'Appreciate it!']),
  () => `That's ${faker.helpers.arrayElement(['great', 'awesome', 'amazing', 'cool', 'perfect'])}!`,
  () => faker.helpers.arrayElement(['I agree', 'Makes sense', 'Good point', 'True', 'Exactly']),

  // Statements
  () => `I ${faker.helpers.arrayElement(['think', 'feel', 'believe'])} ${faker.helpers.arrayElement(['that makes sense', 'we should do it', 'it\'s a good idea', 'that could work', 'you\'re right'])}`,
  () => `Just ${faker.helpers.arrayElement(['finished', 'started', 'working on'])} ${faker.helpers.arrayElement(['my homework', 'that project', 'the assignment', 'some stuff', 'it'])}`,
  () => faker.helpers.arrayElement(['Looking forward to it', 'That sounds good', 'Can\'t wait', 'Sounds like a plan', 'Let\'s do it']),
  () => `Let me know ${faker.helpers.arrayElement(['what you think', 'if you need anything', 'how it goes'])}`,
  () => `I'll ${faker.helpers.arrayElement(['check it out', 'look into it', 'get back to you', 'send you the details'])}`,

  // Time-based
  () => `See you ${faker.helpers.arrayElement(['later', 'tomorrow', 'soon', 'then'])}!`,
  () => faker.helpers.arrayElement(['Good morning!', 'Good afternoon!', 'Good evening!']),
  () => `Have a ${faker.helpers.arrayElement(['great', 'good', 'nice', 'wonderful'])} ${faker.helpers.arrayElement(['day', 'evening', 'weekend'])}!`,

  // Casual
  () => faker.helpers.arrayElement(['lol', 'haha', 'nice', 'cool', 'nice!', 'awesome']),
  () => faker.helpers.arrayElement(['👍', '😊', '🎉', '😂', '❤️', '🔥', '💯']),
  () => `${faker.helpers.arrayElement(['Btw', 'By the way', 'Also'])}, ${faker.helpers.arrayElement(['I forgot to mention', 'don\'t forget', 'thanks for that', 'I heard about it', 'that reminds me'])}`
];

/**
 * Generate a random realistic message
 * @returns {string} Generated message text
 */
function generateMessage() {
  const template = faker.helpers.arrayElement(MESSAGE_TEMPLATES);
  return template();
}

/**
 * Create auth users in Firebase Authentication
 * Fetches existing users if they already exist (by email) to ensure consistent UIDs
 * @param {admin.auth.Auth} auth - Firebase Auth instance
 * @param {Array} users - Array of user objects with displayName, email, and optional photoURL
 * @param {string} password - Password for all users
 * @returns {Promise<string[]>} Array of user UIDs (existing or newly created)
 */
async function createAuthUsers(auth, users, password) {
  console.log('👥 Creating/fetching auth users...');
  const userIds = [];

  for (const user of users) {
    try {
      // First, try to get existing user by email
      let userRecord;
      try {
        userRecord = await auth.getUserByEmail(user.email);
        console.log(`  ✓ Found existing ${user.displayName} (${userRecord.uid})`);
      } catch (error) {
        // User doesn't exist, create new one
        if (error.code === 'auth/user-not-found') {
          userRecord = await auth.createUser({
            email: user.email,
            password: password,
            displayName: user.displayName
          });
          console.log(`  ✓ Created ${user.displayName} (${userRecord.uid})`);
        } else {
          throw error; // Re-throw unexpected errors
        }
      }

      userIds.push(userRecord.uid);
    } catch (error) {
      console.error(`  ✗ Failed to create/fetch ${user.displayName}:`, error.message);
      // Don't add to userIds array if there was an error
    }
  }

  console.log(`\n✅ Processed ${userIds.length} auth users\n`);
  return userIds;
}

/**
 * Create AI Assistant auth user with fixed UID
 * @param {admin.auth.Auth} auth - Firebase Auth instance
 * @param {Object} aiUser - AI user configuration object
 * @returns {Promise<void>}
 */
async function createAIAuthUser(auth, aiUser) {
  console.log('🤖 Creating AI Assistant user...');
  try {
    await auth.createUser({
      uid: aiUser.uid,
      email: aiUser.email,
      password: 'password',
      displayName: aiUser.displayName
    });
    console.log(`  ✓ Created AI Assistant (${aiUser.uid})`);
  } catch (error) {
    console.error(`  ✗ Failed to create AI Assistant:`, error.message);
  }
  console.log('');
}

/**
 * Create Firestore user profiles
 * @param {admin.firestore.Firestore} db - Firestore instance
 * @param {Array} users - Array of user objects with displayName, email, photoURL
 * @param {string[]} userIds - Array of Firebase Auth UIDs
 * @returns {Promise<void>}
 */
async function createUserProfiles(db, users, userIds) {
  console.log('📝 Creating user profiles in Firestore...');

  for (let i = 0; i < users.length; i++) {
    const user = users[i];
    const userId = userIds[i];

    // Use provided photoURL or generate one
    const photoURL = user.photoURL || generateAvatarURL(user.displayName, user.email);

    await db.collection('users').doc(userId).set({
      displayName: user.displayName,
      email: user.email,
      photoURL: photoURL,
      isOnline: i < 2, // Alice and Bob online, others offline
      lastSeen: getTimestamp(0)
    });
    console.log(`  ✓ Created profile for ${user.displayName}`);
  }

  console.log(`\n✅ Created ${users.length} user profiles\n`);
}

/**
 * Create AI Assistant Firestore profile
 * @param {admin.firestore.Firestore} db - Firestore instance
 * @param {Object} aiUser - AI user configuration object
 * @returns {Promise<void>}
 */
async function createAIUserProfile(db, aiUser) {
  console.log('🤖 Creating AI Assistant profile in Firestore...');
  await db.collection('users').doc(aiUser.uid).set({
    displayName: aiUser.displayName,
    email: aiUser.email,
    photoURL: aiUser.photoURL,
    isOnline: aiUser.isOnline,
    lastSeen: getTimestamp(0)
  });
  console.log(`  ✓ Created AI Assistant profile (${aiUser.uid})\n`);
}

/**
 * Create a conversation document in Firestore
 * @param {admin.firestore.Firestore} db - Firestore instance
 * @param {string[]} participantIds - Array of participant user IDs (will be sorted)
 * @param {boolean} isGroup - Whether this is a group chat
 * @param {string|null} groupName - Group name (null for 1:1 chats)
 * @param {string|null} groupImageUrl - Group image URL (null for 1:1 chats)
 * @param {number} messageCount - Number of messages to create later
 * @param {Object|null} aiConfig - AI configuration object (null if AI not enabled)
 * @returns {Promise<Object>} Conversation object with id, participantIds, messageCount, isGroup, name
 */
async function createConversation(db, participantIds, isGroup, groupName, groupImageUrl, messageCount, aiConfig = null) {
  const conversationId = db.collection('conversations').doc().id;
  const lastMessageTime = getTimestamp(0, 1);
  const sortedParticipantIds = [...participantIds].sort();

  const conversationData = {
    participantIds: sortedParticipantIds,
    isGroupChat: isGroup,
    lastMessageTime,
    lastMessage: generateMessage(), // Will be updated after messages are created
    lastMessageSenderId: sortedParticipantIds[0], // First participant sent last message
    lastMessageStatus: 'read', // Default to read
    unreadCounts: {},
    mutedBy: null,  // Optional field - no conversations muted by default
    groupName: isGroup ? groupName : null,
    groupImageUrl: isGroup ? groupImageUrl : null
  };

  // Set unread counts (all 0 for read messages)
  sortedParticipantIds.forEach(id => {
    conversationData.unreadCounts[id] = 0;
  });

  // Add AI configuration if provided
  if (aiConfig) {
    conversationData.aiEnabled = true;
    conversationData.aiConfig = aiConfig;
  }

  await db.collection('conversations').doc(conversationId).set(conversationData);

  return {
    id: conversationId,
    participantIds: sortedParticipantIds,
    messageCount,
    isGroup,
    name: isGroup ? groupName : 'Chat'
  };
}

/**
 * Create messages for a conversation
 * @param {admin.firestore.Firestore} db - Firestore instance
 * @param {string} conversationId - Conversation ID
 * @param {string[]} participantIds - Array of participant user IDs
 * @param {number} count - Number of messages to create
 * @returns {Promise<Object>} Last message data (text, timestamp, senderId, status)
 */
async function createMessages(db, conversationId, participantIds, count) {
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

/**
 * Generate per-user tag data for a conversation
 * @param {string[]} participantIds - Array of participant user IDs
 * @param {string|null} categoryTag - Category tag for all users (business, collaboration, social, fan)
 * @param {string} lastMessageSenderId - ID of user who sent the last message
 * @returns {Object} tagsByUser map with per-user tag data
 */
function generateTagsByUser(participantIds, categoryTag, lastMessageSenderId) {
  const tagsByUser = {};

  participantIds.forEach(userId => {
    const userTags = {};

    // Add category tag if provided
    if (categoryTag) {
      userTags.categoryTags = [categoryTag];
    }

    // Add status tags based on who sent the last message
    if (lastMessageSenderId) {
      if (userId === lastMessageSenderId) {
        // Sender is awaiting reply from others
        userTags.statusTags = ['awaitingReply'];
      } else {
        // Recipients need to respond
        userTags.statusTags = ['needsResponse'];
      }
    }

    tagsByUser[userId] = userTags;
  });

  return tagsByUser;
}

module.exports = {
  generateAvatarURL,
  getTimestamp,
  generateMessage,
  createAuthUsers,
  createAIAuthUser,
  createUserProfiles,
  createAIUserProfile,
  createConversation,
  createMessages,
  generateTagsByUser
};
