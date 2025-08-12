const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);

// Production CORS settings
const allowedOrigins = [
  'http://localhost:3000',
  'http://localhost:3001', 
  'https://your-domain.com', // Add your domain here
  // Add your Flutter app's domain when deployed
];

const io = socketIo(server, {
  cors: {
    origin: function (origin, callback) {
      // Allow requests with no origin (mobile apps, curl, etc.)
      if (!origin) return callback(null, true);
      
      if (allowedOrigins.indexOf(origin) !== -1) {
        return callback(null, true);
      } else {
        // For development, allow any origin
        if (process.env.NODE_ENV !== 'production') {
          return callback(null, true);
        }
        return callback(new Error('Not allowed by CORS'));
      }
    },
    methods: ["GET", "POST"],
    credentials: true
  }
});

app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1) {
      return callback(null, true);
    } else {
      if (process.env.NODE_ENV !== 'production') {
        return callback(null, true);
      }
      return callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
}));

app.use(express.json());

// Store rooms and users
const rooms = new Map();

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'Arena WebRTC Audio Signaling Server', 
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    rooms: rooms.size,
    totalUsers: Array.from(rooms.values()).reduce((total, room) => total + room.size, 0),
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Health check for monitoring
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});

// Stats endpoint
app.get('/stats', (req, res) => {
  const roomStats = Array.from(rooms.entries()).map(([roomId, room]) => ({
    roomId,
    users: room.size,
    userList: Array.from(room.keys())
  }));
  
  res.json({
    totalRooms: rooms.size,
    totalUsers: Array.from(rooms.values()).reduce((total, room) => total + room.size, 0),
    rooms: roomStats
  });
});

io.on('connection', (socket) => {
  console.log(`🔌 User connected: ${socket.id} from ${socket.handshake.address}`);

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
      lastSeen: new Date(),
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
    const targetRoom = getRoomByUserId(targetUserId);
    if (targetRoom) {
      socket.to(targetRoom).emit('offer', {
        offer,
        userId,
      });
    }
  });

  socket.on('answer', (data) => {
    const { answer, userId, targetUserId } = data;
    console.log(`📞 Answer from ${userId} to ${targetUserId}`);
    
    // Forward answer to target user
    const targetRoom = getRoomByUserId(targetUserId);
    if (targetRoom) {
      socket.to(targetRoom).emit('answer', {
        answer,
        userId,
      });
    }
  });

  socket.on('ice-candidate', (data) => {
    const { candidate, userId, targetUserId } = data;
    console.log(`🧊 ICE candidate from ${userId} to ${targetUserId}`);
    
    // Forward ICE candidate to target user
    const targetRoom = getRoomByUserId(targetUserId);
    if (targetRoom) {
      socket.to(targetRoom).emit('ice-candidate', {
        candidate,
        userId,
      });
    }
  });

  // Handle disconnect
  socket.on('disconnect', (reason) => {
    console.log(`❌ User disconnected: ${socket.id}, reason: ${reason}`);
    
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

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Arena WebRTC Signaling Server running on port ${PORT}`);
  console.log(`📡 Socket.io enabled with CORS`);
  console.log(`🔗 Health check: http://localhost:${PORT}/health`);
  console.log(`📊 Stats endpoint: http://localhost:${PORT}/stats`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  
  if (process.env.NODE_ENV === 'production') {
    console.log(`🔒 Production mode - CORS restricted`);
  } else {
    console.log(`🔓 Development mode - CORS open`);
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('👋 Shutting down gracefully...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('👋 Shutting down gracefully...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

module.exports = server;