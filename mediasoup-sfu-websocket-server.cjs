const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const mediasoup = require('mediasoup');
const cors = require('cors');

// Express app
const app = express();
app.use(cors());
app.use(express.json());

// HTTP server
const server = http.createServer(app);
console.log(`🔓 MediaSoup SFU WebSocket server starting on port ${process.env.PORT || 3007}`);

// WebSocket server for signaling (like the working solution)
const wss = new WebSocket.Server({ 
  server,
  path: '/sfu-signaling'
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
        announcedIp: process.env.ANNOUNCED_IP || '172.236.109.9',
      },
    ],
    maxIncomingBitrate: 1500000,
    initialAvailableOutgoingBitrate: 1000000,
  },
};

// MediaSoup setup
let mediasoupWorkers = [];
let nextMediasoupWorkerIdx = 0;

// Room management with SFU capabilities
const rooms = new Map();
const clients = new Map();

class SFURoom {
  constructor(roomId) {
    this.id = roomId;
    this.router = null;
    this.clients = new Map();
    this.producers = new Map(); // producerId -> producer
    this.consumers = new Map(); // consumerId -> consumer
  }

  async initialize() {
    const worker = getMediasoupWorker();
    this.router = await worker.createRouter({
      mediaCodecs: mediasoupConfig.router.mediaCodecs,
    });
    console.log(`📡 MediaSoup router created for room ${this.id}`);
  }

  addClient(clientId, ws, userData = {}) {
    const client = {
      id: clientId,
      ws: ws,
      userId: userData.userId,
      role: userData.role || 'audience',
      room: this.id,
      transports: new Map(), // transportId -> transport
      producers: new Map(),  // producerId -> producer
      consumers: new Map(),  // consumerId -> consumer
    };
    this.clients.set(clientId, client);
    console.log(`👤 Client ${userData.userId} joined SFU room ${this.id} as ${client.role}`);
    return client;
  }

  removeClient(clientId) {
    const client = this.clients.get(clientId);
    if (client) {
      // Clean up transports, producers, consumers
      client.transports.forEach(transport => transport.close());
      client.producers.forEach(producer => {
        producer.close();
        this.producers.delete(producer.id);
      });
      client.consumers.forEach(consumer => {
        consumer.close();
        this.consumers.delete(consumer.id);
      });
      
      this.clients.delete(clientId);
      console.log(`👋 Client ${client.userId} left SFU room ${this.id}`);
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

  // Get RTP capabilities for clients
  getRtpCapabilities() {
    return this.router ? this.router.rtpCapabilities : null;
  }

  // Create WebRTC transport for a client
  async createWebRtcTransport(clientId, direction) {
    const client = this.clients.get(clientId);
    if (!client || !this.router) return null;

    const transport = await this.router.createWebRtcTransport({
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

    client.transports.set(transport.id, transport);
    console.log(`🚛 Created ${direction} transport ${transport.id} for ${client.userId}`);

    return {
      id: transport.id,
      iceParameters: transport.iceParameters,
      iceCandidates: transport.iceCandidates,
      dtlsParameters: transport.dtlsParameters,
    };
  }

  // Connect transport
  async connectTransport(clientId, transportId, dtlsParameters) {
    const client = this.clients.get(clientId);
    if (!client) return false;

    const transport = client.transports.get(transportId);
    if (!transport) return false;

    await transport.connect({ dtlsParameters });
    console.log(`🔗 Connected transport ${transportId} for ${client.userId}`);
    return true;
  }

  // Produce media
  async produce(clientId, transportId, kind, rtpParameters, appData = {}) {
    const client = this.clients.get(clientId);
    if (!client) return null;

    const transport = client.transports.get(transportId);
    if (!transport) return null;

    // Check role permissions for video
    if (kind === 'video' && client.role === 'audience') {
      throw new Error('Video production not allowed for audience role');
    }

    const producer = await transport.produce({
      kind,
      rtpParameters,
      appData: { ...appData, clientId, userId: client.userId, role: client.role },
    });

    client.producers.set(producer.id, producer);
    this.producers.set(producer.id, producer);

    producer.on('transportclose', () => {
      producer.close();
      client.producers.delete(producer.id);
      this.producers.delete(producer.id);
    });

    console.log(`🎬 Created producer ${producer.id} (${kind}) for ${client.userId} (${client.role})`);

    // Notify other clients about new producer
    this.broadcast({
      type: 'new-producer',
      data: {
        producerId: producer.id,
        clientId: clientId,
        userId: client.userId,
        role: client.role,
        kind: kind,
      }
    }, clientId);

    return { producerId: producer.id };
  }

  // Consume media from another producer
  async consume(clientId, producerId, rtpCapabilities) {
    const client = this.clients.get(clientId);
    const producer = this.producers.get(producerId);
    
    if (!client || !producer || !this.router) return null;

    if (!this.router.canConsume({ producerId, rtpCapabilities })) {
      console.log(`❌ Cannot consume producer ${producerId} for ${client.userId}`);
      return null;
    }

    // Find receive transport for this client
    let recvTransport = null;
    for (const transport of client.transports.values()) {
      if (transport.appData?.direction === 'recv') {
        recvTransport = transport;
        break;
      }
    }

    if (!recvTransport) {
      console.log(`❌ No receive transport found for ${client.userId}`);
      return null;
    }

    const consumer = await recvTransport.consume({
      producerId,
      rtpCapabilities,
      paused: true, // Start paused
    });

    client.consumers.set(consumer.id, consumer);
    this.consumers.set(consumer.id, consumer);

    consumer.on('transportclose', () => {
      consumer.close();
      client.consumers.delete(consumer.id);
      this.consumers.delete(consumer.id);
    });

    consumer.on('producerclose', () => {
      consumer.close();
      client.consumers.delete(consumer.id);
      this.consumers.delete(consumer.id);
      
      // Notify client
      client.ws.send(JSON.stringify({
        type: 'consumer-closed',
        data: { consumerId: consumer.id }
      }));
    });

    console.log(`🍽️ Created consumer ${consumer.id} for ${client.userId}`);

    return {
      id: consumer.id,
      producerId,
      kind: consumer.kind,
      rtpParameters: consumer.rtpParameters,
    };
  }

  // Resume consumer
  async resumeConsumer(clientId, consumerId) {
    const client = this.clients.get(clientId);
    if (!client) return false;

    const consumer = client.consumers.get(consumerId);
    if (!consumer) return false;

    await consumer.resume();
    console.log(`▶️ Resumed consumer ${consumerId} for ${client.userId}`);
    return true;
  }

  // Get list of available producers for a client
  getAvailableProducers(clientId) {
    const producers = [];
    this.producers.forEach((producer, producerId) => {
      if (producer.appData.clientId !== clientId) {
        producers.push({
          producerId: producerId,
          clientId: producer.appData.clientId,
          userId: producer.appData.userId,
          role: producer.appData.role,
          kind: producer.kind,
        });
      }
    });
    return producers;
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

function generateClientId() {
  return 'sfu_' + Math.random().toString(36).substr(2, 9);
}

// WebSocket connection handling
wss.on('connection', (ws, req) => {
  const clientId = generateClientId();
  clients.set(ws, { id: clientId, room: null });
  
  console.log(`🔌 SFU WebSocket connection established: ${clientId}`);
  
  // Send connection confirmation
  ws.send(JSON.stringify({
    type: 'connected',
    clientId: clientId,
    timestamp: new Date().toISOString()
  }));

  ws.on('message', async (data) => {
    try {
      const message = JSON.parse(data.toString());
      await handleSFUMessage(ws, clientId, message);
    } catch (error) {
      console.error(`❌ Invalid SFU message from ${clientId}:`, error);
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Invalid JSON message'
      }));
    }
  });

  ws.on('close', (code, reason) => {
    console.log(`🔌 SFU WebSocket disconnected: ${clientId}`);
    handleSFUDisconnect(ws, clientId);
  });

  ws.on('error', (error) => {
    console.error(`❌ SFU WebSocket error for ${clientId}:`, error);
  });
});

async function handleSFUMessage(ws, clientId, message) {
  const { type, data } = message;
  
  console.log(`📨 SFU message from ${clientId}: ${type}`);

  try {
    switch (type) {
      case 'join-room':
        await handleSFUJoinRoom(ws, clientId, data);
        break;
        
      case 'get-rtp-capabilities':
        await handleGetRtpCapabilities(ws, clientId, data);
        break;
        
      case 'create-transport':
        await handleCreateTransport(ws, clientId, data);
        break;
        
      case 'connect-transport':
        await handleConnectTransport(ws, clientId, data);
        break;
        
      case 'produce':
        await handleProduce(ws, clientId, data);
        break;
        
      case 'consume':
        await handleConsume(ws, clientId, data);
        break;
        
      case 'resume-consumer':
        await handleResumeConsumer(ws, clientId, data);
        break;
        
      case 'get-producers':
        await handleGetProducers(ws, clientId, data);
        break;
        
      default:
        console.log(`❓ Unknown SFU message type: ${type}`);
        ws.send(JSON.stringify({
          type: 'error',
          message: `Unknown message type: ${type}`
        }));
    }
  } catch (error) {
    console.error(`❌ Error handling SFU message ${type}:`, error);
    ws.send(JSON.stringify({
      type: 'error',
      message: error.message
    }));
  }
}

async function handleSFUJoinRoom(ws, clientId, data) {
  const { roomId, userId, role } = data;
  
  // Get or create room
  let room = rooms.get(roomId);
  if (!room) {
    room = new SFURoom(roomId);
    await room.initialize();
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
  
  // Send room-joined confirmation with RTP capabilities
  ws.send(JSON.stringify({
    type: 'room-joined',
    data: {
      roomId: roomId,
      clientId: clientId,
      rtpCapabilities: room.getRtpCapabilities(),
    }
  }));
  
  // Notify other clients
  room.broadcast({
    type: 'peer-joined',
    data: {
      clientId: clientId,
      userId: userId,
      role: role
    }
  }, clientId);
}

async function handleGetRtpCapabilities(ws, clientId, data) {
  const clientInfo = clients.get(ws);
  if (!clientInfo?.room) return;
  
  const room = rooms.get(clientInfo.room);
  if (!room) return;
  
  ws.send(JSON.stringify({
    type: 'rtp-capabilities',
    data: {
      rtpCapabilities: room.getRtpCapabilities()
    }
  }));
}

async function handleCreateTransport(ws, clientId, data) {
  const { direction } = data;
  const clientInfo = clients.get(ws);
  if (!clientInfo?.room) return;
  
  const room = rooms.get(clientInfo.room);
  if (!room) return;
  
  const transportParams = await room.createWebRtcTransport(clientId, direction);
  
  ws.send(JSON.stringify({
    type: 'transport-created',
    data: {
      direction: direction,
      ...transportParams
    }
  }));
}

async function handleConnectTransport(ws, clientId, data) {
  const { transportId, dtlsParameters } = data;
  const clientInfo = clients.get(ws);
  if (!clientInfo?.room) return;
  
  const room = rooms.get(clientInfo.room);
  if (!room) return;
  
  const success = await room.connectTransport(clientId, transportId, dtlsParameters);
  
  ws.send(JSON.stringify({
    type: 'transport-connected',
    data: { success }
  }));
}

async function handleProduce(ws, clientId, data) {
  const { transportId, kind, rtpParameters, appData } = data;
  const clientInfo = clients.get(ws);
  if (!clientInfo?.room) return;
  
  const room = rooms.get(clientInfo.room);
  if (!room) return;
  
  const result = await room.produce(clientId, transportId, kind, rtpParameters, appData);
  
  ws.send(JSON.stringify({
    type: 'produced',
    data: result
  }));
}

async function handleConsume(ws, clientId, data) {
  const { producerId, rtpCapabilities } = data;
  const clientInfo = clients.get(ws);
  if (!clientInfo?.room) return;
  
  const room = rooms.get(clientInfo.room);
  if (!room) return;
  
  const consumerParams = await room.consume(clientId, producerId, rtpCapabilities);
  
  ws.send(JSON.stringify({
    type: 'consumed',
    data: consumerParams
  }));
}

async function handleResumeConsumer(ws, clientId, data) {
  const { consumerId } = data;
  const clientInfo = clients.get(ws);
  if (!clientInfo?.room) return;
  
  const room = rooms.get(clientInfo.room);
  if (!room) return;
  
  const success = await room.resumeConsumer(clientId, consumerId);
  
  ws.send(JSON.stringify({
    type: 'consumer-resumed',
    data: { success }
  }));
}

async function handleGetProducers(ws, clientId, data) {
  const clientInfo = clients.get(ws);
  if (!clientInfo?.room) return;
  
  const room = rooms.get(clientInfo.room);
  if (!room) return;
  
  const producers = room.getAvailableProducers(clientId);
  
  ws.send(JSON.stringify({
    type: 'producers-list',
    data: { producers }
  }));
}

function handleSFUDisconnect(ws, clientId) {
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
        if (room.router) {
          room.router.close();
        }
        rooms.delete(clientInfo.room);
        console.log(`🧹 Cleaned up empty SFU room: ${clientInfo.room}`);
      }
    }
  }
  
  clients.delete(ws);
}

// Health check endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Arena MediaSoup SFU WebSocket Server',
    status: 'running',
    workers: mediasoupWorkers.length,
    rooms: rooms.size,
    connections: wss.clients.size,
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'production'
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    workers: mediasoupWorkers.length,
    rooms: rooms.size,
    connections: wss.clients.size,
    uptime: process.uptime()
  });
});

// Start server
const PORT = process.env.PORT || 3007;

async function startServer() {
  try {
    await initializeMediaSoup();
    
    server.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Arena MediaSoup SFU WebSocket Server running on port ${PORT}`);
      console.log(`📊 Workers: ${mediasoupWorkers.length}`);
      console.log(`🌐 Environment: ${process.env.NODE_ENV || 'production'}`);
      console.log(`📡 Announced IP: ${process.env.ANNOUNCED_IP || '172.236.109.9'}`);
      console.log(`🎯 WebRTC ports: ${mediasoupConfig.worker.rtcMinPort}-${mediasoupConfig.worker.rtcMaxPort}`);
      console.log(`🔌 SFU WebSocket endpoint: ws://localhost:${PORT}/sfu-signaling`);
    });
  } catch (error) {
    console.error('❌ Failed to start MediaSoup SFU server:', error);
    process.exit(1);
  }
}

startServer();