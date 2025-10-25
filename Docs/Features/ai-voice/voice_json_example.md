{
  category: "business",
  
  // Core tone
  tone: "professional-friendly",  // Overall vibe
  length: "medium",               // Message length preference
  
  // Writing mechanics (these matter!)
  mechanics: {
    capitalization: "proper",         // "proper" | "lowercase" | "sentence-case"
    punctuation: "standard",          // "standard" | "minimal" | "expressive"
    spellingStyle: "standard",        // "standard" | "casual-shortcuts" | "phonetic"
  },
  
  // Vocabulary patterns
  vocabulary: {
    greetings: {
      standard: ["Hey", "Hi"],                    // What they normally say
      alternatives: ["Hey there", "Hello"]        // Variations they use
    },
    closings: {
      standard: ["Thanks", "Best"],
      alternatives: ["Thank you", "Cheers"]
    },
    commonWords: {
      "what's up": ["what's up", "wuts up"],     // Standard → their version
      "you": ["you", "u"],
      "are": ["are", "r"],
      "probably": ["probably", "prolly"],
      "okay": ["okay", "ok", "k"]
    },
    fillerWords: ["like", "just", "honestly", "literally"],
    signaturePhrases: ["Happy to help", "Let me know", "For sure"]
  },
  
  // Expressiveness
  expressiveness: {
    emojis: "rarely",                // "never" | "rarely" | "sometimes" | "often"
    commonEmojis: ["👍", "😊"],     // When they do use them
    exclamations: "sometimes",       // How often they use !
    multiPunctuation: false,         // Do they use !!! or ???
    ellipsis: false                  // Do they use ...
  },
  
  // Structural habits
  structure: {
    avgLength: "2-3 sentences",      // Rough guideline
    breakIntoMultiple: false,        // Send one message or break into 3 quick ones?
    useLineBreaks: false             // Single paragraph vs multiple lines
  },
  
  // Meta
  sampleSize: 28,
  lastUpdated: Timestamp
}