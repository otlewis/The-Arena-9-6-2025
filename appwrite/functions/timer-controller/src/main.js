import { Client, Databases, Query, ID } from 'node-appwrite';

/**
 * Appwrite Function: Timer Controller
 * 
 * Handles all server-side timer operations:
 * - Start/pause/stop/reset timers
 * - Automatic countdown with server timestamps
 * - Timer state updates every second
 * 
 * Deployment: Deploy this as an Appwrite Function
 * Triggers: HTTP requests from client app + scheduled execution
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
const TIMERS_COLLECTION_ID = 'timers';
const EVENTS_COLLECTION_ID = 'timer_events';

/**
 * Main function handler
 */
export default async ({ req, res, log, error }) => {
  try {
    // Parse request body if it's a string
    let requestBody;
    if (typeof req.body === 'string') {
      requestBody = JSON.parse(req.body);
    } else {
      requestBody = req.body || {};
    }
    
    const { action, data } = requestBody;
    
    log(`Timer Controller: Action=${action}, Body type: ${typeof req.body}`);
    
    switch (action) {
      case 'create':
        return await createTimer(data, res, log);
      case 'start':
        return await startTimer(data, res, log);
      case 'pause':
        return await pauseTimer(data, res, log);
      case 'stop':
        return await stopTimer(data, res, log);
      case 'reset':
        return await resetTimer(data, res, log);
      case 'addTime':
        return await addTime(data, res, log);
      case 'tick':
        return await tickAllActiveTimers(res, log);
      case 'cleanup':
        return await cleanupExpiredTimers(res, log);
      default:
        return res.json({ 
          success: false, 
          error: 'Invalid action. Supported: create, start, pause, stop, reset, addTime, tick, cleanup' 
        }, 400);
    }
  } catch (err) {
    error(`Timer Controller Error: ${err.message}`);
    return res.json({ 
      success: false, 
      error: err.message 
    }, 500);
  }
};

/**
 * Create a new timer
 */
async function createTimer(data, res, log) {
  const {
    roomId,
    roomType,
    timerType,
    durationSeconds,
    createdBy,
    currentSpeaker,
    title,
    config
  } = data;

  // Validate required fields
  if (!roomId || !roomType || !timerType || !durationSeconds || !createdBy) {
    return res.json({
      success: false,
      error: 'Missing required fields: roomId, roomType, timerType, durationSeconds, createdBy'
    }, 400);
  }

  // Check for existing active timers in room
  const activeTimers = await databases.listDocuments(
    DATABASE_ID,
    TIMERS_COLLECTION_ID,
    [
      Query.equal('roomId', roomId),
      Query.equal('isActive', true)
    ]
  );

  // Room type limits
  const maxConcurrentTimers = {
    'openDiscussion': 1,
    'debatesDiscussions': 1,
    'arena': 1
  };

  if (activeTimers.documents.length >= (maxConcurrentTimers[roomType] || 1)) {
    return res.json({
      success: false,
      error: `Maximum concurrent timers (${maxConcurrentTimers[roomType]}) reached for room type ${roomType}`
    }, 409);
  }

  const timerId = ID.unique();
  const now = new Date().toISOString();

  // Create timer document
  const timerDoc = await databases.createDocument(
    DATABASE_ID,
    TIMERS_COLLECTION_ID,
    timerId,
    {
      roomId,
      roomType,
      timerType,
      status: 'stopped',
      durationSeconds,
      remainingSeconds: durationSeconds,
      startTime: null,
      pausedAt: null,
      endTime: null,
      createdBy,
      currentSpeaker: currentSpeaker || null,
      title: title || `${timerType} Timer`,
      lastTick: now,
      isActive: false
    }
  );

  // Log creation event
  await logTimerEvent({
    timerId,
    roomId,
    action: 'created',
    userId: createdBy,
    timestamp: now,
    details: `Timer created: ${title || timerType}`,
    newState: { status: 'stopped', remainingSeconds: durationSeconds }
  });

  log(`Timer created: ${timerId} for room ${roomId}`);

  return res.json({
    success: true,
    timer: timerDoc
  });
}

/**
 * Start a timer
 */
async function startTimer(data, res, log) {
  const { timerId, userId } = data;

  if (!timerId || !userId) {
    return res.json({
      success: false,
      error: 'Missing required fields: timerId, userId'
    }, 400);
  }

  // Get current timer state
  const timer = await databases.getDocument(DATABASE_ID, TIMERS_COLLECTION_ID, timerId);
  
  if (timer.status === 'running') {
    return res.json({
      success: false,
      error: 'Timer is already running'
    }, 409);
  }

  const now = new Date().toISOString();
  const endTime = new Date(Date.now() + (timer.remainingSeconds * 1000)).toISOString();

  // Update timer to running state
  const updatedTimer = await databases.updateDocument(
    DATABASE_ID,
    TIMERS_COLLECTION_ID,
    timerId,
    {
      status: 'running',
      startTime: now,
      endTime: endTime,
      pausedAt: null,
      lastTick: now,
      isActive: true
    }
  );

  // Log start event
  await logTimerEvent({
    timerId,
    roomId: timer.roomId,
    action: timer.status === 'paused' ? 'resumed' : 'started',
    userId,
    timestamp: now,
    details: `Timer ${timer.status === 'paused' ? 'resumed' : 'started'} with ${timer.remainingSeconds}s remaining`,
    previousState: { status: timer.status, remainingSeconds: timer.remainingSeconds },
    newState: { status: 'running', startTime: now, endTime: endTime }
  });

  log(`Timer started: ${timerId} - ${timer.remainingSeconds}s remaining`);

  return res.json({
    success: true,
    timer: updatedTimer
  });
}

/**
 * Pause a timer
 */
async function pauseTimer(data, res, log) {
  const { timerId, userId } = data;

  if (!timerId || !userId) {
    return res.json({
      success: false,
      error: 'Missing required fields: timerId, userId'
    }, 400);
  }

  // Get current timer state
  const timer = await databases.getDocument(DATABASE_ID, TIMERS_COLLECTION_ID, timerId);
  
  if (timer.status !== 'running') {
    return res.json({
      success: false,
      error: 'Timer is not running'
    }, 409);
  }

  // Check if pausing is allowed for this timer type
  const config = getDefaultConfig(timer.roomType, timer.timerType);
  if (!config.allowPause) {
    return res.json({
      success: false,
      error: `Pausing is not allowed for ${timer.timerType} in ${timer.roomType}`
    }, 403);
  }

  const now = new Date().toISOString();
  
  // Calculate remaining time
  const startTime = new Date(timer.startTime).getTime();
  const elapsed = Math.floor((Date.now() - startTime) / 1000);
  const remainingSeconds = Math.max(0, timer.remainingSeconds - elapsed);

  // Update timer to paused state
  const updatedTimer = await databases.updateDocument(
    DATABASE_ID,
    TIMERS_COLLECTION_ID,
    timerId,
    {
      status: 'paused',
      pausedAt: now,
      remainingSeconds: remainingSeconds,
      lastTick: now,
      isActive: true
    }
  );

  // Log pause event
  await logTimerEvent({
    timerId,
    roomId: timer.roomId,
    action: 'paused',
    userId,
    timestamp: now,
    details: `Timer paused with ${remainingSeconds}s remaining`,
    previousState: { status: 'running' },
    newState: { status: 'paused', remainingSeconds: remainingSeconds }
  });

  log(`Timer paused: ${timerId} - ${remainingSeconds}s remaining`);

  return res.json({
    success: true,
    timer: updatedTimer
  });
}

/**
 * Stop a timer
 */
async function stopTimer(data, res, log) {
  const { timerId, userId } = data;

  if (!timerId || !userId) {
    return res.json({
      success: false,
      error: 'Missing required fields: timerId, userId'
    }, 400);
  }

  // Get current timer state
  const timer = await databases.getDocument(DATABASE_ID, TIMERS_COLLECTION_ID, timerId);
  const now = new Date().toISOString();

  // Update timer to stopped state
  const updatedTimer = await databases.updateDocument(
    DATABASE_ID,
    TIMERS_COLLECTION_ID,
    timerId,
    {
      status: 'stopped',
      startTime: null,
      pausedAt: null,
      endTime: null,
      lastTick: now,
      isActive: false
    }
  );

  // Log stop event
  await logTimerEvent({
    timerId,
    roomId: timer.roomId,
    action: 'stopped',
    userId,
    timestamp: now,
    details: 'Timer stopped by user',
    previousState: { status: timer.status },
    newState: { status: 'stopped' }
  });

  log(`Timer stopped: ${timerId}`);

  return res.json({
    success: true,
    timer: updatedTimer
  });
}

/**
 * Reset a timer
 */
async function resetTimer(data, res, log) {
  const { timerId, userId } = data;

  if (!timerId || !userId) {
    return res.json({
      success: false,
      error: 'Missing required fields: timerId, userId'
    }, 400);
  }

  // Get current timer state
  const timer = await databases.getDocument(DATABASE_ID, TIMERS_COLLECTION_ID, timerId);
  const now = new Date().toISOString();

  // Reset timer to original duration
  const updatedTimer = await databases.updateDocument(
    DATABASE_ID,
    TIMERS_COLLECTION_ID,
    timerId,
    {
      status: 'stopped',
      remainingSeconds: timer.durationSeconds,
      startTime: null,
      pausedAt: null,
      endTime: null,
      lastTick: now,
      isActive: false
    }
  );

  // Log reset event
  await logTimerEvent({
    timerId,
    roomId: timer.roomId,
    action: 'reset',
    userId,
    timestamp: now,
    details: `Timer reset to ${timer.durationSeconds}s`,
    previousState: { remainingSeconds: timer.remainingSeconds },
    newState: { status: 'stopped', remainingSeconds: timer.durationSeconds }
  });

  log(`Timer reset: ${timerId} to ${timer.durationSeconds}s`);

  return res.json({
    success: true,
    timer: updatedTimer
  });
}

/**
 * Add time to a timer
 */
async function addTime(data, res, log) {
  const { timerId, additionalSeconds, userId } = data;

  if (!timerId || !additionalSeconds || !userId) {
    return res.json({
      success: false,
      error: 'Missing required fields: timerId, additionalSeconds, userId'
    }, 400);
  }

  // Get current timer state
  const timer = await databases.getDocument(DATABASE_ID, TIMERS_COLLECTION_ID, timerId);
  
  // Check if adding time is allowed
  const config = getDefaultConfig(timer.roomType, timer.timerType);
  if (!config.allowAddTime) {
    return res.json({
      success: false,
      error: `Adding time is not allowed for ${timer.timerType} in ${timer.roomType}`
    }, 403);
  }

  const now = new Date().toISOString();
  let newRemainingSeconds;
  let newEndTime = null;

  if (timer.status === 'running') {
    // Calculate current remaining time and add to it
    const startTime = new Date(timer.startTime).getTime();
    const elapsed = Math.floor((Date.now() - startTime) / 1000);
    const currentRemaining = Math.max(0, timer.remainingSeconds - elapsed);
    newRemainingSeconds = currentRemaining + additionalSeconds;
    newEndTime = new Date(Date.now() + (newRemainingSeconds * 1000)).toISOString();
  } else {
    // Timer is stopped or paused, just add to remaining time
    newRemainingSeconds = timer.remainingSeconds + additionalSeconds;
  }

  // Update timer
  const updatedTimer = await databases.updateDocument(
    DATABASE_ID,
    TIMERS_COLLECTION_ID,
    timerId,
    {
      remainingSeconds: newRemainingSeconds,
      durationSeconds: timer.durationSeconds + additionalSeconds,
      endTime: newEndTime,
      lastTick: now
    }
  );

  // Log time added event
  await logTimerEvent({
    timerId,
    roomId: timer.roomId,
    action: 'time_added',
    userId,
    timestamp: now,
    details: `Added ${additionalSeconds}s (new total: ${newRemainingSeconds}s)`,
    previousState: { remainingSeconds: timer.remainingSeconds },
    newState: { remainingSeconds: newRemainingSeconds }
  });

  log(`Time added to timer: ${timerId} - added ${additionalSeconds}s`);

  return res.json({
    success: true,
    timer: updatedTimer
  });
}

/**
 * Tick all active timers (called every second via scheduled function)
 */
async function tickAllActiveTimers(res, log) {
  // Get all running timers
  const runningTimers = await databases.listDocuments(
    DATABASE_ID,
    TIMERS_COLLECTION_ID,
    [
      Query.equal('status', 'running'),
      Query.equal('isActive', true)
    ]
  );

  const now = new Date().toISOString();
  const nowMs = Date.now();
  let updatedCount = 0;
  let completedCount = 0;

  for (const timer of runningTimers.documents) {
    try {
      const startTime = new Date(timer.startTime).getTime();
      const elapsed = Math.floor((nowMs - startTime) / 1000);
      const remainingSeconds = Math.max(0, timer.remainingSeconds - elapsed);

      // Check if timer has expired
      if (remainingSeconds <= 0) {
        // Timer completed
        await databases.updateDocument(
          DATABASE_ID,
          TIMERS_COLLECTION_ID,
          timer.$id,
          {
            status: 'completed',
            remainingSeconds: 0,
            lastTick: now,
            isActive: false
          }
        );

        // Log completion event
        await logTimerEvent({
          timerId: timer.$id,
          roomId: timer.roomId,
          action: 'completed',
          userId: 'system',
          timestamp: now,
          details: 'Timer expired and completed',
          previousState: { status: 'running', remainingSeconds: timer.remainingSeconds },
          newState: { status: 'completed', remainingSeconds: 0 }
        });

        completedCount++;
        log(`Timer completed: ${timer.$id}`);
      } else {
        // Update remaining time
        await databases.updateDocument(
          DATABASE_ID,
          TIMERS_COLLECTION_ID,
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
    timestamp: now
  });
}

/**
 * Clean up old completed timers
 */
async function cleanupExpiredTimers(res, log) {
  const cutoffDate = new Date(Date.now() - (24 * 60 * 60 * 1000)).toISOString(); // 24 hours ago

  // Get old completed timers
  const oldTimers = await databases.listDocuments(
    DATABASE_ID,
    TIMERS_COLLECTION_ID,
    [
      Query.equal('status', 'completed'),
      Query.lessThan('$updatedAt', cutoffDate)
    ]
  );

  let deletedCount = 0;

  for (const timer of oldTimers.documents) {
    try {
      await databases.deleteDocument(DATABASE_ID, TIMERS_COLLECTION_ID, timer.$id);
      deletedCount++;
    } catch (err) {
      log(`Error deleting timer ${timer.$id}: ${err.message}`);
    }
  }

  log(`Cleanup completed: ${deletedCount} old timers deleted`);

  return res.json({
    success: true,
    deleted: deletedCount
  });
}

/**
 * Log timer event
 */
async function logTimerEvent(eventData) {
  try {
    await databases.createDocument(
      DATABASE_ID,
      EVENTS_COLLECTION_ID,
      ID.unique(),
      eventData
    );
  } catch (err) {
    console.error('Error logging timer event:', err);
  }
}

/**
 * Get default configuration for timer type
 */
function getDefaultConfig(roomType, timerType) {
  const configs = {
    openDiscussion: {
      general: { allowPause: true, allowAddTime: true, warningThreshold: 30 },
      speakerTurn: { allowPause: true, allowAddTime: true, warningThreshold: 15 }
    },
    debatesDiscussions: {
      speakerTurn: { allowPause: true, allowAddTime: true, warningThreshold: 20 },
      questionRound: { allowPause: true, allowAddTime: true, warningThreshold: 60 },
      general: { allowPause: true, allowAddTime: true, warningThreshold: 30 }
    },
    arena: {
      openingStatement: { allowPause: false, allowAddTime: false, warningThreshold: 30 },
      rebuttal: { allowPause: false, allowAddTime: false, warningThreshold: 20 },
      closingStatement: { allowPause: false, allowAddTime: false, warningThreshold: 20 },
      questionRound: { allowPause: false, allowAddTime: false, warningThreshold: 15 },
      general: { allowPause: true, allowAddTime: true, warningThreshold: 10 }
    }
  };

  return configs[roomType]?.[timerType] || { allowPause: true, allowAddTime: true, warningThreshold: 30 };
}