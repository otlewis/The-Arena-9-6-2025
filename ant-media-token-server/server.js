const express = require('express');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

// Secret key - this should match your Ant Media Server's secret key
const SECRET_KEY = process.env.ANT_MEDIA_SECRET || 'your-ant-media-secret-key';

// Token types
const TOKEN_TYPES = {
  PUBLISH: 'publish',
  PLAY: 'play', 
  PUBLISH_PLAY: 'publish_play'
};

/**
 * Generate Ant Media Server JWT token
 * The token format must match what Ant Media Server expects
 */
function generateToken(streamId, type = TOKEN_TYPES.PUBLISH_PLAY, roomId = null) {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + (60 * 60); // 1 hour expiry
  
  const payload = {
    streamId: streamId,
    type: type,
    exp: exp
  };
  
  // For conference mode, include room ID
  if (roomId) {
    payload.roomId = roomId;
  }
  
  // Ant Media Server expects specific JWT format
  return jwt.sign(payload, SECRET_KEY, {
    algorithm: 'HS256'
  });
}

// Generate token for regular streaming
app.post('/api/token', (req, res) => {
  const { streamId, type = TOKEN_TYPES.PUBLISH_PLAY } = req.body;
  
  if (!streamId) {
    return res.status(400).json({ 
      success: false,
      error: 'streamId is required' 
    });
  }
  
  try {
    const token = generateToken(streamId, type);
    
    res.json({ 
      success: true,
      token,
      streamId,
      type
    });
  } catch (error) {
    console.error('Token generation error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to generate token'
    });
  }
});

// Generate token for conference mode
app.post('/api/conference-token', (req, res) => {
  const { roomId, streamId } = req.body;
  
  if (!roomId || !streamId) {
    return res.status(400).json({ 
      success: false,
      error: 'roomId and streamId are required' 
    });
  }
  
  try {
    // For conference mode, generate a publish_play token
    const token = generateToken(streamId, TOKEN_TYPES.PUBLISH_PLAY, roomId);
    
    res.json({ 
      success: true,
      token,
      roomId,
      streamId,
      type: TOKEN_TYPES.PUBLISH_PLAY
    });
  } catch (error) {
    console.error('Conference token generation error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to generate conference token'
    });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    success: true,
    status: 'ok',
    timestamp: new Date().toISOString()
  });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`🚀 Ant Media Token Server running on port ${PORT}`);
  console.log(`📍 Generate token: POST http://localhost:${PORT}/api/token`);
  console.log(`📍 Conference token: POST http://localhost:${PORT}/api/conference-token`);
  console.log(`📍 Health check: GET http://localhost:${PORT}/api/health`);
});