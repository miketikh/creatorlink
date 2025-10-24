# Firebase Emulator Seed Scripts

This directory contains seed scripts that populate the Firebase emulators with test data for development and testing.

## Seeding Standards

**IMPORTANT: When creating or modifying seed files, you MUST follow these standards:**

1. **Always reference `constants.js`** for shared user data, AI configuration, and other constants
2. **Always check `../db-types.md`** for current database schema standards before creating seed data
3. **Use the utility functions** from `utils.js` for consistency across all seed files
4. **Primary users (Alice & Bob)** must always be the first two users in every seed file
5. **AI Assistant** must use the UID defined in `constants.js` (must match iOS app's `AIConstants.AI_USER_ID`)

## File Structure

```
emulator-seed/
├── README.md (this file - seeding guide)
├── constants.js (shared constants - users, AI config, etc.)
├── utils.js (shared utility functions)
├── seed.js (main orchestrator - routes to specific seed files)
├── seed-files/
│   ├── generic.js (general-purpose test data)
│   ├── ai-group.js (AI group conversation testing)
│   └── [future seed files...]
└── package.json
```

## Available Seed Types

### 1. Generic (`generic`)
General-purpose test dataset with various conversation types:
- 1:1 conversations with varying message counts
- Group chats with and without AI enabled
- Mix of read/unread message statuses
- Realistic timestamp distribution

**Use case:** General app testing, UI development, basic feature testing

### 2. AI Group (`ai-group`)
Specialized dataset for testing AI Group message features:
- FAQ detection scenarios
- Similar questions for testing matching
- Edge cases (low similarity, borderline matches)
- Various AI configuration settings

**Use case:** AI feature development, FAQ detection testing

**Status:** ⚠️ Not yet implemented (placeholder created)

## Test Users

All users have password: `password`

**Primary test users (for login):**
- `alice.johnson@test.com` - Alice Johnson (always first user)
- `bob.martinez@test.com` - Bob Martinez (always second user)

**Supporting users:**
- `carol.williams@test.com` - Carol Williams
- `david.chen@test.com` - David Chen
- `emma.davis@test.com` - Emma Davis
- `frank.garcia@test.com` - Frank Garcia
- `grace.kim@test.com` - Grace Kim
- `henry.taylor@test.com` - Henry Taylor
- `iris.patel@test.com` - Iris Patel
- `jack.wilson@test.com` - Jack Wilson

**AI User:**
- `ai@creatorlink.app` - AI Assistant (UID: `ai-assistant`)

## Usage

### Running a Specific Seed

```bash
# Using npm scripts (recommended)
npm run seed:generic
npm run seed:ai-group

# Or using the main script directly
node seed.js --type=generic
node seed.js --type=ai-group
```

### First-Time Setup

1. **Install dependencies:**
   ```bash
   cd emulator-seed
   npm install
   ```

2. **Start Firebase emulators** (in the project root):
   ```bash
   cd ..
   firebase emulators:start
   ```

3. **Run the seed script** (in another terminal):
   ```bash
   cd emulator-seed
   npm run seed:generic
   ```

4. **Export the seeded data** (after seed completes):
   ```bash
   cd ..
   firebase emulators:export ./emulator-data
   ```

5. **Stop the emulators** (Ctrl+C in the emulator terminal)

### Everyday Use

After the first-time setup, just start emulators with the seeded data:

```bash
firebase emulators:start --import=./emulator-data --export-on-exit
```

The `--export-on-exit` flag automatically saves any changes you make during development.

### Re-seeding

If you want to reset to fresh seed data:

1. Delete the `emulator-data` folder
2. Start emulators: `firebase emulators:start`
3. Run seed script: `cd emulator-seed && npm run seed:generic`
4. Export: `firebase emulators:export ./emulator-data`

### Switching Between Seed Types

To test different scenarios:

1. Stop the emulators (Ctrl+C)
2. Delete the `emulator-data` folder
3. Start emulators: `firebase emulators:start`
4. Run desired seed: `cd emulator-seed && npm run seed:ai-group`
5. Export: `firebase emulators:export ./emulator-data`

## Creating New Seed Files

When creating a new seed file for specific testing scenarios:

1. **Create the seed file** in `seed-files/` (e.g., `seed-files/my-feature.js`)

2. **Follow the template structure:**
   ```javascript
   /**
    * [Feature Name] Seed File
    *
    * [Description of what this seed creates and why]
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
     createMessages
   } = require('../utils');

   async function seedMyFeature(auth, db) {
     console.log('🌱 Starting [feature name] seed process...\n');

     // Step 1: Create auth users
     const userIds = await createAuthUsers(auth, ALL_USERS, DEFAULT_PASSWORD);
     await createAIAuthUser(auth, AI_USER);

     // Step 2: Create user profiles
     await createUserProfiles(db, ALL_USERS, userIds);
     await createAIUserProfile(db, AI_USER);

     // Alice and Bob are always first two
     const [alice, bob, ...rest] = userIds;

     // Step 3: Create your specific test data...

     console.log('🎉 [Feature name] seed complete!\n');
   }

   module.exports = seedMyFeature;
   ```

3. **Register the seed file** in `seed.js`:
   ```javascript
   const seedMyFeature = require('./seed-files/my-feature');

   const SEED_TYPES = {
     'generic': seedGeneric,
     'ai-group': seedAIGroup,
     'my-feature': seedMyFeature  // Add this line
   };
   ```

4. **Add npm script** to `package.json`:
   ```json
   "scripts": {
     "seed:my-feature": "node seed.js --type=my-feature"
   }
   ```

5. **Document it** in this README's "Available Seed Types" section

## Seed Data Notes

### Generic Seed

**Conversation Structure:**

**Alice has:**
- 1:1 with Bob (50 messages)
- 1:1 with Carol (1 message)
- 1:1 with David (1 message)
- 1:1 with Emma (50 messages)
- Group: "Study Group" with Bob, Carol, David + AI (10 messages, AI enabled)
- Group: "Weekend Plans" with Bob, Emma, Frank (5 messages, no AI)
- Group: "City Explorers" with Bob, Grace + AI (8 messages, AI enabled)

**Bob has:**
- 1:1 with Alice (same 50 messages)
- 1:1 with Henry (1 message)
- 1:1 with Iris (1 message)
- 1:1 with Jack (50 messages)
- Group: "Study Group" with Alice, Carol, David + AI (same 10 messages, AI enabled)
- Group: "Gaming Squad" with Jack, Frank, Henry + AI (8 messages, AI enabled)

**Data characteristics:**
- Message statuses: Most messages are "read", bottom 3 have "sent" or "delivered" status
- Timestamps: Messages spread over last 3 days for realistic appearance
- Online status: Alice and Bob are "online", others are "offline"
- Messages: Generated using Faker for natural-sounding conversations

## Constants Reference

See `constants.js` for the definitive list of constants that must be consistent across all seeds:

- `AI_USER` - AI Assistant configuration
- `PRIMARY_USERS` - Alice and Bob (must be first two users)
- `ADDITIONAL_USERS` - Other test users
- `ALL_USERS` - Complete user list in correct order
- `DEFAULT_PASSWORD` - Password for all test users
- `PROJECT_ID` - Firebase project ID
- `DEFAULT_AI_CONFIG` - Standard AI configuration for conversations

## Database Schema Reference

Always check `../db-types.md` before creating seed data to ensure you're following current schema standards for:

- User profiles (`users` collection)
- Conversations (`conversations` collection)
- Messages (`messages` collection)
- AI configuration structure
- Message metadata structure
- Realtime Database paths

## Troubleshooting

**Issue:** Seed script fails with "user already exists"
- **Solution:** Delete the `emulator-data` folder and start fresh emulators

**Issue:** Constants not found
- **Solution:** Ensure you're using correct relative paths (`../constants.js` from seed-files)

**Issue:** AI user ID mismatch
- **Solution:** Verify `constants.js` AI_USER.uid matches iOS app's `AIConstants.AI_USER_ID`

**Issue:** Schema validation errors
- **Solution:** Check `../db-types.md` for current schema requirements

## Notes

- The `emulator-seed/node_modules` directory is gitignored to keep the repo clean
- Seed files export a function that takes `auth` and `db` parameters
- The main orchestrator (`seed.js`) handles Firebase initialization
- All seed files should be idempotent when run on fresh emulators
