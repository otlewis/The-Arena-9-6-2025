import { Client, Databases, Query, ID } from 'node-appwrite';

// Timer ticker that directly updates database
export default async ({ req, res, log, error }) => {
  try {
    log('Timer Ticker: Starting tick...');
    
    // Initialize Appwrite client
    const client = new Client()
      .setEndpoint(process.env.APPWRITE_FUNCTION_ENDPOINT)
      .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
      .setKey(process.env.APPWRITE_API_KEY);

    const databases = new Databases(client);
    const DATABASE_ID = process.env.APPWRITE_DATABASE_ID;
    const now = new Date().toISOString();
    const nowMs = Date.now();

    // Get all running timers
    const runningTimers = await databases.listDocuments(
      DATABASE_ID,
      'timers',
      [
        Query.equal('status', 'running'),
        Query.equal('isActive', true),
        Query.limit(100)
      ]
    );

    let updatedCount = 0;
    let completedCount = 0;

    // Update each running timer
    for (const timer of runningTimers.documents) {
      try {
        const startTime = new Date(timer.startTime).getTime();
        const elapsed = Math.floor((nowMs - startTime) / 1000);
        const remainingSeconds = Math.max(0, timer.remainingSeconds - elapsed);

        if (remainingSeconds <= 0) {
          // Timer completed
          await databases.updateDocument(
            DATABASE_ID,
            'timers',
            timer.$id,
            {
              status: 'completed',
              remainingSeconds: 0,
              lastTick: now,
              isActive: false
            }
          );

          // Log completion event
          await databases.createDocument(
            DATABASE_ID,
            'timer_events',
            ID.unique(),
            {
              timerId: timer.$id,
              roomId: timer.roomId,
              action: 'completed',
              userId: 'system',
              timestamp: now,
              details: 'Timer expired and completed'
            }
          );

          completedCount++;
          log(`Timer completed: ${timer.$id}`);
        } else {
          // Update remaining time
          await databases.updateDocument(
            DATABASE_ID,
            'timers',
            timer.$id,
            {
              remainingSeconds: remainingSeconds,
              lastTick: now
            }
          );
          updatedCount++;
        }
      } catch (err) {
        log(`Error updating timer ${timer.$id}: ${err.message}`);
      }
    }

    log(`Timer tick completed: ${updatedCount} updated, ${completedCount} completed`);

    return res.json({
      success: true,
      updated: updatedCount,
      completed: completedCount,
      totalRunning: runningTimers.documents.length,
      timestamp: now
    });

  } catch (err) {
    error(`Timer Ticker Error: ${err.message}`);
    return res.json({
      success: false,
      error: err.message
    }, 500);
  }
};