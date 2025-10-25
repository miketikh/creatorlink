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
    photoURL: 'https://images.unsplash.com/photo-1592621385612-4d7129426394?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8d29tYW58ZW58MHx8MHx8fDI%3D&auto=format&fit=crop&q=60&w=500'
  },
  {
    displayName: 'Bob Martinez',
    email: 'bob.martinez@test.com',
    photoURL: 'https://images.unsplash.com/photo-1480429370139-e0132c086e2a?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8OHx8bWFufGVufDB8fDB8fHwy&auto=format&fit=crop&q=60&w=500'
  }
];

// Additional test users (consistent across all seeds)
const ADDITIONAL_USERS = [
  {
    displayName: 'Carol Williams',
    email: 'carol.williams@test.com',
    photoURL: 'https://images.unsplash.com/photo-1614786269829-d24616faf56d?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8YnVzaW5lc3N3b21hbnxlbnwwfHwwfHx8Mg%3D%3D&auto=format&fit=crop&q=60&w=500'
  },
  {
    displayName: 'David Chen',
    email: 'david.chen@test.com',
    photoURL: 'https://images.unsplash.com/photo-1603574670812-d24560880210?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8N3x8cGhvdG9ncmFwaGVyfGVufDB8fDB8fHwy&auto=format&fit=crop&q=60&w=500'
  },
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
