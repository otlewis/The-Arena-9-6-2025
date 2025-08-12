const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Create HTTP server for development
const server = http.createServer(app);
console.log('🔗 HTTP server created for Arena WebRTC');

const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Room management
const rooms = new Map();

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`🔌 Client connected: ${socket.id}`);

  socket.on('join-room', async ({ roomId, userId, userName }) => {
    try {
      console.log(`👥 ${userName} (${userId}) joining room: ${roomId}`);
      
      socket.join(roomId);
      
      if (!rooms.has(roomId)) {
        rooms.set(roomId, new Map());
      }
      
      const roomParticipants = rooms.get(roomId);
      roomParticipants.set(socket.id, { userId, userName, socketId: socket.id });

      socket.emit('joined-room', {
        roomId,
        participants: Array.from(roomParticipants.values())
      });

      socket.to(roomId).emit('participant-joined', { userId, userName, socketId: socket.id });
      console.log(`✅ ${userName} joined room ${roomId}`);

    } catch (error) {
      console.error('❌ Error joining room:', error);
      socket.emit('error', { message: error.message });
    }
  });

  // WebRTC signaling handlers
  socket.on('offer', ({ offer, roomId, userId, targetUserId }) => {
    console.log(`📤 Relaying offer from ${userId} to ${targetUserId} in room ${roomId}`);
    socket.to(roomId).emit('offer', { offer, userId, targetUserId });
  });

  socket.on('answer', ({ answer, roomId, userId, targetUserId }) => {
    console.log(`📤 Relaying answer from ${userId} to ${targetUserId} in room ${roomId}`);
    socket.to(roomId).emit('answer', { answer, userId, targetUserId });
  });

  socket.on('ice-candidate', ({ candidate, roomId, userId }) => {
    console.log(`🧊 Relaying ICE candidate from ${userId} in room ${roomId}`);
    socket.to(roomId).emit('ice-candidate', { candidate, userId });
  });

  socket.on('disconnect', () => {
    console.log(`🔌 Client disconnected: ${socket.id}`);
    
    rooms.forEach((participants, roomId) => {
      if (participants.has(socket.id)) {
        const participant = participants.get(socket.id);
        participants.delete(socket.id);
        
        socket.to(roomId).emit('participant-left', {
          socketId: socket.id,
          userId: participant.userId
        });
        
        console.log(`👋 ${participant.userName} left room ${roomId}`);
      }
    });
  });
});

// Health check endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Arena WebRTC Server',
    status: 'running',
    rooms: rooms.size,
    timestamp: new Date().toISOString()
  });
});

// Start server
const PORT = process.env.PORT || 3006;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Arena WebRTC server running on port ${PORT}`);
  console.log(`📡 WebSocket endpoint: ws://172.236.109.9:${PORT}`);
  console.log(`🔗 Health check: http://172.236.109.9:${PORT}/`);
});