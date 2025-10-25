# Instructions to always follow

- DO NOT EVER make assumptions. Do not just try running a specific emulator, or assume that something is available at a path. ALWAYS verify, for example for the emulators by first checking which are running. Another example, do not just guess which ios version we're using for, check or ask.
- The year is 2025. If you're asked for searching things, search for the latest documentation for the time
- ALWAYS use the tools you have available over bash commands. If reading files, use read, if searching use the directory search tools, if writing use write tools. ONLY ask for bash command permission when absolutely necessary. Use MCP tools > your tools > bash commands as last resort

## Project Overview

CreatorLink is an iOS messaging application with AI-powered features built using:
- **SwiftUI** - Modern declarative UI framework for iOS 17.0+
- **Firebase** - Backend services (Authentication, Firestore, Realtime Database, Storage)
- **TypeScript Cloud Functions** - Server-side AI processing and message handling
- **Local Emulator Suite** - Full Firebase emulation for development and testing

Key features include real-time messaging, group chats, AI assistant integration, conversation categorization, presence indicators, typing indicators, and read receipts.

## Main Directories

- **CreatorLink/** - iOS application (Xcode project)
  - Models/ - Data models (Conversation, Message, UserProfile, Tags)
  - Services/ - Firebase service wrappers and business logic
  - ViewModels/ - SwiftUI view models using @Observable
  - Views/ - SwiftUI views organized by feature (Auth, Chats, Profile, Common)
  - Utilities/ - Helper functions and extensions
  - Docs/ - In-app documentation and feature specs

- **firebase/** - Firebase configuration and backend
  - functions/src/ - TypeScript Cloud Functions
  - functions/src/ai/ - AI-related functions (categorization, FAQ matching, question detection)
  - firestore.rules - Firestore security rules
  - database.rules.json - Realtime Database security rules
  - storage.rules - Storage security rules

- **emulator-seed/** - Test data generation scripts
  - constants.js - Shared constants (users, AI config) - ALWAYS reference this
  - utils.js - Helper functions for seeding
  - seed-files/ - Individual seed scripts for different scenarios
  - See db-types.md in project root for database schema

- **python-service/** - Planned Python service for vector storage (not currently in use)

## Implementation Patterns

### iOS App (CreatorLink/)

**Architecture: MVVM with SwiftUI**

**Key Patterns:**
- Services are singletons (`.shared`) that wrap Firebase APIs
- ViewModels use `@Observable` macro (modern Swift observation)
- Views subscribe to ViewModels which update automatically on state changes
- Firebase emulators are configured in DEBUG mode (see CreatorLinkApp.swift AppDelegate)

**Common Service Patterns:**
- AuthService - Authentication, user session management
- ConversationService - Conversation CRUD, AI config, categorization
- MessageService - Send/receive messages, read receipts
- PresenceService - User online status (Realtime Database)
- TypingService - Typing indicators (Realtime Database)
- TaggingService - AI tagging and categorization
- UserService - User profile management

**ViewModel Patterns:**
- ViewModels marked with `@Observable` for automatic UI updates
- Typically injected via `@State` or `@StateObject` in views
- Handle business logic and Firebase service orchestration
- Examples: ChatViewModel, ConversationsViewModel, GroupInfoViewModel

**Model Patterns:**
- Conform to `Codable` for Firestore encoding/decoding
- Use `@DocumentID` for Firestore document IDs
- Timestamp fields typically use `Timestamp` from FirebaseFirestore
- See AIConstants.swift for AI-related constants (must match Cloud Functions)

### Firebase Functions (firebase/functions/src/)

**TypeScript Cloud Functions with Triggers**

**Key Patterns:**
- index.ts - Main entry point, exports all functions
- AI_USER_ID constant ("ai-assistant") must match AIConstants.swift in iOS app
- Functions are v2 (firebase-functions/v2)

**AI Functions (ai/ directory):**
- ai/index.ts - Main AI exports (detectIfQuestion, categorizeConversation, etc.)
- ai/client.ts - OpenAI client initialization
- ai/types.ts - TypeScript type definitions
- ai/lib/ - Individual AI capabilities:
  - faq-matcher.ts - Match questions to FAQ responses
  - message-fetcher.ts - Fetch conversation context
  - response-writer.ts - Write AI responses to Firestore
  - categorizer.ts - Categorize conversations by topic
  - etc.

**Important:**
- After modifying Cloud Functions, MUST rebuild: `cd firebase/functions && npm run build`
- Functions trigger on Firestore document events (onDocumentCreated, etc.)

### Emulator Seed (emulator-seed/)

**Pattern: Constants + Utils + Seed Files**

**Key Patterns:**
- constants.js defines AI_USER, PRIMARY_USERS, ALL_USERS - ALWAYS use these
- constants.js values must match AIConstants.swift (AI_USER_ID)
- utils.js provides helper functions (createUser, createConversation, etc.)
- seed-files/ contains scenario-specific seeds:
  - ai-categorization.js - Tests conversation categorization
  - ai-group-test.js - Tests group chat with AI assistant
  - generic.js - Basic conversations for testing

**Important:**
- Always reference constants.js for test users and AI config
- Check db-types.md for current database schema
- Run from emulator-seed directory: `node seed.js` or individual seed files

## Key Files Frequently Updated

### iOS (CreatorLink/)
**Services:**
- ConversationService.swift - Conversation management, AI features
- MessageService.swift - Message handling, read receipts
- TaggingService.swift - AI categorization and tagging
- AuthService.swift - Authentication logic

**ViewModels:**
- ChatViewModel.swift - Individual chat view logic
- ConversationsViewModel.swift - Conversation list management
- GroupInfoViewModel.swift - Group settings and management

**Models:**
- Conversation.swift - Conversation data model and AI config
- Message.swift - Message data model
- ConversationTag.swift, StatusTag.swift - Tag models
- AIConstants.swift - AI configuration constants

### Firebase Functions (firebase/functions/src/)
- index.ts - Function exports and main triggers
- ai/index.ts - AI function exports
- ai/lib/*.ts - Individual AI capabilities (frequently extended)

### Emulator Seed (emulator-seed/)
- constants.js - Test users and AI config (sync with iOS)
- seed-files/ - Individual test scenarios

### Important Constants Sync
These values MUST match across iOS and backend:
- AI_USER_ID: "ai-assistant" (AIConstants.swift, index.ts, constants.js)
- Project ID: "creatorlink-c160a" (constants.js, database URLs)
- Test users: PRIMARY_USERS in constants.js

## Database Schema Reference

See `/db-types.md` for complete database schema documentation including:
- Firestore collections structure (users, conversations, messages)
- Realtime Database paths (presence, typing)
- Field types and requirements
- AI configuration structure

# Firebase Functions

- **IMPORTANT:** After modifying Firebase Cloud Functions TypeScript code in `/firebase/functions/src/`, you MUST rebuild them before the changes take effect: