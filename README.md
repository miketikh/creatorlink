# CreatorLink

A modern iOS messaging application built with SwiftUI and Firebase, featuring real-time chat, group conversations, presence indicators, and read receipts.

## Features

- **Real-time Messaging**: Instant one-on-one and group conversations
- **Presence Indicators**: See when users are online with live status updates
- **Group Chats**: Create and manage group conversations with multiple participants
- **Read Receipts**: Track message delivery and read status
- **Typing Indicators**: See when others are typing
- **Message Notifications**: Push notifications for new messages
- **User Profiles**: Display names and profile photos

## Requirements

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+
- Firebase account

## Setup

### Option A: Local Development with Firebase Emulators (Recommended)

This is the fastest way to get started for local development and testing.

#### 1. Clone the Repository

```bash
git clone <repository-url>
cd CreatorLink
```

#### 2. Install Firebase CLI

```bash
npm install -g firebase-tools
```

#### 3. Install Emulator Seed Dependencies

```bash
cd emulator-seed
npm install
cd ..
```

#### 4. Start Firebase Emulators

```bash
cd firebase
firebase emulators:start
```

This will start:
- **Authentication Emulator** (port 9099)
- **Firestore Emulator** (port 8080)
- **Realtime Database Emulator** (port 9000)
- **Storage Emulator** (port 9199)
- **Emulator UI** (http://localhost:4000)

#### 5. Seed Test Data (Optional)

In a new terminal, seed the emulators with test users and conversations:

```bash
cd emulator-seed
node seed.js
```

This creates 10 test users (Alice, Bob, Carol, etc.) with conversations and messages. All users have password: `password`

#### 6. Build and Run

1. Open `CreatorLink.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run (⌘R)

The app will automatically connect to the local emulators in DEBUG mode.

**Test Users:**
- alice.johnson@test.com / password
- bob.martinez@test.com / password
- carol.williams@test.com / password
- (and 7 more - see `emulator-seed/seed.js`)

### Option B: Production Firebase Setup

For production deployment or testing with real Firebase services.

#### 1. Clone the Repository

```bash
git clone <repository-url>
cd CreatorLink
```

#### 2. Firebase Configuration

The project requires a Firebase configuration file that is not included in version control for security reasons.

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new Firebase project or select an existing one
3. Add an iOS app to your Firebase project
4. Download the `GoogleService-Info.plist` file
5. Place it in the `CreatorLink/` directory (same level as the source files)

**Important**: The app will not build without this file.

#### 3. Firebase Setup Requirements

Your Firebase project needs the following services enabled:

- **Authentication**: Enable Email/Password and/or Google Sign-In
- **Firestore Database**: Create a database with the following collections:
  - `users`
  - `conversations`
  - `messages`
- **Realtime Database**: Required for presence indicators and typing indicators
- **Cloud Messaging** (optional): For push notifications

#### 4. Deploy Security Rules

Deploy the security rules to your Firebase project:

```bash
cd firebase
firebase deploy --only firestore:rules,storage:rules,database:rules
```

Or manually via Firebase Console by copying contents from the `firebase/` directory:
- `firebase/firestore.rules`
- `firebase/storage.rules`
- `firebase/database.rules.json`

#### 5. Build and Run

1. Open `CreatorLink.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run in **Release** mode to connect to production Firebase

## Project Structure

- **CreatorLink/** - iOS app built with SwiftUI. See the Xcode project to build and run.
- **firebase/** - Firebase emulator configuration and Cloud Functions. See `firebase/README.md` for setup details.
- **emulator-seed/** - Scripts for populating Firebase emulators with test data. See `emulator-seed/README.md` for usage.
- **python-service/** - Planned Python service for AI features with Qdrant vector storage (not currently in use). See `python-service/README.md` for details.
- **Docs/** - Project documentation and planning materials.

## Troubleshooting

### Local Development Issues

#### Emulators not starting
- Ensure Firebase CLI is installed: `firebase --version`
- Check that ports 9099, 8080, 9000, 9199, and 4000 are not in use
- Try running: `firebase emulators:start --only auth,firestore,database,storage`

#### App not connecting to emulators
- Verify emulators are running at `http://localhost:4000`
- Ensure you're running the app in **DEBUG** mode (default in Xcode)
- Check console logs for emulator connection messages

#### Seed script fails
- Run `npm install` in the `emulator-seed/` directory
- Ensure emulators are running before running seed script
- Check that `@faker-js/faker` is installed

#### No test data appearing
- Make sure you ran the seed script after starting emulators
- Check the Emulator UI at `http://localhost:4000` to verify data
- Try restarting the emulators and re-running the seed script

### Production Issues

#### Build fails with "GoogleService-Info.plist not found"
- Make sure you've added the `GoogleService-Info.plist` file to the `CreatorLink/` directory
- Verify the file is added to the Xcode project target

#### Authentication not working
- Check that Authentication is enabled in Firebase Console
- Verify your bundle identifier matches the one in Firebase

#### Messages not appearing
- Ensure Firestore Database is created and rules are deployed
- Check that Firestore and Realtime Database are in the same region

#### Presence/typing indicators not updating
- Verify Firebase Realtime Database is enabled in Firebase Console
- Check that database rules are deployed
- Ensure the app has proper read/write permissions

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **Firebase Authentication**: User authentication and management
- **Firestore**: Real-time database for messages and conversations
- **Firebase Realtime Database**: User presence and online status
- **Observation Framework**: Modern state management with `@Observable`

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Add your license here]
