/**
 * Voice Profiles Seed File
 *
 * Creates voice profile configurations for test users across different conversation categories.
 * Profiles are static, manually authored configurations used for AI draft generation.
 *
 * IMPORTANT: Always reference ../constants.js for shared user data.
 * See ../../db-types.md for current database schema standards.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

/**
 * Seed voice profiles for test users
 * @param {admin.firestore.Firestore} db - Firestore instance
 * @param {Array<string>} userIds - Array of user IDs [alice, bob, carol, david, ...]
 */
async function seedVoiceProfiles(db, userIds) {
  console.log('🎙️  Creating voice profiles...');

  // Map test users - Alice, Bob, and David (indices 0, 1, 3 from ALL_USERS)
  const [alice, bob, , david] = userIds;

  const users = [
    { id: alice, name: 'alice' },
    { id: bob, name: 'bob' },
    { id: david, name: 'david' }
  ];

  const categories = ['business', 'collaboration', 'social'];

  for (const user of users) {
    for (const category of categories) {
      // Read JSON file
      const jsonPath = path.join(__dirname, 'voice-profiles', user.name, `${category}.json`);
      const styleRules = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

      // Create voice profile document
      const profileData = {
        userId: user.id,
        category: category,
        styleRules: styleRules,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      };

      // Store in subcollection: users/{userId}/voiceProfiles/{category}
      await db
        .collection('users')
        .doc(user.id)
        .collection('voiceProfiles')
        .doc(category)
        .set(profileData);

      console.log(`  ✓ ${user.name} - ${category}`);
    }
  }

  console.log('✅ Voice profiles created successfully\n');
}

module.exports = seedVoiceProfiles;
