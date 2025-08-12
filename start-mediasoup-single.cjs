const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const mediasoup = require('mediasoup');
const cors = require('cors');
const os = require('os');
const crypto = require('crypto');

// Configuration optimized for single server
const config = {
  serverId: process.env.SERVER_ID || crypto.randomBytes(8).toString('hex'),
  listenIp: '0.0.0.0',
  listenPort: process.env.PORT || 3001,
  announcedIp: process.env.ANNOUNCED_IP || '172.236.109.9',
  
  mediasoup: {
    numWorkers: 2, // Use both CPU cores
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
      ],
    },
    webRtcTransport: {
      listenIps: [
        {
          ip: '0.0.0.0',
          announcedIp: process.env.ANNOUNCED_IP || '172.236.109.9',
        },
      ],
      maxIncomingBitrate: 1500000,
      initialAvailableOutgoingBitrate: 1000000,
      enableUdp: true,
      enableTcp: true,
      preferUdp: true,
    },
  },
};

// Express app
const app = express();
app.use(cors());
app.use(express.json());

// HTTP server
const server = http.createServer(app);

// Socket.IO without Redis (single server)
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  },
  transports: ['websocket', 'polling'],
});

// Server state
const state = {
  workers: [],
  nextWorkerIdx: 0,
  rooms: new Map(), // roomId -> { router, peers: Map() }
  transports: new Map(), // transportId -> transport
  producers: new Map(), // producerId -> producer
  consumers: new Map(), // consumerId -> consumer
  metrics: {
    rooms: 0,
    peers: 0,
    producers: 0,
    consumers: 0,
  }
};

// Initialize MediaSoup workers
async function initializeWorkers() {
  console.log(`🚀 Creating ${config.mediasoup.numWorkers} workers...`);
  
  for (let i = 0; i < config.mediasoup.numWorkers; i++) {
    const worker = await mediasoup.createWorker(config.mediasoup.worker);
    
    worker.on('died', error => {
      console.error(`❌ Worker died: ${error}`);
      setTimeout(() => initializeWorkers(), 2000);
    });
    
    state.workers.push(worker);
    console.log(`✅ Worker ${i} created (pid: ${worker.pid})`);
  }
}

// Get next worker using round-robin
function getNextWorker() {
  const worker = state.workers[state.nextWorkerIdx];
  state.nextWorkerIdx = (state.nextWorkerIdx + 1) % state.workers.length;
  return worker;
}

// Create router for a room
async function createRouter(roomId, roomType) {
  const worker = getNextWorker();
  const router = await worker.createRouter({ mediaCodecs: config.mediasoup.router.mediaCodecs });
  
  const room = {
    id: roomId,
    type: roomType,
    router,
    peers: new Map(),
    createdAt: Date.now(),
  };
  
  state.rooms.set(roomId, room);
  state.metrics.rooms++;
  
  console.log(`🏠 Room ${roomId} created on router ${router.id}`);
  return room;
}

// Get or create room
async function getOrCreateRoom(roomId, roomType) {
  let room = state.rooms.get(roomId);
  
  if (!room) {
    room = await createRouter(roomId, roomType);
  }
  
  return { room, redirect: null };
}

// Clean up peer resources
async function cleanupPeer(roomId, peerId) {
  const room = state.rooms.get(roomId);
  if (!room) return;
  
  const peer = room.peers.get(peerId);
  if (!peer) return;
  
  // Close all transports
  for (const transport of peer.transports.values()) {
    transport.close();
    state.transports.delete(transport.id);
  }
  
  // Close all producers
  for (const producer of peer.producers.values()) {
    producer.close();
    state.producers.delete(producer.id);
    state.metrics.producers--;
  }
  
  // Close all consumers
  for (const consumer of peer.consumers.values()) {
    consumer.close();
    state.consumers.delete(consumer.id);
    state.metrics.consumers--;
  }
  
  room.peers.delete(peerId);
  state.metrics.peers--;
  
  // Clean up room if empty
  if (room.peers.size === 0) {
    room.router.close();
    state.rooms.delete(roomId);
    state.metrics.rooms--;
    console.log(`🗑️ Room ${roomId} closed (empty)`);
  }
}

// Socket.IO connection handler
io.on('connection', (socket) => {
  console.log(`🔌 New connection: ${socket.id}`);
  
  socket.on('join-room', async ({ roomId, peerId, roomType, role }) => {
    try {
      const { room } = await getOrCreateRoom(roomId, roomType);
      
      socket.join(roomId);
      socket.data.roomId = roomId;
      socket.data.peerId = peerId;
      
      const peer = {
        id: peerId,
        socketId: socket.id,
        role,
        transports: new Map(),
        producers: new Map(),
        consumers: new Map(),
        joinedAt: Date.now(),
      };
      
      room.peers.set(peerId, peer);
      state.metrics.peers++;
      
      // Send router capabilities
      socket.emit('router-capabilities', {
        rtpCapabilities: room.router.rtpCapabilities,
      });
      
      // Notify others in room
      socket.to(roomId).emit('peer-joined', { peerId, role });
      
      console.log(`✅ Peer ${peerId} joined room ${roomId} as ${role}`);
      
    } catch (error) {
      console.error('❌ Join room error:', error);
      socket.emit('error', error.message);
    }
  });
  
  socket.on('create-transport', async ({ producing, consuming }, callback) => {
    try {
      const { roomId, peerId } = socket.data;
      const room = state.rooms.get(roomId);
      const peer = room?.peers.get(peerId);
      
      if (!room || !peer) {
        throw new Error('Room or peer not found');
      }
      
      const transport = await room.router.createWebRtcTransport(config.mediasoup.webRtcTransport);
      
      peer.transports.set(transport.id, transport);
      state.transports.set(transport.id, transport);
      
      callback({
        id: transport.id,
        iceParameters: transport.iceParameters,
        iceCandidates: transport.iceCandidates,
        dtlsParameters: transport.dtlsParameters,
      });
      
    } catch (error) {
      console.error('❌ Create transport error:', error);
      callback({ error: error.message });
    }
  });
  
  socket.on('connect-transport', async ({ transportId, dtlsParameters }, callback) => {
    try {
      const transport = state.transports.get(transportId);
      if (!transport) throw new Error('Transport not found');
      
      await transport.connect({ dtlsParameters });
      callback({ success: true });
      
    } catch (error) {
      console.error('❌ Connect transport error:', error);
      callback({ error: error.message });
    }
  });
  
  socket.on('produce', async ({ transportId, kind, rtpParameters, appData }, callback) => {
    try {
      const { roomId, peerId } = socket.data;
      const transport = state.transports.get(transportId);
      const room = state.rooms.get(roomId);
      const peer = room?.peers.get(peerId);
      
      if (!transport || !room || !peer) {
        throw new Error('Transport, room, or peer not found');
      }
      
      const producer = await transport.produce({
        kind,
        rtpParameters,
        appData: { ...appData, peerId, roomId },
      });
      
      peer.producers.set(producer.id, producer);
      state.producers.set(producer.id, producer);
      state.metrics.producers++;
      
      // Notify other peers
      socket.to(roomId).emit('new-producer', {
        producerId: producer.id,
        peerId,
        kind,
        role: peer.role,
      });
      
      callback({ id: producer.id });
      
    } catch (error) {
      console.error('❌ Produce error:', error);
      callback({ error: error.message });
    }
  });
  
  socket.on('consume', async ({ producerId, rtpCapabilities }, callback) => {
    try {
      const { roomId, peerId } = socket.data;
      const room = state.rooms.get(roomId);
      const peer = room?.peers.get(peerId);
      const producer = state.producers.get(producerId);
      
      if (!room || !peer || !producer) {
        throw new Error('Room, peer, or producer not found');
      }
      
      // Check if router can consume
      if (!room.router.canConsume({ producerId, rtpCapabilities })) {
        throw new Error('Cannot consume');
      }
      
      // Find consuming transport
      let transport = Array.from(peer.transports.values())[0];
      
      if (!transport) {
        throw new Error('No transport found');
      }
      
      const consumer = await transport.consume({
        producerId,
        rtpCapabilities,
        paused: false,
      });
      
      peer.consumers.set(consumer.id, consumer);
      state.consumers.set(consumer.id, consumer);
      state.metrics.consumers++;
      
      callback({
        id: consumer.id,
        producerId,
        kind: consumer.kind,
        rtpParameters: consumer.rtpParameters,
      });
      
    } catch (error) {
      console.error('❌ Consume error:', error);
      callback({ error: error.message });
    }
  });
  
  socket.on('disconnect', async () => {
    console.log(`🔌 Disconnected: ${socket.id}`);
    
    if (socket.data.roomId && socket.data.peerId) {
      await cleanupPeer(socket.data.roomId, socket.data.peerId);
      socket.to(socket.data.roomId).emit('peer-left', { 
        peerId: socket.data.peerId 
      });
    }
  });
});

// Health check endpoint
app.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    serverId: config.serverId,
    uptime: process.uptime(),
    workers: state.workers.length,
    metrics: state.metrics,
    memory: process.memoryUsage(),
  };
  
  res.json(health);
});

// Start server
async function start() {
  try {
    await initializeWorkers();
    
    server.listen(config.listenPort, config.listenIp, () => {
      console.log(`🚀 MediaSoup single server running on ${config.listenIp}:${config.listenPort}`);
      console.log(`📡 Server ID: ${config.serverId}`);
      console.log(`🔧 Workers: ${state.workers.length}`);
      console.log(`🌐 Announced IP: ${config.announcedIp}`);
      console.log(`📊 Capacity: ~1,000-1,500 concurrent users on 2-CPU Linode`);
    });
    
  } catch (error) {
    console.error('❌ Server start error:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('🛑 Shutting down gracefully...');
  
  // Close all rooms
  for (const [roomId, room] of state.rooms) {
    for (const peerId of room.peers.keys()) {
      await cleanupPeer(roomId, peerId);
    }
  }
  
  // Close workers
  for (const worker of state.workers) {
    worker.close();
  }
  
  process.exit(0);
});

start();