const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');

// Express app
const app = express();
app.use(cors());
app.use(express.json());

// HTTP server
const server = http.createServer(app);
console.log(`🔓 WebSocket signaling server starting on port ${process.env.PORT || 3006}`);

// WebSocket server (bypasses Socket.IO completely)
const wss = new WebSocket.Server({ 
  server,
  path: '/signaling'
});

// Room management
const rooms = new Map();
const clients = new Map(); // Map WebSocket connections to client info

class Room {
  constructor(roomId) {
    this.id = roomId;
    this.clients = new Map(); // clientId -> client info
  }

  addClient(clientId, ws, userData = {}) {
    const client = {
      id: clientId,
      ws: ws,
      userId: userData.userId,
      role: userData.role || 'audience',
      room: this.id
    };
    this.clients.set(clientId, client);
    console.log(`👤 Client ${userData.userId} joined room ${this.id} as ${client.role}`);
    return client;
  }

  removeClient(clientId) {
    const client = this.clients.get(clientId);
    if (client) {
      this.clients.delete(clientId);
      console.log(`👋 Client ${client.userId} left room ${this.id}`);
    }
    return client;
  }

  broadcast(message, excludeClientId = null) {
    this.clients.forEach((client, clientId) => {
      if (clientId !== excludeClientId && client.ws.readyState === WebSocket.OPEN) {
        client.ws.send(JSON.stringify(message));
      }
    });
  }
}

// WebSocket connection handling
wss.on('connection', (ws, req) => {
  const clientId = generateClientId();
  clients.set(ws, { id: clientId, room: null });
  
  console.log(`🔌 WebSocket connection established: ${clientId}`);
  console.log(`🌐 Remote IP: ${req.connection.remoteAddress}`);
  
  // Send connection confirmation
  ws.send(JSON.stringify({
    type: 'connected',
    clientId: clientId,
    timestamp: new Date().toISOString()
  }));

  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data.toString());
      handleMessage(ws, clientId, message);
    } catch (error) {
      console.error(`❌ Invalid message from ${clientId}:`, error);
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Invalid JSON message'
      }));
    }
  });

  ws.on('close', (code, reason) => {
    console.log(`🔌 WebSocket disconnected: ${clientId}, code: ${code}, reason: ${reason}`);
    handleDisconnect(ws, clientId);
  });

  ws.on('error', (error) => {
    console.error(`❌ WebSocket error for ${clientId}:`, error);
  });
});

function handleMessage(ws, clientId, message) {
  const { type, data } = message;
  
  console.log(`📨 Message from ${clientId}: ${type}`);

  switch (type) {
    case 'join-room':
      handleJoinRoom(ws, clientId, data);
      break;
      
    case 'offer':
      handleOffer(ws, clientId, data);
      break;
      
    case 'answer':
      handleAnswer(ws, clientId, data);
      break;
      
    case 'ice-candidate':
      handleIceCandidate(ws, clientId, data);
      break;
      
    case 'leave-room':
      handleLeaveRoom(ws, clientId, data);
      break;
      
    default:
      console.log(`❓ Unknown message type: ${type}`);
      ws.send(JSON.stringify({
        type: 'error',
        message: `Unknown message type: ${type}`
      }));
  }
}

function handleJoinRoom(ws, clientId, data) {
  const { roomId, userId, role } = data;
  
  // Get or create room
  let room = rooms.get(roomId);
  if (!room) {
    room = new Room(roomId);
    rooms.set(roomId, room);
  }
  
  // Add client to room
  const client = room.addClient(clientId, ws, { userId, role });
  
  // Update client info
  const clientInfo = clients.get(ws);
  if (clientInfo) {
    clientInfo.room = roomId;
    clientInfo.userId = userId;
    clientInfo.role = role;
  }
  
  // Get existing clients in room
  const existingClients = [];
  room.clients.forEach((roomClient, roomClientId) => {
    if (roomClientId !== clientId) {
      existingClients.push({
        clientId: roomClientId,
        userId: roomClient.userId,
        role: roomClient.role
      });
    }
  });
  
  // Send room-joined confirmation
  ws.send(JSON.stringify({
    type: 'room-joined',
    data: {
      roomId: roomId,
      clientId: clientId,
      existingClients: existingClients
    }
  }));
  
  // Notify other clients about new peer
  room.broadcast({
    type: 'peer-joined',
    data: {
      clientId: clientId,
      userId: userId,
      role: role
    }
  }, clientId);
}

function handleOffer(ws, clientId, data) {
  const clientInfo = clients.get(ws);
  if (!clientInfo || !clientInfo.room) return;
  
  const room = rooms.get(clientInfo.room);
  if (!room) return;
  
  console.log(`📤 Relaying offer from ${clientId}`);
  
  // Relay offer to all other clients in room
  room.broadcast({
    type: 'offer',
    data: {
      ...data,
      from: clientId,
      fromUserId: clientInfo.userId
    }
  }, clientId);
}

function handleAnswer(ws, clientId, data) {
  const clientInfo = clients.get(ws);
  if (!clientInfo || !clientInfo.room) return;
  
  const room = rooms.get(clientInfo.room);
  if (!room) return;
  
  console.log(`📤 Relaying answer from ${clientId}`);
  
  // Relay answer to all other clients in room
  room.broadcast({
    type: 'answer',
    data: {
      ...data,
      from: clientId,
      fromUserId: clientInfo.userId
    }
  }, clientId);
}

function handleIceCandidate(ws, clientId, data) {
  const clientInfo = clients.get(ws);
  if (!clientInfo || !clientInfo.room) return;
  
  const room = rooms.get(clientInfo.room);
  if (!room) return;
  
  console.log(`🧊 Relaying ICE candidate from ${clientId}`);
  
  // Relay ICE candidate to all other clients in room
  room.broadcast({
    type: 'ice-candidate',
    data: {
      ...data,
      from: clientId,
      fromUserId: clientInfo.userId
    }
  }, clientId);
}

function handleLeaveRoom(ws, clientId, data) {
  handleDisconnect(ws, clientId);
}

function handleDisconnect(ws, clientId) {
  const clientInfo = clients.get(ws);
  if (clientInfo && clientInfo.room) {
    const room = rooms.get(clientInfo.room);
    if (room) {
      const client = room.removeClient(clientId);
      
      // Notify other clients
      room.broadcast({
        type: 'peer-left',
        data: {
          clientId: clientId,
          userId: client?.userId
        }
      }, clientId);
      
      // Clean up empty rooms
      if (room.clients.size === 0) {
        rooms.delete(clientInfo.room);
        console.log(`🧹 Cleaned up empty room: ${clientInfo.room}`);
      }
    }
  }
  
  clients.delete(ws);
}

function generateClientId() {
  return 'client_' + Math.random().toString(36).substr(2, 9);
}

// Health check endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Arena WebSocket Signaling Server',
    status: 'running',
    connections: wss.clients.size,
    rooms: rooms.size,
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'production'
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    connections: wss.clients.size,
    rooms: rooms.size,
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Start server
const PORT = process.env.PORT || 3006;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Arena WebSocket Signaling Server running on port ${PORT}`);
  console.log(`🌐 Environment: ${process.env.NODE_ENV || 'production'}`);
  console.log(`📡 WebSocket endpoint: ws://localhost:${PORT}/signaling`);
  console.log(`🔍 Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('🛑 SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});