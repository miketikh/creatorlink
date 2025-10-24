/**
 * Shared constants for all seed files
 *
 * IMPORTANT: These values must remain consistent across all seed files.
 * Always reference this file when creating new seed data.
 * See ../db-types.md for current database schema standards.
 */

// AI Assistant configuration - must match AIConstants.swift in iOS app
const AI_USER = {
  uid: 'ai-assistant',  // Must match AIConstants.AI_USER_ID
  displayName: 'AI Assistant',
  email: 'ai@creatorlink.app',
  photoURL: 'https://www.publicdomainpictures.net/pictures/250000/velka/black-robot-1524158506AN1.jpg',
  isOnline: true
};

// Primary test users - ALWAYS use these for login testing
const PRIMARY_USERS = [
  {
    displayName: 'Alice Johnson',
    email: 'alice.johnson@test.com',
    // Special photo for Alice (real image)
    photoURL: 'https://images.unsplash.com/photo-1574158622682-e40e69881006?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&q=80&w=1480'
  },
  {
    displayName: 'Bob Martinez',
    email: 'bob.martinez@test.com'
  }
];

// Additional test users (consistent across all seeds)
const ADDITIONAL_USERS = [
  { displayName: 'Carol Williams', email: 'carol.williams@test.com' },
  { displayName: 'David Chen', email: 'david.chen@test.com' },
  { displayName: 'Emma Davis', email: 'emma.davis@test.com' },
  { displayName: 'Frank Garcia', email: 'frank.garcia@test.com' },
  { displayName: 'Grace Kim', email: 'grace.kim@test.com' },
  { displayName: 'Henry Taylor', email: 'henry.taylor@test.com' },
  { displayName: 'Iris Patel', email: 'iris.patel@test.com' },
  { displayName: 'Jack Wilson', email: 'jack.wilson@test.com' }
];

// Combined user list (always in this order)
const ALL_USERS = [...PRIMARY_USERS, ...ADDITIONAL_USERS];

// Default password for all test users
const DEFAULT_PASSWORD = 'password';

// Firebase project ID
const PROJECT_ID = 'creatorlink-c160a';

// Default AI configuration for conversations
const DEFAULT_AI_CONFIG = {
  faqDetectionEnabled: true,
  minimumSimilarity: 0.85
};

module.exports = {
  AI_USER,
  PRIMARY_USERS,
  ADDITIONAL_USERS,
  ALL_USERS,
  DEFAULT_PASSWORD,
  PROJECT_ID,
  DEFAULT_AI_CONFIG
};
