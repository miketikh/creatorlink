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
- `aiResponseModeEnabled: Bool?` - *Optional* flag to enable AI draft response generation for this user (defaults to false if nil, backward compatible)

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

#### AI User Profile

**Special User ID:** `ai-assistant` (defined in `AIConstants.AI_USER_ID`)

**Purpose:** System user that represents the AI assistant in conversations with AI features enabled.

**Required Fields:**
```json
{
  "id": "ai-assistant",
  "displayName": "AI Assistant",
  "email": "ai@creatorlink.app",
  "photoURL": "https://ui-avatars.com/api/?name=AI&background=6366f1&color=fff",
  "isOnline": true,
  "lastSeen": {
    "_seconds": 1729699200,
    "_nanoseconds": 0
  }
}
```

**Setup Notes:**
- AI user must be created in Firestore before being added to conversations
- AI user ID must match `AIConstants.AI_USER_ID` constant in iOS app
- AI user ID must match what Python AI service and Firebase Cloud Functions use
- `isOnline` should be `true` to make AI always appear available
- `photoURL` uses UI Avatars API with indigo background (6366f1) to distinguish from regular users
- Creation options:
  - Manual creation via Firebase Console (for development)
  - Seed data script (recommended for Firebase Emulator)
  - One-time setup script via Firebase Admin SDK (for production)
- AI user follows standard UserProfile structure - no special model needed

**TODO:** Update seed data script at `/Users/Gauntlet/gauntlet/CreatorLink/firebase/seed-data.js` to automatically create AI user document during Firebase Emulator initialization (Phase 2, PR 2.7)

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
- `aiEnabled: Bool?` - *Optional* whether AI assistant is enabled for this conversation (nil for existing conversations without AI)
- `aiConfig: AIConfig?` - *Optional* AI configuration settings (only present when aiEnabled is true)
- `categoryTags: [ConversationTag]?` - *Optional* array of category tags (business, collaboration, social, fan)
- `primaryCategory: ConversationTag?` - *Optional* denormalized primary category for efficient filtering
- `tagMetadata: TagMetadata?` - *Optional* AI confidence and override tracking for tag suggestions
- `tagsByUser: [String: UserTagData]?` - *Optional* per-user tag data including category and status tags (userId → UserTagData object)

#### AIConfig Struct

**Purpose:** Configuration settings for AI assistant features in a conversation.

**Fields:**
- `faqDetectionEnabled: Bool` - Whether FAQ detection is enabled (default: true)
- `minimumSimilarity: Double` - Minimum similarity threshold for FAQ matching (default: 0.85, range: 0.0-1.0)

**Notes:**
- AIConfig is a nested struct within Conversation
- Only present when `aiEnabled` is true
- Default values make it easy to enable AI with sensible defaults
- minimumSimilarity of 0.85 represents 85% similarity threshold for FAQ matching

#### TagMetadata Struct

**Purpose:** Tracks AI-suggested tags and user override flags for smart categorization.

**Fields:**
- `aiSuggestedCategory: ConversationTag?` - *Optional* AI's suggested primary category
- `aiConfidenceScore: Double?` - *Optional* confidence score for AI suggestion (0.0-1.0)
- `userOverrideCategory: Bool` - Flag indicating if user manually set category (default: false)
- `userOverrideStatus: Bool` - Flag indicating if user manually set status (default: false)
- `lastAIAnalysisTime: Date?` - *Optional* timestamp of last AI analysis

**Notes:**
- TagMetadata is a nested struct within Conversation
- Only present when tags are being managed (nil for conversations without tags)
- Override flags help AI learn from user corrections
- Confidence score indicates how certain AI is about category suggestion
- All fields except override flags are optional

#### UserTagData Struct

**Purpose:** Stores per-user tag data for category and status tags in conversations.

**Fields:**
- `categoryTags: [ConversationTag]?` - *Optional* per-user category tags (overrides conversation-level categoryTags for this user)
- `statusTags: [StatusTag]?` - *Optional* per-user status tags (no conversation-level default exists)

**Notes:**
- UserTagData is a nested struct within Conversation
- Enables different users to have different tag perspectives on the same conversation
- Category tags can be overridden per-user but default to conversation-level tags if not specified
- Status tags are always per-user (no conversation-level statusTags field exists)
- Only present in tagsByUser map when user has set custom tags

#### Relationships

- References: `participantIds` → `users.id`, `lastMessageSenderId` → `users.id`
- Referenced by: `Message.conversationId`

#### Example Document (Group Chat)

```json
{
  "id": "conv456",
  "participantIds": ["user123", "user456", "user789", "ai-assistant"],
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
  "mutedBy": ["user789"],
  "aiEnabled": true,
  "aiConfig": {
    "faqDetectionEnabled": true,
    "minimumSimilarity": 0.85
  },
  "categoryTags": ["collaboration"],
  "primaryCategory": "collaboration",
  "tagMetadata": {
    "aiSuggestedCategory": "collaboration",
    "aiConfidenceScore": 0.92,
    "userOverrideCategory": false,
    "userOverrideStatus": true,
    "lastAIAnalysisTime": {
      "_seconds": 1729699100,
      "_nanoseconds": 0
    }
  },
  "tagsByUser": {
    "user123": {
      "categoryTags": ["collaboration"],
      "statusTags": ["awaitingReply"]
    },
    "user456": {
      "categoryTags": ["collaboration"],
      "statusTags": ["needsResponse", "urgent"]
    },
    "user789": {
      "categoryTags": ["business"],
      "statusTags": []
    }
  }
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
- `aiEnabled` and `aiConfig` are optional for backward compatibility - existing conversations without AI work without migration
- When AI is enabled, "ai-assistant" user ID is added to `participantIds`
- AIConfig should only exist when aiEnabled is true (enforced in UI layer)
- **Tag Fields (all optional for backward compatibility):**
  - `categoryTags`, `statusTags`, `primaryCategory`, `tagMetadata`, and `tagsByUser` are all optional
  - Existing conversations without tags continue to work without migration
  - `tagsByUser` enables per-user tag preferences in group chats (different users can categorize the same conversation differently)
  - `primaryCategory` is denormalized for efficient Firestore `.whereField` filtering
  - Tag raw values are stored as strings (e.g., "business", "urgent") for Firestore compatibility
  - `tagsByUser` map structure: `{ "userId": ["tag1", "tag2"], ... }`

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
- `metadata: [String: String]?` - *Optional* metadata map for AI features and system messages

#### AI Metadata Keys

When `metadata` is present on AI-generated messages, it may contain the following standard keys:

- `"ai_generated"` or `"isAIMessage"` - Flags message as AI-generated (value: "true")
  - Python service currently uses `"ai_generated"`
  - iOS should check both keys for compatibility
- `"faqReference"` - Message ID of the original answer being referenced (value: message document ID)
- `"matchConfidence"` - Similarity score as string (value: "0.0" to "1.0", e.g., "0.92")
- `"matchedQuestion"` - The original question text that was matched (value: question string)
- `"suggestedAnswer"` - The AI's suggested answer text to display in the FAQ link (value: answer string)
- `"isSystemMessage"` - Flags system messages like member join/leave (value: "true")

**Notes:**
- All metadata values must be strings (Firestore `map<string, string>` limitation)
- Metadata is set by the Python AI service for AI-generated messages
- Metadata is optional and only present on AI messages and system messages
- Regular user messages have `metadata: null`

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

#### Example Document (AI-Generated Message)

```json
{
  "id": "msg791",
  "conversationId": "conv456",
  "senderId": "ai-assistant",
  "participantIds": ["user123", "user456", "user789", "ai-assistant"],
  "text": "This question was previously answered here: [link to message]",
  "timestamp": {
    "_seconds": 1729699400,
    "_nanoseconds": 0
  },
  "status": "sent",
  "readBy": {},
  "imageUrl": null,
  "metadata": {
    "ai_generated": "true",
    "faqReference": "msg789",
    "matchConfidence": "0.92",
    "matchedQuestion": "What are your rates?",
    "suggestedAnswer": "My rates are $500/hour for consulting work."
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

### Collection: `knowledge`

**TypeScript Model:** `KnowledgeFact` (firebase/functions/src/ai/types.ts)

**Purpose:** Stores extracted factual information from user messages with vector embeddings for semantic search.

#### Fields

- `id: string` - Firestore document ID (auto-generated)
- `userId: string` - ID of the user this knowledge belongs to
- `text: string` - Normalized, self-contained fact text (e.g., "User has a dog named Max")
- `embedding: number[]` - Vector representation for semantic search (1536 dimensions from OpenAI text-embedding-3-small model)
- `createdAt: Date` - Timestamp when the fact was created (stored as Firestore Timestamp)
- `updatedAt: Date` - Timestamp when the fact was last updated (stored as Firestore Timestamp)

#### Relationships

- References: `userId` → `users.id`

#### Example Document

```json
{
  "id": "fact123",
  "userId": "user456",
  "text": "User charges $500/hour for consulting",
  "embedding": [0.123, -0.456, 0.789, ...], // 1536-dimensional vector
  "createdAt": {
    "_seconds": 1729699200,
    "_nanoseconds": 0
  },
  "updatedAt": {
    "_seconds": 1729699200,
    "_nanoseconds": 0
  }
}
```

#### Notes

- **Minimal schema**: Only essential fields (userId, text, embedding, timestamps)
- **Normalized facts**: Text field stores complete, self-contained sentences that make sense without conversation context
  - Example: "Yes" + context → "User has one dog"
  - Example: "Max" + context ("dog's name?") → "User's dog is named Max"
- **Vector embeddings**: Enable semantic search for relevant knowledge retrieval
  - Uses OpenAI text-embedding-3-small model (1536 dimensions)
  - Stored using `FieldValue.vector()` for Firestore native vector search
- **Deduplication**: Vector similarity (>0.95) used to prevent duplicate facts
- **Security**: Users can only read/write their own knowledge facts
- **Indexing**: Composite index on `userId` for efficient queries
  - Index: `userId` (ascending) + `createdAt` (descending)

#### Security Rules Requirements

```javascript
// Users can only access their own knowledge facts
match /knowledge/{factId} {
  allow read: if request.auth != null && request.auth.uid == resource.data.userId;
  allow write: if request.auth != null && request.auth.uid == request.resource.data.userId;
}
```

---

### Subcollection: `users/{userId}/voiceProfiles/{category}`

**TypeScript Model:** `VoiceProfile` (firebase/functions/src/ai/types.ts)

**Purpose:** Stores user's communication style preferences per conversation category. Profiles are static, manually authored configurations used for AI draft generation.

#### Fields

- `userId: string` - ID of the user this voice profile belongs to
- `category: ConversationCategory` - Which conversation category this profile applies to (business, collaboration, social, fan)
- `styleRules: Record<string, any>` - Arbitrary JSON containing style preferences (passed directly to AI as context)
- `createdAt: Date` - Timestamp when the profile was created (stored as Firestore Timestamp)
- `lastUpdated: Date` - Timestamp when the profile was last updated (stored as Firestore Timestamp)

#### Relationships

- References: `userId` → `users.id`, `category` → `ConversationCategory` enum

#### Notes

- **Subcollection structure**: Voice profiles are stored as subcollections under each user document
- **Document ID**: The document ID is the category name (e.g., "business", "social")
- **Arbitrary JSON**: The `styleRules` field has no enforced structure - it's arbitrary JSON passed to AI for draft generation
- **Example structure**: See `/Docs/Features/ai-voice/voice_json_example.md` for a sample styleRules format
- **Static configuration**: Profiles are manually authored, not learned from messages (learning is Phase 5)
- **Per-category profiles**: Each user can have different writing styles for different conversation categories
- **Security**: Users can only read/write their own voice profiles

#### Security Rules Requirements

```javascript
// Users can only access their own voice profiles
match /users/{userId}/voiceProfiles/{category} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
}
```

---

### Subcollection: `conversations/{conversationId}/drafts/{userId}`

**TypeScript Model:** `MessageDraft` (firebase/functions/src/ai/types.ts)
**Swift Model:** `MessageDraft` (CreatorLink/Models/MessageDraft.swift)

**Purpose:** Stores AI-generated draft responses for users in conversations. Simple schema with just the essentials for functionality.

#### Fields

- `id?: string` - Firestore document ID (optional, auto-generated)
- `conversationId: string` - ID of the parent conversation
- `userId: string` - ID of the user this draft is for (the recipient who will send it)
- `text: string` - Draft message text generated by AI
- `category: ConversationCategory` - Conversation category (business, collaboration, social, fan)
- `generatedAt: Date` - Timestamp when the draft was first generated (stored as Firestore Timestamp)
- `updatedAt: Date` - Timestamp when the draft was last updated (stored as Firestore Timestamp)
- `userTouched?: boolean` - *Optional* flag indicating user manually edited the draft (prevents auto-updates)

#### Relationships

- References: `conversationId` → `conversations.id`, `userId` → `users.id`

#### Example Document

```json
{
  "id": "alice123",
  "conversationId": "conv456",
  "userId": "alice123",
  "text": "My consulting rate is $500/hour. I'm available next week if that works for you!",
  "category": "business",
  "generatedAt": {
    "_seconds": 1729699200,
    "_nanoseconds": 0
  },
  "updatedAt": {
    "_seconds": 1729699300,
    "_nanoseconds": 0
  },
  "userTouched": false
}
```

#### Notes

- **Subcollection structure**: Drafts are stored as subcollections under conversations
- **Document ID**: The document ID is the userId (one draft per user per conversation)
- **Overwrite behavior**: New drafts overwrite existing drafts using Firestore `set()` with merge
- **Update logic**: Drafts update when new messages arrive unless `userTouched` is true or draft is too old (>60 minutes)
- **Simple schema**: No debugging fields - just the conversation, user, text, category, timestamps, and userTouched flag
- **Security**: Users can only read/write drafts for conversations they participate in
- **Indexing**: No complex queries needed (simple document get by userId)

#### Security Rules Requirements

```javascript
// Users can only access drafts for conversations they participate in
match /conversations/{conversationId}/drafts/{userId} {
  allow read: if request.auth != null &&
    request.auth.uid == userId &&
    request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
  allow write: if request.auth != null &&
    request.auth.uid == userId &&
    request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
}
```

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

### Enum: `ConversationTag`

**Swift Model:** `ConversationTag` (ConversationTag.swift)

**Purpose:** Represents conversation category tags for organizing conversations.

#### Values

- `business` - Business-related conversations
- `collaboration` - Collaboration and project work
- `social` - Social and casual conversations
- `fan` - Fan interactions and community

#### Raw Value Type

`String` (Codable, Hashable)

#### Computed Properties

- `emoji: String` - Emoji representation (💼, 🤝, 💬, ⭐)
- `displayName: String` - User-facing display name

#### Example Usage in Firestore

```json
{
  "categoryTags": ["business", "collaboration"],
  "primaryCategory": "business"
}
```

#### Notes

- Stored as raw string values in Firestore
- Maximum of 2 category tags recommended per conversation
- Used in `categoryTags`, `primaryCategory`, and `tagMetadata.aiSuggestedCategory` fields

---

### Enum: `StatusTag`

**Swift Model:** `StatusTag` (StatusTag.swift)

**Purpose:** Represents conversation status tags for tracking message states.

#### Values

- `urgent` - Urgent messages requiring immediate attention
- `needsResponse` - Awaiting user response
- `awaitingReply` - Awaiting reply from others
- `resolved` - Conversation resolved

#### Raw Value Type

`String` (Codable, Hashable)

#### Computed Properties

- `emoji: String` - Emoji representation (🔥, ❓, ⏰, ✅)
- `displayName: String` - User-facing display name

#### Example Usage in Firestore

```json
{
  "statusTags": ["urgent", "needsResponse"]
}
```

#### Notes

- Stored as raw string values in Firestore
- `resolved` is mutually exclusive with `urgent` and `needsResponse`
- If `urgent` is present, `needsResponse` should also be present (business rule)
- Used in `statusTags` field only

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
