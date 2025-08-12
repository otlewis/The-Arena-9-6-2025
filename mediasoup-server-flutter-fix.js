const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const mediasoup = require('mediasoup');
const cors = require('cors');

// Express app
const app = express();
app.use(cors());
app.use(express.json());

// HTTP server for production
const server = http.createServer(app);
console.log(`🔓 HTTP MediaSoup server starting on port ${process.env.PORT || 3001}`);

const io = socketIo(server, {
  transports: ['polling'], // SERVER-SIDE: Force polling only, disable WebSocket
  allowEIO3: true, // Allow older Engine.IO versions
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  },
  // Additional options to prevent WebSocket upgrades
  allowUpgrades: false,
  perMessageDeflate: false,
  httpCompression: false,
  cookie: false,
});

// CRITICAL FIX: Override Engine.IO to block WebSocket upgrades from Flutter client
io.engine.on('connection', (socket) => {
  console.log(`🔌 New Engine.IO connection: ${socket.id}, transport: ${socket.transport.name}`);
  
  // Force polling transport
  socket.transport.name = 'polling';
  
  // Block any upgrade attempts
  const originalOnRequest = socket.onRequest;
  socket.onRequest = function(req) {
    if (req._query && req._query.transport === 'websocket') {
      console.log('🚫 Blocking WebSocket transport request from Flutter client');
      req._query.transport = 'polling';
    }
    return originalOnRequest.call(this, req);
  };
  
  // Disable upgrade listener
  socket.removeAllListeners('upgrade');
  socket.on('upgrade', () => {
    console.log('🚫 Upgrade attempt blocked');
  });
});

// Override handshake to remove WebSocket from upgrades
const originalHandshake = io.engine.handshake;
io.engine.handshake = function(transportName, req) {
  const result = originalHandshake.call(this, transportName, req);
  if (result && typeof result === 'string') {
    // Parse and modify the handshake response
    try {
      const match = result.match(/^(\d+)(.+)$/);
      if (match) {
        const prefix = match[1];
        const data = JSON.parse(match[2]);
        data.upgrades = []; // Remove all upgrade options
        return prefix + JSON.stringify(data);
      }
    } catch (e) {
      console.error('Error modifying handshake:', e);
    }
  }
  return result;
};

// MediaSoup configuration for Linode
const mediasoupConfig = {
  numWorkers: 4, // Adjust based on server specs
  worker: {
    rtcMinPort: 10000,
    rtcMaxPort: 10100,
    logLevel: 'warn',
    logTags: ['info', 'ice', 'dtls', 'rtp', 'srtp', 'rtcp'],
  },
  router: {
    mediaCodecs: [
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
        mimeType: 'video/h264',
        clockRate: 90000,
        parameters: {
          'packetization-mode': 1,
          'profile-level-id': '4d0032',
          'level-asymmetry-allowed': 1,
          'x-google-start-bitrate': 1000,
        },
      },
    ],
  },
  webRtcTransport: {
    listenIps: [
      {
        ip: '0.0.0.0',
        announcedIp: process.env.ANNOUNCED_IP || '172.236.109.9', // Your Linode IP
      },
    ],
    maxIncomingBitrate: 1500000,
    initialAvailableOutgoingBitrate: 1000000,
  },
};

// MediaSoup setup
let mediasoupWorkers = [];
let nextMediasoupWorkerIdx = 0;

// Room management
const rooms = new Map();

class Room {
  constructor(roomId) {
    this.id = roomId;
    this.router = null;
    this.peers = new Map();
  }

  async initialize() {
    const worker = getMediasoupWorker();
    this.router = await worker.createRouter({
      mediaCodecs: mediasoupConfig.router.mediaCodecs,
    });
    console.log(`📡 Router created for room ${this.id}`);
  }

  addPeer(peerId, socket, userData = {}) {
    const peer = {
      id: peerId,
      socket: socket,
      userId: userData.userId,
      role: userData.role || 'audience', // 'moderator', 'speaker', 'audience'
      transports: new Map(),
      producers: new Map(),
      consumers: new Map(),
    };
    this.peers.set(peerId, peer);
    return peer;
  }

  removePeer(peerId) {
    const peer = this.peers.get(peerId);
    if (peer) {
      // Clean up transports, producers, consumers
      peer.transports.forEach(transport => transport.close());
      peer.producers.forEach(producer => producer.close());
      peer.consumers.forEach(consumer => consumer.close());
      this.peers.delete(peerId);
    }
  }
}

// Initialize MediaSoup workers
async function initializeMediaSoup() {
  console.log(`🏭 Creating ${mediasoupConfig.numWorkers} MediaSoup workers...`);
  
  for (let i = 0; i < mediasoupConfig.numWorkers; i++) {
    const worker = await mediasoup.createWorker({
      logLevel: mediasoupConfig.worker.logLevel,
      logTags: mediasoupConfig.worker.logTags,
      rtcMinPort: mediasoupConfig.worker.rtcMinPort,
      rtcMaxPort: mediasoupConfig.worker.rtcMaxPort,
    });

    worker.on('died', () => {
      console.error(`❌ MediaSoup worker ${i} died, exiting in 2 seconds...`);
      setTimeout(() => process.exit(1), 2000);
    });

    mediasoupWorkers.push(worker);
    console.log(`✅ MediaSoup worker ${i} created`);
  }

  console.log(`🎉 All ${mediasoupConfig.numWorkers} MediaSoup workers created successfully`);
}

function getMediasoupWorker() {
  const worker = mediasoupWorkers[nextMediasoupWorkerIdx];
  if (++nextMediasoupWorkerIdx === mediasoupWorkers.length) {
    nextMediasoupWorkerIdx = 0;
  }
  return worker;
}

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`🔌 Client connected: ${socket.id}`);

  // Handle RPC-style requests
  socket.on('request', async (data) => {
    const { id, method, params } = data;
    console.log(`📥 RPC request ${id}: ${method}`);
    
    try {
      let response;
      
      switch (method) {
        case 'getRouterRtpCapabilities':
          const room = rooms.get(params.roomId);
          if (!room) {
            throw new Error('Room not found');
          }
          response = {
            rtpCapabilities: room.router.rtpCapabilities
          };
          break;
          
        case 'createWebRtcTransport':
          response = await handleCreateTransport(socket, params);
          break;
          
        case 'connectWebRtcTransport':
          response = await handleConnectTransport(socket, params);
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
          
        case 'closeProducer':
          response = await handleCloseProducer(socket, params);
          break;
          
        case 'listProducers':
          response = await handleListProducers(socket, params);
          break;
          
        default:
          throw new Error(`Unknown method: ${method}`);
      }
      
      // Send response
      socket.emit(`response-${id}`, response);
      
    } catch (error) {
      console.error(`❌ RPC error for ${method}:`, error);
      socket.emit(`response-${id}`, { error: error.message });
    }
  });

  socket.on('join-room', async (data) => {
    try {
      const { roomId, userId, role } = data;
      console.log(`👥 ${userId} (${role || 'participant'}) joining room: ${roomId}`);
      
      socket.join(roomId);
      
      // Get or create room
      let room = rooms.get(roomId);
      if (!room) {
        room = new Room(roomId);
        await room.initialize();
        rooms.set(roomId, room);
      }
      
      // Add peer to room with role information
      const peer = room.addPeer(socket.id, socket, { userId, role: role || 'audience' });
      
      // Send room joined confirmation
      socket.emit('room-joined', { 
        peerId: socket.id,
        roomId: roomId
      });
      
      // Notify others about new peer
      socket.to(roomId).emit('peer-joined', { 
        peerId: socket.id,
        userId,
        role: role || 'audience'
      });
      
      console.log(`✅ ${userId} joined room ${roomId} as ${role || 'audience'}`);
      
    } catch (error) {
      console.error('❌ Error joining room:', error);
      socket.emit('error', { message: error.message });
    }
  });

  socket.on('disconnect', () => {
    console.log(`🔌 Client disconnected: ${socket.id}`);
    
    // Clean up peer from all rooms
    rooms.forEach((room, roomId) => {
      if (room.peers.has(socket.id)) {
        const peer = room.peers.get(socket.id);
        
        // Notify others about producer closure
        peer.producers.forEach((producer, producerId) => {
          socket.to(roomId).emit('producerClosed', {
            producerId,
            peerId: socket.id
          });
        });
        
        room.removePeer(socket.id);
        socket.to(roomId).emit('peerLeft', { peerId: socket.id });
        
        // Clean up empty rooms
        if (room.peers.size === 0) {
          room.router.close();
          rooms.delete(roomId);
          console.log(`🧹 Cleaned up empty room: ${roomId}`);
        }
      }
    });
  });
});

// RPC Handler Functions
async function handleCreateTransport(socket, params) {
  const { roomId, direction } = params;
  const room = rooms.get(roomId);
  
  if (!room) {
    throw new Error('Room not found');
  }
  
  const transport = await room.router.createWebRtcTransport({
    listenIps: mediasoupConfig.webRtcTransport.listenIps,
    enableUdp: true,
    enableTcp: true,
    preferUdp: true,
    maxIncomingBitrate: mediasoupConfig.webRtcTransport.maxIncomingBitrate,
    initialAvailableOutgoingBitrate: mediasoupConfig.webRtcTransport.initialAvailableOutgoingBitrate,
  });
  
  transport.on('dtlsstatechange', (dtlsState) => {
    if (dtlsState === 'closed') {
      transport.close();
    }
  });
  
  const peer = room.peers.get(socket.id);
  if (peer) {
    peer.transports.set(transport.id, transport);
  }
  
  console.log(`🚛 Created ${direction} transport for ${socket.id}: ${transport.id}`);
  
  return {
    id: transport.id,
    iceParameters: transport.iceParameters,
    iceCandidates: transport.iceCandidates,
    dtlsParameters: transport.dtlsParameters,
  };
}

async function handleConnectTransport(socket, params) {
  const { transportId, dtlsParameters } = params;
  const peer = [...rooms.values()].find(room => room.peers.has(socket.id))?.peers.get(socket.id);
  
  if (!peer) {
    throw new Error('Peer not found');
  }
  
  const transport = peer.transports.get(transportId);
  if (!transport) {
    throw new Error('Transport not found');
  }
  
  await transport.connect({ dtlsParameters });
  console.log(`🔗 Connected transport ${transportId} for ${socket.id}`);
  
  return { connected: true };
}

async function handleProduce(socket, params) {
  const { roomId, transportId, kind, rtpParameters, appData } = params;
  const room = rooms.get(roomId);
  const peer = room?.peers.get(socket.id);
  
  if (!peer) {
    throw new Error('Peer not found');
  }
  
  const transport = peer.transports.get(transportId);
  if (!transport) {
    throw new Error('Transport not found');
  }
  
  const producer = await transport.produce({
    kind,
    rtpParameters,
    appData: {
      ...appData,
      userId: peer.userId,
      role: peer.role
    },
  });
  
  peer.producers.set(producer.id, producer);
  
  producer.on('transportclose', () => {
    producer.close();
    peer.producers.delete(producer.id);
  });
  
  console.log(`🎬 Created ${kind} producer ${producer.id} for ${peer.userId} (${peer.role})`);
  
  // Notify other peers about new producer
  socket.to(roomId).emit('newProducer', {
    peerId: socket.id,
    producerId: producer.id,
    kind,
    userId: peer.userId,
    role: peer.role
  });
  
  return { producerId: producer.id };
}

async function handleConsume(socket, params) {
  const { roomId, transportId, producerId, rtpCapabilities } = params;
  const room = rooms.get(roomId);
  const peer = room?.peers.get(socket.id);
  
  if (!room || !peer) {
    throw new Error('Room or peer not found');
  }
  
  const transport = peer.transports.get(transportId);
  if (!transport) {
    throw new Error('Transport not found');
  }
  
  // Find the producer
  let producer = null;
  let producerPeerId = null;
  for (const [peerId, roomPeer] of room.peers) {
    producer = roomPeer.producers.get(producerId);
    if (producer) {
      producerPeerId = peerId;
      break;
    }
  }
  
  if (!producer) {
    throw new Error('Producer not found');
  }
  
  if (!room.router.canConsume({ producerId, rtpCapabilities })) {
    throw new Error('Cannot consume');
  }
  
  const consumer = await transport.consume({
    producerId,
    rtpCapabilities,
    paused: true,
  });
  
  peer.consumers.set(consumer.id, consumer);
  
  consumer.on('transportclose', () => {
    consumer.close();
    peer.consumers.delete(consumer.id);
  });
  
  consumer.on('producerclose', () => {
    consumer.close();
    peer.consumers.delete(consumer.id);
    socket.emit('consumerClosed', { consumerId: consumer.id });
  });
  
  console.log(`🍽️ Created consumer ${consumer.id} for ${socket.id}`);
  
  return {
    id: consumer.id,
    producerId,
    kind: consumer.kind,
    rtpParameters: consumer.rtpParameters,
  };
}

async function handleResumeConsumer(socket, params) {
  const { consumerId } = params;
  const peer = [...rooms.values()].find(room => room.peers.has(socket.id))?.peers.get(socket.id);
  
  if (!peer) {
    throw new Error('Peer not found');
  }
  
  const consumer = peer.consumers.get(consumerId);
  if (!consumer) {
    throw new Error('Consumer not found');
  }
  
  await consumer.resume();
  console.log(`▶️ Resumed consumer ${consumerId} for ${socket.id}`);
  
  return { resumed: true };
}

async function handleCloseProducer(socket, params) {
  const { producerId } = params;
  const room = [...rooms.values()].find(room => room.peers.has(socket.id));
  const peer = room?.peers.get(socket.id);
  
  if (!peer) {
    throw new Error('Peer not found');
  }
  
  const producer = peer.producers.get(producerId);
  if (!producer) {
    throw new Error('Producer not found');
  }
  
  producer.close();
  peer.producers.delete(producerId);
  
  // Notify others
  if (room) {
    socket.to(room.id).emit('producerClosed', {
      producerId,
      peerId: socket.id
    });
  }
  
  console.log(`🛑 Closed producer ${producerId} for ${socket.id}`);
  
  return { closed: true };
}

async function handleListProducers(socket, params) {
  const { roomId } = params;
  const room = rooms.get(roomId);
  
  if (!room) {
    throw new Error('Room not found');
  }
  
  const producers = [];
  room.peers.forEach((peer, peerId) => {
    peer.producers.forEach((producer, producerId) => {
      producers.push({
        producerId,
        peerId,
        userId: peer.userId,
        role: peer.role,
        kind: producer.kind
      });
    });
  });
  
  return { producers };
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    workers: mediasoupWorkers.length,
    rooms: rooms.size,
    uptime: process.uptime()
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Arena MediaSoup SFU Server',
    status: 'running',
    workers: mediasoupWorkers.length,
    rooms: rooms.size,
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'production'
  });
});

// Start server
const PORT = process.env.PORT || 3001;

async function startServer() {
  try {
    await initializeMediaSoup();
    
    server.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Arena MediaSoup SFU Server running on port ${PORT}`);
      console.log(`📊 Workers: ${mediasoupWorkers.length}`);
      console.log(`🌐 Environment: ${process.env.NODE_ENV || 'production'}`);
      console.log(`📡 Announced IP: ${process.env.ANNOUNCED_IP || '172.236.109.9'}`);
      console.log(`🎯 WebRTC ports: ${mediasoupConfig.worker.rtcMinPort}-${mediasoupConfig.worker.rtcMaxPort}`);
      console.log(`🚫 Transport: POLLING ONLY (WebSocket disabled)`);
      console.log(`🛡️ Flutter Fix: WebSocket upgrade blocking enabled`);
    });
  } catch (error) {
    console.error('❌ Failed to start MediaSoup server:', error);
    process.exit(1);
  }
}

startServer();