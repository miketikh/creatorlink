# Firebase Configuration

This directory contains all Firebase-related configuration, security rules, and Cloud Functions for the CreatorLink application.

## Overview

The Firebase setup includes:
- **Authentication**: Email/password authentication
- **Firestore Database**: Real-time storage for users, conversations, and messages
- **Realtime Database**: User presence and typing indicators
- **Cloud Storage**: Profile images and message attachments
- **Cloud Functions**: AI-powered message processing and conversation categorization
- **Local Emulators**: Full Firebase emulation for local development

## What's Here

This directory contains:

- **Configuration files**: `firebase.json` defines emulator ports and project settings; `.firebaserc` specifies the Firebase project
- **Security rules**: `firestore.rules`, `database.rules.json`, and `storage.rules` control access to your Firebase services
- **Cloud Functions**: The `functions/` directory contains TypeScript code for AI-powered features (question detection, FAQ matching, auto-categorization, etc.)
- **Emulator data**: Local development data is stored in `emulator-data/` (not committed to git)

The main workflow is: modify TypeScript in `functions/src/`, rebuild with `npm run build`, and test with the Firebase emulators.

## Running Firebase Emulators

### Start Emulators

From the `firebase/` directory:

```bash
firebase emulators:start
```

This starts all emulators with the following ports:
- **Authentication**: `localhost:9099`
- **Firestore**: `localhost:8080`
- **Realtime Database**: `localhost:9000`
- **Cloud Storage**: `localhost:9199`
- **Cloud Functions**: `localhost:5001`
- **Emulator UI**: `http://localhost:4000`

### Start Specific Emulators

```bash
firebase emulators:start --only auth,firestore,database
```

### Stop Emulators

Press `Ctrl+C` in the terminal running the emulators.

### Clear Emulator Data

To reset all emulator data:

```bash
rm -rf emulator-data/
```

Then restart the emulators. Optionally re-run the seed script to populate test data.

### Emulator UI

Access the Firebase Emulator UI at `http://localhost:4000` to:
- View Firestore collections and documents
- Browse Realtime Database data
- Inspect authenticated users
- View Cloud Storage files
- Monitor Cloud Functions logs

## Cloud Functions

### Overview

The `functions/` directory contains TypeScript Cloud Functions that provide AI-powered features:

**Main Function:**
- `onMessageCreated` - Triggered when a new message is created in Firestore

**AI Features:**
1. **Question Detection** - Detects if a message is a question using OpenAI
2. **FAQ Matching** - Finds similar questions/answers in conversation history
3. **AI Response Generation** - Generates contextual responses to questions in group chats
4. **Conversation Categorization** - Auto-tags conversations with categories (Work, Personal, etc.)
5. **Status Tagging** - Assigns per-user status tags (Unread, Needs Response, etc.)

### Development Workflow

#### 1. Install Dependencies

```bash
cd functions
npm install
```

#### 2. Build Functions

After modifying TypeScript code in `functions/src/`, you **must** rebuild:

```bash
npm run build
```

Or use watch mode for automatic rebuilding:

```bash
npm run build:watch
```

#### 3. Test Locally

Start functions emulator:

```bash
npm run serve
```

This builds the functions and starts the functions emulator only.

#### 4. View Logs

```bash
npm run logs
```

Or view logs in the Emulator UI at `http://localhost:4000`.

### Environment Variables

Create `functions/.env` for local development:

```bash
OPENAI_API_KEY=your-api-key-here
ENABLE_AUTO_CATEGORIZATION=true
```

For production, set environment variables:

```bash
firebase functions:config:set openai.api_key="your-api-key"
```

### Deploy Functions

Deploy all functions to production:

```bash
npm run deploy
```

Or from the firebase directory:

```bash
firebase deploy --only functions
```

Deploy a specific function:

```bash
firebase deploy --only functions:onMessageCreated
```

## Security Rules

### Firestore Rules (`firestore.rules`)

Secures the following collections:
- **users**: Users can only write their own profile
- **conversations**: Only participants can read/write
- **messages**: Only participants can read, sender can create

**Key Security Features:**
- AI service account authentication via custom tokens
- AI can create messages with `senderId: 'ai-assistant'`
- Users cannot impersonate AI
- Group leave permissions (users can remove themselves)

### Storage Rules (`storage.rules`)

Secures Firebase Storage paths:
- **profile_images/{userId}**: Users can only upload their own profile images
- **message_attachments/{conversationId}**: Authenticated users can upload/read attachments

### Realtime Database Rules (`database.rules.json`)

**WARNING**: Currently set to open read/write for development. Update for production:

```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

### Deploy Rules to Production

Deploy all security rules:

```bash
firebase deploy --only firestore:rules,storage:rules,database:rules
```

Deploy specific rules:

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
firebase deploy --only database:rules
```

## Configuration Files

### `firebase.json`

Main configuration file that defines:
- **Rules file paths**: Links to `firestore.rules`, `storage.rules`, `database.rules.json`
- **Emulator ports**: Configures which ports each emulator uses
- **Emulator UI**: Enables the web UI at port 4000
- **Functions settings**: Source directory and build commands

### `.firebaserc`

Defines Firebase project aliases:

```json
{
  "projects": {
    "default": "creatorlink-c160a"
  }
}
```

To switch projects:

```bash
firebase use <project-id>
```

Or add a new alias:

```bash
firebase use --add
```

### `functions/package.json`

Defines Cloud Functions dependencies:
- `firebase-admin`: Firebase Admin SDK for server-side operations
- `firebase-functions`: Cloud Functions runtime
- `openai`: OpenAI API client for AI features
- `axios`: HTTP client for API requests

**Key Scripts:**
- `build`: Compile TypeScript to JavaScript
- `build:watch`: Auto-rebuild on file changes
- `serve`: Build and start functions emulator
- `deploy`: Deploy functions to production
- `logs`: View function logs

### `functions/tsconfig.json`

TypeScript compiler configuration for Cloud Functions. Compiles `src/` to `lib/`.

## Development Tips

### iOS App Connection

The iOS app automatically connects to local emulators when running in **DEBUG** mode. No configuration needed.

### Test Data

After starting emulators, seed test data:

```bash
cd ../emulator-seed
node seed.js
```

This creates 10 test users with conversations and messages.

### Monitoring Costs

AI functions use OpenAI API which incurs costs. Monitor usage:
- Check function logs for API call counts
- View cost stats in function logs (tracked by `rate-limiter.ts`)
- Set rate limits in `CATEGORIZATION_CONFIG` to control spending

### Debugging Functions

1. Start emulators with functions
2. Check Emulator UI logs at `http://localhost:4000`
3. Add `logger.info()` statements in TypeScript code
4. Rebuild functions after code changes
5. Trigger functions by creating messages in the app

### Common Issues

**Functions not triggering:**
- Ensure functions are built: `npm run build`
- Check emulator is running: `firebase emulators:start`
- Verify trigger path matches: `messages/{messageId}`

**TypeScript errors:**
- Run `npm install` in functions directory
- Check `tsconfig.json` settings
- Ensure Node.js version matches `engines` in `package.json` (Node 22)

**OpenAI API errors:**
- Set `OPENAI_API_KEY` in `functions/.env`
- Check API key validity
- Verify rate limits not exceeded

## Production Deployment

### Full Deployment

Deploy everything (rules + functions):

```bash
firebase deploy
```

### Staged Deployment

1. Deploy rules first:
```bash
firebase deploy --only firestore:rules,storage:rules,database:rules
```

2. Test with production console

3. Deploy functions:
```bash
firebase deploy --only functions
```

### Rollback

If functions fail in production:

```bash
firebase functions:delete onMessageCreated
```

Then redeploy a previous version.

## Additional Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
