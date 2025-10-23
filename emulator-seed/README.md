# Firebase Emulator Seed Script

This script populates the Firebase emulators with test data for development.

## Test Users

All users have password: `password`

**Primary test users (for login):**
- alice.johnson@test.com - Alice Johnson
- bob.martinez@test.com - Bob Martinez

**Supporting users:**
- carol.williams@test.com - Carol Williams
- david.chen@test.com - David Chen
- emma.davis@test.com - Emma Davis
- frank.garcia@test.com - Frank Garcia
- grace.kim@test.com - Grace Kim
- henry.taylor@test.com - Henry Taylor
- iris.patel@test.com - Iris Patel
- jack.wilson@test.com - Jack Wilson

## Conversation Structure

**Alice has:**
- 1:1 with Bob (50 messages)
- 1:1 with Carol (1 message)
- 1:1 with David (1 message)
- 1:1 with Emma (50 messages)
- Group: "Study Group" with Bob, Carol, David (10 messages)
- Group: "Weekend Plans" with Emma, Frank, Grace (5 messages)

**Bob has:**
- 1:1 with Alice (same 50 messages)
- 1:1 with Henry (1 message)
- 1:1 with Iris (1 message)
- 1:1 with Jack (50 messages)
- Group: "Study Group" with Alice, Carol, David (same 10 messages)
- Group: "Gaming Squad" with Jack, Frank, Henry (8 messages)

## First-Time Setup

1. **Install dependencies:**
   ```bash
   cd emulator-seed
   npm install
   ```

2. **Start Firebase emulators** (in the project root):
   ```bash
   cd ..
   firebase emulators:start
   ```

3. **Run the seed script** (in another terminal):
   ```bash
   cd emulator-seed
   npm run seed
   ```

4. **Export the seeded data** (after seed completes):
   ```bash
   cd ..
   firebase emulators:export ./emulator-data
   ```

5. **Stop the emulators** (Ctrl+C in the emulator terminal)

## Everyday Use

After the first-time setup, just start emulators with the seeded data:

```bash
firebase emulators:start --import=./emulator-data --export-on-exit
```

The `--export-on-exit` flag automatically saves any changes you make during development.

## Re-seeding

If you want to reset to fresh seed data:

1. Delete the `emulator-data` folder
2. Start emulators: `firebase emulators:start`
3. Run seed script: `cd emulator-seed && npm run seed`
4. Export: `firebase emulators:export ./emulator-data`

## Notes

- Message statuses: Most messages are marked as "read", bottom 3 messages have "sent" or "delivered" status
- Timestamps: Messages are spread over the last 3 days to look realistic
- Alice and Bob are marked as "online", others are "offline"
- The `emulator-seed/node_modules` directory is gitignored to keep the repo clean
