const express = require('express');
const http = require('http');
const cors = require('cors');

const app = express();
const server = http.createServer(app);

// Enable CORS for all origins
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  credentials: true
}));
app.use(express.json());

// Store rooms and participants
const rooms = new Map();
const sessions = new Map();

// Generate unique session ID
function generateSessionId() {
  return 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

// Health check
app.get('/', (req, res) => {
  res.json({ 
    message: 'Simple Audio Server', 
    rooms: rooms.size,
    sessions: sessions.size,
    timestamp: new Date().toISOString()
  });
});

// Create or join room (HTTP polling approach)
app.post('/api/join-room', (req, res) => {
  const { roomId, userId, userName } = req.body;
  const sessionId = generateSessionId();
  
  console.log(`👥 ${userId} (${userName}) joining room: ${roomId}`);
  
  // Get or create room
  let room = rooms.get(roomId);
  if (!room) {
    room = {
      id: roomId,
      participants: new Map(),
      created: new Date()
    };
    rooms.set(roomId, room);
  }
  
  // Add participant
  const participant = {
    sessionId,
    userId,
    userName,
    joinedAt: new Date(),
    lastSeen: new Date()
  };
  
  room.participants.set(sessionId, participant);
  sessions.set(sessionId, { roomId, userId });
  
  // Return room info
  res.json({
    success: true,
    sessionId,
    roomInfo: {
      roomId: room.id,
      participantCount: room.participants.size,
      participants: Array.from(room.participants.values()).map(p => ({
        userId: p.userId,
        userName: p.userName,
        sessionId: p.sessionId
      }))
    }
  });
});

// Get room status (for polling)
app.get('/api/room-status/:roomId/:sessionId', (req, res) => {
  const { roomId, sessionId } = req.params;
  
  const room = rooms.get(roomId);
  if (!room) {
    return res.status(404).json({ error: 'Room not found' });
  }
  
  // Update last seen
  const participant = room.participants.get(sessionId);
  if (participant) {
    participant.lastSeen = new Date();
  }
  
  res.json({
    roomId: room.id,
    participantCount: room.participants.size,
    participants: Array.from(room.participants.values()).map(p => ({
      userId: p.userId,
      userName: p.userName,
      sessionId: p.sessionId,
      isActive: (new Date() - p.lastSeen) < 5000 // Active if seen in last 5 seconds
    }))
  });
});

// Leave room
app.post('/api/leave-room', (req, res) => {
  const { sessionId } = req.body;
  
  const session = sessions.get(sessionId);
  if (!session) {
    return res.status(404).json({ error: 'Session not found' });
  }
  
  const room = rooms.get(session.roomId);
  if (room) {
    room.participants.delete(sessionId);
    console.log(`👋 ${session.userId} left room: ${session.roomId}`);
    
    // Clean up empty rooms
    if (room.participants.size === 0) {
      rooms.delete(session.roomId);
      console.log(`🧹 Cleaned up empty room: ${session.roomId}`);
    }
  }
  
  sessions.delete(sessionId);
  res.json({ success: true });
});

// WebRTC signaling endpoints (simple offer/answer exchange)
app.post('/api/signal', (req, res) => {
  const { sessionId, targetSessionId, type, data } = req.body;
  
  console.log(`📡 Signal ${type} from ${sessionId} to ${targetSessionId}`);
  
  // In a real app, you'd queue this for the target to poll
  // For now, just acknowledge
  res.json({ success: true });
});

// Clean up inactive participants periodically
setInterval(() => {
  const now = new Date();
  const timeout = 10000; // 10 seconds
  
  rooms.forEach((room, roomId) => {
    room.participants.forEach((participant, sessionId) => {
      if (now - participant.lastSeen > timeout) {
        room.participants.delete(sessionId);
        sessions.delete(sessionId);
        console.log(`⏰ Removed inactive participant: ${participant.userId} from room: ${roomId}`);
      }
    });
    
    // Clean up empty rooms
    if (room.participants.size === 0) {
      rooms.delete(roomId);
      console.log(`🧹 Cleaned up empty room: ${roomId}`);
    }
  });
}, 5000);

const PORT = process.env.PORT || 3002;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Simple Audio Server running on port ${PORT}`);
  console.log(`📡 HTTP-based signaling (no WebSocket/Socket.IO)`);
  console.log(`🔗 Health check: http://localhost:${PORT}/`);
  console.log(`✨ iOS Simulator friendly!`);
});