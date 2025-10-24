# AI FAQ Detection Feature - Testing Guide

**Version:** 1.0
**Last Updated:** October 23, 2025
**Status:** Phase 4 Complete (Backend Integration & Security)

---

## Overview

This guide provides comprehensive testing instructions for the intelligent group FAQ detection feature. The feature detects when users ask questions similar to those previously answered in a conversation and provides AI-suggested references.

### Feature Status

**Completed Phases:**
- ✅ **Phase 1-2**: Data Models & AI User Management (iOS)
- ✅ **Phase 3**: Message Rendering & UI (iOS)
- ✅ **Phase 4**: Firebase Cloud Functions & Security (Backend)

**Future Phases:**
- ⏳ **Phase 5**: Actual FAQ Detection Algorithm (Semantic Search & Embeddings)
- ⏳ **Phase 6**: Polish & Optimization

---

## Architecture Overview

```
User Message → Firebase Cloud Function → Check aiEnabled → Python AI Service → Create AI Response → Firestore
                                              ↓
                                      (Skip if not enabled)
```

### Key Components

1. **iOS App** (`/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/`)
   - Message rendering with AI styling
   - FAQ reference link display
   - Scroll-to-message navigation
   - AI user management

2. **Firebase Cloud Functions** (`/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts`)
   - Message trigger on new message creation
   - Conversation `aiEnabled` check
   - FAQ detection toggle via `aiConfig.faqDetectionEnabled`
   - Payload forwarding to Python service

3. **Python AI Service** (`/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py`)
   - Message processing endpoint
   - AI response generation (currently echo agent)
   - Metadata creation with FAQ fields
   - Message creation via Firebase Admin SDK

4. **Firestore Security Rules** (`/Users/Gauntlet/gauntlet/CreatorLink/firebase/firestore.rules`)
   - Prevent user impersonation of AI
   - Allow AI service account to create messages
   - Conversation participant validation

---

## Test Environment Setup

### Prerequisites

- Xcode 15+ with iOS 17+ simulator
- Node.js 18+ and npm
- Python 3.9+ with pip
- Firebase CLI (`npm install -g firebase-tools`)
- Firebase emulator suite running

### Starting the Test Environment

1. **Start Firebase Emulators**
   ```bash
   cd /Users/Gauntlet/gauntlet/CreatorLink
   firebase emulators:start --import=./emulator-data --export-on-exit
   ```

2. **Start Python AI Service**
   ```bash
   cd /Users/Gauntlet/gauntlet/CreatorLink/python-service
   python -m app.main
   ```
   Service should be running on `http://localhost:8000`

3. **Build and Run iOS App**
   - Open Xcode project
   - Select iOS Simulator (iPhone 15 Pro recommended)
   - Build and run (Cmd+R)

4. **Seed Test Data**
   ```bash
   cd /Users/Gauntlet/gauntlet/CreatorLink/emulator-seed
   node seed.js --type=ai-group
   firebase emulators:export ./emulator-data
   ```

---

## Phase 4 Testing Procedures

### Test 1: aiEnabled Conversation Check

**Objective:** Verify Cloud Function only calls Python service when AI is enabled.

**Firestore Data Structure:**
```json
// conversations/{conversationId}
{
  "participantIds": ["user123", "user456", "ai-assistant"],
  "aiEnabled": true,
  "aiConfig": {
    "faqDetectionEnabled": true,
    "minimumSimilarity": 0.85
  }
}
```

**Steps:**

1. **Test with AI Enabled:**
   - Open Firebase emulator UI: `http://localhost:4000/firestore`
   - Locate the "Brand Partnerships" conversation
   - Verify `aiEnabled: true` is set
   - In iOS app, login as Alice (alice.johnson@test.com / password)
   - Open "Brand Partnerships" group
   - Send a test message: "Hello, this is a test"
   - Check Cloud Function logs in terminal:
     ```
     ✓ Should see: "Checking if AI is enabled for conversation"
     ✓ Should see: "New message detected"
     ✓ Should NOT see: "AI not enabled for conversation - skipping"
     ```
   - Check Python service logs:
     ```
     ✓ Should see: "Received message request: {messageId}"
     ✓ Should see: "AI Config: faqDetection=True, similarity=0.85"
     ✓ Should see: "AI response sent successfully"
     ```
   - Check Firestore messages collection:
     ```
     ✓ New AI message should appear with senderId: "ai-assistant"
     ✓ Metadata should include: ai_generated, agent_type, agent_version
     ```

2. **Test with AI Disabled:**
   - In Firestore emulator, edit the conversation document
   - Set `aiEnabled: false`
   - Send another message: "Testing with AI disabled"
   - Check Cloud Function logs:
     ```
     ✓ Should see: "AI not enabled for conversation - skipping"
     ✓ Should NOT see Python service being called
     ```
   - Check Firestore:
     ```
     ✓ No new AI message should be created
     ```

3. **Test with FAQ Detection Disabled:**
   - Set conversation to: `aiEnabled: true`
   - Set `aiConfig.faqDetectionEnabled: false`
   - Send message: "Testing FAQ detection disabled"
   - Check Cloud Function logs:
     ```
     ✓ Should see: "FAQ detection disabled - skipping"
     ```

**Expected Results:**
- AI responses only generated when `aiEnabled: true` AND `faqDetectionEnabled: true`
- Cloud Function logs show decision-making at each step
- No errors or infinite loops

---

### Test 2: AI User ID Consistency

**Objective:** Verify all systems use consistent AI user ID: `"ai-assistant"`

**Steps:**

1. **Check Firestore AI User Document:**
   - Firebase emulator UI → Firestore → users collection
   - Find document with ID `ai-assistant`
   - Verify fields:
     ```json
     {
       "id": "ai-assistant",
       "displayName": "AI Assistant",
       "email": "ai@creatorlink.app",
       "photoURL": "https://www.publicdomainpictures.net/pictures/250000/velka/black-robot-1524158506AN1.jpg",
       "isOnline": true
     }
     ```

2. **Check Cloud Function Constant:**
   - Open `/Users/Gauntlet/gauntlet/CreatorLink/firebase/functions/src/index.ts`
   - Verify line ~17: `const AI_USER_ID = "ai-assistant";`
   - Verify line ~30 uses this constant: `if (messageData?.senderId === AI_USER_ID)`

3. **Check Python Service:**
   - Open `/Users/Gauntlet/gauntlet/CreatorLink/python-service/app/main.py`
   - Verify line ~157: `sender_id="ai-assistant"`

4. **Check iOS Constants:**
   - Open `/Users/Gauntlet/gauntlet/CreatorLink/CreatorLink/Models/AIConstants.swift`
   - Verify: `static let AI_USER_ID = "ai-assistant"`

5. **Send Test Message:**
   - Send message in AI-enabled conversation
   - Check created AI message in Firestore:
     ```
     ✓ senderId should be: "ai-assistant"
     ✓ Should NOT be: "ai-agent" or any other value
     ```

**Expected Results:**
- All systems use `"ai-assistant"` consistently
- No hardcoded "ai-agent" references remain
- AI messages properly identified in iOS app

---

### Test 3: aiConfig Parameter Passing

**Objective:** Verify aiConfig is passed from Cloud Function to Python service.

**Firestore Data Structure:**
```json
// Test configurations to try
{
  // Config 1: Default values
  "aiConfig": {
    "faqDetectionEnabled": true,
    "minimumSimilarity": 0.85
  },

  // Config 2: Custom threshold
  "aiConfig": {
    "faqDetectionEnabled": true,
    "minimumSimilarity": 0.92
  },

  // Config 3: Missing config (should use defaults)
  "aiConfig": null
}
```

**Steps:**

1. **Test with Default Config:**
   - Set conversation aiConfig as Config 1 above
   - Send message: "Testing default config"
   - Check Python service logs:
     ```
     ✓ Should see: "AI Config: faqDetection=True, similarity=0.85"
     ```

2. **Test with Custom Threshold:**
   - Update conversation to Config 2
   - Send message: "Testing custom threshold"
   - Check Python service logs:
     ```
     ✓ Should see: "AI Config: faqDetection=True, similarity=0.92"
     ```

3. **Test with Missing Config:**
   - Remove aiConfig field or set to null
   - Send message: "Testing missing config"
   - Check Cloud Function logs:
     ```
     ✓ Should see payload includes default config
     ```
   - Check Python service logs:
     ```
     ✓ Should see: "AI Config: faqDetection=True, similarity=0.85"
     ✓ No errors about missing config
     ```

**Expected Results:**
- aiConfig values correctly passed to Python service
- Default values applied when config missing
- No errors with null or missing aiConfig

---

### Test 4: Security Rules - Prevent AI Impersonation

**Objective:** Verify regular users cannot create messages with AI senderId.

**WARNING:** This test should fail with permission denied - that's correct behavior!

**Steps:**

1. **Attempt AI Impersonation from iOS:**
   - Note: This requires temporarily modifying iOS code to attempt impersonation
   - Alternatively, use Firebase emulator REST API

   **Using curl:**
   ```bash
   # Get auth token for a regular user
   # This should FAIL with permission denied
   curl -X POST \
     http://localhost:8080/v1/projects/creatorlink-c160a/databases/(default)/documents/messages \
     -H "Authorization: Bearer {user-auth-token}" \
     -H "Content-Type: application/json" \
     -d '{
       "fields": {
         "conversationId": {"stringValue": "conv123"},
         "senderId": {"stringValue": "ai-assistant"},
         "text": {"stringValue": "Fake AI message"},
         "participantIds": {"arrayValue": {"values": [{"stringValue": "user123"}]}},
         "timestamp": {"timestampValue": "2025-10-23T00:00:00Z"},
         "status": {"stringValue": "sent"}
       }
     }'
   ```

2. **Expected Result:**
   ```
   ✓ HTTP 403 Forbidden
   ✓ Error: "Missing or insufficient permissions"
   ✓ Message NOT created in Firestore
   ```

3. **Verify Python Service CAN Create AI Messages:**
   - Send regular message in AI-enabled conversation
   - Python service creates AI response
   - Check Firestore:
     ```
     ✓ AI message created successfully
     ✓ senderId: "ai-assistant"
     ✓ No permission errors
     ```

**Expected Results:**
- Regular users blocked from creating AI messages
- Python service (using Admin SDK) can create AI messages
- Security rules properly enforced

---

### Test 5: Conversation Creation with AI User

**Objective:** Verify AI user can be added to conversations but not as sole participant.

**Steps:**

1. **Create Group with AI + Humans:**
   - In iOS app, create new group
   - Add participants: Alice, Bob, AI Assistant
   - Attempt to save
   - Expected:
     ```
     ✓ Conversation created successfully
     ✓ participantIds includes "ai-assistant"
     ```

2. **Attempt AI-Only Conversation:**
   - Note: Current iOS UI doesn't allow this, but test via API
   - Use Firestore emulator REST API or direct write
   - Try creating conversation with only AI participant
   - Expected:
     ```
     ✓ Should succeed (current rules allow it)
     ✓ Note: This is a known limitation - see PR 4.3 notes
     ```

**Expected Results:**
- AI can be added to group conversations
- Conversations with AI participant work normally

---

### Test 6: Metadata Structure Validation

**Objective:** Verify AI messages have correct metadata format.

**Expected Metadata Structure:**
```json
{
  "ai_generated": "true",
  "original_message_id": "msg123",
  "agent_type": "faq_detector",
  "agent_version": "0.2.0"
}
```

**Steps:**

1. **Send Test Message:**
   - Send message in AI-enabled conversation
   - Wait for AI response

2. **Check AI Message Metadata:**
   - Firebase emulator UI → messages collection
   - Find AI message (senderId: "ai-assistant")
   - Inspect metadata field:
     ```
     ✓ ai_generated: "true" (string, not boolean)
     ✓ original_message_id: (UUID of user's message)
     ✓ agent_type: "faq_detector" (not "echo")
     ✓ agent_version: "0.2.0" (not "0.1.0")
     ```

3. **Verify iOS Display:**
   - Check message in iOS app
   - AI message should have purple background
   - Should show sparkles icon and "AI" badge

**Expected Results:**
- All metadata values are strings
- Metadata structure matches iOS Message model
- Version numbers updated correctly

---

### Test 7: Cloud Function Error Handling

**Objective:** Verify graceful handling of edge cases.

**Test Cases:**

1. **Conversation Not Found:**
   - Manually create message with invalid conversationId
   - Check Cloud Function logs:
     ```
     ✓ Should see: "Conversation not found"
     ✓ Should return null (no retry)
     ```

2. **Python Service Down:**
   - Stop Python service
   - Send message in AI-enabled conversation
   - Check Cloud Function logs:
     ```
     ✓ Should see: "Error calling Python service"
     ✓ Should NOT crash or retry infinitely
     ✓ Regular message still works
     ```

3. **Invalid Message Data:**
   - Send message with missing required fields
   - Check Cloud Function logs:
     ```
     ✓ Should handle gracefully
     ✓ Log error but don't crash
     ```

**Expected Results:**
- No infinite retry loops
- Errors logged but don't crash function
- Regular messaging still works when AI fails

---

## Manual Testing Scenarios

### Scenario 1: Complete FAQ Flow (Simulated)

**Note:** Actual FAQ matching not implemented - using manual data from seed script.

1. **Setup:**
   - Run seed script: `node seed.js --type=ai-group`
   - Login as Alice
   - Open "Brand Partnerships" group

2. **Observe Seed Data:**
   - Scroll up to message ~31: "What do you charge for sponsored Instagram posts?"
   - See message ~32: "I typically charge around $750 per post..."
   - Scroll down to bottom
   - See AI message with FAQ reference

3. **Test FAQ Link:**
   - Tap FAQ reference link on AI message
   - Should scroll to message ~32
   - Yellow highlight should appear
   - Highlight fades after 2 seconds

**Expected:**
- FAQ link visible and tappable
- Scroll animation smooth
- Highlight visible and animates properly

---

### Scenario 2: AI Enabled/Disabled Toggle

1. **Start with AI Disabled:**
   - Create or find conversation without aiEnabled
   - Send several messages
   - Verify no AI responses

2. **Enable AI:**
   - In Firestore, set aiEnabled: true
   - Add "ai-assistant" to participantIds
   - Send new message

3. **Verify:**
   - Cloud Function now calls Python service
   - AI response appears
   - iOS displays AI message with styling

**Expected:**
- Clear on/off behavior
- No errors during transitions
- AI only responds when enabled

---

## Performance Testing

### Load Test: Multiple Messages

**Objective:** Verify system handles rapid message creation.

**Steps:**

1. Send 10 messages rapidly in AI-enabled conversation
2. Observe:
   - Cloud Function processes all messages
   - Python service handles concurrent requests
   - No duplicate AI responses
   - No missed messages

**Expected:**
- All messages processed
- AI responses for each (if enabled)
- No race conditions or errors

---

## Troubleshooting Guide

### Issue: Cloud Function Not Calling Python Service

**Diagnostics:**
1. Check Cloud Function logs for "AI not enabled" message
2. Verify conversation has `aiEnabled: true`
3. Verify `aiConfig.faqDetectionEnabled` is not false
4. Check Python service is running: `curl http://localhost:8000/health`

**Solution:**
- Ensure conversation properly configured
- Restart emulators if needed
- Rebuild Cloud Functions: `cd firebase/functions && npm run build`

---

### Issue: AI Messages Have Wrong Sender ID

**Diagnostics:**
1. Check AI message in Firestore
2. Look at senderId field
3. Check Python service code for sender_id value

**Solution:**
- Verify Python service uses "ai-assistant" not "ai-agent"
- Check line ~157 in main.py
- Restart Python service after changes

---

### Issue: Security Rules Block AI Messages

**Diagnostics:**
1. Check Firestore emulator logs for permission errors
2. Verify security rules deployed to emulator
3. Check Python service authentication method

**Solution:**
- Python service should use Firebase Admin SDK (bypasses rules)
- If using emulator, rules auto-loaded from firestore.rules
- Restart emulator if rules changed

---

## Test Data Reference

### Seed Data Summary

**ai-group seed creates:**
- 4 regular users + AI assistant
- 1 group conversation with AI enabled
- 50 messages including:
  - Message 31: Original question
  - Message 32: Answer to reference
  - Message 49: Similar question
  - Message 50: AI response with FAQ metadata

**Login Credentials:**
- Alice: alice.johnson@test.com / password
- Bob: bob.martinez@test.com / password
- Carol: carol.williams@test.com / password
- David: david.chen@test.com / password

---

## Phase 5 Preview

**Future FAQ Detection Features:**
- Semantic similarity search using embeddings
- Automatic question matching
- Dynamic FAQ link creation
- Confidence scoring
- Historical answer retrieval

**Current Limitation:**
- FAQ metadata is manually added via seed script
- No actual similarity matching implemented
- Python service currently echoes messages

---

## Reporting Issues

When reporting bugs, include:

1. **Environment:**
   - iOS version
   - Xcode version
   - Emulator versions

2. **Steps to Reproduce:**
   - Exact actions taken
   - Test data used

3. **Logs:**
   - Cloud Function logs
   - Python service logs
   - iOS console output

4. **Expected vs Actual:**
   - What should happen
   - What actually happened

5. **Screenshots:**
   - Firestore data
   - iOS app screens
   - Error messages

---

**End of Testing Guide**

For questions or issues, refer to:
- Main implementation plan: `/Users/Gauntlet/gauntlet/CreatorLink/plan_ios.md`
- Task document: `/Users/Gauntlet/gauntlet/CreatorLink/tasks_phase2_ios.md`
- Database schema: `/Users/Gauntlet/gauntlet/CreatorLink/db-types.md`
