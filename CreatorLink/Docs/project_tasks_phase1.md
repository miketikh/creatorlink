# Phase 1: Foundation & Authentication

**Timeline:** Day 1 Morning
**Deadline:** Day 1, 12pm
**Duration:** ~4 hours

## Phase Overview

Establish the foundational infrastructure for the messaging app, including Firebase backend setup, Xcode project configuration, and complete authentication flow with Google Sign-In. By the end of this phase, users should be able to sign in with Google and see their profile information displayed in the app.

## Dependencies

- None (starting from scratch with basic SwiftUI project)

## Success Criteria

- Firebase project fully configured with Auth, Firestore, Cloud Functions, and FCM enabled
- User can sign in with Google on iOS simulator
- User profile is created in Firestore upon first login
- Auth state persists across app restarts
- Basic app navigation structure (TabView) is in place

---

## Task 1: Firebase Project Setup

**Description:** Create and configure Firebase project with all required services for the messaging app.

**Implementation Details:**
- Create new Firebase project in Firebase Console
- Enable Firebase Authentication with Google Sign-In provider
- Enable Cloud Firestore in native mode (not Datastore mode)
- Enable Cloud Functions for later AI integration
- Enable Firebase Cloud Messaging (FCM) for push notifications
- Enable Firebase Storage for image uploads (preparing for Phase 6)

**Technical Notes:**
- Choose Firebase project location carefully (cannot be changed later)
- Use Firestore in "production mode" initially, we'll configure security rules next
- Note down the Firebase project ID and configuration values

**Files/Resources Created:**
- Firebase Console project
- GoogleService-Info.plist (downloaded from Firebase Console)

**Dependencies:** None

---

## Task 2: Configure Firestore Security Rules

**Description:** Set up Firestore security rules to ensure only authenticated users can access data, with appropriate read/write permissions.

**Implementation Details:**
- Configure security rules in Firebase Console under Firestore → Rules
- Authenticated users should be able to read/write their own user document
- Authenticated users should be able to read all user profiles (for displaying in chat UI)
- Authenticated users should be able to read conversations they're participating in
- Authenticated users should be able to write messages to conversations they're in
- Authenticated users should be able to read messages from conversations they're in

**Technical Notes:**
- Rules should validate that conversation participantIds array contains the requesting user's ID
- Rules should validate that message senderId matches the authenticated user
- Consider rate limiting in future phases to prevent spam

**Security Considerations:**
- Never allow unauthenticated access
- Validate all writes match expected schema
- Ensure users cannot modify other users' profiles
- Ensure users cannot add themselves to conversations without permission (will handle via Cloud Functions later)

**Files Modified:**
- Firebase Console: Firestore Security Rules

**Dependencies:** Task 1

---

## Task 3: Create Firestore Composite Indexes

**Description:** Set up composite indexes for efficient querying of conversations and messages.

**Implementation Details:**
- Create composite index for messages collection: conversationId (Ascending), timestamp (Descending)
- Create composite index for conversations collection: participantIds (Array contains), lastMessageTime (Descending)
- Configure indexes in Firebase Console under Firestore → Indexes

**Technical Notes:**
- These indexes are critical for query performance
- Without proper indexes, Firestore queries will fail in production
- Additional indexes may be needed for AI features in later phases

**Query Patterns to Support:**
- Fetch all messages in a conversation ordered by timestamp
- Fetch all conversations for a user ordered by most recent message
- Real-time listeners on these queries

**Files Modified:**
- Firebase Console: Firestore Indexes

**Dependencies:** Task 1

---

## Task 4: Xcode Project Configuration

**Description:** Configure the existing Xcode project with Firebase SDK and necessary dependencies.

**Implementation Details:**
- Add Firebase SDK via Swift Package Manager (SPM)
- Required Firebase packages: FirebaseAuth, FirebaseFirestore, FirebaseStorage, FirebaseMessaging
- Add GoogleSignIn SDK via SPM (for Google Sign-In flow)
- Add GoogleService-Info.plist to Xcode project (from Task 1)
- Ensure GoogleService-Info.plist is included in app bundle (check Target Membership)

**Technical Notes:**
- Use exact versions compatible with current Xcode/Swift version
- FirebaseCore will be automatically included as a dependency
- Ensure all packages are added to the main app target, not test targets

**Package URLs:**
- Firebase: https://github.com/firebase/firebase-ios-sdk
- GoogleSignIn: https://github.com/google/GoogleSignIn-iOS

**Files Modified:**
- Project.pbxproj (via Xcode SPM interface)
- Package.resolved (auto-generated)

**Files Added:**
- GoogleService-Info.plist (from Firebase Console)

**Dependencies:** Task 1

---

## Task 5: Configure Info.plist for Firebase and Google Sign-In

**Description:** Update Info.plist with required configurations for Firebase and Google Sign-In to function properly.

**Implementation Details:**
- Add URL scheme for Google Sign-In (REVERSED_CLIENT_ID from GoogleService-Info.plist)
- Add URL scheme under CFBundleURLTypes array
- Configure app to support universal links (for future deep linking)
- Ensure app has necessary permissions placeholders

**Technical Notes:**
- REVERSED_CLIENT_ID is found in GoogleService-Info.plist
- Format: com.googleusercontent.apps.YOUR-CLIENT-ID (reversed)
- This allows Google Sign-In to redirect back to the app

**Info.plist Additions:**
- CFBundleURLTypes array with Google Sign-In URL scheme
- CFBundleURLSchemes with REVERSED_CLIENT_ID value

**Files Modified:**
- Info.plist

**Dependencies:** Task 4

---

## Task 6: Initialize Firebase in App Lifecycle

**Description:** Configure Firebase initialization when the app launches.

**Implementation Details:**
- Import FirebaseCore in CreatorLinkApp.swift
- Call FirebaseApp.configure() in the app initializer using init()
- Configure Firebase before any views are loaded
- Add proper error handling if Firebase fails to initialize

**Technical Notes:**
- Firebase must be configured before any Firebase services are used
- Use init() method of the App struct, not in the body
- This runs once when the app launches

**Files Modified:**
- CreatorLinkApp.swift (main app entry point)

**Dependencies:** Task 4, Task 5

---

## Task 7: Create Service Layer Architecture

**Description:** Establish service layer pattern for Firebase interactions with proper separation of concerns.

**Implementation Details:**
- Create Services folder in Xcode project
- Create AuthService.swift for authentication operations
- Create UserService.swift for user profile operations
- Create FirestoreService.swift as base service for common Firestore operations
- Each service should be a class (not struct) with shared instance pattern or use @Observable macro

**Service Responsibilities:**
- AuthService: Sign in, sign out, auth state listening, current user access
- UserService: Create/update/fetch user profiles, online status management
- FirestoreService: Common Firestore utilities, collection references

**Architectural Notes:**
- Services should be injectable for future testing
- Services should handle errors gracefully and return Result types or throw specific errors
- Services should use async/await for all Firebase operations
- Consider using @Observable macro for SwiftUI reactivity

**Files Created:**
- Services/AuthService.swift
- Services/UserService.swift
- Services/FirestoreService.swift

**Dependencies:** Task 6

---

## Task 8: Implement AuthService

**Description:** Build authentication service handling Google Sign-In flow and Firebase Auth state management.

**Implementation Details:**
- Implement Google Sign-In flow using GoogleSignIn SDK
- Handle OAuth flow: present Google Sign-In UI → get credentials → sign in to Firebase
- Create method: signInWithGoogle() -> async throws User
- Create method: signOut() -> async throws Void
- Implement auth state listener using Firebase Auth.auth().addStateDidChangeListener
- Store current user state using @Published or @Observable
- Handle token refresh automatically (Firebase handles this)

**Authentication Flow:**
1. User taps "Sign in with Google" button
2. Present Google Sign-In UI (GIDSignIn.sharedInstance.signIn)
3. Receive Google credentials
4. Exchange Google credentials for Firebase auth token
5. Sign in to Firebase with credential
6. Create user profile in Firestore (call UserService)
7. Update auth state

**Technical Notes:**
- Google Sign-In requires presenting view controller (use UIKit interop)
- Handle cancellation gracefully (user dismisses sign-in sheet)
- Store auth state changes in @Published property for SwiftUI reactivity

**Error Handling:**
- Network errors during sign-in
- User cancellation
- Invalid credentials
- Firebase auth errors

**Files Modified:**
- Services/AuthService.swift

**Dependencies:** Task 7

---

## Task 9: Implement UserService

**Description:** Build user profile service for creating and managing user documents in Firestore.

**Implementation Details:**
- Implement method: createUserProfile(userId: String, displayName: String, email: String, photoURL: String?) -> async throws
- Implement method: fetchUserProfile(userId: String) -> async throws UserProfile
- Implement method: updateOnlineStatus(userId: String, isOnline: Bool) -> async throws
- Implement method: updateLastSeen(userId: String) -> async throws
- User profile should be created immediately after first sign-in

**Firestore Structure:**
- Collection: "users"
- Document ID: Firebase Auth UID
- Fields: displayName, email, photoURL (optional), isOnline, lastSeen

**Technical Notes:**
- Use Firestore merge option when creating profiles to avoid overwriting existing data
- Cache user profiles locally to avoid repeated Firestore reads
- Handle case where user profile doesn't exist (first-time user vs. returning user)

**Online Presence Strategy:**
- Set isOnline to true when user signs in
- Update lastSeen timestamp periodically
- Use Firestore onDisconnect (will implement in Phase 3) to set isOnline to false when user disconnects

**Files Modified:**
- Services/UserService.swift

**Dependencies:** Task 7

---

## Task 10: Create Data Models

**Description:** Define Swift data models for User, Conversation, and Message that match the Firestore schema.

**Implementation Details:**
- Create Models folder in Xcode project
- Create User.swift model with Codable and Identifiable conformance
- Create Conversation.swift model with Codable and Identifiable conformance
- Create Message.swift model with Codable and Identifiable conformance
- Use Swift types that map cleanly to Firestore: String, Bool, Date, Array
- Use enums for message status: sending, sent, delivered, read

**User Model Fields:**
- id: String (Firebase Auth UID)
- displayName: String
- email: String
- photoURL: String? (optional)
- isOnline: Bool
- lastSeen: Date

**Conversation Model Fields:**
- id: String (generated by Firestore)
- participantIds: [String]
- lastMessage: String
- lastMessageTime: Date
- isGroupChat: Bool
- groupName: String? (optional)

**Message Model Fields:**
- id: String (generated by Firestore)
- conversationId: String
- senderId: String
- text: String
- timestamp: Date
- status: MessageStatus enum
- readBy: [String: Date] (userId to timestamp map)
- imageUrl: String? (optional, for Phase 6)
- metadata: [String: Any]? (optional, for AI features in Phase 8)

**Technical Notes:**
- Use Codable for automatic Firestore encoding/decoding
- Use Identifiable for SwiftUI list performance
- Date will automatically convert to/from Firestore Timestamp
- Consider using CodingKeys for custom Firestore field names if needed

**Files Created:**
- Models/User.swift
- Models/Conversation.swift
- Models/Message.swift
- Models/MessageStatus.swift (enum)

**Dependencies:** None (can be done in parallel with services)

---

## Task 11: Create App Navigation Structure

**Description:** Build the main navigation structure with TabView for Chats and Profile sections.

**Implementation Details:**
- Replace ContentView with TabView containing two tabs
- Create Views folder structure in Xcode project
- Create ChatsView.swift (placeholder for now, will implement in Phase 2)
- Create ProfileView.swift (displays user profile information)
- Add tab icons using SF Symbols: "bubble.left.and.bubble.right.fill" for Chats, "person.fill" for Profile
- Configure tab labels and accessibility identifiers

**Navigation Structure:**
- TabView as root view
- Tab 1: ChatsView (conversation list)
- Tab 2: ProfileView (user profile and settings)

**Technical Notes:**
- TabView should be the root view in CreatorLinkApp.swift body
- Each tab should have a distinct tag for programmatic navigation
- Consider using NavigationStack within each tab for hierarchical navigation

**Files Created:**
- Views/Chats/ChatsView.swift
- Views/Profile/ProfileView.swift

**Files Modified:**
- CreatorLinkApp.swift (replace ContentView with TabView)

**Dependencies:** Task 6

---

## Task 12: Implement Authentication UI

**Description:** Build the sign-in screen with Google Sign-In button and loading states.

**Implementation Details:**
- Create AuthView.swift as the initial view when user is not authenticated
- Display app branding/logo at top
- Show "Sign in with Google" button with Google branding
- Display loading indicator during sign-in process
- Show error message if sign-in fails
- Use appropriate error messaging for different failure scenarios

**UI Requirements:**
- Follow Google Sign-In branding guidelines
- Show activity indicator during authentication
- Disable sign-in button during authentication to prevent double-taps
- Display user-friendly error messages (not raw error codes)
- Consider adding app tagline: "Messaging for Content Creators"

**State Management:**
- Observe AuthService auth state
- Show AuthView when user is nil
- Show TabView when user is authenticated
- Handle loading state between screens

**Files Created:**
- Views/Auth/AuthView.swift

**Files Modified:**
- CreatorLinkApp.swift (conditionally show AuthView vs TabView)

**Dependencies:** Task 8, Task 11

---

## Task 13: Implement ProfileView

**Description:** Build profile screen displaying user information with sign-out functionality.

**Implementation Details:**
- Display user's profile photo (if available, otherwise use placeholder)
- Display user's display name
- Display user's email address
- Show online status indicator
- Add "Sign Out" button
- Show loading state while signing out
- Handle sign-out errors gracefully

**UI Layout:**
- Profile photo at top (circular, large)
- Display name below photo
- Email in smaller text
- Online status indicator (green dot + "Online" text)
- Sign Out button at bottom of screen
- Use proper spacing and alignment

**Technical Notes:**
- Load profile photo asynchronously using AsyncImage
- Call AuthService.signOut() when sign-out button is tapped
- Navigate back to AuthView after successful sign-out
- Consider adding placeholder image if photoURL is nil

**Files Modified:**
- Views/Profile/ProfileView.swift

**Dependencies:** Task 8, Task 9, Task 11

---

## Task 14: Test Authentication Flow End-to-End

**Description:** Comprehensive testing of authentication flow on iOS simulator.

**Testing Checklist:**
- Launch app on simulator → see AuthView
- Tap "Sign in with Google" → Google Sign-In sheet appears
- Complete sign-in flow → redirects back to app
- User profile created in Firestore (verify in Firebase Console)
- App shows TabView with Chats and Profile tabs
- Profile tab shows correct user information
- Force quit app → relaunch → user still signed in (no sign-in required)
- Tap Sign Out → returns to AuthView
- Check Firestore console to verify user document exists with correct fields

**Test Scenarios:**
1. First-time user sign-in (creates new user document)
2. Returning user sign-in (existing user document)
3. Sign-out and sign-in again
4. App restart with active session
5. Cancel sign-in flow (should not crash)

**Expected Behaviors:**
- Smooth transitions between screens
- No authentication errors
- User profile created on first sign-in
- Auth state persists across app restarts
- Sign-out clears auth state

**Debugging Tips:**
- Check Xcode console for Firebase initialization logs
- Verify GoogleService-Info.plist is included in bundle
- Check Firebase Console Authentication tab for signed-in users
- Check Firestore console for user documents

**Dependencies:** All previous tasks in Phase 1

---

## Phase 1 Completion Checklist

Before moving to Phase 2, verify:
- [ ] Firebase project fully configured (Auth, Firestore, Functions, FCM, Storage enabled)
- [ ] Firestore security rules configured for authenticated access
- [ ] Composite indexes created for messages and conversations
- [ ] Xcode project has all Firebase packages installed
- [ ] Google Sign-In fully functional on simulator
- [ ] User can sign in and see their profile information
- [ ] User profile created in Firestore with correct schema
- [ ] Auth state persists across app restarts
- [ ] User can sign out successfully
- [ ] Basic app navigation (TabView) in place
- [ ] No console errors or warnings

---

## Deliverables

By the end of Phase 1, you should have:
1. Fully configured Firebase backend
2. Working authentication flow with Google Sign-In
3. User profiles stored in Firestore
4. Basic app navigation structure
5. Clean, organized code structure with services and models

---

## Notes for Next Phase

Phase 2 will build on this foundation to implement:
- Real-time messaging between users
- Conversation creation and management
- Message sending and receiving
- Optimistic UI updates

Ensure Phase 1 is completely stable before proceeding, as all future features depend on this foundation.
