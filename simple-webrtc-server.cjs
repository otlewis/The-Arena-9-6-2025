const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Room management
const rooms = new Map();

io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id}`);
  
  socket.on('join', ({ room, userId, role }) => {
    console.log(`${userId} (${role}) joining room ${room}`);
    
    // Store user info on socket
    socket.userId = userId;
    socket.role = role;
    
    // Leave any previous room
    const previousRoom = [...socket.rooms].find(r => r !== socket.id);
    if (previousRoom) {
      socket.leave(previousRoom);
      socket.to(previousRoom).emit('peer-left', { peerId: socket.id });
    }
    
    // Join new room
    socket.join(room);
    
    // Get other users in room with their info
    const roomSockets = io.sockets.adapter.rooms.get(room);
    const otherUsers = roomSockets ? [...roomSockets].filter(id => id !== socket.id).map(id => {
      const otherSocket = io.sockets.sockets.get(id);
      return {
        peerId: id,
        userId: otherSocket?.userId,
        role: otherSocket?.role
      };
    }) : [];
    
    // Tell the joiner about existing users
    socket.emit('existing-peers', { peers: otherUsers });
    
    // Tell others about new user
    socket.to(room).emit('peer-joined', { peerId: socket.id, userId, role });
  });
  
  // Handle SimpleWebRTCService compatibility
  socket.on('join-room', ({ roomId, userId, role }) => {
    console.log(`[SimpleWebRTCService] ${userId} (${role}) joining room ${roomId}`);
    
    // Store user info on socket
    socket.userId = userId;
    socket.role = role;
    
    // Leave any previous room
    const previousRoom = [...socket.rooms].find(r => r !== socket.id);
    if (previousRoom) {
      socket.leave(previousRoom);
      socket.to(previousRoom).emit('peer-left', { peerId: socket.id });
    }
    
    // Join new room
    socket.join(roomId);
    
    // Get other users in room with their info
    const roomSockets = io.sockets.adapter.rooms.get(roomId);
    const otherUsers = roomSockets ? [...roomSockets].filter(id => id !== socket.id).map(id => {
      const otherSocket = io.sockets.sockets.get(id);
      return {
        clientId: id,  // SimpleWebRTCService expects clientId
        userId: otherSocket?.userId,
        role: otherSocket?.role
      };
    }) : [];
    
    console.log(`[SimpleWebRTCService] Room ${roomId} now has ${otherUsers.length + 1} users`);
    
    // SimpleWebRTCService expects room-joined event
    socket.emit('room-joined', { 
      roomId: roomId, 
      clientId: socket.id,
      existingClients: otherUsers 
    });
    
    // Tell existing users about new joiner
    socket.to(roomId).emit('peer-joined', { 
      clientId: socket.id, 
      userId, 
      role 
    });
  });
  
  // WebRTC signaling
  socket.on('offer', ({ targetId, offer }) => {
    console.log(`Forwarding offer from ${socket.id} to ${targetId}`);
    io.to(targetId).emit('offer', { 
      peerId: socket.id, 
      offer 
    });
  });
  
  socket.on('answer', ({ targetId, answer }) => {
    console.log(`Forwarding answer from ${socket.id} to ${targetId}`);
    io.to(targetId).emit('answer', { 
      peerId: socket.id, 
      answer 
    });
  });
  
  socket.on('ice-candidate', ({ targetId, candidate }) => {
    console.log(`Forwarding ICE candidate from ${socket.id} to ${targetId}`);
    io.to(targetId).emit('ice-candidate', { 
      peerId: socket.id, 
      candidate 
    });
  });
  
  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
    // Notify all rooms this peer was in
    socket.rooms.forEach(room => {
      if (room !== socket.id) {
        socket.to(room).emit('peer-left', { peerId: socket.id });
      }
    });
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', rooms: rooms.size });
});

const PORT = process.env.PORT || 3002;
server.listen(PORT, () => {
  console.log(`Simple WebRTC signaling server running on port ${PORT}`);
});