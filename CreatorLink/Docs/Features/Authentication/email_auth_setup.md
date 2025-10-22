# Email/Password Authentication Setup

Email/password authentication provides an alternative sign-in method for CreatorLink users who prefer not to use Google Sign-In. This feature allows users to create accounts using their email address and password, with automatic profile creation and avatar generation.

**What this provides:**
- Account creation with email, password, and display name
- Sign-in for existing email/password users
- Password reset via email
- Auto-generated colorful avatars for email users
- Consistent user experience across authentication methods

---

## Firebase Console Configuration

To enable email/password authentication in CreatorLink, follow these steps:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your CreatorLink project
3. Navigate to **Authentication** in the left sidebar
4. Click the **Sign-in method** tab
5. Under **Sign-in providers**, find **Email/Password**
6. Click the pencil/edit icon
7. Toggle **Enable** to ON
8. Click **Save**

That's it! Email/password authentication is now enabled for your app.

---

## Optional Configuration

### Email Enumeration Protection

Email enumeration protection prevents attackers from discovering which email addresses have accounts by analyzing error messages.

**Location:** Authentication → Settings → User account management

**Recommendation:** Enable for production apps

**Trade-off:** When enabled, error messages become less specific. Users won't know if they entered a wrong password or if the account doesn't exist.

### Password Policy

Enforce stronger password requirements beyond the default 6-character minimum.

**Location:** Authentication → Settings → Password policy

**Default:** 6 characters minimum (Firebase default)

**Customizable options:**
- Minimum length (increase to 8-12 characters)
- Require uppercase letters
- Require lowercase letters
- Require numbers
- Require special characters

**Note:** Stronger password policies improve security but may frustrate users. Balance security with usability based on your app's needs.

### Email Verification

Require users to verify their email address before accessing app features.

**Location:** Authentication → Templates tab (Email address verification template)

**Note:** Email verification is not currently implemented in CreatorLink's code. Enabling this feature would require additional development work to:
- Check user email verification status on sign-in
- Resend verification emails
- Handle unverified user state in the app

This can be added as a future enhancement if needed.

---

## Email Templates

Firebase provides customizable email templates for password reset and email verification.

**Location:** Authentication → Templates tab

**Available templates:**
- **Password reset** - Used when users tap "Forgot Password?" in the app
- **Email verification** - Used if email verification is implemented
- **Email address change** - Used if users change their email address
- **SMS verification** - For phone authentication (not used in CreatorLink)

**Customization options:**
- Sender name (e.g., "CreatorLink Team")
- Email subject line
- Email body content
- Custom action URL

**Default behavior:** Firebase provides working templates out of the box. Customization is optional but recommended for better branding.

---

## Testing

### Email Delivery Notes

- Password reset emails may take 1-2 minutes to arrive
- Check spam/junk folder if emails don't appear in inbox
- Some email providers (especially corporate/school domains) may block Firebase emails
- Gmail, Outlook, and Yahoo typically deliver Firebase emails reliably

### Test Email Feature

Firebase provides a test email feature for development:

**Location:** Authentication → Users

**To test:**
1. Create a test user in the Firebase Console
2. Click on the user
3. Use "Send password reset email" option
4. Verify email is received and link works

### Testing with Emulator

For local development without sending real emails:
1. Use Firebase Emulator Suite for Authentication
2. Configure in Firebase Console → Authentication → Settings
3. Password reset emails will be logged instead of sent
4. This is useful for automated testing

---

## Security Best Practices

### For Production Apps

1. **Enable email enumeration protection**
   - Prevents attackers from discovering which emails have accounts
   - Location: Authentication → Settings → User account management

2. **Customize password policy**
   - Increase minimum length to 8+ characters
   - Consider requiring uppercase, numbers, or special characters
   - Balance security with user experience

3. **Monitor authentication activity**
   - Review Firebase Console → Authentication → Usage
   - Look for suspicious patterns (multiple failed attempts, unusual locations)
   - Set up alerts for unusual activity

4. **Configure authorized domains**
   - Location: Authentication → Settings → Authorized domains
   - Firebase defaults to localhost and your deployed domains
   - Remove unused domains to prevent unauthorized use
   - Add custom domains if you host authentication pages

5. **Review Firestore security rules**
   - Ensure only authenticated users can read/write their own data
   - Prevent unauthorized access to user profiles
   - Location: Firestore Database → Rules

6. **Consider rate limiting**
   - Prevent brute force attacks on sign-in
   - Can be implemented with Cloud Functions (advanced)
   - Monitor for repeated failed sign-in attempts

### Privacy Considerations

- User email addresses are stored in both Firebase Auth and Firestore
- Display names are stored in both locations for offline access
- Passwords are NEVER stored in Firestore (only in Firebase Auth's secure storage)
- Avatar URLs are generated using UI Avatars API (no user data sent to third parties)
- No sensitive information is exposed in error messages

---

## Troubleshooting

### Password reset email not received

**Possible causes:**
- Email in spam/junk folder
- Email provider blocking Firebase emails
- Incorrect email address entered
- Firebase email sending not configured

**Solutions:**
- Check spam folder
- Try a different email provider (Gmail usually works)
- Verify email templates are configured in Firebase Console
- Check Firebase project email sending limits (should be sufficient for normal use)

### "Email already in use" error

**Cause:** User trying to sign up with email that already has an account

**Solution:** Direct user to sign-in instead, or use password reset if they forgot credentials

### Weak password error

**Cause:** Password doesn't meet Firebase password policy requirements

**Solution:** Ensure password is at least 6 characters (or longer if custom policy is set)

### Authentication working in iOS app but not web

**Cause:** Domain not authorized in Firebase Console

**Solution:** Add domain to authorized domains list in Firebase Console → Authentication → Settings

### Users can't change password in app

**Note:** Password change functionality is not currently implemented in CreatorLink. Users must use the "Forgot Password?" flow to reset their password via email.

**Future enhancement:** Add a "Change Password" feature in app settings for authenticated users.

---

## Next Steps

After enabling email/password authentication:

1. **Test the complete flow**
   - Create a test account with email/password
   - Sign out and sign in again
   - Test password reset flow
   - Verify avatar generation works

2. **Customize email templates** (optional)
   - Update password reset email with your branding
   - Customize sender name to match your app

3. **Enable security features**
   - Turn on email enumeration protection for production
   - Review and adjust password policy if needed

4. **Monitor usage**
   - Check Firebase Console regularly for authentication activity
   - Watch for any errors or suspicious patterns

5. **Consider future enhancements**
   - Email verification requirement
   - Password change in app settings
   - Account deletion option
   - Two-factor authentication (2FA)

---

## Additional Resources

- [Firebase Email/Password Authentication Documentation](https://firebase.google.com/docs/auth/ios/password-auth)
- [Firebase Authentication Best Practices](https://firebase.google.com/docs/auth/best-practices)
- [UI Avatars API Documentation](https://ui-avatars.com/)
- [Firebase Security Rules Guide](https://firebase.google.com/docs/rules)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-21
**Status:** Complete
**Feature:** Email/Password Authentication Setup
