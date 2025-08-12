import { Client, Databases, Query } from 'node-appwrite';

/**
 * Appwrite Function: Timer Ticker with Second-level Precision
 * 
 * Scheduled function that runs every minute but creates internal second-by-second updates
 * This ensures near-perfect synchronization across all clients
 * 
 * Schedule: Every 1 minute via cron expression "* * * * *"
 * Runtime: Node.js 18.0
 */

// Initialize Appwrite client
const client = new Client()
  .setEndpoint(process.env.APPWRITE_FUNCTION_ENDPOINT)
  .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);

// Constants
const DATABASE_ID = process.env.APPWRITE_DATABASE_ID;
const MAX_EXECUTION_TIME = 12000; // 12 seconds to avoid timeout

/**
 * Main function handler - runs internal loop for second-level precision
 */
export default async ({ req, res, log, error }) => {
  try {
    const startTime = Date.now();
    let totalUpdated = 0;
    let totalCompleted = 0;
    let tickCount = 0;
    
    log('Timer Ticker: Starting second-level precision loop...');
    
    // Run internal loop for up to 50 seconds (allowing 10s buffer for cleanup)
    while ((Date.now() - startTime) < MAX_EXECUTION_TIME) {
      const tickStartTime = Date.now();
      
      try {
        // Update all running timers
        const result = await updateRunningTimers(log, error);
        
        totalUpdated += result.updated;
        totalCompleted += result.completed;
        tickCount++;
        
        if (result.updated > 0 || result.completed > 0) {
          log(`Tick ${tickCount}: Updated ${result.updated}, Completed ${result.completed}`);
        }
        
      } catch (tickError) {
        error(`Tick ${tickCount} failed: ${tickError.message}`);
      }
      
      // Wait for remainder of 1 second
      const tickDuration = Date.now() - tickStartTime;
      const waitTime = Math.max(0, 1000 - tickDuration);
      
      if (waitTime > 0) {
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
    
    const totalDuration = Date.now() - startTime;
    
    log(`Timer Ticker: Completed ${tickCount} ticks in ${totalDuration}ms - Updated: ${totalUpdated}, Completed: ${totalCompleted}`);
    
    return res.json({
      success: true,
      updated: totalUpdated,
      completed: totalCompleted,
      ticks: tickCount,
      duration: totalDuration,
      timestamp: new Date().toISOString()
    });
    
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
 * Update all running timers - called every second
 */
async function updateRunningTimers(log, error) {
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
        Query.limit(50) // Process reasonable batch size
      ]
    );

    if (runningTimers.documents.length === 0) {
      return { updated: 0, completed: 0 };
    }

    let updatedCount = 0;
    let completedCount = 0;
    const updates = [];

    // Calculate updates for each timer
    for (const timer of runningTimers.documents) {
      try {
        const startTime = new Date(timer.startTime).getTime();
        const elapsed = Math.floor((nowMs - startTime) / 1000);
        const remainingSeconds = Math.max(0, timer.durationSeconds - elapsed);

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
        } else if (remainingSeconds !== timer.remainingSeconds) {
          // Update remaining time only if changed
          updates.push({
            id: timer.$id,
            data: {
              remainingSeconds: remainingSeconds,
              lastTick: now
            }
          });
          updatedCount++;
        }
      } catch (timerError) {
        error(`Error processing timer ${timer.$id}: ${timerError.message}`);
      }
    }

    // Execute batch updates with error handling
    if (updates.length > 0) {
      const updatePromises = updates.map(update => 
        databases.updateDocument(
          DATABASE_ID,
          'timers',
          update.id,
          update.data
        ).catch(err => {
          error(`Error updating timer ${update.id}: ${err.message}`);
          return null;
        })
      );

      await Promise.all(updatePromises);
    }

    return {
      updated: updatedCount,
      completed: completedCount
    };
    
  } catch (err) {
    error(`updateRunningTimers Error: ${err.message}`);
    throw err;
  }
}