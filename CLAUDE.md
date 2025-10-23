
- DO NOT EVER make assumptions. Do not just try running a specific emulator, or assume that something is available at a path. ALWAYS verify, for example for the emulators by first checking which are running. Another example, do not just guess which ios version we're using for, check or ask.
- The year is 2025. If you're asked for searching things, search for the latest documentation for the time

## Firebase Functions

- **IMPORTANT:** After modifying Firebase Cloud Functions TypeScript code in `/firebase/functions/src/`, you MUST rebuild them before the changes take effect:
  ```bash
  cd /Users/Gauntlet/gauntlet/CreatorLink/firebase/functions
  npm run build
  ```
- The Firebase emulator does NOT always auto-reload function changes
- If functions aren't behaving as expected after code changes, rebuild and restart the emulator