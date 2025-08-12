const WebSocket = require('ws');
const https = require('https');
const fs = require('fs');

// SSL certificates from Let's Encrypt
const server = https.createServer({
  cert: fs.readFileSync('/etc/letsencrypt/live/jitsi.dialecticlabs.com/fullchain.pem'),
  key: fs.readFileSync('/etc/letsencrypt/live/jitsi.dialecticlabs.com/privkey.pem')
});

const wss = new WebSocket.Server({ server });

// Room management
const rooms = new Map();
const users = new Map();

console.log('WebRTC Signaling Server Starting...');

wss.on('connection', (ws) => {
  let currentRoom = null;
  let userId = null;
  
  console.log('New client connected');

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log('Received:', data.type, 'from:', userId || 'unknown');
      
      switch(data.type) {
        case 'join':
          currentRoom = data.room;
          userId = data.userId;
          
          // Store user info
          users.set(ws, { userId, room: currentRoom });
          
          // Create room if doesn't exist
          if (!rooms.has(currentRoom)) {
            rooms.set(currentRoom, new Set());
            console.log('Created room:', currentRoom);
          }
          
          // Add user to room
          rooms.get(currentRoom).add(ws);
          console.log(`User ${userId} joined room ${currentRoom}. Room size: ${rooms.get(currentRoom).size}`);
          
          // Notify others in room
          broadcast(currentRoom, {
            type: 'user-joined',
            userId: userId,
            roomSize: rooms.get(currentRoom).size
          }, ws);
          
          // Send current room participants to new user
          const participants = [];
          rooms.get(currentRoom).forEach(client => {
            const userInfo = users.get(client);
            if (userInfo && userInfo.userId !== userId) {
              participants.push(userInfo.userId);
            }
          });
          
          ws.send(JSON.stringify({
            type: 'room-state',
            participants: participants
          }));
          break;
          
        case 'offer':
        case 'answer':
        case 'ice-candidate':
          // Relay WebRTC signaling to specific user or broadcast
          if (data.targetUserId) {
            // Send to specific user
            relayToUser(currentRoom, data.targetUserId, data, ws);
          } else {
            // Broadcast to all in room
            broadcast(currentRoom, {
              ...data,
              fromUserId: userId
            }, ws);
          }
          break;
          
        case 'leave':
          handleUserLeave(ws, currentRoom, userId);
          break;
          
        case 'ping':
          // Heartbeat to keep connection alive
          ws.send(JSON.stringify({ type: 'pong' }));
          break;
      }
    } catch (error) {
      console.error('Message handling error:', error);
    }
  });

  ws.on('close', () => {
    console.log('Client disconnected:', userId || 'unknown');
    handleUserLeave(ws, currentRoom, userId);
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
  
  // Send initial connection success
  ws.send(JSON.stringify({ type: 'connected' }));
});

function handleUserLeave(ws, room, userId) {
  if (room && rooms.has(room)) {
    rooms.get(room).delete(ws);
    
    if (rooms.get(room).size === 0) {
      rooms.delete(room);
      console.log('Deleted empty room:', room);
    } else {
      // Notify others that user left
      broadcast(room, {
        type: 'user-left',
        userId: userId,
        roomSize: rooms.get(room).size
      }, ws);
    }
  }
  
  users.delete(ws);
}

function broadcast(room, message, sender) {
  if (rooms.has(room)) {
    rooms.get(room).forEach(client => {
      if (client !== sender && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify(message));
      }
    });
  }
}

function relayToUser(room, targetUserId, message, sender) {
  if (rooms.has(room)) {
    rooms.get(room).forEach(client => {
      const userInfo = users.get(client);
      if (userInfo && userInfo.userId === targetUserId && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({
          ...message,
          fromUserId: users.get(sender).userId
        }));
      }
    });
  }
}

// Start server
const PORT = process.env.PORT || 8443;
server.listen(PORT, () => {
  console.log(`WebRTC Signaling Server running on wss://jitsi.dialecticlabs.com:${PORT}`);
  console.log('Rooms:', rooms.size);
  console.log('Ready for connections...');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing server...');
  wss.close(() => {
    server.close(() => {
      console.log('Server closed');
      process.exit(0);
    });
  });
});