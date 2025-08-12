const express = require('express');
const socketIo = require('socket.io');
const mediasoup = require('mediasoup');
const cors = require('cors');

const app = express();

// CORS configuration for cross-origin requests
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST'],
  credentials: false
}));

app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    service: 'mediasoup-sfu',
    port: process.env.PORT || 3005
  });
});

const server = require('http').createServer(app);

// Socket.IO configuration that accepts both polling and websocket
const io = socketIo(server, {
  path: '/socket.io/',
  transports: ['polling', 'websocket'], // Allow both transports
  allowEIO3: false, // Use Engine.IO v4
  pingTimeout: 60000,
  pingInterval: 25000,
  allowUpgrades: true, // Allow upgrades since Flutter insists
  maxHttpBufferSize: 1e6,
  cookie: false,
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
    credentials: false
  }
});

// MediaSoup configuration
const mediaCodecs = [
  {
    kind: 'audio',
    mimeType: 'audio/opus',
    clockRate: 48000,
    channels: 2,
  },
  {
    kind: 'video',
    mimeType: 'video/VP8',
    clockRate: 90000,
    parameters: {
      'x-google-start-bitrate': 1000,
    },
  },
  {
    kind: 'video',
    mimeType: 'video/VP9',
    clockRate: 90000,
    parameters: {
      'profile-id': 2,
      'x-google-start-bitrate': 1000,
    },
  },
  {
    kind: 'video',
    mimeType: 'video/h264',
    clockRate: 90000,
    parameters: {
      'packetization-mode': 1,
      'profile-level-id': '4d0032',
      'level-asymmetry-allowed': 1,
      'x-google-start-bitrate': 1000,
    },
  },
];

// Global variables
let worker;
let router;
const rooms = new Map();
const peers = new Map();

// Room class to manage MediaSoup resources
class Room {
  constructor(roomId) {
    this.id = roomId;
    this.peers = new Map();
    this.router = null;
  }

  async init() {
    this.router = await worker.createRouter({ mediaCodecs });
    console.log(`🏠 Room ${this.id} initialized with router`);
  }

  addPeer(socketId, userId, role, roomType) {
    const peer = {
      id: socketId,
      userId,
      role,
      roomType,
      transports: new Map(),
      producers: new Map(),
      consumers: new Map(),
    };
    this.peers.set(socketId, peer);
    console.log(`👤 Added peer ${userId} (${role}) to room ${this.id}`);
    return peer;
  }

  removePeer(socketId) {
    const peer = this.peers.get(socketId);
    if (peer) {
      // Close all transports
      for (const transport of peer.transports.values()) {
        transport.close();
      }
      this.peers.delete(socketId);
      console.log(`👋 Removed peer ${peer.userId} from room ${this.id}`);
    }
  }

  close() {
    if (this.router) {
      this.router.close();
    }
    console.log(`🚪 Room ${this.id} closed`);
  }
}

async function startMediasoupWorker() {
  try {
    worker = await mediasoup.createWorker({
      rtcMinPort: 10000,
      rtcMaxPort: 10100,
      logLevel: 'warn',
    });

    worker.on('died', (error) => {
      console.error('❌ MediaSoup worker died:', error);
      setTimeout(() => process.exit(1), 2000);
    });

    console.log('✅ MediaSoup worker started');
  } catch (error) {
    console.error('❌ Failed to start MediaSoup worker:', error);
    process.exit(1);
  }
}

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`🔌 Client connected: ${socket.id}`);
  console.log(`   Transport: ${socket.conn.transport.name}`);
  console.log(`   User-Agent: ${socket.handshake.headers['user-agent']?.substring(0, 50)}...`);

  // Handle RPC-style requests from Flutter client
  socket.on('request', async (data) => {
    const { id, method, params } = data;
    console.log(`📥 RPC request: ${method} from ${socket.id}`);
    
    try {
      let response;
      
      switch (method) {
        case 'getRouterRtpCapabilities':
          response = await handleGetRouterRtpCapabilities(socket, params);
          break;
        case 'createWebRtcTransport':
          response = await handleCreateWebRtcTransport(socket, params);
          break;
        case 'connectWebRtcTransport':
          response = await handleConnectWebRtcTransport(socket, params);
          break;
        case 'produce':
          response = await handleProduce(socket, params);
          break;
        case 'consume':
          response = await handleConsume(socket, params);
          break;
        case 'resumeConsumer':
          response = await handleResumeConsumer(socket, params);
          break;
        case 'getExistingProducers':
          response = await handleGetExistingProducers(socket, params);
          break;
        default:
          throw new Error(`Unknown method: ${method}`);
      }
      
      socket.emit(`response-${id}`, response);
      
    } catch (error) {
      console.error(`❌ RPC error for ${method}:`, error.message);
      socket.emit(`response-${id}`, { error: error.message });
    }
  });

  // Handle room joining
  socket.on('join-room', async (data) => {
    const { roomId, userId, role, roomType, canPublish } = data;
    
    try {
      console.log(`🚪 ${userId} joining room ${roomId} as ${role} (can publish: ${canPublish})`);
      
      // Get or create room
      let room = rooms.get(roomId);
      if (!room) {
        room = new Room(roomId);
        await room.init();
        rooms.set(roomId, room);
      }
      
      // Add peer to room
      const peer = room.addPeer(socket.id, userId, role, roomType);
      peers.set(socket.id, { roomId, peer });
      
      // Join socket to room
      socket.join(roomId);
      
      // Get existing participants
      const participants = Array.from(room.peers.values()).map(p => ({
        peerId: p.id,
        userId: p.userId,
        role: p.role,
      }));
      
      // Send room joined confirmation
      socket.emit('room-joined', {
        myPeerId: socket.id,
        participants: participants.filter(p => p.peerId !== socket.id),
      });
      
      // Notify other peers
      socket.to(roomId).emit('peer-joined', {
        peerId: socket.id,
        userId,
        role,
      });
      
      console.log(`✅ ${userId} joined room ${roomId}`);
      
    } catch (error) {
      console.error(`❌ Failed to join room:`, error);
      socket.emit('error', { message: `Failed to join room: ${error.message}` });
    }
  });

  // Handle leaving room
  socket.on('leave-room', (data) => {
    handleDisconnection(socket);
  });

  socket.on('disconnect', (reason) => {
    console.log(`🔌 Client disconnected: ${socket.id} (${reason})`);
    handleDisconnection(socket);
  });
});

function handleDisconnection(socket) {
  const peerInfo = peers.get(socket.id);
  if (peerInfo) {
    const { roomId, peer } = peerInfo;
    const room = rooms.get(roomId);
    
    if (room) {
      room.removePeer(socket.id);
      
      // Notify other peers
      socket.to(roomId).emit('peer-left', {
        peerId: socket.id,
      });
      
      // Clean up room if empty
      if (room.peers.size === 0) {
        room.close();
        rooms.delete(roomId);
        console.log(`🧹 Cleaned up empty room ${roomId}`);
      }
    }
    
    peers.delete(socket.id);
  }
}

// RPC method handlers
async function handleGetRouterRtpCapabilities(socket, params) {
  const { roomId } = params;
  const room = rooms.get(roomId);
  
  if (!room) {
    throw new Error('Room not found');
  }
  
  return { rtpCapabilities: room.router.rtpCapabilities };
}

async function handleCreateWebRtcTransport(socket, params) {
  const { roomId, direction } = params;
  const room = rooms.get(roomId);
  const peerInfo = peers.get(socket.id);
  
  if (!room || !peerInfo) {
    throw new Error('Room or peer not found');
  }
  
  const transportOptions = {
    listenIps: [
      { ip: '0.0.0.0', announcedIp: process.env.ANNOUNCED_IP || '172.236.109.9' }
    ],
    enableUdp: true,
    enableTcp: true,
    preferUdp: true,
  };
  
  const transport = await room.router.createWebRtcTransport(transportOptions);
  peerInfo.peer.transports.set(transport.id, transport);
  
  console.log(`🚛 Created ${direction} transport for ${peerInfo.peer.userId}`);
  
  return {
    id: transport.id,
    iceParameters: transport.iceParameters,
    iceCandidates: transport.iceCandidates,
    dtlsParameters: transport.dtlsParameters,
  };
}

async function handleConnectWebRtcTransport(socket, params) {
  const { transportId, dtlsParameters } = params;
  const peerInfo = peers.get(socket.id);
  
  if (!peerInfo) {
    throw new Error('Peer not found');
  }
  
  const transport = peerInfo.peer.transports.get(transportId);
  if (!transport) {
    throw new Error('Transport not found');
  }
  
  await transport.connect({ dtlsParameters });
  console.log(`🔗 Connected transport ${transportId} for ${peerInfo.peer.userId}`);
  
  return { success: true };
}

async function handleProduce(socket, params) {
  const { roomId, transportId, kind, rtpParameters, appData } = params;
  const room = rooms.get(roomId);
  const peerInfo = peers.get(socket.id);
  
  if (!room || !peerInfo) {
    throw new Error('Room or peer not found');
  }
  
  const transport = peerInfo.peer.transports.get(transportId);
  if (!transport) {
    throw new Error('Transport not found');
  }
  
  const producer = await transport.produce({
    kind,
    rtpParameters,
    appData: {
      ...appData,
      peerId: socket.id,
    },
  });
  
  peerInfo.peer.producers.set(producer.id, producer);
  
  // Notify other peers about new producer
  socket.to(roomId).emit('newProducer', {
    producerId: producer.id,
    peerId: socket.id,
    userId: peerInfo.peer.userId,
    role: peerInfo.peer.role,
    kind,
  });
  
  console.log(`🎬 Created ${kind} producer for ${peerInfo.peer.userId}`);
  
  return { producerId: producer.id };
}

async function handleConsume(socket, params) {
  const { roomId, transportId, producerId, rtpCapabilities } = params;
  const room = rooms.get(roomId);
  const peerInfo = peers.get(socket.id);
  
  if (!room || !peerInfo) {
    throw new Error('Room or peer not found');
  }
  
  const transport = peerInfo.peer.transports.get(transportId);
  if (!transport) {
    throw new Error('Transport not found');
  }
  
  // Find the producer
  let producer = null;
  for (const peer of room.peers.values()) {
    producer = peer.producers.get(producerId);
    if (producer) break;
  }
  
  if (!producer) {
    throw new Error('Producer not found');
  }
  
  // Check if we can consume this producer
  if (!room.router.canConsume({ producerId, rtpCapabilities })) {
    throw new Error('Cannot consume this producer');
  }
  
  const consumer = await transport.consume({
    producerId,
    rtpCapabilities,
    paused: true, // Start paused
  });
  
  peerInfo.peer.consumers.set(consumer.id, consumer);
  
  console.log(`🎧 Created consumer for ${peerInfo.peer.userId}`);
  
  return {
    id: consumer.id,
    producerId,
    kind: consumer.kind,
    rtpParameters: consumer.rtpParameters,
  };
}

async function handleResumeConsumer(socket, params) {
  const { consumerId } = params;
  const peerInfo = peers.get(socket.id);
  
  if (!peerInfo) {
    throw new Error('Peer not found');
  }
  
  const consumer = peerInfo.peer.consumers.get(consumerId);
  if (!consumer) {
    throw new Error('Consumer not found');
  }
  
  await consumer.resume();
  console.log(`▶️ Resumed consumer ${consumerId} for ${peerInfo.peer.userId}`);
  
  return { success: true };
}

async function handleGetExistingProducers(socket, params) {
  const { roomId } = params;
  const room = rooms.get(roomId);
  const peerInfo = peers.get(socket.id);
  
  if (!room || !peerInfo) {
    throw new Error('Room or peer not found');
  }
  
  // Find all producers from other peers
  const producers = [];
  for (const peer of room.peers.values()) {
    if (peer.id !== socket.id) {
      for (const producer of peer.producers.values()) {
        producers.push({
          producerId: producer.id,
          peerId: peer.id,
          userId: peer.userId,
          role: peer.role,
          kind: producer.kind,
        });
      }
    }
  }
  
  // Send each producer as a separate newProducer event
  for (const producerInfo of producers) {
    socket.emit('newProducer', producerInfo);
  }
  
  console.log(`📋 Sent ${producers.length} existing producers to ${peerInfo.peer.userId}`);
  
  return { count: producers.length };
}

// Start the server
async function startServer() {
  await startMediasoupWorker();
  
  const PORT = process.env.PORT || 3005;
  
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`\n🚀 MediaSoup SFU Server running on port ${PORT}`);
    console.log(`🌐 Health check: http://172.236.109.9:${PORT}/health`);
    console.log(`🔌 Socket.IO endpoint: http://172.236.109.9:${PORT}/socket.io/`);
    console.log(`📱 Configured for Flutter client compatibility`);
    console.log(`🎯 Transport: polling + websocket (allows upgrade)`);
    console.log(`📡 Announced IP: ${process.env.ANNOUNCED_IP || '172.236.109.9'}`);
  });
}

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('🛑 Shutting down MediaSoup server...');
  
  // Close all rooms
  for (const room of rooms.values()) {
    room.close();
  }
  
  if (worker) {
    worker.close();
  }
  
  server.close(() => {
    console.log('✅ Server shutdown complete');
    process.exit(0);
  });
});

startServer().catch(console.error);