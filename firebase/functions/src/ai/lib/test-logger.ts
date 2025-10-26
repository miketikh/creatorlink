/**
 * Test Logger for Knowledge Extraction Testing
 * Writes clean, focused logs to a file instead of console
 */

import * as fs from "fs";
import * as path from "path";

const LOG_FILE = path.join(__dirname, "../../../knowledge-extraction-test.log");

// Clear the log file when module loads (emulator starts)
try {
  fs.writeFileSync(LOG_FILE, `=== KNOWLEDGE EXTRACTION TEST LOG ===\n`);
  fs.appendFileSync(LOG_FILE, `Started: ${new Date().toISOString()}\n\n`);
} catch (error) {
  // Ignore errors if file can't be created
}

/**
 * Log a test message to the test log file
 */
export function testLog(message: string, data?: Record<string, any>) {
  try {
    const timestamp = new Date().toISOString().substring(11, 23); // Just time portion
    let logLine = `[${timestamp}] ${message}`;

    if (data) {
      logLine += `\n  ${JSON.stringify(data, null, 2).split('\n').join('\n  ')}`;
    }

    logLine += '\n\n';

    fs.appendFileSync(LOG_FILE, logLine);
  } catch (error) {
    // Ignore errors - don't break function execution
  }
}
