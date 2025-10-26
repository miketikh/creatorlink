/**
 * Add Voice Profiles Seed File (Standalone)
 *
 * Adds voice profiles to EXISTING users in the database.
 * Queries users by email, then adds voice profiles for Alice, Bob, and David.
 *
 * Usage: node seed.js --type=add-voice-profiles
 *
 * IMPORTANT: Always reference ../constants.js for shared user data.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

/**
 * Add voice profiles to existing users
 * @param {admin.auth.Auth} auth - Firebase Auth instance (unused)
 * @param {admin.firestore.Firestore} db - Firestore instance
 */
async function addVoiceProfiles(auth, db) {
  console.log('🎙️  Adding voice profiles to existing users...\n');

  // Users that should have voice profiles (from constants.js)
  const targetUsers = [
    { email: 'alice.johnson@test.com', name: 'alice' },
    { email: 'bob.martinez@test.com', name: 'bob' },
    { email: 'david.chen@test.com', name: 'david' }
  ];

  const categories = ['business', 'collaboration', 'social'];

  // Find each user in Firestore and add their voice profiles
  for (const targetUser of targetUsers) {
    console.log(`Looking up user: ${targetUser.email}...`);

    // Query Firestore for user by email
    const userSnapshot = await db.collection('users')
      .where('email', '==', targetUser.email)
      .limit(1)
      .get();

    if (userSnapshot.empty) {
      console.log(`  ⚠️  User not found: ${targetUser.email} - skipping\n`);
      continue;
    }

    const userDoc = userSnapshot.docs[0];
    const userId = userDoc.id;
    console.log(`  Found user: ${userId}`);

    // Add voice profiles for each category
    for (const category of categories) {
      try {
        // Read JSON file
        const jsonPath = path.join(__dirname, 'voice-profiles', targetUser.name, `${category}.json`);

        if (!fs.existsSync(jsonPath)) {
          console.log(`  ⚠️  Profile not found: ${jsonPath} - skipping`);
          continue;
        }

        const styleRules = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

        // Create voice profile document
        const profileData = {
          userId: userId,
          category: category,
          styleRules: styleRules,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        };

        // Store in subcollection: users/{userId}/voiceProfiles/{category}
        await db
          .collection('users')
          .doc(userId)
          .collection('voiceProfiles')
          .doc(category)
          .set(profileData);

        console.log(`  ✓ Added ${category} profile`);

      } catch (error) {
        console.error(`  ✗ Error adding ${category} profile:`, error.message);
      }
    }

    console.log(`✅ Voice profiles added for ${targetUser.name}\n`);
  }

  console.log('✅ All voice profiles processed\n');
}

module.exports = addVoiceProfiles;
