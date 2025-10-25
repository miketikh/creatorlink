/**
 * Main Seed Orchestrator
 *
 * Routes to specific seed files based on --type flag.
 * Usage: node seed.js --type=generic (or ai-group, etc.)
 *
 * Available seed types:
 * - generic: General-purpose test data with various conversation types
 * - ai-group: AI Group conversation testing scenarios
 *
 * IMPORTANT: See README.md for seeding guide and standards.
 * See ../db-types.md for current database schema standards.
 */

const admin = require('firebase-admin');
const { PROJECT_ID } = require('./constants');

// Configure for emulator
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';

// Initialize Firebase Admin
admin.initializeApp({
  projectId: PROJECT_ID
});

const auth = admin.auth();
const db = admin.firestore();

// Import seed files
const seedGeneric = require('./seed-files/generic');
const seedAIGroup = require('./seed-files/ai-group-nofunction');
const seedAIGroupTest = require('./seed-files/ai-group-test');
const seedAICategorization = require('./seed-files/ai-categorization');
const seedTestDraft = require('./seed-files/test-draft');

// Map of seed types to seed functions
const SEED_TYPES = {
  'generic': seedGeneric,
  'ai-group': seedAIGroup,
  'ai-group-test': seedAIGroupTest,
  'ai-categorization': seedAICategorization,
  'test-draft': seedTestDraft
};

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const typeArg = args.find(arg => arg.startsWith('--type='));

  if (!typeArg) {
    console.error('❌ Error: --type flag is required\n');
    console.log('Usage: node seed.js --type=<seed-type>\n');
    console.log('Available seed types:');
    Object.keys(SEED_TYPES).forEach(type => {
      console.log(`  - ${type}`);
    });
    process.exit(1);
  }

  const type = typeArg.split('=')[1];

  if (!SEED_TYPES[type]) {
    console.error(`❌ Error: Unknown seed type "${type}"\n`);
    console.log('Available seed types:');
    Object.keys(SEED_TYPES).forEach(t => {
      console.log(`  - ${t}`);
    });
    process.exit(1);
  }

  return type;
}

// Main execution
async function main() {
  const seedType = parseArgs();
  const seedFunction = SEED_TYPES[seedType];

  console.log(`\n🚀 Running seed type: ${seedType}\n`);
  console.log('================================\n');

  try {
    await seedFunction(auth, db);
    console.log('================================\n');
    console.log('✨ Seeding completed successfully!\n');
    console.log('💾 Now run: firebase emulators:export ./emulator-data\n');
    process.exit(0);
  } catch (error) {
    console.error('❌ Seeding failed:', error);
    process.exit(1);
  }
}

main();
