const express = require('express');
const https = require('https');
const socketIo = require('socket.io');
const cors = require('cors');
const fs = require('fs');

// Express app
const app = express();
app.use(cors());
app.use(express.json());

// HTTPS server with SSL certificates
const options = {
  cert: fs.readFileSync('/etc/letsencrypt/live/jitsi.dialecticlabs.com/fullchain.pem'),
  key: fs.readFileSync('/etc/letsencrypt/live/jitsi.dialecticlabs.com/privkey.pem'),
};

const server = https.createServer(options, app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Room management
const rooms = new Map();

class SimpleRoom {
  constructor(roomId) {
    this.id = roomId;
    this.peers = new Map();
    console.log(`📺 Simple room ${roomId} created`);
  }

  addPeer(socketId, userId) {
    this.peers.set(socketId, { socketId, userId });
    console.log(`👤 Peer ${userId} (${socketId}) joined room ${this.id} (${this.peers.size} total)`);
  }

  removePeer(socketId) {
    const peer = this.peers.get(socketId);
    if (peer) {
      this.peers.delete(socketId);
      console.log(`👋 Peer ${peer.userId} (${socketId}) left room ${this.id} (${this.peers.size} remaining)`);
    }
    
    // Close room if empty
    if (this.peers.size === 0) {
      console.log(`🚪 Room ${this.id} closed (empty)`);
      rooms.delete(this.id);
    }
  }

  getPeers() {
    return Array.from(this.peers.values());
  }

  broadcastToPeers(fromSocketId, event, data) {
    this.peers.forEach((peer, socketId) => {
      if (socketId !== fromSocketId) {
        io.to(socketId).emit(event, { ...data, from: this.peers.get(fromSocketId)?.userId });
      }
    });
  }
}

// Get or create room
function getOrCreateRoom(roomId) {
  let room = rooms.get(roomId);
  if (!room) {
    room = new SimpleRoom(roomId);
    rooms.set(roomId, room);
  }
  return room;
}

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`🔗 Socket connected: ${socket.id}`);
  
  let currentRoom = null;
  let userId = null;

  socket.on('join-room', (data, callback) => {
    try {
      const { roomId, userId: userIdParam, device } = data;
      console.log(`📥 Join room request: ${roomId} from user ${userIdParam} (${socket.id})`);
      
      currentRoom = getOrCreateRoom(roomId);
      userId = userIdParam;
      
      currentRoom.addPeer(socket.id, userId);
      socket.join(roomId);
      
      // Notify other peers about new peer
      currentRoom.broadcastToPeers(socket.id, 'peer-joined', {
        peerId: socket.id,
        userId: userId,
        device: device
      });
      
      callback({ success: true });
      
    } catch (error) {
      console.error('Error joining room:', error);
      callback({ success: false, error: error.message });
    }
  });

  // WebRTC signaling
  socket.on('offer', (data) => {
    console.log(`📥 Offer from ${data.from} to ${data.to}`);
    if (data.to === 'room' && currentRoom) {
      // Broadcast offer to all peers in room
      currentRoom.broadcastToPeers(socket.id, 'offer', data);
    } else {
      // Send to specific peer
      socket.to(data.to).emit('offer', data);
    }
  });

  socket.on('answer', (data) => {
    console.log(`📥 Answer from ${data.from} to ${data.to}`);
    if (data.to === 'room' && currentRoom) {
      // Broadcast answer to all peers in room
      currentRoom.broadcastToPeers(socket.id, 'answer', data);
    } else {
      // Send to specific peer
      socket.to(data.to).emit('answer', data);
    }
  });

  socket.on('ice-candidate', (data) => {
    console.log(`🧊 ICE candidate from ${data.from}`);
    if (data.to === 'room' && currentRoom) {
      // Broadcast ICE candidate to all peers in room
      currentRoom.broadcastToPeers(socket.id, 'ice-candidate', data);
    } else {
      // Send to specific peer
      socket.to(data.to).emit('ice-candidate', data);
    }
  });

  socket.on('disconnect', () => {
    console.log(`🔌 Socket disconnected: ${socket.id}`);
    
    if (currentRoom) {
      // Notify other peers
      currentRoom.broadcastToPeers(socket.id, 'peer-left', {
        peerId: socket.id,
        userId: userId
      });
      
      currentRoom.removePeer(socket.id);
    }
  });
});

// API endpoints
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    rooms: rooms.size,
    type: 'simple-mediasoup-production'
  });
});

app.get('/rooms', (req, res) => {
  const roomList = Array.from(rooms.values()).map(room => ({
    id: room.id,
    peers: room.peers.size
  }));
  res.json({ rooms: roomList });
});

// Start server
const PORT = process.env.PORT || 8443;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Arena MediaSoup Signaling Server (PRODUCTION) running on port ${PORT}`);
  console.log(`🔒 HTTPS enabled with SSL certificates`);
  console.log(`🌐 Environment: ${process.env.NODE_ENV || 'production'}`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('🛑 Received SIGINT, shutting down gracefully...');
  
  rooms.forEach(room => {
    room.peers.clear();
  });
  rooms.clear();
  
  server.close(() => {
    console.log('👋 Server closed');
    process.exit(0);
  });
});