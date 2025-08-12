const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const mediasoup = require('mediasoup');
const cors = require('cors');

// Express app
const app = express();
app.use(cors());
app.use(express.json());

// HTTP server
const server = http.createServer(app);
console.log(`🚀 MediaSoup SFU server starting on port ${process.env.PORT || 3001}`);

const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// MediaSoup configuration
const mediasoupConfig = {
  numWorkers: 4,
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
    // STUN/TURN servers
    iceServers: [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' },
    ],
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
    console.log(`📡 Router created for room ${this.id} with RTP capabilities`);
  }

  addPeer(peerId, socket, userData = {}) {
    const peer = {
      id: peerId,
      socket: socket,
      userId: userData.userId,
      role: userData.role || 'audience',
      transports: new Map(),
      producers: new Map(),
      consumers: new Map(),
    };
    this.peers.set(peerId, peer);
    console.log(`➕ Added peer ${peerId} (${userData.userId}) as ${peer.role} to room ${this.id}`);
    return peer;
  }

  removePeer(peerId) {
    const peer = this.peers.get(peerId);
    if (peer) {
      console.log(`➖ Removing peer ${peerId} (${peer.userId}) from room ${this.id}`);
      
      // Close all transports
      peer.transports.forEach(transport => {
        console.log(`🚛 Closing transport ${transport.id} for peer ${peerId}`);
        transport.close();
      });
      
      // Close all producers
      peer.producers.forEach(producer => {
        console.log(`🎙️ Closing producer ${producer.id} for peer ${peerId}`);
        producer.close();
      });
      
      // Close all consumers
      peer.consumers.forEach(consumer => {
        console.log(`🎧 Closing consumer ${consumer.id} for peer ${peerId}`);
        consumer.close();
      });
      
      this.peers.delete(peerId);
    }
  }

  close() {
    // Close all peers
    this.peers.forEach((peer, peerId) => this.removePeer(peerId));
    
    // Close router
    if (this.router) {
      this.router.close();
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

  // RPC handler for request/response pattern
  socket.on('request', async (data) => {
    const { id, method, params } = data;
    console.log(`📨 RPC Request: ${method} (${id}) from ${socket.id}`, params);

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
        case 'listProducers':
          response = await handleListProducers(socket, params);
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
        default:
          response = { error: `Unknown method: ${method}` };
      }
      
      // Send response back to client
      socket.emit(`response-${id}`, response);
      
    } catch (error) {
      console.error(`❌ RPC Error in ${method}:`, error);
      socket.emit(`response-${id}`, { error: error.message });
    }
  });

  // Join room (separate from RPC for compatibility)
  socket.on('join-room', async (data) => {
    try {
      const { roomId, userId, role } = data;
      console.log(`👥 ${userId} (${role || 'audience'}) joining room: ${roomId}`);
      
      socket.join(roomId);
      socket.roomId = roomId; // Store for cleanup
      
      // Get or create room
      let room = rooms.get(roomId);
      if (!room) {
        room = new Room(roomId);
        await room.initialize();
        rooms.set(roomId, room);
      }
      
      // Add peer to room
      const peer = room.addPeer(socket.id, socket, { userId, role: role || 'audience' });
      
      socket.emit('room-joined', { 
        success: true,
        roomId,
        peerId: socket.id
      });
      
      // Notify others about new peer
      socket.to(roomId).emit('peer-joined', { 
        peerId: socket.id,
        userId,
        role: role || 'audience'
      });
      
    } catch (error) {
      console.error('❌ Error joining room:', error);
      socket.emit('error', { message: error.message });
    }
  });

  // Handle disconnect
  socket.on('disconnect', () => {
    console.log(`🔌 Client disconnected: ${socket.id}`);
    
    // Find and remove peer from their room
    rooms.forEach((room, roomId) => {
      const peer = room.peers.get(socket.id);
      if (peer) {
        // Notify others in room
        socket.to(roomId).emit('peerLeft', { 
          roomId,
          peerId: socket.id 
        });
        
        // Notify about closed producers
        peer.producers.forEach((producer, producerId) => {
          socket.to(roomId).emit('producerClosed', {
            roomId,
            producerId,
            peerId: socket.id
          });
        });
        
        room.removePeer(socket.id);
        
        // Clean up empty rooms
        if (room.peers.size === 0) {
          console.log(`🧹 Closing empty room ${roomId}`);
          room.close();
          rooms.delete(roomId);
        }
      }
    });
  });
});

// RPC Handlers

async function handleGetRouterRtpCapabilities(socket, params) {
  const { roomId } = params;
  
  let room = rooms.get(roomId);
  if (!room) {
    room = new Room(roomId);
    await room.initialize();
    rooms.set(roomId, room);
  }
  
  const rtpCapabilities = room.router.rtpCapabilities;
  console.log(`📡 Sending router RTP capabilities for room ${roomId}`);
  
  return { rtpCapabilities };
}

async function handleCreateWebRtcTransport(socket, params) {
  const { roomId, direction } = params;
  const room = rooms.get(roomId);
  
  if (!room) {
    return { error: 'Room not found' };
  }
  
  const peer = room.peers.get(socket.id);
  if (!peer) {
    return { error: 'Peer not found. Join room first.' };
  }
  
  // Only moderators and speakers can create send transports
  if (direction === 'send' && peer.role === 'audience') {
    return { error: 'Audience members cannot create send transports' };
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
    console.log(`DTLS state changed to ${dtlsState} for transport ${transport.id}`);
    if (dtlsState === 'closed') {
      transport.close();
    }
  });
  
  transport.on('close', () => {
    console.log(`Transport ${transport.id} closed`);
  });
  
  peer.transports.set(transport.id, transport);
  
  console.log(`🚛 Created ${direction} transport ${transport.id} for ${socket.id} in room ${roomId}`);
  
  return {
    id: transport.id,
    iceParameters: transport.iceParameters,
    iceCandidates: transport.iceCandidates,
    dtlsParameters: transport.dtlsParameters,
  };
}

async function handleConnectWebRtcTransport(socket, params) {
  const { transportId, dtlsParameters } = params;
  
  const room = rooms.get(socket.roomId);
  if (!room) {
    return { error: 'Room not found' };
  }
  
  const peer = room.peers.get(socket.id);
  if (!peer) {
    return { error: 'Peer not found' };
  }
  
  const transport = peer.transports.get(transportId);
  if (!transport) {
    return { error: 'Transport not found' };
  }
  
  await transport.connect({ dtlsParameters });
  console.log(`🔗 Connected transport ${transportId} for ${socket.id}`);
  
  return { success: true };
}

async function handleProduce(socket, params) {
  const { roomId, transportId, kind, rtpParameters, appData } = params;
  const room = rooms.get(roomId);
  
  if (!room) {
    return { error: 'Room not found' };
  }
  
  const peer = room.peers.get(socket.id);
  if (!peer) {
    return { error: 'Peer not found' };
  }
  
  // Only moderators and speakers can produce
  if (peer.role === 'audience') {
    return { error: 'Audience members cannot produce media' };
  }
  
  const transport = peer.transports.get(transportId);
  if (!transport) {
    return { error: 'Transport not found' };
  }
  
  const producer = await transport.produce({
    kind,
    rtpParameters,
    appData: {
      ...appData,
      peerId: socket.id,
      userId: peer.userId,
      role: peer.role,
    },
  });
  
  producer.on('transportclose', () => {
    console.log(`Producer ${producer.id} transport closed`);
    producer.close();
  });
  
  peer.producers.set(producer.id, producer);
  
  console.log(`🎙️ Created ${kind} producer ${producer.id} for ${peer.userId} (${peer.role}) in room ${roomId}`);
  
  // Notify all other peers in room about new producer
  socket.to(roomId).emit('newProducer', {
    roomId,
    producerId: producer.id,
    kind: producer.kind,
    peerId: socket.id,
    userId: peer.userId,
    role: peer.role,
  });
  
  return {
    producerId: producer.id,
    peerId: socket.id,
  };
}

async function handleListProducers(socket, params) {
  const { roomId } = params;
  const room = rooms.get(roomId);
  
  if (!room) {
    return { error: 'Room not found' };
  }
  
  const producers = [];
  
  room.peers.forEach((peer, peerId) => {
    peer.producers.forEach((producer, producerId) => {
      producers.push({
        producerId,
        kind: producer.kind,
        peerId,
        userId: peer.userId,
        role: peer.role,
      });
    });
  });
  
  console.log(`📋 Listing ${producers.length} producers in room ${roomId}`);
  
  return { producers };
}

async function handleConsume(socket, params) {
  const { roomId, transportId, producerId, rtpCapabilities } = params;
  const room = rooms.get(roomId);
  
  if (!room) {
    return { error: 'Room not found' };
  }
  
  const consumerPeer = room.peers.get(socket.id);
  if (!consumerPeer) {
    return { error: 'Consumer peer not found' };
  }
  
  const transport = consumerPeer.transports.get(transportId);
  if (!transport) {
    return { error: 'Transport not found' };
  }
  
  // Find the producer
  let producer = null;
  let producerPeer = null;
  
  room.peers.forEach((peer, peerId) => {
    const p = peer.producers.get(producerId);
    if (p) {
      producer = p;
      producerPeer = peer;
    }
  });
  
  if (!producer) {
    return { error: 'Producer not found' };
  }
  
  // Check if router can consume
  if (!room.router.canConsume({
    producerId: producer.id,
    rtpCapabilities,
  })) {
    return { error: 'Cannot consume this producer' };
  }
  
  // Create consumer
  const consumer = await transport.consume({
    producerId: producer.id,
    rtpCapabilities,
    paused: false, // Start immediately
  });
  
  consumer.on('transportclose', () => {
    console.log(`Consumer ${consumer.id} transport closed`);
  });
  
  consumer.on('producerclose', () => {
    console.log(`Consumer ${consumer.id} producer closed`);
    socket.emit('consumerClosed', { consumerId: consumer.id });
  });
  
  consumerPeer.consumers.set(consumer.id, consumer);
  
  console.log(`🎧 Created consumer ${consumer.id} for ${consumerPeer.userId} consuming from ${producerPeer.userId} (${producer.kind})`);
  
  return {
    id: consumer.id,
    kind: consumer.kind,
    rtpParameters: consumer.rtpParameters,
    producerId: producer.id,
    peerId: producerPeer.id,
    userId: producerPeer.userId,
    role: producerPeer.role,
  };
}

async function handleResumeConsumer(socket, params) {
  const { consumerId } = params;
  
  const room = rooms.get(socket.roomId);
  if (!room) {
    return { error: 'Room not found' };
  }
  
  const peer = room.peers.get(socket.id);
  if (!peer) {
    return { error: 'Peer not found' };
  }
  
  const consumer = peer.consumers.get(consumerId);
  if (!consumer) {
    return { error: 'Consumer not found' };
  }
  
  await consumer.resume();
  console.log(`▶️ Resumed consumer ${consumerId}`);
  
  return { success: true };
}

async function handleCloseProducer(socket, params) {
  const { producerId } = params;
  
  const room = rooms.get(socket.roomId);
  if (!room) {
    return { error: 'Room not found' };
  }
  
  const peer = room.peers.get(socket.id);
  if (!peer) {
    return { error: 'Peer not found' };
  }
  
  const producer = peer.producers.get(producerId);
  if (!producer) {
    return { error: 'Producer not found' };
  }
  
  producer.close();
  peer.producers.delete(producerId);
  
  // Notify all peers in room
  socket.to(socket.roomId).emit('producerClosed', {
    roomId: socket.roomId,
    producerId,
    peerId: socket.id,
  });
  
  console.log(`🛑 Closed producer ${producerId}`);
  
  return { success: true };
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    workers: mediasoupWorkers.length,
    rooms: rooms.size,
    uptime: process.uptime(),
  });
});

// Start server
async function startServer() {
  try {
    await initializeMediaSoup();
    
    const PORT = process.env.PORT || 3001;
    server.listen(PORT, () => {
      console.log(`🚀 MediaSoup SFU server running on port ${PORT}`);
      console.log(`🏥 Health check: http://localhost:${PORT}/health`);
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

startServer();