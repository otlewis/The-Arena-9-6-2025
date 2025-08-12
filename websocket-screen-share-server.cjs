const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);

// Health endpoint
app.get('/health', (req, res) => {
  const roomCount = rooms.size;
  res.json({ status: 'ok', rooms: roomCount });
});

// WebSocket server
const wss = new WebSocket.Server({ 
  server,
  path: '/signaling' 
});

// Room management
const rooms = new Map();
const clients = new Map();

console.log('🔌 WebSocket Screen Share Server starting...');

wss.on('connection', (ws) => {
  const clientId = generateClientId();
  clients.set(clientId, { ws, clientId, userId: null, roomId: null });
  
  console.log(`🔌 WebSocket client connected: ${clientId}`);

  // Send connection confirmation
  ws.send(JSON.stringify({
    type: 'connected',
    clientId: clientId
  }));

  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data);
      handleWebSocketMessage(ws, clientId, message);
    } catch (e) {
      console.error('❌ Error parsing WebSocket message:', e);
    }
  });

  ws.on('close', () => {
    console.log(`🔌 WebSocket client disconnected: ${clientId}`);
    handleClientDisconnect(clientId);
  });

  ws.on('error', (error) => {
    console.error(`❌ WebSocket error for ${clientId}:`, error);
  });
});

function handleWebSocketMessage(ws, clientId, message) {
  const { type, data } = message;
  console.log(`📨 Received message type: ${type} from ${clientId}`);

  switch (type) {
    case 'join-room':
      handleJoinRoom(clientId, data);
      break;
    case 'offer':
      relayMessage('offer', data);
      break;
    case 'answer':
      relayMessage('answer', data);
      break;
    case 'ice-candidate':
      relayMessage('ice-candidate', data);
      break;
    case 'screen-share-status':
      handleScreenShareStatus(clientId, data);
      break;
    default:
      console.log(`❓ Unknown message type: ${type}`);
  }
}

function handleJoinRoom(clientId, data) {
  const { roomId, userId, role } = data;
  const client = clients.get(clientId);
  
  if (!client) return;

  console.log(`👥 ${userId} (${role}) joining room: ${roomId}`);

  // Update client info
  client.userId = userId;
  client.roomId = roomId;
  client.role = role;

  // Initialize room if it doesn't exist
  if (!rooms.has(roomId)) {
    rooms.set(roomId, new Map());
  }

  const roomClients = rooms.get(roomId);
  const existingClients = Array.from(roomClients.values());

  // Add client to room
  roomClients.set(clientId, client);

  // Send existing clients to the new joiner
  client.ws.send(JSON.stringify({
    type: 'room-joined',
    data: {
      roomId,
      clientId,
      existingClients: existingClients.map(c => ({
        clientId: c.clientId,
        userId: c.userId,
        role: c.role
      }))
    }
  }));

  // Notify existing clients about the new joiner
  existingClients.forEach(existingClient => {
    if (existingClient.ws.readyState === WebSocket.OPEN) {
      existingClient.ws.send(JSON.stringify({
        type: 'peer-joined',
        data: {
          clientId,
          userId,
          role
        }
      }));
    }
  });

  console.log(`✅ ${userId} joined room ${roomId} (${roomClients.size} total)`);
}

function handleScreenShareStatus(senderClientId, data) {
  const { userId, isSharing, roomId } = data;
  const senderClient = clients.get(senderClientId);
  
  if (!senderClient || !roomId) return;

  console.log(`📺 Screen share status from ${userId}: ${isSharing ? 'started' : 'stopped'} in room ${roomId}`);

  // Get all clients in the room
  const roomClients = rooms.get(roomId);
  if (!roomClients) return;

  let relayCount = 0;

  // Relay to all other clients in the room (except sender)
  roomClients.forEach((client) => {
    if (client.clientId !== senderClientId && client.ws.readyState === WebSocket.OPEN) {
      client.ws.send(JSON.stringify({
        type: 'screen-share-status',
        data: { userId, isSharing, roomId }
      }));
      relayCount++;
    }
  });

  console.log(`📺 Relayed screen share status to ${relayCount} clients in room ${roomId}`);
}

function relayMessage(type, data) {
  const { to } = data;
  const targetClient = clients.get(to);
  
  if (targetClient && targetClient.ws.readyState === WebSocket.OPEN) {
    targetClient.ws.send(JSON.stringify({
      type,
      data: {
        ...data,
        from: data.from || 'unknown'
      }
    }));
  }
}

function handleClientDisconnect(clientId) {
  const client = clients.get(clientId);
  if (!client) return;

  const { roomId, userId } = client;
  
  // Remove from clients map
  clients.delete(clientId);

  // Remove from room and notify others
  if (roomId && rooms.has(roomId)) {
    const roomClients = rooms.get(roomId);
    roomClients.delete(clientId);

    // Notify remaining clients
    roomClients.forEach((remainingClient) => {
      if (remainingClient.ws.readyState === WebSocket.OPEN) {
        remainingClient.ws.send(JSON.stringify({
          type: 'peer-left',
          data: { clientId, userId }
        }));
      }
    });

    // Clean up empty rooms
    if (roomClients.size === 0) {
      rooms.delete(roomId);
      console.log(`🗑️ Cleaned up empty room: ${roomId}`);
    }
  }
}

function generateClientId() {
  return 'client_' + Math.random().toString(36).substr(2, 9);
}

const PORT = process.env.PORT || 3002;
server.listen(PORT, () => {
  console.log(`🚀 WebSocket Screen Share Server running on port ${PORT}`);
  console.log(`📡 WebSocket endpoint: ws://localhost:${PORT}/signaling`);
});