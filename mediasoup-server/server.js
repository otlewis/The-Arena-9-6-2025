const express = require('express');
const https = require('https');
const http = require('http');
const socketIo = require('socket.io');
const mediasoup = require('mediasoup');
const cors = require('cors');
const fs = require('fs');
const config = require('./config');

// Express app
const app = express();
app.use(cors());
app.use(express.json());

// HTTP/HTTPS servers
let server;
let io;

// Initialize servers based on environment
if (process.env.NODE_ENV === 'production' && fs.existsSync(config.https.tls.cert)) {
  // Production with HTTPS
  const options = {
    cert: fs.readFileSync(config.https.tls.cert),
    key: fs.readFileSync(config.https.tls.key),
  };
  server = https.createServer(options, app);
  console.log(`🔒 HTTPS server starting on port ${config.https.listenPort}`);
} else {
  // Development with HTTP
  server = http.createServer(app);
  console.log(`🔓 HTTP server starting on port ${config.http.listenPort}`);
}

io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

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
    this.closed = false;
    
    console.log(`📺 Room ${roomId} created`);
  }

  async init() {
    const mediaCodecs = config.mediasoup.router.mediaCodecs;
    this.router = await getMediasoupWorker().createRouter({ mediaCodecs });
    console.log(`🔧 Router created for room ${this.id}`);
  }

  close() {
    this.closed = true;
    this.router?.close();
    this.peers.clear();
    console.log(`🚪 Room ${this.id} closed`);
  }

  addPeer(peer) {
    this.peers.set(peer.id, peer);
    console.log(`👤 Peer ${peer.id} joined room ${this.id} (${this.peers.size} total)`);
  }

  removePeer(peerId) {
    this.peers.delete(peerId);
    console.log(`👋 Peer ${peerId} left room ${this.id} (${this.peers.size} remaining)`);
    
    // Close room if empty
    if (this.peers.size === 0) {
      this.close();
      rooms.delete(this.id);
    }
  }

  getPeers() {
    return Array.from(this.peers.values());
  }
}

class Peer {
  constructor(socketId, roomId, socket, userId = null) {
    this.id = socketId;
    this.userId = userId; // Arena user ID
    this.roomId = roomId;
    this.socket = socket;
    this.transports = new Map();
    this.producers = new Map();
    this.consumers = new Map();
    this.device = null;
    
    console.log(`🤝 Peer ${socketId} (user: ${userId}) created for room ${roomId}`);
  }

  close() {
    this.transports.forEach(transport => transport.close());
    this.producers.forEach(producer => producer.close());
    this.consumers.forEach(consumer => consumer.close());
    console.log(`🔌 Peer ${this.id} closed`);
  }

  addTransport(transport) {
    this.transports.set(transport.id, transport);
  }

  addProducer(producer) {
    this.producers.set(producer.id, producer);
  }

  addConsumer(consumer) {
    this.consumers.set(consumer.id, consumer);
  }

  removeConsumer(consumerId) {
    this.consumers.delete(consumerId);
  }
}

// Get MediaSoup worker (round-robin)
function getMediasoupWorker() {
  const worker = mediasoupWorkers[nextMediasoupWorkerIdx];
  if (++nextMediasoupWorkerIdx === mediasoupWorkers.length) {
    nextMediasoupWorkerIdx = 0;
  }
  return worker;
}

// Get or create room
async function getOrCreateRoom(roomId) {
  let room = rooms.get(roomId);
  if (!room) {
    room = new Room(roomId);
    await room.init();
    rooms.set(roomId, room);
  }
  return room;
}

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`🔗 Socket connected: ${socket.id}`);
  
  let peer = null;
  let room = null;

  socket.on('join-room', async (data, callback) => {
    try {
      const { roomId, device, userId, role } = data;
      console.log(`📥 Join room request: ${roomId} from ${socket.id} (user: ${userId}, role: ${role})`);
      
      room = await getOrCreateRoom(roomId);
      peer = new Peer(socket.id, roomId, socket, userId);
      peer.device = device;
      peer.role = role;
      
      room.addPeer(peer);
      
      // Send router RTP capabilities
      callback({
        success: true,
        rtpCapabilities: room.router.rtpCapabilities
      });
      
      // Send existing peers to the new peer
      const existingPeers = room.getPeers().filter(p => p.id !== socket.id);
      existingPeers.forEach(existingPeer => {
        socket.emit('peer-joined', {
          peerId: existingPeer.id,
          userId: existingPeer.userId,
          role: existingPeer.role,
          device: existingPeer.device
        });
        
        // Also send existing producers from this peer
        existingPeer.producers.forEach(producer => {
          socket.emit('new-producer', {
            peerId: existingPeer.id,
            userId: existingPeer.userId,
            producerId: producer.id,
            kind: producer.kind
          });
        });
      });
      
      // Notify other peers about new peer
      socket.to(roomId).emit('peer-joined', {
        peerId: socket.id,
        userId: userId,
        role: role,
        device: device
      });
      
      socket.join(roomId);
      
    } catch (error) {
      console.error('Error joining room:', error);
      callback({ success: false, error: error.message });
    }
  });

  socket.on('get-router-capabilities', (callback) => {
    try {
      console.log(`🎛️ Sending router capabilities to ${socket.id}`);
      
      if (!room) {
        console.log(`⚠️ Room not found for ${socket.id}, sending error response`);
        callback({ success: false, error: 'Peer not in room' });
        return;
      }

      console.log(`✅ Sending router capabilities for room ${room.id}`);
      callback({
        success: true,
        rtpCapabilities: room.router.rtpCapabilities
      });
    } catch (error) {
      console.error('Error getting router capabilities:', error);
      callback({ success: false, error: error.message });
    }
  });

  socket.on('create-transport', async (data, callback) => {
    try {
      const { direction } = data; // 'send' or 'recv'
      console.log(`🚛 Creating ${direction} transport for ${socket.id}`);
      
      if (!room || !peer) {
        throw new Error('Peer not in room');
      }

      const transport = await room.router.createWebRtcTransport({
        ...config.mediasoup.webRtcTransport,
        appData: { peerId: socket.id, direction }
      });

      peer.addTransport(transport);

      transport.on('dtlsstatechange', (dtlsState) => {
        if (dtlsState === 'closed') {
          console.log(`🔐 Transport closed for peer ${socket.id}`);
          transport.close();
        }
      });

      callback({
        success: true,
        params: {
          id: transport.id,
          iceParameters: transport.iceParameters,
          iceCandidates: transport.iceCandidates,
          dtlsParameters: transport.dtlsParameters
        }
      });

    } catch (error) {
      console.error('Error creating transport:', error);
      callback({ success: false, error: error.message });
    }
  });

  socket.on('connect-transport', async (data, callback) => {
    try {
      const { transportId, dtlsParameters } = data;
      console.log(`🔌 Connecting transport ${transportId} for ${socket.id}`);
      
      const transport = peer.transports.get(transportId);
      if (!transport) {
        throw new Error('Transport not found');
      }

      await transport.connect({ dtlsParameters });
      callback({ success: true });

    } catch (error) {
      console.error('Error connecting transport:', error);
      callback({ success: false, error: error.message });
    }
  });

  socket.on('produce', async (data, callback) => {
    try {
      const { transportId, kind, rtpParameters, appData } = data;
      console.log(`🎬 Producing ${kind} for ${socket.id}`);
      
      const transport = peer.transports.get(transportId);
      if (!transport) {
        throw new Error('Transport not found');
      }

      const producer = await transport.produce({
        kind,
        rtpParameters,
        appData: { ...appData, peerId: socket.id }
      });

      peer.addProducer(producer);

      producer.on('transportclose', () => {
        console.log(`📹 Producer transport closed for ${socket.id}`);
        producer.close();
      });

      callback({ success: true, id: producer.id });

      // Notify other peers about new producer
      socket.to(room.id).emit('new-producer', {
        peerId: socket.id,
        userId: peer.userId,
        producerId: producer.id,
        kind: producer.kind
      });

    } catch (error) {
      console.error('Error producing:', error);
      callback({ success: false, error: error.message });
    }
  });

  socket.on('consume', async (data, callback) => {
    try {
      const { transportId, producerId, rtpCapabilities } = data;
      console.log(`🍽️ Consuming ${producerId} for ${socket.id}`);
      
      const transport = peer.transports.get(transportId);
      if (!transport) {
        throw new Error('Transport not found');
      }

      if (!room.router.canConsume({ producerId, rtpCapabilities })) {
        throw new Error('Cannot consume');
      }

      const consumer = await transport.consume({
        producerId,
        rtpCapabilities,
        paused: true,
        appData: { peerId: socket.id, producerId }
      });

      peer.addConsumer(consumer);

      consumer.on('transportclose', () => {
        console.log(`📺 Consumer transport closed for ${socket.id}`);
        peer.removeConsumer(consumer.id);
      });

      consumer.on('producerclose', () => {
        console.log(`📹 Producer closed for consumer ${consumer.id}`);
        socket.emit('consumer-closed', { consumerId: consumer.id });
        peer.removeConsumer(consumer.id);
      });

      callback({
        success: true,
        params: {
          id: consumer.id,
          producerId: producerId,
          kind: consumer.kind,
          rtpParameters: consumer.rtpParameters,
          type: consumer.type,
          producerPaused: consumer.producerPaused
        }
      });

    } catch (error) {
      console.error('Error consuming:', error);
      callback({ success: false, error: error.message });
    }
  });

  socket.on('resume-consumer', async (data, callback) => {
    try {
      const { consumerId } = data;
      console.log(`▶️ Resuming consumer ${consumerId} for ${socket.id}`);
      
      const consumer = peer.consumers.get(consumerId);
      if (!consumer) {
        throw new Error('Consumer not found');
      }

      await consumer.resume();
      callback({ success: true });

    } catch (error) {
      console.error('Error resuming consumer:', error);
      callback({ success: false, error: error.message });
    }
  });

  socket.on('get-producers', (callback) => {
    if (!room) {
      callback({ success: false, error: 'Not in room' });
      return;
    }

    const producers = [];
    room.getPeers().forEach(p => {
      if (p.id !== socket.id) {
        p.producers.forEach(producer => {
          producers.push({
            peerId: p.id,
            producerId: producer.id,
            kind: producer.kind
          });
        });
      }
    });

    callback({ success: true, producers });
  });

  socket.on('disconnect', () => {
    console.log(`🔌 Socket disconnected: ${socket.id}`);
    
    if (peer) {
      peer.close();
      
      if (room) {
        room.removePeer(socket.id);
        
        // Notify other peers
        socket.to(room.id).emit('peer-left', { peerId: socket.id });
      }
    }
  });
});

// API endpoints
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    rooms: rooms.size,
    workers: mediasoupWorkers.length 
  });
});

app.get('/rooms', (req, res) => {
  const roomList = Array.from(rooms.values()).map(room => ({
    id: room.id,
    peers: room.peers.size,
    closed: room.closed
  }));
  res.json({ rooms: roomList });
});

// Initialize MediaSoup workers
async function initializeMediaSoup() {
  const numWorkers = config.mediasoup.numWorkers;
  console.log(`🏭 Creating ${numWorkers} MediaSoup workers...`);

  for (let i = 0; i < numWorkers; i++) {
    const worker = await mediasoup.createWorker({
      logLevel: config.mediasoup.worker.logLevel,
      logTags: config.mediasoup.worker.logTags,
      rtcMinPort: config.mediasoup.worker.rtcMinPort,
      rtcMaxPort: config.mediasoup.worker.rtcMaxPort,
    });

    worker.on('died', () => {
      console.error(`💀 MediaSoup worker ${i} died, exiting in 2 seconds...`);
      setTimeout(() => process.exit(1), 2000);
    });

    mediasoupWorkers.push(worker);
    console.log(`✅ MediaSoup worker ${i} created`);
  }

  console.log(`🎉 All ${numWorkers} MediaSoup workers created successfully`);
}

// Start server
async function startServer() {
  try {
    await initializeMediaSoup();
    
    const port = process.env.NODE_ENV === 'production' && fs.existsSync(config.https.tls.cert) 
      ? config.https.listenPort 
      : config.http.listenPort;
    
    server.listen(port, () => {
      console.log(`🚀 Arena MediaSoup SFU Server running on port ${port}`);
      console.log(`📊 Workers: ${mediasoupWorkers.length}`);
      console.log(`🌐 Environment: ${process.env.NODE_ENV || 'development'}`);
    });
    
  } catch (error) {
    console.error('💥 Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('🛑 Received SIGINT, shutting down gracefully...');
  
  rooms.forEach(room => room.close());
  mediasoupWorkers.forEach(worker => worker.close());
  
  server.close(() => {
    console.log('👋 Server closed');
    process.exit(0);
  });
});

// Start the server
startServer();