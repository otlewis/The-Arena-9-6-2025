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
  allowEIO3: false, // Client is using EIO=4
  pingTimeout: 60000, // Increase ping timeout
  pingInterval: 25000, // Ping interval
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Debug logging for all Engine.IO events (moved from main handler)

io.engine.on('connection', (socket) => {
  console.log(`🔧 New Engine.IO connection: ${socket.id}`);
  
  // Add error handling for Engine.IO
  socket.on('error', (error) => {
    console.log(`❌ Engine.IO error for ${socket.id}: ${error}`);
  });
  
  socket.on('close', (reason, description) => {
    console.log(`🔌 Engine.IO connection closed for ${socket.id}: ${reason}`);
    if (description) {
      console.log(`🔍 Close description: ${description}`);
    }
  });
  
  // Log all messages
  socket.on('message', (message) => {
    console.log(`📨 Engine.IO message from ${socket.id}: ${message}`);
  });
});

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
        announcedIp: process.env.ANNOUNCED_IP || '172.236.109.9', // Linode public IP
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

// RPC Handler Functions
async function handleCreateTransport(socketId, params) {
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
  
  const peer = room.peers.get(socketId);
  if (peer) {
    peer.transports.set(transport.id, transport);
  }
  
  console.log(`🚛 RPC: Created ${direction} transport for ${socketId}: ${transport.id}`);
  
  return {
    id: transport.id,
    iceParameters: transport.iceParameters,
    iceCandidates: transport.iceCandidates,
    dtlsParameters: transport.dtlsParameters,
  };
}

async function handleConnectTransport(socketId, params) {
  const { transportId, dtlsParameters } = params;
  const peer = [...rooms.values()].find(room => room.peers.has(socketId))?.peers.get(socketId);
  
  if (!peer) {
    throw new Error('Peer not found');
  }
  
  const transport = peer.transports.get(transportId);
  if (!transport) {
    throw new Error('Transport not found');
  }
  
  await transport.connect({ dtlsParameters });
  console.log(`🔗 RPC: Connected transport ${transportId} for ${socketId}`);
  
  return { success: true };
}

async function handleProduce(socketId, params) {
  const { roomId, transportId, kind, rtpParameters, appData } = params;
  const room = rooms.get(roomId);
  const peer = room?.peers.get(socketId);
  
  if (!peer) {
    throw new Error('Peer not found');
  }
  
  // Enable video production for moderators and speakers
  if (kind === 'video' && peer.role === 'audience') {
    throw new Error('Video disabled for audience role');
  }
  
  const transport = peer.transports.get(transportId);
  if (!transport) {
    throw new Error('Transport not found');
  }
  
  const producer = await transport.produce({
    kind,
    rtpParameters,
    appData,
  });
  
  peer.producers.set(producer.id, producer);
  
  producer.on('transportclose', () => {
    producer.close();
    peer.producers.delete(producer.id);
  });
  
  console.log(`🎬 RPC: Created producer ${producer.id} (${kind}) for ${peer.userId} (${peer.role})`);
  
  // Notify other peers about new producer
  if (room) {
    [...room.peers.values()].forEach(roomPeer => {
      if (roomPeer.id !== socketId) {
        roomPeer.socket.emit('newProducer', {
          peerId: socketId,
          producerId: producer.id,
          kind,
          userId: peer.userId,
          role: peer.role
        });
      }
    });
  }
  
  return { producerId: producer.id };
}

async function handleListProducers(socketId, params) {
  const { roomId } = params;
  const room = rooms.get(roomId);
  
  if (!room) {
    throw new Error('Room not found');
  }
  
  const producers = [];
  room.peers.forEach((peer, peerId) => {
    if (peerId !== socketId) {
      peer.producers.forEach((producer, producerId) => {
        producers.push({
          peerId,
          producerId,
          kind: producer.kind,
          userId: peer.userId,
          role: peer.role
        });
      });
    }
  });
  
  console.log(`📋 RPC: Listed ${producers.length} producers for ${socketId}`);
  return { producers };
}

async function handleConsume(socketId, params) {
  const { roomId, transportId, producerId, rtpCapabilities } = params;
  const room = rooms.get(roomId);
  const peer = room?.peers.get(socketId);
  
  if (!room || !peer) {
    throw new Error('Room or peer not found');
  }
  
  const transport = peer.transports.get(transportId);
  if (!transport) {
    throw new Error('Transport not found');
  }
  
  // Find the producer in the room
  let producer = null;
  for (const [peerId, roomPeer] of room.peers) {
    producer = roomPeer.producers.get(producerId);
    if (producer) break;
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
    peer.socket.emit('consumerClosed', { consumerId: consumer.id });
  });
  
  console.log(`🍽️ RPC: Created consumer ${consumer.id} for ${socketId}`);
  
  return {
    id: consumer.id,
    producerId,
    kind: consumer.kind,
    rtpParameters: consumer.rtpParameters,
  };
}

async function handleResumeConsumer(socketId, params) {
  const { consumerId } = params;
  const peer = [...rooms.values()].find(room => room.peers.has(socketId))?.peers.get(socketId);
  
  if (!peer) {
    throw new Error('Peer not found');
  }
  
  const consumer = peer.consumers.get(consumerId);
  if (!consumer) {
    throw new Error('Consumer not found');
  }
  
  await consumer.resume();
  console.log(`▶️ RPC: Resumed consumer ${consumerId} for ${socketId}`);
  
  return { success: true };
}

async function handleCloseProducer(socketId, params) {
  const { producerId } = params;
  const room = [...rooms.values()].find(room => room.peers.has(socketId));
  const peer = room?.peers.get(socketId);
  
  if (!peer) {
    throw new Error('Peer not found');
  }
  
  const producer = peer.producers.get(producerId);
  if (!producer) {
    throw new Error('Producer not found');
  }
  
  producer.close();
  peer.producers.delete(producerId);
  
  // Notify other peers
  if (room) {
    [...room.peers.values()].forEach(roomPeer => {
      if (roomPeer.id !== socketId) {
        roomPeer.socket.emit('producerClosed', {
          peerId: socketId,
          producerId
        });
      }
    });
  }
  
  console.log(`🛑 RPC: Closed producer ${producerId} for ${socketId}`);
  return { success: true };
}

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`🔌 Socket.IO connection established: ${socket.id}`);
  console.log(`📡 Transport: ${socket.conn.transport.name}`);
  console.log(`🌐 Remote IP: ${socket.handshake.address}`);
  console.log(`🔗 Handshake query: ${JSON.stringify(socket.handshake.query)}`);
  
  // Add general error handling
  socket.on('error', (error) => {
    console.error(`❌ Socket.IO error for ${socket.id}: ${error}`);
  });
  
  socket.on('disconnect', (reason) => {
    console.log(`🔌 Socket.IO disconnect for ${socket.id}: ${reason}`);
  });

  socket.on('join-room', async (data) => {
    try {
      const { roomId, userId, role } = data; // Add role support
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
      
      // Get router RTP capabilities
      const rtpCapabilities = room.router.rtpCapabilities;
      
      // Send current producers to new participant
      const existingProducers = [];
      room.peers.forEach((roomPeer, peerId) => {
        if (peerId !== socket.id) {
          roomPeer.producers.forEach((producer, producerId) => {
            existingProducers.push({
              peerId,
              producerId,
              kind: producer.kind,
              userId: roomPeer.userId,
              role: roomPeer.role
            });
          });
        }
      });
      
      socket.emit('room-joined', { 
        rtpCapabilities,
        existingProducers,
        myPeerId: socket.id
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

  // RPC request handler
  socket.on('request', async (data) => {
    const { id, method, params } = data;
    
    try {
      let response = {};
      
      switch (method) {
        case 'getRouterRtpCapabilities':
          const room = rooms.get(params.roomId);
          if (room) {
            response = { rtpCapabilities: room.router.rtpCapabilities };
          } else {
            throw new Error('Room not found');
          }
          break;
          
        case 'createWebRtcTransport':
          response = await handleCreateTransport(socket.id, params);
          break;
          
        case 'connectWebRtcTransport':
          response = await handleConnectTransport(socket.id, params);
          break;
          
        case 'produce':
          response = await handleProduce(socket.id, params);
          break;
          
        case 'listProducers':
          response = await handleListProducers(socket.id, params);
          break;
          
        case 'consume':
          response = await handleConsume(socket.id, params);
          break;
          
        case 'resumeConsumer':
          response = await handleResumeConsumer(socket.id, params);
          break;
          
        case 'closeProducer':
          response = await handleCloseProducer(socket.id, params);
          break;
          
        default:
          throw new Error(`Unknown method: ${method}`);
      }
      
      socket.emit(`response-${id}`, response);
      
    } catch (error) {
      console.error(`❌ RPC error for ${method}:`, error);
      socket.emit(`response-${id}`, { error: error.message });
    }
  });

  // MediaSoup transport creation
  socket.on('createWebRtcTransport', async (data, callback) => {
    try {
      const { roomId, producing } = data;
      const room = rooms.get(roomId);
      
      if (!room) {
        return callback({ error: 'Room not found' });
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
      
      console.log(`🚛 Created WebRTC transport for ${socket.id}: ${transport.id}`);
      
      callback({
        params: {
          id: transport.id,
          iceParameters: transport.iceParameters,
          iceCandidates: transport.iceCandidates,
          dtlsParameters: transport.dtlsParameters,
        },
      });
      
    } catch (error) {
      console.error('❌ Error creating WebRTC transport:', error);
      callback({ error: error.message });
    }
  });
  
  // Connect transport
  socket.on('connectTransport', async (data, callback) => {
    try {
      const { transportId, dtlsParameters } = data;
      const peer = [...rooms.values()].find(room => room.peers.has(socket.id))?.peers.get(socket.id);
      
      if (peer) {
        const transport = peer.transports.get(transportId);
        if (transport) {
          await transport.connect({ dtlsParameters });
          console.log(`🔗 Connected transport ${transportId} for ${socket.id}`);
          callback({ success: true });
        } else {
          callback({ error: 'Transport not found' });
        }
      } else {
        callback({ error: 'Peer not found' });
      }
    } catch (error) {
      console.error('❌ Error connecting transport:', error);
      callback({ error: error.message });
    }
  });
  
  // Produce media
  socket.on('produce', async (data, callback) => {
    try {
      const { transportId, kind, rtpParameters, appData } = data;
      const room = [...rooms.values()].find(room => room.peers.has(socket.id));
      const peer = room?.peers.get(socket.id);
      
      if (!peer) {
        return callback({ error: 'Peer not found' });
      }
      
      // Enable video production for moderators and speakers
      if (kind === 'video' && peer.role === 'audience') {
        console.log(`🚫 Video production disabled for audience members`);
        return callback({ error: 'Video disabled for audience role' });
      }
      
      const transport = peer.transports.get(transportId);
      if (!transport) {
        return callback({ error: 'Transport not found' });
      }
      
      const producer = await transport.produce({
        kind,
        rtpParameters,
        appData,
      });
      
      peer.producers.set(producer.id, producer);
      
      producer.on('transportclose', () => {
        producer.close();
        peer.producers.delete(producer.id);
      });
      
      console.log(`🎬 Created producer ${producer.id} (${kind}) for ${peer.userId} (${peer.role})`);
      
      // Notify other peers about new producer
      if (room) {
        socket.to(room.id).emit('newProducer', {
          peerId: socket.id,
          producerId: producer.id,
          kind,
          userId: peer.userId,
          role: peer.role
        });
      }
      
      callback({ id: producer.id });
      
    } catch (error) {
      console.error('❌ Error creating producer:', error);
      callback({ error: error.message });
    }
  });
  
  // Consume media
  socket.on('consume', async (data, callback) => {
    try {
      const { transportId, producerId, rtpCapabilities } = data;
      const room = [...rooms.values()].find(room => room.peers.has(socket.id));
      const peer = room?.peers.get(socket.id);
      
      if (!room || !peer) {
        return callback({ error: 'Room or peer not found' });
      }
      
      const transport = peer.transports.get(transportId);
      if (!transport) {
        return callback({ error: 'Transport not found' });
      }
      
      // Find the producer in the room
      let producer = null;
      for (const [peerId, roomPeer] of room.peers) {
        producer = roomPeer.producers.get(producerId);
        if (producer) break;
      }
      
      if (!producer) {
        return callback({ error: 'Producer not found' });
      }
      
      if (!room.router.canConsume({ producerId, rtpCapabilities })) {
        return callback({ error: 'Cannot consume' });
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
      
      callback({
        id: consumer.id,
        producerId,
        kind: consumer.kind,
        rtpParameters: consumer.rtpParameters,
      });
      
    } catch (error) {
      console.error('❌ Error creating consumer:', error);
      callback({ error: error.message });
    }
  });
  
  // Resume consumer
  socket.on('resumeConsumer', async (data, callback) => {
    try {
      const { consumerId } = data;
      const peer = [...rooms.values()].find(room => room.peers.has(socket.id))?.peers.get(socket.id);
      
      if (peer) {
        const consumer = peer.consumers.get(consumerId);
        if (consumer) {
          await consumer.resume();
          console.log(`▶️ Resumed consumer ${consumerId} for ${socket.id}`);
          callback({ success: true });
        } else {
          callback({ error: 'Consumer not found' });
        }
      } else {
        callback({ error: 'Peer not found' });
      }
    } catch (error) {
      console.error('❌ Error resuming consumer:', error);
      callback({ error: error.message });
    }
  });

  // Simple WebRTC signaling relay
  socket.on('offer', (data) => {
    console.log(`📤 Relaying offer from ${socket.id} to room`);
    socket.broadcast.emit('offer', {
      ...data,
      from: socket.id,
    });
  });
  
  socket.on('answer', (data) => {
    console.log(`📤 Relaying answer from ${socket.id}`);
    socket.broadcast.emit('answer', {
      ...data,
      from: socket.id,
    });
  });
  
  socket.on('ice-candidate', (data) => {
    console.log(`🧊 Relaying ICE candidate from ${socket.id}`);
    socket.broadcast.emit('ice-candidate', {
      ...data,
      from: socket.id,
    });
  });

  socket.on('error', (error) => {
    console.error(`❌ Socket error for ${socket.id}:`, error);
  });

  socket.on('disconnect', () => {
    console.log(`🔌 Client disconnected: ${socket.id}`);
    
    // Clean up peer from all rooms
    rooms.forEach((room, roomId) => {
      if (room.peers.has(socket.id)) {
        room.removePeer(socket.id);
        socket.to(roomId).emit('peer-left', { peerId: socket.id });
        
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

// Health check endpoint
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
    });
  } catch (error) {
    console.error('❌ Failed to start MediaSoup server:', error);
    process.exit(1);
  }
}

startServer();