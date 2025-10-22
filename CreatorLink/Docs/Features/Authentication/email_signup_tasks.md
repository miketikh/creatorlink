# Email/Password Authentication Implementation Tasks

## Context

This document provides step-by-step implementation tasks for adding email/password authentication to CreatorLink, a Swift/SwiftUI iOS messaging app. Currently, the app only supports Google Sign-In. This feature will add a second authentication method, allowing users to create accounts and sign in using email and password.

**What this provides:**
- Email/password account creation with display name
- Email/password sign-in for existing users
- Password reset via email
- Automatic avatar generation for email users (using UI Avatars API)
- Enhanced error handling with user-friendly messages
- Consistent user profile creation flow

**Key design decisions:**
- Keep Google Sign-In as primary option (already working, established UX)
- Email/password as alternative authentication method
- Generate colorful avatar URLs for email users (Google users keep their Google profile photos)
- Use Firebase Authentication's built-in email/password provider
- Maintain consistent user profile structure in Firestore

This implementation is broken into 3 phases that build on each other. Each phase can be tested independently before moving to the next.

---

## Instructions for AI Agent

When implementing these tasks:
1. **Work sequentially** - Complete Phase 1 before Phase 2, etc.
2. **Test after each PR** - Follow the "What to Test" instructions to verify functionality
3. **Use existing patterns** - Reference AuthService and UserService for code style
4. **Preserve existing functionality** - Don't break Google Sign-In
5. **Follow Swift/SwiftUI conventions** - Use @Observable for services, async/await for asynchronous operations

**File path conventions:**
- Services: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/`
- Views: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/`
- Models: `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/`

---

## Phase 1: Backend Authentication Methods

**Estimated Time:** 1-2 hours

This phase adds the core email/password authentication methods to AuthService, including avatar generation for email users.

### PR 1.1: Add Avatar Generation Helper

**Goal:** Create a helper method to generate consistent avatar URLs for email/password users using the UI Avatars API.

**Tasks:**
- [x] Open `AuthService.swift`
- [x] Add new private method `generateAvatarURL(displayName: String, email: String) -> String`
- [x] Define color palette array inside method:
  - Use colors: `["FF6B6B", "4ECDC4", "45B7D1", "FFA07A", "98D8C8", "F7DC6F", "BB8FCE", "85C1E2"]`
- [x] Hash the email to select consistent color:
  - Calculate: `let colorIndex = abs(email.hashValue) % colorOptions.count`
  - Get: `let color = colorOptions[colorIndex]`
- [x] URL-encode the display name for API call:
  - Use: `displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? displayName`
- [x] Construct avatar URL:
  - Format: `https://ui-avatars.com/api/?name={encodedName}&background={color}&color=fff&rounded=true&size=128&bold=true`
- [x] Return the complete URL string

**What to Test:**
1. Build to verify no compilation errors
2. Add temporary test code that calls the method with sample data:
   - `let url1 = generateAvatarURL(displayName: "John Doe", email: "john@example.com")`
   - `let url2 = generateAvatarURL(displayName: "John Doe", email: "john@example.com")` (same email)
   - `let url3 = generateAvatarURL(displayName: "John Doe", email: "jane@example.com")` (different email)
3. Verify url1 and url2 are identical (same email = same color)
4. Verify url3 has different background color than url1
5. Copy URL to browser and verify it generates a circular avatar with initials "JD"

**Files Changed:**
- `CreatorLink/Services/AuthService.swift` - Add generateAvatarURL helper method

**Notes:**
- UI Avatars API is free with no API key required
- Using email hash ensures same user always gets same color
- The `size=128` parameter generates 128x128px images, good for profile pictures
- URL encoding handles names with spaces or special characters
- This method is private since it's only used internally by AuthService

---

### PR 1.2: Expand AuthError Enum

**Goal:** Add error cases for email/password authentication to provide better error messages.

**Tasks:**
- [x] Open `AuthService.swift`
- [x] Locate the `AuthError` enum (around line 120)
- [x] Add new error cases:
  - `case invalidEmail`
  - `case weakPassword`
  - `case emailAlreadyInUse`
  - `case wrongPassword`
  - `case userNotFound`
  - `case userDisabled`
  - `case networkError`
- [x] Update `errorDescription` computed property with friendly messages:
  - `invalidEmail`: "Please enter a valid email address."
  - `weakPassword`: "Password must be at least 6 characters long."
  - `emailAlreadyInUse`: "An account with this email already exists. Please sign in instead."
  - `wrongPassword`: "Incorrect email or password. Please try again."
  - `userNotFound`: "No account found with this email. Please sign up first."
  - `userDisabled`: "This account has been disabled. Please contact support."
  - `networkError`: "Network error. Please check your connection and try again."
- [x] Add helper method `static func from(_ error: Error) -> AuthError`:
  - Cast error to `NSError`
  - Map Firebase auth error codes to AuthError cases using `error.code`:
    - `AuthErrorCode.invalidEmail.rawValue` → `.invalidEmail`
    - `AuthErrorCode.weakPassword.rawValue` → `.weakPassword`
    - `AuthErrorCode.emailAlreadyInUse.rawValue` → `.emailAlreadyInUse`
    - `AuthErrorCode.wrongPassword.rawValue` → `.wrongPassword`
    - `AuthErrorCode.userNotFound.rawValue` → `.userNotFound`
    - `AuthErrorCode.userDisabled.rawValue` → `.userDisabled`
    - `AuthErrorCode.networkError.rawValue` → `.networkError`
  - Default to returning the original error if no mapping found

**What to Test:**
1. Build to verify no compilation errors
2. No behavioral changes yet - this is infrastructure
3. Verify all error cases have descriptions
4. Verify helper method compiles correctly

**Files Changed:**
- `CreatorLink/Services/AuthService.swift` - Expand AuthError enum with email/password cases and error mapping helper

**Notes:**
- Firebase auth error codes are defined in FirebaseAuth framework
- Error messages should be user-friendly and actionable
- The helper method will be used in next PR to convert Firebase errors
- Keep existing error cases (missingClientID, noRootViewController, missingIDToken)

---

### PR 1.3: Add Email Sign-Up Method

**Goal:** Implement email/password account creation with automatic profile and avatar generation.

**Tasks:**
- [x] Open `AuthService.swift`
- [x] Add new public method after `signInWithGoogle()`:
  - Signature: `func signUpWithEmail(email: String, password: String, displayName: String) async throws -> User`
- [x] Add input validation:
  - Trim whitespace from email and displayName
  - Check if email is empty → throw `.invalidEmail`
  - Check if password.count < 6 → throw `.weakPassword`
  - Check if displayName is empty → throw custom error or use "User" as default
- [x] Create Firebase auth user:
  - Call: `let authResult = try await Auth.auth().createUser(withEmail: email, password: password)`
  - Wrap in do-catch block
  - Convert Firebase errors using `AuthError.from(error)`
- [x] Update Firebase user profile with display name:
  - Create: `let changeRequest = authResult.user.createProfileChangeRequest()`
  - Set: `changeRequest.displayName = displayName`
  - Call: `try await changeRequest.commitChanges()`
- [x] Generate avatar URL:
  - Call: `let avatarURL = generateAvatarURL(displayName: displayName, email: email)`
- [x] Create user profile in Firestore:
  - Call: `try await UserService.shared.createUserProfile(userId: authResult.user.uid, displayName: displayName, email: email, photoURL: avatarURL)`
  - Wrap in do-catch - don't throw if profile creation fails (log error instead)
- [x] Request notification permissions:
  - Create Task block: `Task { _ = await NotificationManager.shared.requestPermission() }`
  - Don't await - let it run in background
- [x] Return the created user:
  - Return: `authResult.user`

**What to Test:**
1. Build to verify no compilation errors
2. Add temporary test button in AuthView that calls:
   - `try await authService.signUpWithEmail(email: "test@example.com", password: "password123", displayName: "Test User")`
3. Tap button and verify:
   - No errors are thrown
   - Check Firebase Console → Authentication → Users to see new user
   - Check Firestore Console → users collection to see user profile with photoURL
4. Copy photoURL from Firestore and open in browser - verify avatar shows "TU" initials
5. Try signing up with same email again - verify error message: "An account with this email already exists"
6. Try weak password (< 6 chars) - verify error message: "Password must be at least 6 characters"
7. Verify notification permission dialog appears after sign-up

**Files Changed:**
- `CreatorLink/Services/AuthService.swift` - Add signUpWithEmail method with validation, avatar generation, and profile creation

**Notes:**
- Firebase requires minimum 6 character passwords by default
- Display name is stored in both Firebase Auth profile AND Firestore (redundant but useful)
- Avatar URL generation happens synchronously (no API call - just URL construction)
- UserService.createUserProfile already handles optional photoURL correctly
- Notification permission request matches existing pattern from signInWithGoogle

---

### PR 1.4: Add Email Sign-In Method

**Goal:** Implement email/password sign-in for existing users.

**Tasks:**
- [x] Open `AuthService.swift`
- [x] Add new public method after `signUpWithEmail()`:
  - Signature: `func signInWithEmail(email: String, password: String) async throws -> User`
- [x] Add input validation:
  - Trim whitespace from email
  - Check if email is empty → throw `.invalidEmail`
  - Check if password is empty → throw `.wrongPassword` (or custom error)
- [x] Sign in with Firebase:
  - Call: `let authResult = try await Auth.auth().signIn(withEmail: email, password: password)`
  - Wrap in do-catch block
  - Convert Firebase errors using `AuthError.from(error)`
- [x] Update existing user profile in Firestore (don't create new one):
  - Fetch current profile to verify it exists:
    - `let existingProfile = try? await UserService.shared.fetchUserProfile(userId: authResult.user.uid)`
  - Only update if profile doesn't exist (edge case handling):
    - If profile is nil, create one using display name from Firebase Auth
    - Generate avatar if needed: `let avatarURL = authResult.user.photoURL?.absoluteString ?? generateAvatarURL(...)`
    - Call: `try await UserService.shared.createUserProfile(...)`
- [x] Return the authenticated user:
  - Return: `authResult.user`

**What to Test:**
1. Build to verify no compilation errors
2. First, create a test account using signUpWithEmail (from PR 1.3)
3. Sign out
4. Add test button that calls:
   - `try await authService.signInWithEmail(email: "test@example.com", password: "password123")`
5. Tap button and verify:
   - Sign-in succeeds
   - User can access the app
   - No new user profile is created in Firestore (check console)
6. Try signing in with wrong password - verify error: "Incorrect email or password"
7. Try signing in with non-existent email - verify error: "No account found with this email"
8. Try signing in with empty email - verify error: "Please enter a valid email address"

**Files Changed:**
- `CreatorLink/Services/AuthService.swift` - Add signInWithEmail method with validation and error handling

**Notes:**
- Sign-in is simpler than sign-up (no profile creation needed)
- Edge case: If user exists in Firebase Auth but not Firestore, create profile
- We don't request notification permission on sign-in (only on first sign-up)
- Error messages should not reveal whether email exists (security best practice) but Firebase defaults do

---

### PR 1.5: Add Password Reset Method

**Goal:** Implement password reset functionality via email.

**Tasks:**
- [x] Open `AuthService.swift`
- [x] Add new public method after `signInWithEmail()`:
  - Signature: `func resetPassword(email: String) async throws`
- [x] Add input validation:
  - Trim whitespace from email
  - Check if email is empty → throw `.invalidEmail`
  - Basic email format validation (contains @ and .)
- [x] Send password reset email:
  - Call: `try await Auth.auth().sendPasswordReset(withEmail: email)`
  - Wrap in do-catch block
  - Convert Firebase errors using `AuthError.from(error)`
- [x] Method returns successfully without revealing if email exists:
  - Firebase automatically sends email only if account exists
  - We don't tell user either way (security best practice)

**What to Test:**
1. Build to verify no compilation errors
2. Add test button that calls:
   - `try await authService.resetPassword(email: "test@example.com")`
3. Tap button and verify no errors
4. Check email inbox for password reset email (may take 1-2 minutes)
5. Click link in email and verify:
   - Opens Firebase password reset page
   - Can set new password
   - Can sign in with new password
6. Try with non-existent email - verify no error (security by design)
7. Try with invalid email format - verify error: "Please enter a valid email address"

**Files Changed:**
- `CreatorLink/Services/AuthService.swift` - Add resetPassword method

**Notes:**
- Firebase handles the entire password reset flow (email template, reset page, etc.)
- Successful response even for non-existent emails prevents email enumeration attacks
- Email templates can be customized in Firebase Console → Authentication → Templates
- No need to update Firestore - password is stored in Firebase Auth only

---

## Phase 2: UI Implementation

**Estimated Time:** 2-3 hours

This phase adds the user interface for email/password authentication, including sign-in, sign-up, and password reset flows.

### PR 2.1: Create Email Sign-In Form View

**Goal:** Build the email/password sign-in form UI as a separate component.

**Tasks:**
- [ ] Create new file `EmailAuthView.swift` in `Views/Auth/` directory
- [ ] Import SwiftUI and add header comment
- [ ] Create struct `EmailAuthView: View`:
  - Add `@Binding var isPresented: Bool` to control dismissal
  - Add `@State private var authService = AuthService.shared`
  - Add `@State private var email = ""`
  - Add `@State private var password = ""`
  - Add `@State private var displayName = ""`
  - Add `@State private var isSignUp = false` (toggle between sign in/sign up)
  - Add `@State private var isLoading = false`
  - Add `@State private var errorMessage: String?`
  - Add `@State private var showPasswordReset = false`
- [ ] Create form UI in body:
  - Use `NavigationStack` as root container
  - Add `.navigationTitle(isSignUp ? "Sign Up" : "Sign In")`
  - Add `.navigationBarTitleDisplayMode(.inline)`
  - Use `VStack(spacing: 20)` for main content
  - Add close button in toolbar (top-right): `.toolbar { Button("Cancel") { isPresented = false } }`
- [ ] Add input fields:
  - If `isSignUp` is true, show `TextField("Full Name", text: $displayName)` with `.textContentType(.name)`
  - Always show `TextField("Email", text: $email)` with:
    - `.textContentType(.emailAddress)`
    - `.keyboardType(.emailAddress)`
    - `.autocapitalization(.none)`
  - Always show `SecureField("Password", text: $password)` with `.textContentType(isSignUp ? .newPassword : .password)`
- [ ] Style input fields consistently:
  - Add `.padding()`
  - Add `.background(Color(.systemGray6))`
  - Add `.cornerRadius(10)`
- [ ] Add error message display:
  - If `errorMessage != nil`, show red text above button
  - Use `.font(.caption)` and `.foregroundColor(.red)`
- [ ] Add primary action button:
  - Button text: isSignUp ? "Create Account" : "Sign In"
  - Action: call `handlePrimaryAction()`
  - Show loading spinner when `isLoading`
  - Disable when loading or fields are empty
  - Style: full width, blue background, white text, rounded corners
- [ ] Add mode toggle button:
  - Show text: isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up"
  - Action: toggle `isSignUp` and clear error message
  - Style: plain text button with blue color
- [ ] Add "Forgot Password?" button:
  - Only show when `!isSignUp`
  - Action: set `showPasswordReset = true`
  - Style: small caption text, secondary color
- [ ] Add `.padding()` to entire VStack

**What to Test:**
1. Build to verify no compilation errors
2. Temporarily add button to AuthView that shows EmailAuthView in a sheet:
   - `@State private var showEmailAuth = false`
   - `Button("Test Email Auth") { showEmailAuth = true }`
   - `.sheet(isPresented: $showEmailAuth) { EmailAuthView(isPresented: $showEmailAuth) }`
3. Tap button and verify:
   - Sheet opens with "Sign In" title
   - Shows Email and Password fields only
   - Shows "Sign In" button
   - Shows "Don't have an account? Sign Up" link
   - Shows "Forgot Password?" link
4. Tap "Sign Up" link and verify:
   - Title changes to "Sign Up"
   - Full Name field appears
   - Button text changes to "Create Account"
   - Toggle link changes to "Already have an account? Sign In"
   - "Forgot Password?" link disappears
5. Toggle back to sign-in mode and verify fields update correctly
6. Verify keyboard types are appropriate (email keyboard shows @, password is hidden)
7. Tap "Cancel" button and verify sheet dismisses

**Files Changed:**
- `CreatorLink/Views/Auth/EmailAuthView.swift` - NEW: Email/password authentication form UI

**Notes:**
- This PR focuses on UI only - no actual authentication yet
- Keep Google Sign-In separate (on main AuthView)
- Use NavigationStack for consistent header styling
- Follow iOS design conventions: `.systemGray6` for input backgrounds
- Display name only shown for sign-up (not needed for sign-in)
- Keyboard types and text content types help iOS provide better autocomplete

---

### PR 2.2: Wire Up Email Authentication Actions

**Goal:** Connect the email auth form UI to the AuthService methods from Phase 1.

**Tasks:**
- [ ] Open `EmailAuthView.swift`
- [ ] Add private method `handlePrimaryAction()`:
  - Set `isLoading = true` and clear error message
  - Wrap in Task for async operations
  - If `isSignUp`:
    - Validate displayName is not empty (set error and return if empty)
    - Call: `try await authService.signUpWithEmail(email: email, password: password, displayName: displayName)`
  - Else:
    - Call: `try await authService.signInWithEmail(email: email, password: password)`
  - On success: dismiss sheet with `isPresented = false`
  - On error: set `errorMessage = error.localizedDescription`
  - Always set `isLoading = false` at end
- [ ] Add input validation before submitting:
  - Check email is not empty
  - Check password is not empty
  - Check displayName is not empty (if sign-up mode)
  - Disable button if validation fails
- [ ] Add computed property `isFormValid: Bool`:
  - Return false if email or password is empty
  - If isSignUp, also check displayName is not empty
  - Use this to disable the submit button
- [ ] Update primary button disabled state:
  - `.disabled(isLoading || !isFormValid)`

**What to Test:**
1. Build and run app
2. Open EmailAuthView sheet
3. Try submitting empty form - verify button is disabled
4. Enter only email - verify button still disabled
5. Enter email + password - verify button becomes enabled
6. Switch to sign-up mode - verify button disabled until display name entered
7. Test sign-up flow:
   - Enter: "John Test" / "john.test@example.com" / "password123"
   - Tap "Create Account"
   - Verify loading spinner appears
   - Verify sheet dismisses on success
   - Verify you're signed into app
   - Check Firebase Console for new user
8. Sign out and test sign-in flow:
   - Enter: "john.test@example.com" / "password123"
   - Tap "Sign In"
   - Verify loading spinner appears
   - Verify sheet dismisses on success
9. Test error handling:
   - Try signing up with existing email - verify error message appears
   - Try signing in with wrong password - verify error message appears
   - Try invalid email format - verify error message appears
   - Try weak password (< 6 chars) - verify error message appears
10. Verify error messages are user-friendly (using AuthError descriptions)

**Files Changed:**
- `CreatorLink/Views/Auth/EmailAuthView.swift` - Add authentication logic and form validation

**Notes:**
- Form validation provides instant feedback (button disabled state)
- Error messages from AuthError enum provide clear guidance
- Loading state prevents double-submission
- Sheet auto-dismisses on successful authentication (AuthService listener updates currentUser)
- Test both sign-up and sign-in flows thoroughly

---

### PR 2.3: Add Password Reset Sheet

**Goal:** Implement the password reset UI flow.

**Tasks:**
- [ ] Create new file `PasswordResetView.swift` in `Views/Auth/` directory
- [ ] Import SwiftUI and add header comment
- [ ] Create struct `PasswordResetView: View`:
  - Add `@Binding var isPresented: Bool`
  - Add `@State private var authService = AuthService.shared`
  - Add `@State private var email = ""`
  - Add `@State private var isLoading = false`
  - Add `@State private var errorMessage: String?`
  - Add `@State private var successMessage: String?`
- [ ] Create UI in body:
  - Use `NavigationStack` as root
  - Add `.navigationTitle("Reset Password")`
  - Add `.navigationBarTitleDisplayMode(.inline)`
  - Add close button in toolbar
  - Use `VStack(spacing: 20)` for content
- [ ] Add instructional text:
  - Show: "Enter your email address and we'll send you a link to reset your password."
  - Style: `.font(.subheadline)` and `.foregroundColor(.secondary)`
- [ ] Add email input field:
  - `TextField("Email", text: $email)`
  - Apply same styling as EmailAuthView (padding, background, corner radius)
  - Add `.textContentType(.emailAddress)` and `.keyboardType(.emailAddress)`
- [ ] Add error/success message display:
  - If `errorMessage != nil`: show red text
  - If `successMessage != nil`: show green text
  - Style with `.font(.caption)` and appropriate color
- [ ] Add "Send Reset Link" button:
  - Action: call `handlePasswordReset()`
  - Show loading spinner when `isLoading`
  - Disable when email is empty or loading
  - Style: full width, blue background, white text, rounded
- [ ] Add padding to VStack
- [ ] Add Spacer() at bottom

**What to Test:**
1. Build to verify no compilation errors
2. Open EmailAuthView and tap "Forgot Password?" link
3. Verify PasswordResetView sheet opens
4. Verify shows title "Reset Password"
5. Verify shows instruction text
6. Verify shows email field
7. Verify button is disabled when email is empty
8. Enter email and verify button becomes enabled
9. Tap "Cancel" and verify sheet dismisses

**Files Changed:**
- `CreatorLink/Views/Auth/PasswordResetView.swift` - NEW: Password reset form UI

**Notes:**
- Keep UI simple and focused on single task
- Clear instructions help user understand what will happen
- Success message is important since Firebase doesn't show confirmation
- Next PR will wire up the actual reset functionality

---

### PR 2.4: Wire Up Password Reset Action

**Goal:** Connect password reset UI to AuthService resetPassword method.

**Tasks:**
- [ ] Open `PasswordResetView.swift`
- [ ] Add private method `handlePasswordReset()`:
  - Set `isLoading = true`
  - Clear both error and success messages
  - Wrap in Task for async operations
  - Call: `try await authService.resetPassword(email: email.trimmingCharacters(in: .whitespaces))`
  - On success:
    - Set `successMessage = "Password reset link sent! Check your email."`
    - Wait 2 seconds: `try? await Task.sleep(nanoseconds: 2_000_000_000)`
    - Dismiss sheet: `isPresented = false`
  - On error:
    - Set `errorMessage = error.localizedDescription`
  - Always set `isLoading = false` at end
- [ ] Open `EmailAuthView.swift`
- [ ] Add state variable: `@State private var showPasswordReset = false`
- [ ] Update "Forgot Password?" button action:
  - Set `showPasswordReset = true`
- [ ] Add sheet modifier to view:
  - `.sheet(isPresented: $showPasswordReset) { PasswordResetView(isPresented: $showPasswordReset) }`

**What to Test:**
1. Build and run app
2. Open EmailAuthView sheet
3. Verify in sign-in mode (not sign-up)
4. Tap "Forgot Password?" link
5. Verify PasswordResetView sheet opens
6. Test with valid email (use account from earlier testing):
   - Enter: "john.test@example.com"
   - Tap "Send Reset Link"
   - Verify loading spinner appears
   - Verify success message: "Password reset link sent! Check your email."
   - Wait 2 seconds - verify sheet auto-dismisses
7. Check email inbox for password reset email
8. Test error handling:
   - Try with empty email - verify button disabled
   - Try with invalid email format - verify error message
9. Test the full reset flow:
   - Open password reset email
   - Click link (opens in browser)
   - Enter new password
   - Return to app
   - Sign in with new password
   - Verify sign-in succeeds

**Files Changed:**
- `CreatorLink/Views/Auth/PasswordResetView.swift` - Add password reset logic
- `CreatorLink/Views/Auth/EmailAuthView.swift` - Add password reset sheet presentation

**Notes:**
- Success message provides immediate feedback since email may take time to arrive
- 2-second delay allows user to read success message before dismissal
- Firebase sends email even if account doesn't exist (security feature - no email enumeration)
- Password reset email goes to spam sometimes - note this in testing
- Firebase password reset page is hosted by Google and secure

---

## Phase 3: Integration with Main Auth Flow

**Estimated Time:** 1 hour

This phase integrates email/password authentication into the main authentication view and ensures everything works together.

### PR 3.1: Add Email Auth Button to AuthView

**Goal:** Add "Sign in with Email" button to the main authentication screen.

**Tasks:**
- [x] Open `AuthView.swift`
- [x] Add state variable: `@State private var showEmailAuth = false`
- [x] Locate the Google Sign-In button (around line 46-68)
- [x] After the Google Sign-In button (and before the final Spacer), add divider:
  - Add `HStack` with text "OR" centered with lines on both sides:
    ```swift
    HStack {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(.gray.opacity(0.3))
        Text("OR")
            .font(.caption)
            .foregroundColor(.secondary)
        Rectangle()
            .frame(height: 1)
            .foregroundColor(.gray.opacity(0.3))
    }
    .padding(.horizontal, 40)
    ```
- [x] Add "Sign in with Email" button:
  - Action: set `showEmailAuth = true`
  - Style similar to Google button but with different color/icon:
    - Use `Image(systemName: "envelope.fill")` icon
    - Use `.gray` or `.secondary` background color
    - Keep same structure as Google button (HStack, padding, corner radius)
    - Text: "Sign in with Email"
  - Add `.padding(.horizontal, 40)` to match Google button
- [x] Add sheet modifier after final closing brace of VStack:
  - `.sheet(isPresented: $showEmailAuth) { EmailAuthView(isPresented: $showEmailAuth) }`

**What to Test:**
1. Build and run app
2. Sign out if currently signed in (to see AuthView)
3. Verify AuthView shows:
   - App logo and title at top
   - Google Sign-In button
   - "OR" divider
   - Email Sign-In button (gray/secondary colored)
   - Both buttons same width and aligned
4. Tap "Sign in with Email" button
5. Verify EmailAuthView sheet opens
6. Test complete sign-up flow from AuthView:
   - Tap Email button
   - Switch to Sign Up mode
   - Create new account
   - Verify app opens to main interface
   - Verify user profile created with avatar
7. Sign out and test sign-in flow:
   - Tap Email button
   - Sign in with credentials
   - Verify authentication succeeds
8. Verify Google Sign-In still works:
   - Sign out
   - Tap Google button
   - Complete Google auth flow
   - Verify still works as before

**Files Changed:**
- `CreatorLink/Views/Auth/AuthView.swift` - Add email authentication button and divider

**Notes:**
- Google Sign-In remains primary option (at top)
- Email option is clearly presented as alternative
- Visual hierarchy: Google button slightly more prominent (blue vs gray)
- OR divider clarifies these are alternative options
- Sheet presentation provides smooth modal experience
- Test both auth methods to ensure neither broke the other

---

### PR 3.2: Update Sign-Out to Handle Both Auth Methods

**Goal:** Ensure sign-out works correctly for both Google and email users.

**Tasks:**
- [x] Open `AuthService.swift`
- [x] Locate `signOut()` method (around line 112)
- [x] Review current implementation - verify it calls:
  - `try Auth.auth().signOut()` (signs out from Firebase)
  - `GIDSignIn.sharedInstance.signOut()` (signs out from Google)
- [x] No changes needed if already structured this way
- [x] Add comment explaining behavior:
  - "Sign out from Firebase (works for all auth providers)"
  - "Sign out from Google Sign-In (no-op if user signed in with email)"

**What to Test:**
1. Build and run app
2. Test Google Sign-In user sign-out:
   - Sign in with Google
   - Navigate to profile/settings (wherever sign-out button is)
   - Tap sign out
   - Verify returns to AuthView
   - Try signing in with Google again - verify works
3. Test email user sign-out:
   - Sign in with email/password
   - Navigate to sign-out button
   - Tap sign out
   - Verify returns to AuthView
   - Try signing in with email again - verify works
4. Test switching between auth methods:
   - Sign in with Google
   - Sign out
   - Sign in with Email
   - Sign out
   - Sign in with Google again
   - Verify no issues

**Files Changed:**
- `CreatorLink/Services/AuthService.swift` - Add comments explaining sign-out behavior (no code changes needed)

**Notes:**
- Firebase signOut() works for all auth providers (Google, email, Facebook, etc.)
- Google signOut() is safe to call even if user didn't use Google (it's a no-op)
- No changes likely needed - this PR is verification and documentation
- Auth state listener automatically updates when user signs out
- Both auth methods use same User object in Firebase, so app treats them identically

---

### PR 3.3: Add Avatar Display to User Profile

**Goal:** Ensure email user avatars are displayed correctly throughout the app.

**Tasks:**
- [ ] Search for components that display user profile photos
- [ ] Open `ChatsView.swift` (or similar files that show user avatars)
- [ ] Verify avatar loading logic handles both:
  - Google profile photos (direct image URLs)
  - UI Avatars URLs (generated image URLs)
- [ ] Check if using AsyncImage or similar - verify it can load from both URL types
- [ ] Test that placeholder/fallback is shown if photoURL is nil or empty
- [ ] Look for any hardcoded assumptions about Google photo URLs
- [ ] Add comment where avatar URLs are loaded:
  - "Supports both Google profile photos and generated avatars (UI Avatars API)"

**What to Test:**
1. Build and run app
2. Create email account with test user:
   - Sign up as "Alice Test" / "alice@example.com"
   - Note the auto-generated avatar color/initials
3. Sign in on second device/simulator as different user (or create another account)
4. Start conversation with Alice
5. Verify in chat list:
   - Alice's avatar appears with correct initials "AT"
   - Avatar is circular
   - Background color matches what was generated
6. Open conversation with Alice
7. Verify in chat detail:
   - Avatar appears next to messages
   - Avatar looks consistent with chat list
8. Test with Google user:
   - Sign in with Google on another device
   - Verify Google profile photo appears correctly
   - Start conversation with Alice (email user)
   - Verify both avatars display correctly in same conversation
9. Test missing avatar handling:
   - Manually set a user's photoURL to empty string in Firestore
   - Verify app shows fallback/placeholder
   - Verify no crashes

**Files Changed:**
- Various view files that display avatars (ChatsView.swift, ChatDetailView.swift, etc.) - Add verification and comments about dual URL support

**Notes:**
- AsyncImage in SwiftUI handles both Google and UI Avatars URLs automatically
- UI Avatars API returns PNG images, same as most profile photo services
- Both URL types should "just work" - this PR is mostly verification
- If avatar loading is already working for Google users, it should work for email users too
- Add fallback for nil/empty photoURL (show initials or generic icon)

---

### PR 3.4: Add Firebase Console Setup Documentation

**Goal:** Document the Firebase Console configuration required for email/password authentication.

**Tasks:**
- [x] Create new file `email_auth_setup.md` in `Docs/Features/Authentication/` directory
- [x] Add header and context:
  - Title: "# Email/Password Authentication Setup"
  - Brief description of what email auth provides
- [x] Add section "## Firebase Console Configuration"
- [x] Add step-by-step instructions:
  1. Go to Firebase Console (console.firebase.google.com)
  2. Select your CreatorLink project
  3. Navigate to "Authentication" in left sidebar
  4. Click "Sign-in method" tab
  5. Under "Sign-in providers", find "Email/Password"
  6. Click the pencil/edit icon
  7. Toggle "Enable" to ON
  8. Click "Save"
- [x] Add section "## Optional Configuration"
- [x] Document optional settings:
  - **Email Enumeration Protection**: Prevents attackers from discovering which emails have accounts
    - Location: Authentication → Settings → User account management
    - Recommendation: Enable for production apps
  - **Password Policy**: Enforce stronger password requirements
    - Location: Authentication → Settings → Password policy
    - Default: 6 characters minimum (Firebase default)
    - Can customize: require uppercase, numbers, special characters
  - **Email Verification**: Require users to verify email before accessing app
    - Location: Customize email verification template in Authentication → Templates
    - Note: Not implemented in current app version (would require additional code)
- [x] Add section "## Email Templates"
- [x] Document customizable email templates:
  - Password reset email (used by resetPassword method)
  - Email verification (if implemented later)
  - Location: Authentication → Templates tab
  - Note: Can customize sender name, subject, and email body
- [x] Add section "## Testing"
- [x] Add testing notes:
  - Email delivery may be delayed (1-2 minutes)
  - Check spam folder if reset emails don't arrive
  - Firebase provides test email feature in Authentication → Users
- [x] Add section "## Security Best Practices"
- [x] Document security recommendations:
  - Enable email enumeration protection in production
  - Customize password policy if needed
  - Monitor authentication activity in Firebase Console
  - Set up authorized domains (defaults to localhost and your deployed domains)

**What to Test:**
1. Follow the documentation steps yourself
2. Verify instructions are clear and accurate
3. Take screenshots if helpful (optional)
4. Ensure all Firebase Console locations are correct
5. Test that email auth works after following setup steps

**Files Changed:**
- `CreatorLink/Docs/Features/Authentication/email_auth_setup.md` - NEW: Firebase setup documentation

**Notes:**
- This documentation is for the developer/admin, not end users
- Firebase Console UI may change - keep instructions high-level where appropriate
- Setup is required before email auth will work
- Most settings are optional - email auth works with defaults
- Email templates can be customized but work fine with defaults

---

## Testing Matrix

### Comprehensive Test Scenarios

After completing all phases, run through these test scenarios to verify complete functionality:

#### Scenario 1: Complete Sign-Up Flow
1. Sign out if currently signed in
2. Tap "Sign in with Email" button
3. Tap "Don't have an account? Sign Up"
4. **Expected:** Form shows Full Name, Email, and Password fields
5. Enter:
   - Full Name: "Test User"
   - Email: "test@example.com"
   - Password: "password123"
6. Tap "Create Account"
7. **Expected:**
   - Loading spinner appears
   - Notification permission dialog appears (approve it)
   - Sheet dismisses
   - App opens to main interface
   - User is authenticated
8. Check Firebase Console → Authentication → Users
9. **Expected:** New user exists with email "test@example.com"
10. Check Firebase Console → Firestore → users collection
11. **Expected:**
    - User document exists with correct ID
    - displayName: "Test User"
    - email: "test@example.com"
    - photoURL: Contains UI Avatars URL with "TU" initials
12. Copy photoURL and open in browser
13. **Expected:** Shows circular avatar with "TU" initials and colored background

#### Scenario 2: Sign-In Flow
1. Sign out from app
2. Tap "Sign in with Email" button
3. Verify form is in sign-in mode (no Full Name field)
4. Enter:
   - Email: "test@example.com"
   - Password: "password123"
5. Tap "Sign In"
6. **Expected:**
   - Loading spinner appears
   - Sheet dismisses
   - App opens to main interface
   - User is authenticated

#### Scenario 3: Error Handling - Sign-Up
1. Sign out and open email auth sheet
2. Switch to Sign Up mode
3. Test weak password:
   - Enter name, email, and password: "12345" (5 chars)
   - Tap "Create Account"
   - **Expected:** Error message: "Password must be at least 6 characters long."
4. Clear error by editing password to "123456"
5. Use existing email:
   - Enter email that already exists
   - Tap "Create Account"
   - **Expected:** Error message: "An account with this email already exists. Please sign in instead."
6. Test invalid email:
   - Enter email: "notanemail"
   - Tap "Create Account"
   - **Expected:** Error message: "Please enter a valid email address."
7. Test empty display name:
   - Clear name field
   - Verify button is disabled (can't submit)

#### Scenario 4: Error Handling - Sign-In
1. Open email auth sheet (sign-in mode)
2. Test wrong password:
   - Enter valid email and wrong password
   - Tap "Sign In"
   - **Expected:** Error message: "Incorrect email or password. Please try again."
3. Test non-existent email:
   - Enter email that doesn't exist
   - Tap "Sign In"
   - **Expected:** Error message: "No account found with this email. Please sign up first."
4. Test empty fields:
   - Clear email or password
   - Verify button is disabled

#### Scenario 5: Password Reset Flow
1. Open email auth sheet (sign-in mode)
2. Tap "Forgot Password?"
3. **Expected:** Password reset sheet opens
4. Enter valid email: "test@example.com"
5. Tap "Send Reset Link"
6. **Expected:**
   - Loading spinner appears
   - Success message: "Password reset link sent! Check your email."
   - After 2 seconds, sheet dismisses
7. Check email inbox (may take 1-2 minutes)
8. **Expected:** Receive password reset email from Firebase
9. Click link in email
10. **Expected:** Opens Firebase password reset page in browser
11. Enter new password and confirm
12. **Expected:** Success message on web page
13. Return to app
14. Try signing in with OLD password
15. **Expected:** Error: "Incorrect email or password"
16. Sign in with NEW password
17. **Expected:** Sign-in succeeds

#### Scenario 6: Avatar Display
1. Create email account "User A" with email "usera@example.com"
2. Note the avatar color and initials
3. Sign out
4. Create Google account "User B" on different device/simulator
5. User B starts conversation with User A
6. **Expected:**
   - User A's avatar shows initials "UA" with colored background
   - User B's avatar shows Google profile photo
7. User A sends message
8. User B views conversation
9. **Expected:**
   - Both avatars display correctly in message bubbles
   - No broken images or loading errors
10. Test group chat with mix of email and Google users
11. **Expected:** All avatars display correctly

#### Scenario 7: Switching Between Auth Methods
1. Sign in with Google
2. Navigate around app - verify works
3. Sign out
4. Sign in with Email/Password
5. Navigate around app - verify works
6. Sign out
7. Sign in with Google again
8. **Expected:**
   - No issues switching between methods
   - Each method works independently
   - User profiles are distinct (different users)

#### Scenario 8: Avatar Color Consistency
1. Create email account: "Color Test" / "colortest@example.com"
2. Note the avatar background color
3. Sign out
4. Sign in again with same account
5. **Expected:** Avatar has SAME background color as before
6. Create different account: "Color Test" / "colortest2@example.com" (different email)
7. **Expected:** Avatar has DIFFERENT background color (emails differ)
8. Create account: "Other Name" / "colortest@example.com" (if allowed - may not be)
9. **Expected:** Same email should produce same color (color based on email, not name)

#### Scenario 9: Form Validation
1. Open email auth sheet
2. Try submitting with all fields empty
3. **Expected:** Button is disabled
4. Enter only email
5. **Expected:** Button still disabled
6. Enter email + password
7. **Expected:** Button becomes enabled (sign-in mode)
8. Switch to sign-up mode
9. **Expected:** Button disabled again (needs display name)
10. Enter display name
11. **Expected:** Button enabled
12. Clear any field
13. **Expected:** Button disabled immediately

#### Scenario 10: Network Error Handling
1. Enable Airplane Mode on device
2. Try to sign up or sign in
3. **Expected:** Error message about network connectivity
4. Disable Airplane Mode
5. Try again
6. **Expected:** Authentication succeeds

---

## Files Summary

### New Files Created

| File Path | Purpose | Phase |
|-----------|---------|-------|
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Auth/EmailAuthView.swift` | Email/password sign-in and sign-up form UI | 2 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Auth/PasswordResetView.swift` | Password reset request form UI | 2 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Docs/Features/Authentication/email_auth_setup.md` | Firebase Console setup documentation | 3 |

### Files Modified

| File Path | Changes | Phase |
|-----------|---------|-------|
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/AuthService.swift` | - Add generateAvatarURL helper method<br>- Expand AuthError enum with email auth cases<br>- Add error mapping helper<br>- Add signUpWithEmail method<br>- Add signInWithEmail method<br>- Add resetPassword method<br>- Add comments to signOut method | 1, 3 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Auth/AuthView.swift` | - Add email sign-in button<br>- Add "OR" divider<br>- Add sheet presentation for EmailAuthView | 3 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatsView.swift` | - Add comments about dual avatar URL support<br>- Verify AsyncImage handles both URL types | 3 |
| `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/ChatDetailView.swift` | - Add comments about avatar loading<br>- Verify fallback for missing avatars | 3 |

### No Changes Required

- UserProfile model (photoURL already optional String)
- UserService (createUserProfile already handles optional photoURL)
- Firebase Realtime Database structure
- Any conversation or message models
- NotificationManager (works same for all auth methods)
- Firestore security rules (should allow authenticated users regardless of auth method)

---

## Success Criteria

Email/password authentication implementation is complete when all of the following are verified:

- [ ] Users can create new accounts with email, password, and display name
- [ ] Users can sign in with existing email/password credentials
- [ ] Users can request password reset via email
- [ ] Password reset email is received and link works
- [ ] Email users get auto-generated avatars with initials and consistent colors
- [ ] Avatars display correctly throughout the app
- [ ] Both email and Google authentication methods work independently
- [ ] User can switch between auth methods (sign out and use different method)
- [ ] Form validation prevents invalid submissions
- [ ] Error messages are clear and user-friendly
- [ ] Loading states provide feedback during async operations
- [ ] AuthView shows both sign-in options with clear visual hierarchy
- [ ] Email auth follows same user profile structure as Google auth
- [ ] Notification permissions requested after email sign-up
- [ ] No crashes or broken functionality in existing Google auth flow

---

## Common Issues and Solutions

### Issue: Password reset email not received
**Solution:** Check spam folder. Firebase emails sometimes filtered. Also check Firebase Console → Authentication → Templates to ensure email sending is configured. Test email may take 1-2 minutes to arrive.

### Issue: Avatar not displaying
**Solution:** Verify photoURL in Firestore contains valid UI Avatars URL. Check that URL encoding handled spaces in name correctly. Test URL in browser to confirm it loads. Verify AsyncImage used for avatar loading.

### Issue: "Email already exists" error when testing
**Solution:** Use Firebase Console → Authentication → Users to delete test accounts, or use unique email addresses for each test (e.g., test1@example.com, test2@example.com).

### Issue: Weak password error even with 6+ characters
**Solution:** Check Firebase Console → Authentication → Settings → Password policy. May have custom requirements enabled. Default is 6 characters minimum with no complexity requirements.

### Issue: Sign-up succeeds but profile not created in Firestore
**Solution:** Check Firestore security rules. Ensure authenticated users can write to `users/{userId}` collection. Check UserService.createUserProfile error handling - failures shouldn't prevent sign-up but should be logged.

### Issue: Avatar color changes on each sign-in
**Solution:** Verify color is hashed from email, not random generation. Check generateAvatarURL implementation uses `email.hashValue` consistently. Same email must always produce same hash.

### Issue: Button remains disabled with valid form
**Solution:** Check isFormValid computed property logic. Verify all @State bindings are updating correctly. Check for whitespace-only inputs (may need trimming).

### Issue: Google Sign-In broke after adding email auth
**Solution:** Verify didn't accidentally modify Google auth code. Check signInWithGoogle method is unchanged. Ensure Google button still wired correctly in AuthView.

### Issue: Sheet doesn't dismiss after successful auth
**Solution:** Verify `isPresented` binding is set to false. Check that auth state listener is working - successful auth should update currentUser which triggers view updates.

---

## Next Steps

After completing all phases:

1. **Test thoroughly** using the Testing Matrix above
2. **Enable email/password in Firebase Console** following setup documentation
3. **Gather user feedback** on authentication UX
4. **Consider future enhancements**:
   - Email verification requirement (require users to verify email before accessing app)
   - Social auth providers (Apple Sign-In, Facebook, Twitter)
   - Two-factor authentication (2FA) for enhanced security
   - Profile editing (allow users to change display name, upload custom avatar)
   - Account deletion (allow users to delete their accounts)
5. **Monitor authentication errors** in Firebase Console → Authentication → Analytics

---

## Security Considerations

### Current Implementation
- Passwords handled entirely by Firebase (never stored locally or in Firestore)
- Minimum 6 character password requirement (Firebase default)
- Password reset via secure Firebase email flow
- Auth state managed by Firebase Authentication

### Recommendations for Production
- **Enable email enumeration protection** in Firebase Console
  - Prevents attackers from discovering which emails have accounts
  - Trade-off: Less specific error messages for users
- **Customize password policy** for stronger requirements
  - Require uppercase, lowercase, numbers, special characters
  - Increase minimum length to 8-12 characters
- **Implement email verification** (requires additional code)
  - Require users to verify email before accessing app features
  - Reduces spam accounts and ensures email deliverability
- **Set up authorized domains** in Firebase Console
  - Limit which domains can authenticate (prevent domain spoofing)
- **Monitor authentication logs** regularly
  - Check for suspicious patterns (brute force attempts, etc.)
  - Firebase provides basic analytics in Console
- **Consider rate limiting** for sign-up/sign-in attempts
  - Prevents automated attacks
  - Can be implemented with Cloud Functions (not included in this implementation)

### Privacy Considerations
- User email stored in both Firebase Auth and Firestore (needed for user profiles)
- Display name stored in both locations (redundant but useful for offline access)
- Avatar URL generated based on email and name (no external service stores data)
- Passwords never stored in Firestore (only in secure Firebase Auth)
- No sensitive data in error messages (email enumeration protection)

---

## Estimated Timeline

- **Phase 1** (Backend Authentication): 1-2 hours
  - PR 1.1: 15 minutes
  - PR 1.2: 15 minutes
  - PR 1.3: 30 minutes
  - PR 1.4: 20 minutes
  - PR 1.5: 15 minutes
- **Phase 2** (UI Implementation): 2-3 hours
  - PR 2.1: 45 minutes
  - PR 2.2: 30 minutes
  - PR 2.3: 30 minutes
  - PR 2.4: 30 minutes
- **Phase 3** (Integration): 1 hour
  - PR 3.1: 20 minutes
  - PR 3.2: 10 minutes
  - PR 3.3: 20 minutes
  - PR 3.4: 15 minutes

**Total Implementation Time:** 4-6 hours

**Testing Time:** 2-3 hours for comprehensive testing across all scenarios

**Firebase Console Setup:** 5-10 minutes (one-time setup)

---

## Additional Resources

- [Firebase Email/Password Authentication Guide](https://firebase.google.com/docs/auth/ios/password-auth)
- [UI Avatars API Documentation](https://ui-avatars.com/)
- [Firebase Password Reset Documentation](https://firebase.google.com/docs/auth/ios/manage-users#send_a_password_reset_email)
- [Apple Human Interface Guidelines - Authentication](https://developer.apple.com/design/human-interface-guidelines/authentication)
- [Swift Hashing Documentation](https://developer.apple.com/documentation/swift/hashable)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-21
**Status:** Ready for Implementation
**Feature:** Email/Password Authentication
