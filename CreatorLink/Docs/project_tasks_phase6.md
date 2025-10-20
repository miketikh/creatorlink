# Phase 6: Media Support & UI Polish

**Timeline:** Day 3 Afternoon
**Deadline:** Day 3, 8pm
**Duration:** ~6 hours

## Phase Overview

Add rich media capabilities with image sending/receiving, implement push notifications for background message alerts, and polish the UI for a professional, production-ready experience. This phase transforms the app from a functional prototype into a polished product with smooth animations, proper loading states, and reliable push notifications. By the end of this phase, users can share images, receive notifications when messages arrive, and enjoy a refined, responsive interface.

## Dependencies

- Phase 1 complete (Firebase configured, Auth working)
- Phase 2 complete (Core messaging functional)
- Phase 3 complete (Message states, real-time features)
- Phase 4 complete (Offline support, persistence)
- Phase 5 complete (Group chat support)

## Success Criteria

- Users can select and send images from photo library
- Images upload to Firebase Storage reliably
- Images display correctly in message bubbles with loading states
- Image thumbnails generated for efficient display
- Push notifications work in foreground and background (best effort)
- Notification payload includes conversation context for deep linking
- UI animations are smooth and purposeful
- Loading states are clear and non-intrusive
- Error handling provides helpful feedback
- Profile pictures display throughout the app
- Pull-to-refresh works reliably
- Overall UI feels polished and professional

---

## Task 1: Configure Firebase Storage

**Description:** Set up Firebase Storage for hosting user-uploaded images with appropriate security rules and folder organization.

**Implementation Details:**
- Enable Firebase Storage in Firebase Console
- Configure storage security rules to allow authenticated users to upload/read
- Define folder structure: /messages/{conversationId}/{messageId}/{filename}
- Set up CORS rules if needed for web access (future-proofing)
- Configure storage bucket location (should match Firestore region)

**Security Rules:**
- Authenticated users can upload images to /messages/{conversationId}/
- Users can only upload to conversations they participate in
- Image size limit: 10MB per file
- Allowed file types: image/jpeg, image/png, image/heif
- Users can read any image in conversations they participate in
- Prevent overwriting existing images (use unique filenames)

**Folder Structure:**
- /users/{userId}/profile.jpg - profile pictures
- /messages/{conversationId}/{messageId}/{timestamp}_{filename} - message images
- Use timestamp + random suffix to ensure unique filenames

**Technical Notes:**
- Configure Firebase Storage via Firebase Console
- Add storage rules in Storage → Rules section
- Test rules with Firebase Emulator (optional for MVP)
- Storage bucket URL format: gs://your-project.appspot.com

**Files Modified:**
- Firebase Console: Storage Rules
- Firebase Console: Enable Storage

**Dependencies:** Phase 1 (Firebase setup)

---

## Task 2: Add Firebase Storage SDK to Project

**Description:** Integrate Firebase Storage SDK into Xcode project for uploading and downloading images.

**Implementation Details:**
- Add FirebaseStorage package via Swift Package Manager (may already be included)
- Import FirebaseStorage in relevant service files
- Verify GoogleService-Info.plist includes storage configuration
- Test Storage connection with simple write operation

**Package Configuration:**
- FirebaseStorage is part of firebase-ios-sdk package
- Minimum iOS version: iOS 13+ (check deployment target)
- Ensure package version matches other Firebase dependencies

**Technical Notes:**
- Storage SDK should already be available if Firebase was configured in Phase 1
- If not present, add via File → Add Packages in Xcode
- No additional Info.plist configuration needed for Storage

**Files Modified:**
- Project.pbxproj (via Xcode SPM if adding package)
- Package.resolved (auto-updated)

**Dependencies:** Phase 1 (Task 4: Xcode Project Configuration)

---

## Task 3: Create StorageService for Image Operations

**Description:** Build service layer for uploading, downloading, and managing images in Firebase Storage.

**Implementation Details:**
- Create StorageService.swift in Services folder
- Implement uploadImage(imageData: Data, conversationId: String, messageId: String) -> async throws URL
- Implement downloadImage(url: URL) -> async throws Data
- Implement deleteImage(url: URL) -> async throws (for future message deletion)
- Implement generateThumbnail(image: UIImage, maxSize: CGSize) -> UIImage
- Handle upload progress tracking for large images
- Implement retry logic for failed uploads

**Image Upload Flow:**
1. Accept UIImage from user's photo picker
2. Compress image to reasonable size (max 1920x1920, quality 0.7)
3. Generate thumbnail (200x200) for quick preview
4. Upload full image to Storage: /messages/{conversationId}/{messageId}/image.jpg
5. Upload thumbnail to Storage: /messages/{conversationId}/{messageId}/thumb.jpg
6. Return download URLs for both
7. Store full image URL and thumbnail URL in message document

**Image Compression:**
- Max dimensions: 1920x1920 pixels (maintain aspect ratio)
- JPEG compression quality: 0.7 (balance between size and quality)
- Thumbnail dimensions: 200x200 pixels
- Use UIImage compression APIs for processing

**Technical Notes:**
- Use Storage.storage().reference() to get reference
- Use .putData() for uploading with metadata
- Use .downloadURL() to get public URL after upload
- Track upload progress with .observe(.progress) for large images
- Handle storage quota errors gracefully

**Error Handling:**
- Network failures: retry with exponential backoff
- Storage quota exceeded: alert user, prevent upload
- Invalid image data: validate before upload
- Permission errors: check security rules

**Files Created:**
- Services/StorageService.swift

**Dependencies:** Task 1, Task 2

---

## Task 4: Implement Image Picker Integration

**Description:** Add UIImagePickerController or PHPickerViewController integration for selecting images from photo library.

**Implementation Details:**
- Use PHPickerViewController (modern API) instead of UIImagePickerController
- Create ImagePicker.swift as SwiftUI-compatible wrapper
- Support single image selection (no multi-select for MVP)
- Handle permissions for photo library access
- Request photo library usage permission in Info.plist

**PHPickerConfiguration:**
- Selection limit: 1 image
- Filter: .images only (no videos)
- Preferred asset representation: .current
- Selection behavior: .default

**SwiftUI Integration:**
- Use UIViewControllerRepresentable to wrap PHPickerViewController
- Provide completion handler with selected UIImage
- Handle cancellation gracefully
- Present as sheet over chat view

**Permissions:**
- Add NSPhotoLibraryUsageDescription to Info.plist
- Description: "We need access to your photos to send images in messages"
- PHPicker automatically requests permission when presented

**Technical Implementation:**
- Create ImagePicker struct conforming to UIViewControllerRepresentable
- Implement makeUIViewController and updateUIViewController
- Use Coordinator for delegate callbacks
- Convert PHPickerResult to UIImage asynchronously

**Files Created:**
- Views/Common/ImagePicker.swift

**Files Modified:**
- Info.plist (add NSPhotoLibraryUsageDescription key)

**Dependencies:** None (can be done in parallel with StorageService)

---

## Task 5: Add Image Attachment Button to Chat Input

**Description:** Add image attachment button to message input area in ChatDetailView for initiating image selection.

**Implementation Details:**
- Add image attachment button (paperclip or photo icon) next to send button
- Position button to the left of text field
- Present image picker sheet when button is tapped
- Handle image selection and upload flow
- Show upload progress indicator while uploading
- Disable send button during upload

**UI Layout:**
- HStack layout: [Image Button] [TextField] [Send Button]
- Image button: SF Symbol "photo" or "paperclip" in gray color
- Button size: 44x44 points (minimum tap target)
- Padding and spacing consistent with send button

**User Flow:**
1. User taps image button
2. Image picker sheet appears
3. User selects image from library
4. Sheet dismisses, upload begins
5. Progress indicator shown in input area
6. On success: message with image URL is sent
7. On failure: error alert shown with retry option

**Technical Implementation:**
- Add @State var showingImagePicker: Bool
- Use .sheet(isPresented:) to present ImagePicker
- Handle selected image in onImageSelected callback
- Trigger upload and message send in one flow

**Files Modified:**
- Views/Chats/ChatDetailView.swift

**Dependencies:** Task 4

---

## Task 6: Implement Image Upload and Message Sending

**Description:** Coordinate image upload to Firebase Storage with message creation, handling the full flow from selection to delivery.

**Implementation Details:**
- When image is selected, immediately start upload to Firebase Storage
- Show upload progress in UI (progress bar or percentage)
- Generate thumbnail during upload process
- After successful upload, create message with imageUrl field
- Send message to Firestore with image URLs
- Handle upload cancellation
- Support offline queuing (upload when connectivity restored)

**Image Message Flow:**
1. User selects image from picker
2. Compress full image and generate thumbnail
3. Upload both to Firebase Storage simultaneously
4. Get download URLs for both images
5. Create Message object with imageUrl (full) and thumbnailUrl fields
6. Save to SwiftData for offline support
7. Send message to Firestore with image URLs
8. Display image in UI using thumbnail URL initially

**Upload Progress:**
- Show progress bar or percentage below input field
- Display "Uploading image..." text
- Allow cancellation with X button
- Disable image button during upload
- Enable after upload completes or fails

**Error Handling:**
- Upload fails: show retry button, keep image locally
- Network offline: queue upload for later (use offline queue from Phase 4)
- Storage quota exceeded: show clear error message
- Invalid image: validate before upload attempt

**Technical Implementation:**
- Extend ChatViewModel with sendImageMessage(image: UIImage) method
- Use StorageService.uploadImage within the method
- Track upload progress with @Published uploadProgress property
- Update UI reactively based on progress
- Integrate with offline queue for reliability

**Files Modified:**
- ViewModels/ChatViewModel.swift
- Services/MessageService.swift (add image message support)

**Dependencies:** Task 3, Task 5

---

## Task 7: Display Images in Message Bubbles

**Description:** Enhance MessageBubbleView to display images with proper sizing, loading states, and tap-to-view functionality.

**Implementation Details:**
- Display thumbnail image in message bubble when imageUrl is present
- Use AsyncImage for loading images with placeholder
- Handle loading states with ProgressView
- Handle failed loads with error icon and retry option
- Make images tappable to view full-size
- Set maximum image size in bubble (e.g., 200x200 points)
- Maintain aspect ratio of images
- Support both text-only, image-only, and text+image messages

**Image Display:**
- If message has imageUrl, show image above or instead of text
- Use thumbnail URL for bubble display (fast loading)
- Load full image URL when tapped (present in fullscreen)
- Show loading spinner while image loads
- Show placeholder or error icon if load fails

**Image Sizing:**
- Max width: 70% of screen width (same as text bubbles)
- Max height: 300 points
- Maintain original aspect ratio
- Use .aspectRatio(.fit) modifier
- Round corners to match bubble style (18pt radius)

**Loading States:**
- Loading: show gray placeholder with ProgressView spinner
- Failed: show gray placeholder with exclamation icon and "Tap to retry"
- Loaded: display image

**Tap to View Fullscreen:**
- Tap image to present fullscreen viewer
- Use full image URL (not thumbnail) in fullscreen
- Support pinch-to-zoom in fullscreen view
- Add close button or swipe-to-dismiss gesture
- Show image sender and timestamp in fullscreen view

**Technical Implementation:**
- Modify MessageBubbleView to accept message with optional imageUrl
- Use AsyncImage with placeholder and error handling
- Add .onTapGesture to present fullscreen image view
- Create FullscreenImageView.swift for image viewer

**Files Modified:**
- Views/Chats/MessageBubbleView.swift
- Models/Message.swift (ensure imageUrl and thumbnailUrl fields exist)

**Files Created:**
- Views/Chats/FullscreenImageView.swift

**Dependencies:** Task 6

---

## Task 8: Create Fullscreen Image Viewer

**Description:** Build fullscreen image viewer with zoom, pan, and dismiss gestures for viewing message images.

**Implementation Details:**
- Create FullscreenImageView as a fullscreen modal
- Display full-resolution image with loading state
- Support pinch-to-zoom and double-tap-to-zoom gestures
- Support pan gesture when zoomed in
- Swipe down to dismiss when at normal zoom
- Display message metadata (sender, timestamp) as overlay
- Provide close button in corner

**UI Layout:**
- Full screen black background
- Image centered, scaling to fit screen
- Close button: X in top-right corner
- Message info overlay at bottom (sender name, timestamp)
- Info overlay fades out after 2 seconds (reappears on tap)

**Gestures:**
- Single tap: toggle info overlay visibility
- Double tap: zoom in to 2x, or zoom out to fit
- Pinch: zoom in/out (scale 1x to 4x)
- Pan: move image when zoomed in
- Swipe down: dismiss viewer (only at 1x zoom)

**Technical Implementation:**
- Use MagnificationGesture for pinch-to-zoom
- Use DragGesture for panning when zoomed
- Use .scaleEffect and .offset modifiers for transformations
- Track current zoom level with @State
- Reset zoom when dismissing
- Use AsyncImage for loading full-resolution image

**Accessibility:**
- VoiceOver support: "Image from [sender name]"
- Close button clearly labeled
- Support for reduce motion preferences

**Files Created:**
- Views/Chats/FullscreenImageView.swift

**Dependencies:** Task 7

---

## Task 9: Configure Firebase Cloud Messaging (FCM)

**Description:** Set up Firebase Cloud Messaging for push notifications, including certificates and device token registration.

**Implementation Details:**
- Enable Firebase Cloud Messaging in Firebase Console (already enabled in Phase 1)
- Configure APNs certificates/keys in Firebase Console
- Generate APNs authentication key in Apple Developer Portal
- Upload APNs key to Firebase Console
- Configure app for remote notifications in Xcode capabilities

**APNs Configuration Steps:**
1. Go to Apple Developer Portal → Certificates, Identifiers & Profiles
2. Create new Key with Apple Push Notifications service (APNs) enabled
3. Download .p8 key file (only chance to download)
4. Note Key ID and Team ID
5. Upload to Firebase Console → Project Settings → Cloud Messaging → APNs
6. Enter Key ID and Team ID in Firebase

**Xcode Configuration:**
- Enable Push Notifications capability in target settings
- Enable Background Modes: Remote notifications
- Ensure app has proper bundle identifier matching provisioning profile
- Request notification permissions in code

**Info.plist:**
- No additional keys needed for FCM (handled by Firebase SDK)

**Technical Notes:**
- APNs key (.p8) is more modern than certificates
- Key works for both development and production
- Firebase handles environment detection automatically
- For MVP, production APNs is sufficient (no separate dev setup)

**Files Modified:**
- Project target: Capabilities (via Xcode UI)
- Entitlements file (auto-generated by Xcode)

**Dependencies:** Phase 1 (Firebase setup)

---

## Task 10: Implement FCM Device Token Registration

**Description:** Register device for push notifications and send device token to Firebase for message routing.

**Implementation Details:**
- Request notification permissions on app launch
- Register for remote notifications with APNs
- Receive device token from APNs
- Send device token to Firebase Cloud Messaging
- Store device token in Firestore user document for targeting
- Handle token refresh when it changes

**Permission Request:**
- Request authorization on first app launch or when user signs in
- Use UNUserNotificationCenter to request permissions
- Request alert, badge, and sound permissions
- Handle user acceptance or denial gracefully

**Token Registration Flow:**
1. Call UNUserNotificationCenter.requestAuthorization
2. If authorized, call UIApplication.registerForRemoteNotifications()
3. Receive token in AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken
4. Pass token to Firebase: Messaging.messaging().apnsToken = token
5. Receive FCM token from Messaging.messaging().token
6. Save FCM token to Firestore user document

**Token Storage:**
- Store FCM token in Firestore users/{userId}/fcmToken field
- Update token whenever it changes (rare but possible)
- Support multiple tokens per user (if user has multiple devices)
- Use array of tokens: fcmTokens: [String]

**Technical Implementation:**
- Create NotificationService.swift for notification handling
- Implement permission request logic
- Handle token registration in AppDelegate or app lifecycle
- Update UserService to store FCM tokens in Firestore

**Files Created:**
- Services/NotificationService.swift

**Files Modified:**
- CreatorLinkApp.swift (request permissions on launch)
- Services/UserService.swift (add fcmToken methods)

**Dependencies:** Task 9

---

## Task 11: Implement Notification Handling

**Description:** Handle incoming push notifications in foreground and background, with proper routing to conversations.

**Implementation Details:**
- Handle foreground notifications (app is active)
- Handle background notifications (app in background/terminated)
- Parse notification payload to extract conversation and message info
- Deep link to conversation when notification is tapped
- Display notification banner in foreground with custom UI
- Update badge count for unread messages

**Notification Payload Structure:**
- title: sender name
- body: message text preview (first 100 characters)
- conversationId: for deep linking
- messageId: for marking as read
- senderId: for filtering self-sent messages
- imageUrl: optional thumbnail for image messages

**Foreground Notification Handling:**
- Use UNUserNotificationCenterDelegate.willPresent notification
- Display custom in-app banner or use system banner
- Play sound and show badge
- Don't show notification for messages in currently open conversation
- Update conversation list automatically via existing real-time listeners

**Background Notification Handling:**
- User taps notification while app is backgrounded
- Use UNUserNotificationCenterDelegate.didReceive response
- Parse conversationId from payload
- Navigate to ChatDetailView for that conversation
- Mark messages as read automatically

**Deep Linking:**
- Create AppState or coordinator to handle navigation
- Store selected conversationId
- Trigger navigation to ChatDetailView when app opens
- Handle case where app is already open on different conversation

**Technical Implementation:**
- Implement UNUserNotificationCenterDelegate methods
- Set delegate in app initialization
- Parse notification.request.content.userInfo for payload
- Route navigation based on conversationId
- Use @Published navigation state or NavigationPath

**Files Modified:**
- Services/NotificationService.swift
- CreatorLinkApp.swift (set notification delegate)
- ViewModels/ConversationsViewModel.swift (handle deep link navigation)

**Dependencies:** Task 10

---

## Task 12: Send Push Notifications via Cloud Functions

**Description:** Create Cloud Function to send FCM notifications when messages are sent, targeting recipient devices.

**Implementation Details:**
- Create Cloud Function triggered by Firestore message creation
- Fetch recipient FCM tokens from Firestore users collection
- Construct notification payload with message details
- Send notification via Firebase Admin SDK
- Handle multiple recipients for group chats
- Filter out sender's devices (don't notify self)
- Handle token errors and invalid tokens

**Cloud Function Setup:**
- Use Firebase Functions (Node.js or Python)
- Trigger: Firestore onCreate for messages collection
- Function: sendMessageNotification(snapshot, context)
- Deploy to same region as Firestore for low latency

**Notification Logic:**
1. Function triggered when new message document created
2. Extract conversationId and senderId from message
3. Fetch conversation document to get participantIds
4. Filter out senderId from participants (don't notify sender)
5. Fetch FCM tokens for each recipient from users collection
6. For each token, send FCM notification with payload
7. Handle invalid tokens (remove from user document)

**FCM Payload:**
- notification: { title, body } - for display
- data: { conversationId, messageId, senderId } - for deep linking
- apns: { sound: "default", badge: 1 } - iOS-specific options
- priority: "high" - ensure delivery

**Error Handling:**
- Invalid token: remove from user's fcmTokens array
- Network errors: retry with exponential backoff
- Rate limiting: respect FCM quotas
- Log errors for debugging

**Technical Implementation:**
- Initialize Firebase Admin SDK in Cloud Function
- Use admin.messaging().send() to send notifications
- Use Firestore queries to fetch tokens
- Update token arrays when tokens are invalid

**Files Created:**
- functions/index.js (or index.ts for TypeScript)
- functions/package.json (with firebase-admin dependency)

**Deployment:**
- Initialize Firebase Functions: firebase init functions
- Write function code
- Deploy: firebase deploy --only functions
- Test with Firestore trigger

**Dependencies:** Task 10

---

## Task 13: Add Profile Pictures Throughout App

**Description:** Display user profile pictures consistently across all views (conversation list, chat headers, message bubbles for groups).

**Implementation Details:**
- Conversation list: show other user's profile photo in ConversationRowView
- Chat detail header: show other user's profile photo in navigation bar
- Group chat: show multiple profile photos or group icon
- Message bubbles in groups: show sender's profile photo next to received messages
- Use AsyncImage for all profile photos with placeholder
- Cache profile photos to reduce network requests

**Profile Photo Locations:**
- ConversationRowView: left side, 50x50 points, circular
- ChatDetailView header: navigation bar, 32x32 points, circular
- MessageBubbleView (group messages): left of bubble, 28x28 points, circular
- ProfileView: top center, 100x100 points, circular

**Placeholder Handling:**
- If photoURL is nil, show initials on colored background
- Generate background color from user's name hash
- Use SF Symbol "person.circle.fill" as fallback

**Image Loading:**
- Use AsyncImage with placeholder
- Show gray circle with initials while loading
- Handle load failures gracefully with fallback
- Cache using AsyncImage's built-in caching

**Group Photos:**
- For 1-on-1: show other user's photo
- For groups: show multiple overlapping photos (up to 4)
- For large groups: show group icon or "GC" initials

**Technical Implementation:**
- Create ProfileImageView.swift reusable component
- Accept user: User and size: CGFloat parameters
- Generate initials from displayName
- Use hash of name for consistent color generation
- Apply .clipShape(.circle) for circular appearance

**Files Created:**
- Views/Common/ProfileImageView.swift

**Files Modified:**
- Views/Chats/ConversationRowView.swift
- Views/Chats/ChatDetailView.swift
- Views/Chats/MessageBubbleView.swift (for group messages)

**Dependencies:** Phase 1 (User model with photoURL)

---

## Task 14: Implement Pull-to-Refresh

**Description:** Add pull-to-refresh functionality to conversation list and message list for manual sync triggering.

**Implementation Details:**
- Add .refreshable modifier to ChatsView (conversation list)
- Add .refreshable modifier to ChatDetailView (message list)
- Trigger full sync when pulled
- Show loading indicator during refresh
- Provide haptic feedback on completion
- Disable refresh during active sync to prevent conflicts

**Pull-to-Refresh Behavior:**
- User pulls down on list
- Loading spinner appears
- Trigger SyncService sync operations
- Fetch latest data from Firestore
- Update local SwiftData cache
- UI updates automatically via listeners
- Spinner disappears, success haptic plays

**Conversation List Refresh:**
- Fetch all conversations for current user
- Update conversation metadata (last message, timestamps)
- Fetch new conversations that were created on another device
- Update user presence for all participants

**Message List Refresh:**
- Fetch messages for current conversation
- Check for new messages since last fetch
- Update message statuses (read receipts)
- Refresh user profiles for participants

**Technical Implementation:**
- Use .refreshable { await ... } modifier on List or ScrollView
- Call SyncService methods asynchronously
- Return after sync completes
- Use Task for async/await in SwiftUI

**UI Feedback:**
- System-provided loading indicator (SwiftUI handles this)
- Haptic feedback: UINotificationFeedbackGenerator on completion
- Ensure smooth animation when data updates
- Don't interrupt user's scroll position

**Files Modified:**
- Views/Chats/ChatsView.swift
- Views/Chats/ChatDetailView.swift

**Dependencies:** Phase 4 (SyncService)

---

## Task 15: Add Smooth Animations and Transitions

**Description:** Enhance UI with purposeful animations for view transitions, message appearance, and interactive elements.

**Implementation Details:**
- Animate message bubble appearance when messages arrive
- Smooth transitions between conversation list and chat detail
- Animate status indicator changes (sending → sent → delivered → read)
- Animate typing indicator appearance/disappearance
- Animate offline banner sliding in/out
- Add spring animations for button taps
- Ensure animations respect reduce motion accessibility setting

**Key Animations:**

**Message Appearance:**
- New messages slide in from bottom with fade
- Use .transition(.move(edge: .bottom).combined(with: .opacity))
- Duration: 0.3 seconds with spring animation
- Only animate newly added messages, not all messages on load

**Status Changes:**
- Status icon changes fade between states
- Use .animation(.easeInOut(duration: 0.2), value: message.status)
- Subtle color transitions for status indicators

**View Transitions:**
- Use NavigationStack's built-in transitions
- Add custom hero animation for profile photos (optional)
- Smooth fade for sheet presentations

**Typing Indicator:**
- Fade in/out when state changes
- Use .transition(.opacity) with 0.2s duration
- Animated ellipsis using phase animator

**Offline Banner:**
- Slide in from top when offline
- Slide out when online
- Use .transition(.move(edge: .top))
- Duration: 0.3 seconds

**Button Feedback:**
- Scale down slightly on tap (0.95)
- Use .scaleEffect with spring animation
- Restore to 1.0 on release

**Technical Implementation:**
- Use .animation modifier with specific value watching
- Use .transition for view insertion/removal
- Use withAnimation { } for explicit animations
- Add @Environment(\.accessibilityReduceMotion) check
- Disable or simplify animations if reduce motion is enabled

**Accessibility:**
- Respect .accessibilityReduceMotion environment value
- Skip animations or use crossfade instead if enabled
- Ensure animations don't interfere with VoiceOver

**Files Modified:**
- Views/Chats/ChatDetailView.swift
- Views/Chats/MessageBubbleView.swift
- Views/Chats/TypingIndicatorView.swift
- Views/Common/OfflineBannerView.swift (if created)
- All button-containing views

**Dependencies:** None (polish for existing views)

---

## Task 16: Enhance Loading States

**Description:** Improve loading states across the app with skeleton views, progress indicators, and clear feedback.

**Implementation Details:**
- Conversation list: skeleton rows while loading initial data
- Message list: spinner in center while fetching messages
- Image upload: progress bar with percentage
- Profile photos: placeholder circles while loading
- Empty states: clear messaging with actionable prompts
- Error states: descriptive messages with retry actions

**Skeleton Views (Optional but Polished):**
- Show placeholder rows in conversation list during initial load
- Animated shimmer effect on placeholders
- Replace with real data as it loads
- Use for first-time users with no cached data

**Loading Indicators:**
- Use ProgressView for indeterminate loading
- Use ProgressView with value for determinate loading (image uploads)
- Show "Loading..." text with spinner for long operations
- Position centrally for full-screen loads

**Empty States:**
- No conversations: "Start your first conversation" with + button highlighted
- No messages: "Send your first message" in center of chat view
- No users to chat with: "No other users yet"
- Search no results: "No conversations found"

**Error States:**
- Network error: "Connection lost" with retry button
- Permission error: "Enable notifications in Settings"
- Upload error: "Failed to upload image" with retry button
- Sync error: "Couldn't sync messages" with retry button

**Technical Implementation:**
- Create EmptyStateView.swift reusable component
- Create SkeletonRow.swift for skeleton loading (optional)
- Use @ViewBuilder to conditionally show states
- Track loading state with @Published properties in ViewModels

**Files Created:**
- Views/Common/EmptyStateView.swift
- Views/Common/SkeletonRow.swift (optional)

**Files Modified:**
- Views/Chats/ChatsView.swift
- Views/Chats/ChatDetailView.swift
- ViewModels (add loading state properties)

**Dependencies:** None (enhancement of existing views)

---

## Task 17: Polish Conversation List UI

**Description:** Refine conversation list appearance with consistent spacing, typography, and visual hierarchy.

**Implementation Details:**
- Consistent row height: 72 points
- Clear visual hierarchy: name bold, message preview secondary
- Proper spacing between elements
- Dividers between rows (subtle)
- Unread indicator prominent but not overwhelming
- Swipe actions for common operations (archive, mute - optional)

**Row Layout Refinements:**
- Profile photo: 50x50 points, 12pt leading padding
- Content VStack: 8pt spacing
- Name: 16pt bold, primary color
- Last message: 14pt regular, secondary color
- Timestamp: 12pt, tertiary color, top-aligned
- Unread badge: blue, 20pt diameter, trailing side

**Typography:**
- Use system font with appropriate sizes
- Use .primary, .secondary, .tertiary colors for hierarchy
- Truncate long names and messages with ellipsis
- Line limit: 1 for name, 2 for message preview

**Visual Polish:**
- Subtle separator between rows (1pt, .separator color)
- Highlight row on tap with subtle background change
- Selected row (navigation state) with accent color background
- Smooth highlight animations

**Swipe Actions (Optional):**
- Swipe left: Archive, Mute options
- Swipe right: Mark as unread/read
- Use .swipeActions modifier
- Confirm destructive actions

**Technical Implementation:**
- Refine ConversationRowView layout
- Use proper SwiftUI spacing and padding modifiers
- Apply .listRowSeparator for dividers
- Use .listRowBackground for selection highlight
- Test on different device sizes for consistency

**Files Modified:**
- Views/Chats/ConversationRowView.swift
- Views/Chats/ChatsView.swift

**Dependencies:** None (refinement of existing UI)

---

## Task 18: Polish Chat Detail UI

**Description:** Refine chat interface appearance with improved message bubbles, input area, and navigation bar.

**Implementation Details:**
- Message bubbles: proper padding, consistent corner radius
- Input area: clean design, proper keyboard handling
- Navigation bar: user info clearly displayed
- Scroll behavior: smooth, auto-scroll when appropriate
- Timestamp grouping: clear date separators
- Keyboard avoidance: input never hidden by keyboard

**Message Bubble Refinements:**
- Padding: 12pt vertical, 16pt horizontal
- Corner radius: 18pt
- Max width: 70% of screen width
- Shadow for sent messages (subtle depth)
- Proper spacing between consecutive messages

**Input Area Polish:**
- Always visible at bottom
- Keyboard pushes input up (not over it)
- Clear separation from messages (top border or shadow)
- Button states clear (enabled/disabled)
- Smooth transitions when keyboard appears/dismisses

**Navigation Bar:**
- Profile photo: 32x32 points
- User name: 16pt semibold
- Online status or "last seen": 12pt, secondary color below name
- Back button: system standard
- Info button: leading side for conversation settings (optional)

**Scroll Behavior:**
- Auto-scroll to bottom only for new messages
- Don't auto-scroll if user is scrolled up (reading history)
- Provide "scroll to bottom" button when scrolled up
- Smooth scroll animation, not jarring

**Visual Hierarchy:**
- Messages clearly separated from input
- Sender vs. receiver distinction obvious
- Timestamps visible but not distracting
- Focus on message content

**Technical Implementation:**
- Refine ChatDetailView layout and spacing
- Use .safeAreaInset for input area to handle keyboard
- Implement scroll detection for auto-scroll behavior
- Add floating action button for scroll-to-bottom

**Files Modified:**
- Views/Chats/ChatDetailView.swift
- Views/Chats/MessageBubbleView.swift

**Dependencies:** None (refinement of existing UI)

---

## Task 19: Add Error Handling UI

**Description:** Implement user-friendly error messaging throughout the app with actionable recovery options.

**Implementation Details:**
- Network errors: banner with "No connection" and auto-dismiss when reconnected
- Upload errors: inline error with retry button on message bubble
- Permission errors: alert with "Open Settings" button
- Firestore errors: generic "Something went wrong" with retry
- Validation errors: inline feedback on input fields

**Error Display Patterns:**

**Banner Errors (Non-critical):**
- Offline state: persistent banner at top
- Sync failures: temporary banner with auto-dismiss
- Use red for errors, orange for warnings

**Alert Errors (Requires action):**
- Permission denied: "Enable notifications in Settings" with action button
- Storage quota exceeded: "Storage full, please free up space"
- Use native SwiftUI .alert modifier

**Inline Errors (Contextual):**
- Failed message send: red error icon on message bubble
- Failed image upload: error icon in image placeholder
- Show retry button next to error

**Error Messages:**
- Clear and specific: "Couldn't send message" not "Error 500"
- Actionable: always provide next step (retry, settings, etc.)
- Non-technical: avoid error codes unless necessary
- Encouraging: "Try again" not "Failed"

**Technical Implementation:**
- Create ErrorBannerView.swift for banner errors
- Use .alert modifier for modal errors
- Add error state to ViewModels
- Provide retry closures for recovery actions
- Log errors to console for debugging (use os_log)

**Files Created:**
- Views/Common/ErrorBannerView.swift

**Files Modified:**
- All ViewModels (add error handling)
- All Views (display errors)

**Dependencies:** None (enhancement of existing error handling)

---

## Task 20: Comprehensive Media and Polish Testing

**Description:** Thoroughly test all Phase 6 features to ensure reliable image handling, push notifications, and polished UX.

**Testing Setup:**
- Two iOS simulators (iPhone models)
- Mac with Firebase Console and Storage browser open
- Network Link Conditioner for testing poor connectivity
- Physical device for actual push notification testing (simulators limited)

**Test Scenarios:**

**Scenario 1: Image Sending and Receiving**
1. User A taps image button in chat with User B
2. Select image from photo library
3. Verify upload progress indicator appears
4. Wait for upload to complete
5. Verify message with image appears in User A's chat
6. Verify image appears in User B's chat within 2 seconds
7. Tap image on both devices to view fullscreen
8. Verify full-resolution image loads
9. Test pinch-to-zoom gesture
10. Check Firebase Storage console to verify image uploaded

**Scenario 2: Image Thumbnail Performance**
1. Send multiple images in conversation
2. Scroll through conversation list
3. Verify thumbnails load quickly (< 1 second)
4. Verify no lag when scrolling
5. Force quit app and reopen
6. Verify thumbnails cached and load instantly

**Scenario 3: Image Upload Failures**
1. Select very large image (10MB+)
2. Verify compression occurs
3. Turn off network mid-upload
4. Verify error indicator appears
5. Tap retry button
6. Turn network back on
7. Verify upload completes successfully

**Scenario 4: Push Notifications (Foreground)**
1. User A and User B both have app open
2. User A is on conversation list (not in chat)
3. User B sends message to User A
4. Verify notification banner appears on User A's device
5. Verify notification includes sender name and message preview
6. Tap notification
7. Verify navigation to conversation

**Scenario 5: Push Notifications (Background)**
1. User A closes app (but doesn't terminate)
2. User B sends message to User A
3. Wait 5 seconds
4. Verify notification appears on User A's lock screen/notification center
5. Tap notification
6. Verify app opens to correct conversation

**Scenario 6: Push Notifications (Terminated)**
1. User A force quits app completely
2. User B sends message to User A
3. Verify notification appears on User A's device
4. Tap notification
5. Verify app launches and navigates to conversation

**Scenario 7: Group Image Messages**
1. Create group chat with 3 users
2. User A sends image
3. Verify image appears for all participants
4. Verify sender attribution clear (profile photo + name)
5. Tap to view fullscreen from different users

**Scenario 8: Profile Pictures**
1. Verify profile photos display in conversation list
2. Verify profile photos display in chat headers
3. Verify profile photos display next to group messages
4. Test with user who has no profile photo (placeholder)
5. Verify fallback initials display correctly

**Scenario 9: Pull-to-Refresh**
1. Open conversation list
2. Pull down to refresh
3. Verify loading indicator appears
4. Verify conversations update
5. Repeat in chat detail view
6. Verify messages update

**Scenario 10: UI Polish and Animations**
1. Send multiple messages rapidly
2. Verify smooth message appearance animations
3. Watch status indicators change
4. Verify smooth status transitions (no flicker)
5. Test keyboard appearance/dismissal
6. Verify input area moves smoothly
7. Test offline banner appearance
8. Verify banner slides in/out smoothly
9. Test on different device sizes
10. Verify layout adapts properly

**Scenario 11: Loading and Error States**
1. Sign in as new user (no cached data)
2. Verify skeleton loading or spinner appears
3. Verify conversation list loads smoothly
4. Test empty states (no conversations)
5. Create conversation and verify empty state in chat
6. Test various error conditions
7. Verify error messages are clear and helpful

**Scenario 12: Image Edge Cases**
1. Send very wide image (panorama)
2. Verify aspect ratio maintained
3. Send very tall image (screenshot)
4. Verify proper scaling
5. Send small image (icon-sized)
6. Verify doesn't stretch
7. Try sending non-image file (should fail gracefully)

**Verification Points:**
- All images upload successfully
- Thumbnails load quickly
- Full images load in fullscreen
- Push notifications arrive reliably
- Notification payload includes correct data
- Deep linking works from notifications
- Profile pictures display everywhere
- Animations are smooth (60fps)
- Loading states are clear
- Error messages are helpful
- UI looks polished and professional
- No crashes or console errors

**Performance Checks:**
- Image upload time: < 5 seconds for typical photo
- Thumbnail load time: < 1 second
- Notification delivery time: < 3 seconds
- UI animations smooth (no dropped frames)
- Memory usage reasonable (< 150MB with images)
- App launch time: < 2 seconds

**Dependencies:** All tasks in Phase 6

---

## Phase 6 Completion Checklist

Before moving to Phase 7, verify:
- [ ] Firebase Storage configured with security rules
- [ ] Firebase Storage SDK integrated
- [ ] StorageService implemented for uploads/downloads
- [ ] Image picker integrated with photo library access
- [ ] Image attachment button added to chat input
- [ ] Image upload and message sending coordinated
- [ ] Images display in message bubbles with loading states
- [ ] Fullscreen image viewer with zoom and gestures
- [ ] FCM configured with APNs certificates
- [ ] Device token registration working
- [ ] Notification handling implemented (foreground and background)
- [ ] Cloud Function sending notifications
- [ ] Profile pictures display throughout app
- [ ] Pull-to-refresh working in conversation list and chat
- [ ] Smooth animations added to key interactions
- [ ] Loading states clear and informative
- [ ] Conversation list UI polished
- [ ] Chat detail UI polished
- [ ] Error handling UI user-friendly
- [ ] Comprehensive testing passed
- [ ] No crashes or critical bugs

---

## Deliverables

By the end of Phase 6, you should have:
1. Full image sending and receiving capability
2. Reliable push notifications (foreground and background)
3. Polished, professional UI with smooth animations
4. Clear loading and error states
5. Profile pictures throughout the app
6. Pull-to-refresh for manual sync
7. Fullscreen image viewer with gestures
8. Production-ready user experience

---

## Known Limitations and Future Improvements

- Push notifications best-effort on iOS (background execution limits)
- Image upload limited to 10MB (configurable in security rules)
- No image editing or filters (future feature)
- No video support (out of scope for MVP)
- No message reactions or emoji (Phase 7 or post-MVP)
- Cloud Function cold start may delay first notification (~5s)

---

## Notes for Next Phase

Phase 7 will focus on MVP testing and hardening:
- Comprehensive two-simulator testing
- Rapid-fire message stress testing
- Group chat with 3+ users
- Offline/online scenarios
- App lifecycle testing
- Poor network simulation
- Bug fixes and stability improvements
- Performance optimization
- Final polish before adding AI features

Ensure Phase 6 features are rock-solid and polished before proceeding to Phase 7. The app should feel production-ready at this point, with all core messaging features working flawlessly.

---

## Post-Phase 6: Ready for AI Features

After Phase 7 (MVP Testing), the app will be ready for AI features:
- Auto-categorization of messages
- Response drafting in creator's voice
- FAQ auto-responder
- Sentiment analysis
- Collaboration opportunity scoring
- Advanced multi-step agent capabilities

The solid foundation built in Phases 1-6 ensures AI features can be added without compromising core messaging reliability.
