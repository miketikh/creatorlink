# AI responding in users voice


## Flow

Imagine trying to create automatic responses for user A

- Each message cloud fn passes through to AI, passes in msg + last 5
- AI checks if there is any new information to extract IN THIS message only, so as not to add the same piece of info
    - ex. if exchange has "do you like dogs?" and user a responds with "I like dogs", then "I've got a golden retriever", AI would add them sequentially to user a's vector knowledgebase
- Every 10 messages in a conversatoin, would trigger script to analyze user behavior
    - See plan below, but would update a json or config with the user's behavior (capitalization, length, etc) for specific contexts (for business, social, collaboration)
        - would only update behaviors when it notices a change to patterns
- with AI mode activated when the AI has enough info, can suggest responses based on that combination
    - someone asks question, IF the AI has that knowledge, combines it with the right tone to create custom response and send back


## Necessary changes

- UX
    - How to activate "AI response mode"
        - Should it be per conversation or in general?
        - SHould it send responses, or just suggest them?
            - maybe we can have a drafts feature in conversations, that loads up the text into the input when the user loads the conversation, and the AI would save their suggestion to drafts
            - would also be nice then to have a filter
        - Decisions
            - Should be a one off toggle per user
            - Set AI response mode to on / off
            - AI creates responses as "drafts" for conversations, gets shown when user clicks on the convo, and in the chat preview as "AI DRAFT: " (should differentiate AI suggested drafts from user drafts)    
            - The AI should update the draft as new messages come in, so if the sender sends more messages, it should update the draft response based on those
- AI portion    
    - need to expand AI capabilities to
        - add knowledge to vector store
        - update user's tone preferences / voice every 10-20 messages
        - AFTER it has sufficient information, create draft responses for user in the conversation if feature is enabled
            - For example, should not create responses before it understands user's tone OR if vector store doesnt have relevant answer

## Caution points

- Need to review and analyze our AI implementation as we're adding more features
    - Dont want to just keep passing one message through 20 if / else statements and conditions
    - Should we move to langchain and have an orchestrator AI? 
- How do we trigger the firestore tone update to only send every 10-20 messages in a conversation?
- Does firestore have vector store capabilities? (Look up to verify, may have changed)

## MVP implementation

- Can skip updates to user tone for now, create static file
- Can seed vector with user knowledge

Original AI discussion with ideas (note, does not have to be strictly adhered to, but good for guidance):
```
Great! This is a meaty feature. Let me break down both components and challenge some assumptions.

---

## **COMPONENT 1: Voice/Style Learning**

### **What You DON'T Want to Store**

❌ **Exact message templates** ("I usually say 'Hey! Thanks for reaching out...'")
- Reason: Sounds robotic, repetitive, loses authenticity

❌ **Every typo verbatim** ("teh" instead of "the")
- Reason: Makes AI look like it's mocking you, not authentic

❌ **Raw message history for style** (all 500 messages in context)
- Reason: Expensive, slow, and LLMs can extract style from instructions better than examples

### **What You DO Want to Capture**

Think of it as **"style DNA"** not "message templates." Here's what matters:

---

## **Style Profile Structure**

### **Proposed Schema: `users/{userId}/voiceProfiles/{category}`**

```javascript
{
  category: "business",
  
  // Structural patterns
  structure: {
    avgMessageLength: 45,        // words
    sentencesPerMessage: 2.3,
    paragraphStyle: "single",    // "single" | "multi" | "mixed"
    useBulletPoints: false,
    useNumberedLists: false
  },
  
  // Language patterns
  language: {
    formality: 0.8,              // 0 (very casual) to 1 (very formal)
    contractionFreq: 0.3,        // "I'm" vs "I am" (0 = never, 1 = always)
    slangs: ["btw", "imo"],      // common slang terms used
    fillerWords: ["just", "honestly", "actually"],
    technicalTerms: ["ROI", "deliverables", "scope"]
  },
  
  // Punctuation & capitalization
  mechanics: {
    capitalization: "proper",     // "proper" | "lowercase" | "mixed"
    punctuationStyle: "formal",   // "formal" (periods) | "casual" (none/minimal)
    exclamationFreq: 0.1,         // How often messages end with !
    questionMarkUsage: "standard", // "standard" | "multiple" (???)
    ellipsisUsage: false,         // Use of ...
  },
  
  // Emoji & expressiveness
  expressiveness: {
    emojiFrequency: 0.05,         // emojis per message
    commonEmojis: ["👍", "😊"],
    emojiPlacement: "end",        // "end" | "inline" | "both"
    useGIFs: false,
    useReactions: true
  },
  
  // Opening & closing patterns
  patterns: {
    greetings: {
      common: ["Hi", "Hey"],
      formal: ["Good morning", "Hello"],
      casual: ["yo", "sup"]
    },
    closings: {
      common: ["Thanks", "Best"],
      formal: ["Best regards", "Thank you"],
      casual: ["cheers", "talk soon"]
    },
    responseStarters: ["Absolutely", "For sure", "I think"],
    transitionPhrases: ["That said", "Also", "By the way"]
  },
  
  // Timing & behavior
  behavior: {
    responseSpeed: "moderate",    // "instant" | "moderate" | "delayed"
    multiMessageBursts: true,     // Sends 3 quick messages vs 1 long one?
    editsMessages: false,         // Frequently edits after sending?
    voiceNoteUser: false          // Uses voice notes?
  },
  
  // Contextual preferences
  context: {
    firstMessageStyle: "warm",    // How to start new convos
    followUpStyle: "brief",       // How to continue existing threads
    questionAnswerStyle: "direct" // Direct answers vs elaboration
  },
  
  // Meta
  confidence: 0.7,                // How confident is this profile?
  sampleSize: 47,                 // Based on N messages
  lastUpdated: Timestamp
}
```

---

## **How to Build This Profile**

### **Approach 1: Statistical Analysis (Lightweight)**

Every time user sends a message in a category:

```javascript
// Pseudo-code
function analyzeAndUpdateProfile(message, category) {
  const profile = getUserProfile(category);
  
  // Update statistics
  profile.structure.avgMessageLength = 
    rollingAverage(profile.structure.avgMessageLength, 
                   message.wordCount, 
                   profile.sampleSize);
  
  profile.mechanics.exclamationFreq = 
    countOccurrences(message.text, '!') / profile.sampleSize;
  
  profile.expressiveness.emojiFrequency = 
    countEmojis(message.text) / profile.sampleSize;
  
  // Detect patterns
  if (startsWithGreeting(message.text)) {
    profile.patterns.greetings.push(extractGreeting(message.text));
  }
  
  // Update confidence
  profile.confidence = Math.min(1.0, profile.sampleSize / 50);
  profile.sampleSize++;
  
  saveProfile(profile);
}
```

**Pros:** Simple, fast, incremental
**Cons:** Misses nuance, purely quantitative

---

### **Approach 2: LLM-Based Style Extraction (Better)**

Every 10-20 messages, ask an LLM to analyze:

```javascript
function extractStyleWithLLM(recentMessages, category) {
  const prompt = `
    Analyze these ${recentMessages.length} messages to extract communication style:
    
    ${recentMessages.map(m => m.text).join('\n')}
    
    Extract:
    1. Formality level (0-1 scale)
    2. Common greeting/closing phrases
    3. Average message length preference
    4. Punctuation habits
    5. Emoji usage patterns
    6. Any unique speech patterns or phrases
    
    Return as JSON matching this schema: ${styleProfileSchema}
  `;
  
  const analysis = await callOpenAI(prompt, { response_format: "json" });
  
  return mergeWithExistingProfile(currentProfile, analysis);
}
```

**Pros:** Captures nuance, context-aware
**Cons:** More expensive, requires periodic batch processing

---

### **Approach 3: Hybrid (Recommended)**

- **Real-time:** Update simple stats (length, emoji count, punctuation)
- **Batch (daily):** LLM analyzes last 20 messages for deeper patterns
- **User feedback:** When user edits AI suggestion, extract what they changed

---

## **COMPONENT 2: Knowledge Storage**

### **What to Store in Vector DB**

Think of this as **"facts about me that I've shared"**:

**Examples:**
- "My consulting rate is $500/hour"
- "I'm based in Austin, Texas"
- "I don't work with alcohol brands"
- "My audience is 70% Gen Z"
- "I'm available Tuesday afternoons for calls"
- "I prefer email for contracts"
- "My manager handles sponsorships over $10k"

### **Vector Entry Structure**

```javascript
{
  id: "knowledge_abc123",
  embedding: [0.234, -0.567, ...],
  metadata: {
    userId: "user123",
    category: "business",          // Where this knowledge applies
    factType: "pricing",            // pricing | availability | preference | fact
    text: "My rate for sponsored Instagram posts is $2,000",
    extractedFrom: "msg_xyz789",   // Source message
    confidence: 0.9,
    dateShared: Timestamp,
    timeSensitive: true,           // Does this expire?
    expiresAt: null                // For time-sensitive facts
  }
}
```

---

## **How to Extract Knowledge**

### **Trigger: User Sends a Message Containing Info**

```javascript
async function extractKnowledge(userMessage, conversationContext) {
  const prompt = `
    Extract factual information the user shared about themselves:
    
    Message: "${userMessage.text}"
    Context: Last 5 messages: ${conversationContext}
    
    Extract:
    - Facts (pricing, availability, preferences, constraints)
    - Category relevance (business/social/collab)
    - Time-sensitivity (does this expire?)
    
    Return JSON array of facts.
  `;
  
  const facts = await callOpenAI(prompt);
  
  // For each fact, create embedding and store
  for (const fact of facts) {
    const embedding = await createEmbedding(fact.text);
    await vectorDB.store({
      embedding,
      metadata: {
        userId: currentUser,
        factType: fact.type,
        text: fact.text,
        category: fact.category,
        ...
      }
    });
  }
}
```

### **Example Extraction**

**User message:** "I charge $500/hour for consulting, but my rate goes up to $750 for weekend work"

**Extracted facts:**
```json
[
  {
    "text": "Consulting rate is $500/hour",
    "factType": "pricing",
    "category": "business",
    "timeSensitive": false
  },
  {
    "text": "Weekend consulting rate is $750/hour",
    "factType": "pricing",
    "category": "business",
    "timeSensitive": false
  }
]
```

---

## **PUTTING IT TOGETHER: Response Generation**

### **When User Receives a Message**

```javascript
async function generateSuggestedResponse(incomingMessage, conversation) {
  
  // 1. Determine category
  const category = conversation.aiCategory; // "business"
  
  // 2. Get style profile
  const styleProfile = await getVoiceProfile(userId, category);
  
  // 3. Query knowledge base (vector search)
  const messageEmbedding = await createEmbedding(incomingMessage.text);
  const relevantKnowledge = await vectorDB.query({
    embedding: messageEmbedding,
    filter: { userId, category },
    topK: 5
  });
  
  // 4. Get recent conversation context
  const recentMessages = await getRecentMessages(conversation.id, 10);
  
  // 5. Generate response
  const response = await callOpenAI({
    model: "gpt-4",
    messages: [
      {
        role: "system",
        content: buildStyleInstruction(styleProfile)
      },
      {
        role: "user",
        content: buildPrompt(incomingMessage, relevantKnowledge, recentMessages)
      }
    ]
  });
  
  return response;
}
```

---

## **Style Instruction Example**

```javascript
function buildStyleInstruction(profile) {
  return `
    You are drafting a response in this person's voice. Follow these rules:
    
    TONE & FORMALITY:
    - Formality level: ${profile.language.formality} (0=casual, 1=formal)
    - Use contractions ${profile.language.contractionFreq > 0.5 ? 'frequently' : 'sparingly'}
    - Common phrases: ${profile.patterns.responseStarters.join(', ')}
    
    STRUCTURE:
    - Keep responses around ${profile.structure.avgMessageLength} words
    - Use ${profile.structure.sentencesPerMessage} sentences typically
    - ${profile.structure.paragraphStyle === 'single' ? 'Single paragraph only' : 'Can use multiple paragraphs'}
    
    MECHANICS:
    - Capitalization: ${profile.mechanics.capitalization}
    - Punctuation: ${profile.mechanics.punctuationStyle}
    - ${profile.mechanics.exclamationFreq > 0.2 ? 'Use exclamation points for enthusiasm' : 'Use periods, avoid exclamation points'}
    
    EXPRESSIVENESS:
    - ${profile.expressiveness.emojiFrequency > 0.1 ? `Include 1-2 emojis like ${profile.expressiveness.commonEmojis.join(', ')}` : 'No emojis'}
    - Emoji placement: ${profile.expressiveness.emojiPlacement}
    
    OPENING/CLOSING:
    - Start with: ${profile.patterns.greetings.common.join(' or ')}
    - Close with: ${profile.patterns.closings.common.join(' or ')}
    
    IMPORTANT: Sound natural, not formulaic. These are guidelines, not templates.
  `;
}
```

---

## **Knowledge Injection Example**

```javascript
function buildPrompt(incomingMessage, knowledge, context) {
  return `
    You received this message:
    "${incomingMessage.text}"
    
    Recent conversation context:
    ${context.map(m => `${m.sender}: ${m.text}`).join('\n')}
    
    ${knowledge.length > 0 ? `
    Relevant information you've shared before:
    ${knowledge.map(k => `- ${k.text}`).join('\n')}
    ` : ''}
    
    Draft a response that:
    1. Addresses their question/message
    2. Uses the factual information provided if relevant
    3. Matches the style guidelines given
    4. Feels natural and authentic
  `;
}
```

---

## **Response Generation Flow Diagram**

```
Incoming Message: "What's your rate for a sponsored post?"
         ↓
Determine Category: Business
         ↓
   ┌────┴────┐
   ↓         ↓
Style     Knowledge
Profile   Retrieval
   ↓         ↓
formal    "$2k for IG posts"
2-3 sent  "prefer email contracts"
no emoji  "manager handles >$10k"
   ↓         ↓
   └────┬────┘
        ↓
   LLM Generation
        ↓
Generated Response:
"Hi! My rate for sponsored Instagram posts is $2,000. 
Happy to discuss details over email if you'd like to move forward."
        ↓
User sees 3 variations (adjust tone/length)
```

---

## **Common Approaches in Industry**

### **What Real Products Do:**

**1. Grammarly/WritingStyle:**
- Extract statistical patterns (sentence length, complexity)
- Build "writing DNA" profile
- Don't store exact phrases

**2. Smart Compose (Gmail):**
- Learn from sent emails
- Extract common closings/greetings
- Predict based on context + your patterns

**3. Custom GPTs / Character.AI:**
- Give LLM a "character card" with traits
- LLM generates in that style
- No need for embeddings of every past message

**4. RAG (Retrieval Augmented Generation):**
- Store facts in vector DB
- Retrieve relevant info
- Inject into prompt

**Your system is essentially:** Smart Compose + RAG combined

---

## **Challenges & Solutions**

### **Challenge 1: Cold Start**

**Problem:** New user, no style profile yet

**Solution:**
- Default to neutral/professional style
- After 10 messages, build initial profile
- Show confidence level: "Learning your style... (7/20 messages)"

### **Challenge 2: Inconsistent Style**

**Problem:** User writes differently on different days/moods

**Solution:**
- Use rolling averages (recent messages weighted more)
- Category-based profiles help (business vs social ARE different)
- Don't over-fit to edge cases

### **Challenge 3: Knowledge Conflicts**

**Problem:** "My rate is $500" (last month) vs "My rate is $600" (today)

**Solution:**
- Time-stamp facts
- Prioritize recent facts
- Flag contradictions: "You said $500 before, now $600. Which is current?"

### **Challenge 4: Over-Reliance on AI**

**Problem:** User always accepts suggestions without editing

**Solution:**
- Occasionally intentionally vary suggestions
- Prompt user: "Want to personalize this?"
- Learn MORE from when they DO edit

---

## **MVP Feature Set**

### **Phase 1: Basic Style Learning**
- Capture: length, formality, emoji usage, greetings/closings
- Store per-category
- Generate responses using style instructions

### **Phase 2: Knowledge Base**
- Extract facts from user messages
- Store in vector DB
- Retrieve relevant facts for responses

### **Phase 3: Refinement**
- Learn from user edits
- Confidence scoring
- Periodic profile updates

---

## **My Recommendation**

**For demo:**
1. **Style Profile:** Use Approach 3 (Hybrid)
   - Real-time: Track simple stats
   - Batch: LLM analyzes style every 20 messages
   - Store as JSON in Firestore (not vectors - it's structured data)

2. **Knowledge Base:** Vector DB
   - Extract facts with LLM
   - Embed and store
   - Retrieve with semantic search

3. **Generation:** Single LLM call
   - Style instruction + Knowledge + Context → Response

**Skip for demo:**
- User editing feedback loop (just generate, don't learn from edits yet)
- Conflict resolution for knowledge
- Advanced confidence scoring

---

**Does this structure make sense? Want to drill into:**
1. The specific metrics to track for style?
2. The knowledge extraction prompts?
3. How to handle the user feedback loop when they edit suggestions?
```
        

