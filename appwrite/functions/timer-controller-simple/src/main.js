import { Client, Databases, ID } from 'node-appwrite';

export default async ({ req, res, log, error }) => {
  try {
    const { action, data } = req.body || {};
    log(`Simple Timer Controller: Action=${action}`);
    
    // Initialize Appwrite client
    const client = new Client()
      .setEndpoint(process.env.APPWRITE_FUNCTION_ENDPOINT)
      .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
      .setKey(process.env.APPWRITE_API_KEY);

    const databases = new Databases(client);
    const DATABASE_ID = process.env.APPWRITE_DATABASE_ID;

    if (action === 'create') {
      const {
        roomId,
        roomType,
        timerType,
        durationSeconds,
        createdBy,
        currentSpeaker,
        title
      } = data;

      // Basic validation
      if (!roomId || !roomType || !timerType || !durationSeconds || !createdBy) {
        return res.json({
          success: false,
          error: 'Missing required fields'
        }, 400);
      }

      const timerId = ID.unique();
      const now = new Date().toISOString();

      // Create timer document
      const timerDoc = await databases.createDocument(
        DATABASE_ID,
        'timers',
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

      log(`Timer created: ${timerId} for room ${roomId}`);

      return res.json({
        success: true,
        timer: timerDoc
      });
    }

    // Handle other actions (start, stop, etc.)
    return res.json({
      success: false,
      error: `Action ${action} not implemented in simple version`
    }, 400);

  } catch (err) {
    error(`Simple Timer Controller Error: ${err.message}`);
    return res.json({
      success: false,
      error: err.message
    }, 500);
  }
};