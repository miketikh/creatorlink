# Leave Group Debugging Report

**Date:** 2025-10-22
**Issue:** Leave Group functionality not working
**Status:** ROOT CAUSE IDENTIFIED - Firestore Security Rules

---

## Problem Summary

User clicks "Leave Group" → Confirms alert → **Nothing happens**
- User remains in the group
- Group still shows in conversation list
- No error messages displayed to user
- Firestore update appears to fail silently

---

## Investigation History

### Attempts Made (All Failed):
1. ❌ Used real-time listener to detect participantIds change and dismiss
2. ❌ Added manual dismiss() after successful leave
3. ❌ Switched to callback pattern (onDismiss) instead of @Environment(\.dismiss)
4. ❌ Added 300ms delay for alert animation timing
5. ❌ Changed to state-triggered .task(id:) pattern
6. ❌ Wrapped dismiss in MainActor.run

### What We Learned:
- The UI code is working correctly
- Alert button triggers properly
- Task block executes
- All IDs (conversationId, userId) are valid
- ConversationService.leaveGroup() is called
- Firestore document is fetched successfully
- System message is created

---

## Root Cause - FIRESTORE SECURITY RULES

**Captured logs reveal the actual problem:**

```
[ConversationService] 🔥 leaveGroup: Updating Firestore to remove userId from participantIds
[GroupInfoView] 📡 Listener: Received update, participantIds count: 2
[GroupInfoView] 👤 Listener: Current userId: rT4dwJ2UhvYUt4lXLyn6GJVy59J2, isStillInGroup: false
[ConversationService] ❌ leaveGroup: Unexpected error: Missing or insufficient permissions.
[GroupInfoViewModel] ❌ leaveGroup: Error occurred: Failed to update conversation: Missing or insufficient permissions.
[GroupInfoView] 📡 Listener: Received update, participantIds count: 3
[GroupInfoView] 👤 Listener: Current userId: rT4dwJ2UhvYUt4lXLyn6GJVy59J2, isStillInGroup: true
```

**What's happening:**
1. ConversationService attempts to update Firestore: `arrayRemove([userId])`
2. Update briefly succeeds - listener sees `participantIds count: 2`
3. **Firestore security rules reject the update**: `Missing or insufficient permissions`
4. Firestore **rolls back the transaction** - count returns to 3
5. User remains in the group

---

## The Firestore Update Operation

**File:** `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift`

**Method:** `leaveGroup(conversationId:userId:)`

**The failing Firestore operation:**
```swift
try await docRef.updateData([
    "participantIds": FieldValue.arrayRemove([userId]),
    "unreadCounts.\(userId)": FieldValue.delete()
])
```

**Why it's failing:**
The current Firestore security rules for the `conversations` collection do NOT allow users to:
- Remove themselves from the `participantIds` array
- Delete their own entry in the `unreadCounts` map

---

## Solution Required

**Update Firestore Security Rules** to allow users to leave groups by:

1. Allowing users to remove themselves from `participantIds`
2. Allowing users to delete their own `unreadCounts` entry
3. Ensuring this only works for the current authenticated user (not allowing removal of others)

**Example rule pattern needed:**
```javascript
match /conversations/{conversationId} {
  allow update: if request.auth != null
    && (
      // Allow users to remove themselves from participantIds
      (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['participantIds', 'unreadCounts'])
       && resource.data.participantIds.hasAll([request.auth.uid])
       && !request.resource.data.participantIds.hasAll([request.auth.uid]))
      // ... other update conditions
    );
}
```

---

## Files Involved

### Working Files (No Changes Needed):
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Views/Chats/GroupInfoView.swift` - UI and alert handling ✅
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/ViewModels/GroupInfoViewModel.swift` - Business logic ✅
- `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Services/ConversationService.swift` - Firestore operations ✅

### File That Needs Changes:
- **Firestore Security Rules** (firestore.rules in Firebase Console) ❌

---

## Comparison: Why Remove Participant Works

The "Remove Participant" feature works because:
- It's likely initiated by a group admin/creator
- Security rules probably allow the creator to modify `participantIds`
- Different permission level than self-removal

**Leave Group is different:**
- User removing *themselves* from `participantIds`
- Requires explicit security rule to allow self-removal
- Currently blocked by overly restrictive rules

---

## Next Steps

1. **Access Firebase Console** → Go to Firestore Database → Rules tab
2. **Locate conversations collection rules**
3. **Add permission for users to remove themselves from groups**
4. **Test the leave functionality** - should work immediately after rule update
5. **No code changes required** - the Swift code is correct

---

## Current Implementation (Correct)

**Alert Pattern:**
```swift
.alert("Leave Group", isPresented: $showLeaveConfirmation) {
    Button("Cancel", role: .cancel) {}
    Button("Leave", role: .destructive) {
        Task {
            await leaveGroupTapped()
        }
    }
}
```

**Leave Method:**
```swift
private func leaveGroupTapped() async {
    guard let conversationId = conversation.id,
          let userId = UserService.shared.currentUserId else { return }

    do {
        try await viewModel.leaveGroup(conversationId: conversationId, userId: userId)
        onDismiss()
    } catch {
        // Error shown via viewModel.errorMessage
    }
}
```

**Service Method:**
```swift
func leaveGroup(conversationId: String, userId: String) async throws {
    // ... fetch conversation ...

    try await docRef.updateData([
        "participantIds": FieldValue.arrayRemove([userId]),
        "unreadCounts.\(userId)": FieldValue.delete()
    ])
}
```

---

## Key Insight

**All the Swift code is working perfectly.** The issue is purely a Firestore security configuration problem. The extensive debugging and multiple attempted fixes were all unnecessary - we were fixing the wrong layer. The logs clearly show the Firestore operation is being rejected by security rules, not failing due to Swift code issues.

---

**Document Version:** 1.0
**Last Updated:** 2025-10-22
**Issue Status:** Identified - Awaiting Firestore Rules Update
