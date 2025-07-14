import { Client, Databases, Query, Functions } from 'node-appwrite';

/**
 * Appwrite Function: Timer Ticker
 * 
 * Scheduled function that runs every second to update all active timers
 * This ensures perfect synchronization across all clients
 * 
 * Schedule: Every 1 second via cron expression "* * * * * *"
 * Runtime: Node.js 18.0
 */

// Initialize Appwrite client
const client = new Client()
  .setEndpoint(process.env.APPWRITE_FUNCTION_ENDPOINT)
  .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);
const functions = new Functions(client);

// Constants
const DATABASE_ID = process.env.APPWRITE_DATABASE_ID;
const TIMER_CONTROLLER_FUNCTION_ID = process.env.TIMER_CONTROLLER_FUNCTION_ID;

/**
 * Main function handler - runs every second
 */
export default async ({ req, res, log, error }) => {
  try {
    const startTime = Date.now();
    
    log('Timer Ticker: Starting scheduled tick...');
    
    // Call the timer controller function to update all active timers
    const result = await functions.createExecution(
      TIMER_CONTROLLER_FUNCTION_ID,
      JSON.stringify({
        action: 'tick'
      }),
      false, // sync execution
      '/tick',
      'POST',
      {
        'Content-Type': 'application/json'
      }
    );
    
    const duration = Date.now() - startTime;
    
    if (result.responseStatusCode === 200) {
      const response = JSON.parse(result.responseBody);
      log(`Timer Ticker: Success - Updated: ${response.updated}, Completed: ${response.completed}, Duration: ${duration}ms`);
      
      return res.json({
        success: true,
        updated: response.updated,
        completed: response.completed,
        duration: duration,
        timestamp: new Date().toISOString()
      });
    } else {
      throw new Error(`Timer controller function failed: ${result.responseStatusCode} - ${result.responseBody}`);
    }
    
  } catch (err) {
    error(`Timer Ticker Error: ${err.message}`);
    
    return res.json({
      success: false,
      error: err.message,
      timestamp: new Date().toISOString()
    }, 500);
  }
};

/**
 * Alternative implementation: Direct database updates (use if function calls are limited)
 */
async function directTimerTick(log, error) {
  try {
    const now = new Date().toISOString();
    const nowMs = Date.now();
    
    // Get all running timers
    const runningTimers = await databases.listDocuments(
      DATABASE_ID,
      'timers',
      [
        Query.equal('status', 'running'),
        Query.equal('isActive', true),
        Query.limit(100) // Process in batches
      ]
    );

    let updatedCount = 0;
    let completedCount = 0;
    const updates = [];

    // Prepare batch updates
    for (const timer of runningTimers.documents) {
      const startTime = new Date(timer.startTime).getTime();
      const elapsed = Math.floor((nowMs - startTime) / 1000);
      const remainingSeconds = Math.max(0, timer.remainingSeconds - elapsed);

      if (remainingSeconds <= 0) {
        // Timer completed
        updates.push({
          id: timer.$id,
          data: {
            status: 'completed',
            remainingSeconds: 0,
            lastTick: now,
            isActive: false
          }
        });
        completedCount++;
      } else {
        // Update remaining time
        updates.push({
          id: timer.$id,
          data: {
            remainingSeconds: remainingSeconds,
            lastTick: now
          }
        });
        updatedCount++;
      }
    }

    // Execute batch updates
    const updatePromises = updates.map(update => 
      databases.updateDocument(
        DATABASE_ID,
        'timers',
        update.id,
        update.data
      ).catch(err => {
        log(`Error updating timer ${update.id}: ${err.message}`);
        return null;
      })
    );

    await Promise.all(updatePromises);

    log(`Direct Timer Tick: ${updatedCount} updated, ${completedCount} completed`);
    
    return {
      success: true,
      updated: updatedCount,
      completed: completedCount,
      timestamp: now
    };
    
  } catch (err) {
    error(`Direct Timer Tick Error: ${err.message}`);
    throw err;
  }
}