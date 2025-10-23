# Firebase Data Models

This document provides comprehensive documentation for all Firebase data structures used in the CreatorLink iOS app. It includes Firestore collections, Firebase Realtime Database paths, and all related Swift models.

---

## Table of Contents

1. [Firestore Collections](#firestore-collections)
   - [users](#collection-users)
   - [conversations](#collection-conversations)
   - [messages](#collection-messages)
2. [Firebase Realtime Database](#firebase-realtime-database)
   - [presence](#rtdb-presence)
   - [typing](#rtdb-typing)
3. [Enums](#enums)
   - [MessageStatus](#enum-messagestatus)
4. [Data Relationships](#data-relationships)

---

## Firestore Collections

### Collection: `users`

**Swift Model:** `UserProfile` (UserProfile.swift)

**Purpose:** Stores user profile information including online status and display preferences.

#### Fields

- `id: String` - User ID (document ID, corresponds to Firebase Auth UID)
- `displayName: String` - User's display name (max 50 characters)
- `email: String` - User's email address
- `photoURL: String?` - *Optional* profile photo URL (must start with http:// or https://, empty string for default avatar)
- `isOnline: Bool` - Current online status (synced from Realtime Database)
- `lastSeen: Date` - Timestamp of last activity (stored as Firestore Timestamp, auto-updated on presence changes)

#### Relationships

- Referenced by: `Message.senderId`, `Conversation.participantIds`, `Message.readBy` keys, `Conversation.lastMessageSenderId`, `Conversation.mutedBy`

#### Example Document

```json
{
  "id": "user123",
  "displayName": "Alice Johnson",
  "email": "alice@example.com",
  "photoURL": "https://example.com/avatar.jpg",
  "isOnline": true,
  "lastSeen": {
    "_seconds": 1729699200,
    "_nanoseconds": 0
  }
}
```

#### Notes

- Document ID is set to the Firebase Auth UID
- `photoURL` can be empty string to use fallback avatar
- `lastSeen` uses `FieldValue.serverTimestamp()` for consistency
- `isOnline` is denormalized from Realtime Database for query performance

---

### Collection: `conversations`

**Swift Model:** `Conversation` (Conversation.swift)

**Purpose:** Stores conversation metadata for both one-on-one and group chats.

#### Fields

- `@DocumentID id: String?` - Firestore document ID (auto-generated)
- `participantIds: [String]` - Array of user IDs (sorted for consistent lookups)
- `lastMessage: String` - Text of the most recent message
- `lastMessageTime: Date` - Timestamp of the most recent message (stored as Firestore Timestamp)
- `isGroupChat: Bool` - `true` for group chats (>2 participants), `false` for one-on-one
- `groupName: String?` - *Optional* custom name for group chats
- `groupImageUrl: String?` - *Optional* custom image URL for group chats (auto-generated placeholder if not provided)
- `lastMessageSenderId: String?` - *Optional* ID of user who sent the last message
- `lastMessageStatus: MessageStatus?` - *Optional* status of the last message (enum: sending, sent, delivered, read)
- `unreadCounts: [String: Int]?` - *Optional* denormalized unread count per user (userId: count)
- `mutedBy: [String]?` - *Optional* array of user IDs who have muted this conversation

#### Relationships

- References: `participantIds` → `users.id`, `lastMessageSenderId` → `users.id`
- Referenced by: `Message.conversationId`

#### Example Document (Group Chat)

```json
{
  "id": "conv456",
  "participantIds": ["user123", "user456", "user789"],
  "lastMessage": "See you tomorrow!",
  "lastMessageTime": {
    "_seconds": 1729699200,
    "_nanoseconds": 0
  },
  "isGroupChat": true,
  "groupName": "Project Team",
  "groupImageUrl": "https://ui-avatars.com/api/?name=P&background=random",
  "lastMessageSenderId": "user123",
  "lastMessageStatus": "read",
  "unreadCounts": {
    "user123": 0,
    "user456": 2,
    "user789": 1
  },
  "mutedBy": ["user789"]
}
```

#### Example Document (One-on-One Chat)

```json
{
  "id": "conv123",
  "participantIds": ["user123", "user456"],
  "lastMessage": "Hello!",
  "lastMessageTime": {
    "_seconds": 1729699200,
    "_nanoseconds": 0
  },
  "isGroupChat": false,
  "groupName": null,
  "groupImageUrl": null,
  "lastMessageSenderId": "user123",
  "lastMessageStatus": "sent",
  "unreadCounts": {
    "user123": 0,
    "user456": 1
  },
  "mutedBy": null
}
```

#### Notes

- `participantIds` is always sorted alphabetically for consistent conversation lookups
- `groupName` max length is 35 characters
- `groupImageUrl` uses UI Avatars API placeholder if not provided for group chats
- `unreadCounts` is denormalized for performance (updated via `FieldValue.increment()`)
- Uses `FieldValue.arrayUnion()` and `FieldValue.arrayRemove()` for concurrent-safe participant management
- Last person leaving a group triggers conversation deletion
- System messages use `senderId: "system"` for member join/leave events

---

### Collection: `messages`

**Swift Model:** `Message` (Message.swift)

**Purpose:** Stores individual messages within conversations.

#### Fields

- `@DocumentID id: String?` - Firestore document ID (auto-generated)
- `conversationId: String` - ID of the parent conversation
- `senderId: String` - ID of the user who sent the message (or "system" for system messages)
- `participantIds: [String]` - Denormalized array of participant IDs (required for security rules)
- `text: String` - Message text content
- `timestamp: Date` - When the message was sent (stored as Firestore Timestamp)
- `status: MessageStatus` - Delivery status (enum: sending, sent, delivered, read)
- `readBy: [String: Date]` - Map of userId to timestamp when read (stored as Firestore Timestamps)
- `imageUrl: String?` - *Optional* image URL for media messages (for future Phase 6)
- `metadata: [String: String]?` - *Optional* metadata map for AI features and system messages (for future Phase 8)

#### Relationships

- References: `conversationId` → `conversations.id`, `senderId` → `users.id`, `participantIds` → `users.id`, `readBy` keys → `users.id`

#### Example Document (Regular Message)

```json
{
  "id": "msg789",
  "conversationId": "conv123",
  "senderId": "user123",
  "participantIds": ["user123", "user456"],
  "text": "Hello, how are you?",
  "timestamp": {
    "_seconds": 1729699200,
    "_nanoseconds": 0
  },
  "status": "read",
  "readBy": {
    "user123": {
      "_seconds": 1729699200,
      "_nanoseconds": 0
    },
    "user456": {
      "_seconds": 1729699250,
      "_nanoseconds": 0
    }
  },
  "imageUrl": null,
  "metadata": null
}
```

#### Example Document (System Message)

```json
{
  "id": "msg790",
  "conversationId": "conv456",
  "senderId": "system",
  "participantIds": ["user123", "user456", "user789"],
  "text": "Alice Johnson added a new member to the group",
  "timestamp": {
    "_seconds": 1729699300,
    "_nanoseconds": 0
  },
  "status": "sent",
  "readBy": {},
  "imageUrl": null,
  "metadata": {
    "isSystemMessage": "true"
  }
}
```

#### Notes

- Uses `@DocumentID` property wrapper for Firestore document ID management
- `participantIds` is denormalized for security rules (validates user has access)
- `readBy` uses dotted notation for updates: `readBy.{userId}` with `FieldValue.serverTimestamp()`
- Batch read operations use Firestore batch writes for efficiency
- Reading messages decrements `unreadCounts` in the parent conversation
- System messages have `senderId: "system"` and `metadata.isSystemMessage: true`
- `imageUrl` and `metadata` stored as `NSNull()` when nil in Firestore
- Custom `Hashable` and `Equatable` implementations exclude `readBy` and `metadata` for performance

---

## Firebase Realtime Database

### RTDB: `presence`

**Path:** `/presence/{userId}`

**Purpose:** Real-time online/offline status tracking with automatic disconnect handling.

#### Structure

```
/presence
  /{userId}
    /isOnline: Boolean
    /lastSeen: ServerTimestamp (milliseconds since epoch)
```

#### Fields

- `isOnline: Boolean` - Current online status
- `lastSeen: Number` - Server timestamp in milliseconds

#### Example Data

```json
{
  "presence": {
    "user123": {
      "isOnline": true,
      "lastSeen": 1729699200000
    },
    "user456": {
      "isOnline": false,
      "lastSeen": 1729699100000
    }
  }
}
```

#### Notes

- Uses `onDisconnect()` handlers to automatically set `isOnline: false` when user disconnects
- `lastSeen` uses `ServerValue.timestamp()` for consistency
- Synced to Firestore `users` collection for query performance
- Offline timer provides grace period before marking user offline (handles brief disconnects)

---

### RTDB: `typing`

**Path:** `/typing/{conversationId}/{userId}`

**Purpose:** Real-time typing indicator tracking with auto-expiration.

#### Structure

```
/typing
  /{conversationId}
    /{userId}
      /isTyping: Boolean
      /timestamp: ServerTimestamp (milliseconds since epoch)
```

#### Fields

- `isTyping: Boolean` - Whether user is currently typing
- `timestamp: Number` - Server timestamp in milliseconds

#### Example Data

```json
{
  "typing": {
    "conv123": {
      "user456": {
        "isTyping": true,
        "timestamp": 1729699200000
      }
    }
  }
}
```

#### Notes

- Automatically clears after 3 seconds of inactivity (client-side timer)
- Uses `onDisconnect()` handlers to clear typing state on disconnect
- Listeners filter out typing states older than 5 seconds
- Current user's typing state is excluded from listener results
- Uses `removeValue()` to clear typing state (not set to false)

---

## Enums

### Enum: `MessageStatus`

**Swift Model:** `MessageStatus` (MessageStatus.swift)

**Purpose:** Represents message delivery and read status.

#### Values

- `sending` - Message is being sent to server
- `sent` - Message successfully written to Firestore
- `delivered` - Message delivered to recipient (not currently used)
- `read` - Message read by recipient

#### Raw Value Type

`String` (Codable, Hashable)

#### Example Usage in Firestore

```json
{
  "status": "read"
}
```

#### Notes

- Stored as raw string value in Firestore
- `delivered` status is defined but not currently implemented
- Status transitions: `sending` → `sent` → `read`
- Batch read operations update multiple messages to `read` status

---

## Data Relationships

### Entity Relationship Diagram

```
users (Firestore)
  └─ id (document ID)
      ├─ Referenced by: Message.senderId
      ├─ Referenced by: Message.readBy keys
      ├─ Referenced by: Conversation.participantIds
      ├─ Referenced by: Conversation.lastMessageSenderId
      ├─ Referenced by: Conversation.mutedBy
      ├─ Synced with: presence/{userId} (RTDB)
      └─ Used in: typing/{conversationId}/{userId} (RTDB)

conversations (Firestore)
  └─ id (document ID)
      └─ Referenced by: Message.conversationId

messages (Firestore)
  └─ id (document ID)

presence (RTDB)
  └─ /presence/{userId}
      └─ Syncs to: users.isOnline, users.lastSeen

typing (RTDB)
  └─ /typing/{conversationId}/{userId}
      └─ References: conversations.id, users.id
```

### Key Relationships

1. **User → Conversations (Many-to-Many)**
   - A user can participate in multiple conversations
   - A conversation can have multiple participants
   - Join table: `Conversation.participantIds` array

2. **Conversation → Messages (One-to-Many)**
   - A conversation contains multiple messages
   - A message belongs to one conversation
   - Foreign key: `Message.conversationId`

3. **User → Messages (One-to-Many as Sender)**
   - A user can send multiple messages
   - A message has one sender
   - Foreign key: `Message.senderId`

4. **User → Messages (Many-to-Many as Readers)**
   - A user can read multiple messages
   - A message can be read by multiple users
   - Join map: `Message.readBy` dictionary

5. **User ↔ Presence (One-to-One)**
   - Real-time online status in RTDB
   - Denormalized to Firestore for queries
   - Bidirectional sync

6. **Conversation × User ↔ Typing (Many-to-Many)**
   - Real-time typing indicators in RTDB
   - Temporary data (auto-expires)
   - Not persisted to Firestore

### Data Denormalization

The following data is denormalized for performance:

1. **Conversation.lastMessage, lastMessageTime, lastMessageSenderId, lastMessageStatus**
   - Duplicated from latest message
   - Enables efficient conversation list queries without joining messages

2. **Conversation.unreadCounts**
   - Count of unread messages per user
   - Updated atomically via `FieldValue.increment()`
   - Avoids expensive count queries on messages collection

3. **Message.participantIds**
   - Duplicated from parent conversation
   - Required for Firestore security rules (validates user access)

4. **users.isOnline, users.lastSeen**
   - Duplicated from Realtime Database presence
   - Enables Firestore queries on online status
   - Synced bidirectionally

### Security Model

All Firestore security rules use the following patterns:

1. **User must be authenticated**: `request.auth != null`
2. **User must be participant**: `request.auth.uid in resource.data.participantIds`
3. **User can only modify own data**: `request.auth.uid == userId`

RTDB rules follow similar patterns with user-based path restrictions.

---

## Development Notes

### Firestore Configuration

- **Emulator URL (DEBUG)**: `localhost:8080`
- **Production**: Firebase project `creatorlink-c160a`

### Realtime Database Configuration

- **Emulator URL (DEBUG)**: `http://127.0.0.1:9000?ns=creatorlink-c160a`
- **Production**: Firebase project `creatorlink-c160a`

### Key Implementation Patterns

1. **Optimistic Updates**: Messages show as "sending" immediately, then update to "sent"
2. **Atomic Operations**: Use `FieldValue.arrayUnion()`, `arrayRemove()`, `increment()` for concurrent safety
3. **Batch Operations**: Batch writes for marking multiple messages as read
4. **Server Timestamps**: Always use `FieldValue.serverTimestamp()` for consistency
5. **Null Handling**: Use `NSNull()` for nullable fields in Firestore writes
6. **Real-time Listeners**: Clean up with `ListenerRegistration.remove()` or `DatabaseReference.removeObserver()`

### Testing Data

Seed script available at: `/Users/Gauntlet/gauntlet/CreatorLink/firebase/seed-data.js`

---

**Last Updated:** October 23, 2025
**iOS App Version:** Development
**Firebase Project:** creatorlink-c160a
