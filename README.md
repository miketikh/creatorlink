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

### 1. Clone the Repository

```bash
git clone <repository-url>
cd CreatorLink
```

### 2. Firebase Configuration

The project requires a Firebase configuration file that is not included in version control for security reasons.

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new Firebase project or select an existing one
3. Add an iOS app to your Firebase project
4. Download the `GoogleService-Info.plist` file
5. Place it in the `CreatorLink/` directory (same level as the source files)

**Important**: The app will not build without this file.

### 3. Firebase Setup Requirements

Your Firebase project needs the following services enabled:

- **Authentication**: Enable Email/Password and/or Google Sign-In
- **Firestore Database**: Create a database with the following collections:
  - `users`
  - `conversations`
  - `messages`
- **Realtime Database**: Required for presence indicators
- **Cloud Messaging** (optional): For push notifications

### 4. Firestore Security Rules

The project includes a `firestore.rules` file with the necessary security rules. Deploy them to your Firebase project:

**Option 1: Via Firebase Console**
1. Go to Firebase Console → Firestore Database → Rules tab
2. Copy the contents of `firestore.rules` from this repo
3. Paste and publish

**Option 2: Via Firebase CLI**
```bash
firebase deploy --only firestore:rules
```

**Important**: The rules include permissions for:
- Users leaving group conversations
- Updating read receipts and delivery status
- Muting/unmuting conversations
- Standard read/write operations based on participation

### 5. Build and Run

1. Open `CreatorLink.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run (⌘R)

## Project Structure

```
CreatorLink/
├── Models/           # Data models (User, Conversation, Message)
├── Services/         # Firebase services and business logic
├── ViewModels/       # View models for state management
├── Views/            # SwiftUI views
│   ├── Auth/         # Authentication screens
│   └── Chats/        # Chat and conversation screens
└── GoogleService-Info.plist  # Firebase config (not in git)
```

## Troubleshooting

### Build fails with "GoogleService-Info.plist not found"
- Make sure you've added the `GoogleService-Info.plist` file to the `CreatorLink/` directory
- Verify the file is added to the Xcode project target

### Authentication not working
- Check that Authentication is enabled in Firebase Console
- Verify your bundle identifier matches the one in Firebase

### Messages not appearing
- Ensure Firestore Database is created and rules are configured
- Check that Firestore and Realtime Database are in the same region

### Presence indicators not updating
- Verify Firebase Realtime Database is enabled
- Check that the app has proper read/write permissions

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
