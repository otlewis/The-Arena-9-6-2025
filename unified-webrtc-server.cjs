const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Create HTTP server
const server = http.createServer(app);
console.log('🔗 Unified WebRTC server starting...');

const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Room management
const rooms = new Map();
const mediasoupRooms = new Map();
const signalingRooms = new Map();

// Default namespace for basic signaling
io.on('connection', (socket) => {
  console.log(`🔌 Client connected to default namespace: ${socket.id}`);

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

  // Basic WebRTC signaling
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
    console.log(`🔌 Client disconnected from default: ${socket.id}`);
    _cleanupParticipant(socket.id, rooms);
  });
});

// MediaSoup namespace for advanced audio/video
const mediasoupNamespace = io.of('/mediasoup');
mediasoupNamespace.on('connection', (socket) => {
  console.log(`🎥 MediaSoup client connected: ${socket.id}`);

  socket.on('join-room', async (data) => {
    try {
      const { roomId, userId, role, device } = data;
      console.log(`🎥 MediaSoup join-room: ${userId} (${role}) joining room: ${roomId}`);
      console.log(`🎥 Device info: ${JSON.stringify(device)}`);
      
      socket.join(roomId);
      
      if (!mediasoupRooms.has(roomId)) {
        mediasoupRooms.set(roomId, new Map());
      }
      
      const roomParticipants = mediasoupRooms.get(roomId);
      const participant = { 
        userId, 
        role, 
        socketId: socket.id,
        device: device || { name: 'Unknown', version: '1.0.0' }
      };
      roomParticipants.set(socket.id, participant);

      // Emit room-joined confirmation
      socket.emit('room-joined', {
        roomId,
        userId,
        role,
        participants: Array.from(roomParticipants.values()),
        success: true
      });

      // Notify other participants
      socket.to(roomId).emit('peer-joined', { 
        peerId: socket.id,
        userId,
        role 
      });

      console.log(`✅ ${userId} joined MediaSoup room ${roomId} as ${role}`);
      console.log(`🏠 Room ${roomId} now has ${roomParticipants.size} participants`);

    } catch (error) {
      console.error('❌ MediaSoup join-room error:', error);
      socket.emit('join-room-error', { message: error.message });
    }
  });

  // Advanced WebRTC signaling for MediaSoup
  socket.on('offer', (data) => {
    const { to, from, sdp, type } = data;
    console.log(`📤 MediaSoup offer from ${from} to ${to}`);
    socket.to(to).emit('offer', { from, sdp, type });
  });

  socket.on('answer', (data) => {
    const { to, from, sdp, type } = data;
    console.log(`📤 MediaSoup answer from ${from} to ${to}`);
    socket.to(to).emit('answer', { from, sdp, type });
  });

  socket.on('ice-candidate', (data) => {
    const { to, from, candidate, sdpMid, sdpMLineIndex } = data;
    console.log(`🧊 MediaSoup ICE candidate from ${from} to ${to}`);
    socket.to(to).emit('ice-candidate', { 
      from, 
      candidate, 
      sdpMid, 
      sdpMLineIndex 
    });
  });

  socket.on('disconnect', () => {
    console.log(`🎥 MediaSoup client disconnected: ${socket.id}`);
    
    // Notify peers in all rooms
    mediasoupRooms.forEach((participants, roomId) => {
      if (participants.has(socket.id)) {
        const participant = participants.get(socket.id);
        participants.delete(socket.id);
        
        socket.to(roomId).emit('peer-left', {
          peerId: socket.id,
          userId: participant.userId
        });
        
        console.log(`👋 ${participant.userId} left MediaSoup room ${roomId}`);
      }
    });
  });
});

// Signaling namespace for basic WebRTC
const signalingNamespace = io.of('/signaling');
signalingNamespace.on('connection', (socket) => {
  console.log(`📡 Signaling client connected: ${socket.id}`);

  socket.on('join-room', async (data) => {
    try {
      const { roomId, userId, role } = data;
      console.log(`📡 Signaling join-room: ${userId} joining room: ${roomId}`);
      
      socket.join(roomId);
      
      // Initialize room if it doesn't exist
      if (!signalingRooms.has(roomId)) {
        signalingRooms.set(roomId, new Map());
      }
      
      const roomParticipants = signalingRooms.get(roomId);
      const participant = { userId, role, socketId: socket.id };
      
      // Send existing participants to the new joiner
      const existingParticipants = Array.from(roomParticipants.values());
      if (existingParticipants.length > 0) {
        console.log(`📡 Sending ${existingParticipants.length} existing participants to ${userId}`);
        for (const existingParticipant of existingParticipants) {
          socket.emit('peer-joined', { 
            peerId: existingParticipant.socketId, 
            userId: existingParticipant.userId, 
            role: existingParticipant.role 
          });
        }
      }
      
      // Add new participant to room
      roomParticipants.set(socket.id, participant);
      
      // Send confirmation to new joiner
      socket.emit('room-joined', { roomId, userId, role, success: true });
      
      // Notify existing participants about new joiner
      socket.to(roomId).emit('peer-joined', { peerId: socket.id, userId, role });

      console.log(`✅ ${userId} joined signaling room ${roomId}`);
      console.log(`🏠 Room ${roomId} now has ${roomParticipants.size} participants`);
    } catch (error) {
      console.error('❌ Signaling join-room error:', error);
      socket.emit('join-room-error', { message: error.message });
    }
  });

  socket.on('offer', (data) => {
    const { to, from, sdp, type } = data;
    socket.to(to).emit('offer', { from, sdp, type });
  });

  socket.on('answer', (data) => {
    const { to, from, sdp, type } = data;
    socket.to(to).emit('answer', { from, sdp, type });
  });

  socket.on('ice-candidate', (data) => {
    const { to, from, candidate, sdpMid, sdpMLineIndex } = data;
    socket.to(to).emit('ice-candidate', { from, candidate, sdpMid, sdpMLineIndex });
  });

  // Handle screen sharing status
  socket.on('screen-share-status', (data) => {
    const { userId, isSharing, roomId } = data;
    console.log(`📺 Screen share status from ${userId}: ${isSharing ? 'started' : 'stopped'} in room ${roomId}`);
    
    // Broadcast to all other participants in the room (except the sender)
    socket.to(roomId).emit('screen-share-status', { userId, isSharing, roomId });
    console.log(`📺 Relayed screen share status to room ${roomId}`);
  });

  socket.on('disconnect', () => {
    console.log(`📡 Signaling client disconnected: ${socket.id}`);
    
    // Notify peers in all signaling rooms
    signalingRooms.forEach((participants, roomId) => {
      if (participants.has(socket.id)) {
        const participant = participants.get(socket.id);
        participants.delete(socket.id);
        
        socket.to(roomId).emit('peer-left', {
          peerId: socket.id,
          userId: participant.userId
        });
        
        console.log(`👋 ${participant.userId} left signaling room ${roomId}`);
      }
    });
  });
});

// Helper function to clean up participants
function _cleanupParticipant(socketId, roomsMap) {
  roomsMap.forEach((participants, roomId) => {
    if (participants.has(socketId)) {
      const participant = participants.get(socketId);
      participants.delete(socketId);
      console.log(`👋 ${participant.userId || participant.userName} left room ${roomId}`);
    }
  });
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    message: 'Unified Arena WebRTC Server',
    version: '2.0.0', // Version to confirm updated server
    status: 'running',
    namespaces: ['/', '/signaling', '/mediasoup'],
    defaultRooms: rooms.size,
    mediasoupRooms: mediasoupRooms.size,
    timestamp: new Date().toISOString(),
    port: 3001
  });
});

app.get('/', (req, res) => {
  res.redirect('/health');
});

// Start server
const PORT = 3001; // Use port 3001 as configured in Flutter

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Unified Arena WebRTC server running on port ${PORT}`);
  console.log(`📡 Default namespace: ws://0.0.0.0:${PORT}/`);
  console.log(`📡 Signaling namespace: ws://0.0.0.0:${PORT}/signaling`);
  console.log(`🎥 MediaSoup namespace: ws://0.0.0.0:${PORT}/mediasoup`);
  console.log(`🔗 Health check: http://0.0.0.0:${PORT}/health`);
});