const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);

// Enable CORS for all origins (for testing)
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());

// Store rooms and users
const rooms = new Map();

// Simple health check endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'WebRTC Audio Signaling Server', 
    rooms: rooms.size,
    timestamp: new Date().toISOString()
  });
});

io.on('connection', (socket) => {
  console.log(`🔌 User connected: ${socket.id}`);

  // Join room
  socket.on('join-room', (data) => {
    const { roomId, userId, userName } = data;
    
    console.log(`👥 ${userId} (${userName}) joining room: ${roomId}`);
    
    // Leave any existing rooms
    socket.rooms.forEach(room => {
      if (room !== socket.id) {
        socket.leave(room);
      }
    });
    
    // Join new room
    socket.join(roomId);
    
    // Initialize room if it doesn't exist
    if (!rooms.has(roomId)) {
      rooms.set(roomId, new Map());
    }
    
    const room = rooms.get(roomId);
    room.set(userId, {
      socketId: socket.id,
      userName: userName,
      joinedAt: new Date(),
    });
    
    // Notify existing users about new user
    socket.to(roomId).emit('user-joined', {
      userId: userId,
      userName: userName,
    });
    
    // Send existing users to new user
    const existingUsers = Array.from(room.entries()).map(([id, user]) => ({
      userId: id,
      userName: user.userName,
    }));
    
    socket.emit('room-users', {
      users: existingUsers,
    });
    
    console.log(`✅ Room ${roomId} now has ${room.size} users`);
  });

  // Leave room
  socket.on('leave-room', (data) => {
    const { roomId, userId } = data;
    
    console.log(`👋 ${userId} leaving room: ${roomId}`);
    
    socket.leave(roomId);
    
    if (rooms.has(roomId)) {
      const room = rooms.get(roomId);
      room.delete(userId);
      
      // Notify others
      socket.to(roomId).emit('user-left', { userId });
      
      // Clean up empty rooms
      if (room.size === 0) {
        rooms.delete(roomId);
        console.log(`🧹 Cleaned up empty room: ${roomId}`);
      } else {
        console.log(`✅ Room ${roomId} now has ${room.size} users`);
      }
    }
  });

  // WebRTC signaling events
  socket.on('offer', (data) => {
    const { offer, userId, targetUserId } = data;
    console.log(`📞 Offer from ${userId} to ${targetUserId}`);
    
    // Forward offer to target user
    socket.to(getRoomByUserId(targetUserId)).emit('offer', {
      offer,
      userId,
    });
  });

  socket.on('answer', (data) => {
    const { answer, userId, targetUserId } = data;
    console.log(`📞 Answer from ${userId} to ${targetUserId}`);
    
    // Forward answer to target user
    socket.to(getRoomByUserId(targetUserId)).emit('answer', {
      answer,
      userId,
    });
  });

  socket.on('ice-candidate', (data) => {
    const { candidate, userId, targetUserId } = data;
    console.log(`🧊 ICE candidate from ${userId} to ${targetUserId}`);
    
    // Forward ICE candidate to target user
    socket.to(getRoomByUserId(targetUserId)).emit('ice-candidate', {
      candidate,
      userId,
    });
  });

  // Handle disconnect
  socket.on('disconnect', () => {
    console.log(`❌ User disconnected: ${socket.id}`);
    
    // Find and remove user from all rooms
    rooms.forEach((room, roomId) => {
      room.forEach((user, userId) => {
        if (user.socketId === socket.id) {
          room.delete(userId);
          
          // Notify others in room
          socket.to(roomId).emit('user-left', { userId });
          
          console.log(`👋 ${userId} removed from room ${roomId} due to disconnect`);
          
          // Clean up empty rooms
          if (room.size === 0) {
            rooms.delete(roomId);
            console.log(`🧹 Cleaned up empty room: ${roomId}`);
          }
        }
      });
    });
  });

  // Helper function to find room by user ID
  function getRoomByUserId(userId) {
    for (const [roomId, room] of rooms) {
      if (room.has(userId)) {
        return roomId;
      }
    }
    return null;
  }
});

const PORT = process.env.PORT || 3001;

server.listen(PORT, () => {
  console.log(`🚀 WebRTC Audio Signaling Server running on port ${PORT}`);
  console.log(`📡 Socket.io enabled with CORS`);
  console.log(`🔗 Test endpoint: http://localhost:${PORT}/`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('👋 Shutting down gracefully...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

module.exports = server;