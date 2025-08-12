const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const mediasoup = require('mediasoup');

const app = express();
const server = http.createServer(app);

// CORS configuration
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps)
    if (!origin) return callback(null, true);
    
    // In production, you should restrict this to your domains
    return callback(null, true);
  },
  credentials: true
};

app.use(cors(corsOptions));
app.use(express.json());

// Socket.IO with namespace support
const io = socketIo(server, {
  cors: corsOptions,
  transports: ['websocket', 'polling']
});

// MediaSoup globals
let worker;
let rooms = new Map();

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
];

// Initialize MediaSoup
async function createWorker() {
  worker = await mediasoup.createWorker({
    rtcMinPort: 40000,
    rtcMaxPort: 49999,
    logLevel: 'warn',
    logTags: [
      'info',
      'ice',
      'dtls',
      'rtp',
      'srtp',
      'rtcp',
    ],
  });

  console.log(`🎥 MediaSoup worker pid ${worker.pid}`);

  worker.on('died', error => {
    console.error('MediaSoup worker has died:', error);
    setTimeout(() => process.exit(1), 2000);
  });

  return worker;
}

// Room class for MediaSoup
class Room {
  constructor(roomId) {
    this.id = roomId;
    this.router = null;
    this.peers = new Map();
  }

  async createRouter() {
    this.router = await worker.createRouter({ mediaCodecs });
    return this.router;
  }

  addPeer(peerId, peer) {
    this.peers.set(peerId, peer);
  }

  removePeer(peerId) {
    this.peers.delete(peerId);
  }

  getPeer(peerId) {
    return this.peers.get(peerId);
  }

  close() {
    this.peers.clear();
    if (this.router) {
      this.router.close();
    }
  }
}

// Signaling namespace for general WebRTC
const signalingNamespace = io.of('/signaling');

signalingNamespace.on('connection', (socket) => {
  console.log(`📡 Signaling client connected: ${socket.id}`);

  socket.on('join-room', ({ roomId, userId }) => {
    socket.join(roomId);
    socket.userId = userId;
    socket.roomId = roomId;
    
    // Notify others in room
    socket.to(roomId).emit('user-joined', { userId, socketId: socket.id });
    
    // Send existing users to new user
    const users = [];
    signalingNamespace.adapter.rooms.get(roomId)?.forEach(id => {
      if (id !== socket.id) {
        const userSocket = signalingNamespace.sockets.get(id);
        if (userSocket?.userId) {
          users.push({ userId: userSocket.userId, socketId: id });
        }
      }
    });
    socket.emit('existing-users', users);
  });

  socket.on('offer', ({ to, offer }) => {
    signalingNamespace.to(to).emit('offer', {
      from: socket.id,
      offer
    });
  });

  socket.on('answer', ({ to, answer }) => {
    signalingNamespace.to(to).emit('answer', {
      from: socket.id,
      answer
    });
  });

  socket.on('ice-candidate', ({ to, candidate }) => {
    signalingNamespace.to(to).emit('ice-candidate', {
      from: socket.id,
      candidate
    });
  });

  socket.on('disconnect', () => {
    if (socket.roomId) {
      socket.to(socket.roomId).emit('user-left', {
        userId: socket.userId,
        socketId: socket.id
      });
    }
    console.log(`📡 Signaling client disconnected: ${socket.id}`);
  });
});

// MediaSoup namespace
const mediasoupNamespace = io.of('/mediasoup');

mediasoupNamespace.on('connection', async (socket) => {
  console.log(`🎥 MediaSoup client connected: ${socket.id}`);

  socket.on('createRoom', async ({ roomId }, callback) => {
    try {
      if (rooms.has(roomId)) {
        callback({ error: 'Room already exists' });
        return;
      }

      const room = new Room(roomId);
      await room.createRouter();
      rooms.set(roomId, room);

      callback({ success: true });
    } catch (error) {
      console.error('Error creating room:', error);
      callback({ error: error.message });
    }
  });

  socket.on('join', async ({ roomId, peerId }, callback) => {
    try {
      let room = rooms.get(roomId);
      if (!room) {
        room = new Room(roomId);
        await room.createRouter();
        rooms.set(roomId, room);
      }

      const rtpCapabilities = room.router.rtpCapabilities;
      socket.join(roomId);
      socket.roomId = roomId;
      socket.peerId = peerId;

      room.addPeer(peerId, {
        socket,
        transports: new Map(),
        producers: new Map(),
        consumers: new Map(),
      });

      callback({ rtpCapabilities });
    } catch (error) {
      console.error('Error joining room:', error);
      callback({ error: error.message });
    }
  });

  socket.on('createWebRtcTransport', async ({ producing }, callback) => {
    try {
      const room = rooms.get(socket.roomId);
      if (!room) {
        callback({ error: 'Room not found' });
        return;
      }

      const transport = await room.router.createWebRtcTransport({
        listenIps: [
          {
            ip: '0.0.0.0',
            announcedIp: process.env.PUBLIC_IP || '192.168.1.1', // Set your public IP
          }
        ],
        enableUdp: true,
        enableTcp: true,
        preferUdp: true,
      });

      const peer = room.getPeer(socket.peerId);
      if (peer) {
        peer.transports.set(transport.id, transport);
      }

      callback({
        params: {
          id: transport.id,
          iceParameters: transport.iceParameters,
          iceCandidates: transport.iceCandidates,
          dtlsParameters: transport.dtlsParameters,
        },
      });
    } catch (error) {
      console.error('Error creating transport:', error);
      callback({ error: error.message });
    }
  });

  socket.on('connectTransport', async ({ transportId, dtlsParameters }, callback) => {
    try {
      const room = rooms.get(socket.roomId);
      const peer = room?.getPeer(socket.peerId);
      const transport = peer?.transports.get(transportId);

      if (!transport) {
        callback({ error: 'Transport not found' });
        return;
      }

      await transport.connect({ dtlsParameters });
      callback({ success: true });
    } catch (error) {
      console.error('Error connecting transport:', error);
      callback({ error: error.message });
    }
  });

  socket.on('produce', async ({ transportId, kind, rtpParameters }, callback) => {
    try {
      const room = rooms.get(socket.roomId);
      const peer = room?.getPeer(socket.peerId);
      const transport = peer?.transports.get(transportId);

      if (!transport) {
        callback({ error: 'Transport not found' });
        return;
      }

      const producer = await transport.produce({
        kind,
        rtpParameters,
      });

      peer.producers.set(producer.id, producer);

      // Notify other peers
      socket.to(socket.roomId).emit('newProducer', {
        producerId: producer.id,
        peerId: socket.peerId,
        kind: producer.kind,
      });

      callback({ id: producer.id });
    } catch (error) {
      console.error('Error producing:', error);
      callback({ error: error.message });
    }
  });

  socket.on('disconnect', () => {
    console.log(`🎥 MediaSoup client disconnected: ${socket.id}`);
    
    if (socket.roomId && socket.peerId) {
      const room = rooms.get(socket.roomId);
      if (room) {
        const peer = room.getPeer(socket.peerId);
        if (peer) {
          // Close all transports
          peer.transports.forEach(transport => transport.close());
          room.removePeer(socket.peerId);
          
          // Notify others
          socket.to(socket.roomId).emit('peerLeft', { peerId: socket.peerId });
          
          // Clean up empty rooms
          if (room.peers.size === 0) {
            room.close();
            rooms.delete(socket.roomId);
          }
        }
      }
    }
  });
});

// Health check endpoints
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok',
    services: {
      signaling: 'active',
      mediasoup: 'active',
      worker: worker ? 'running' : 'not started'
    }
  });
});

// Start server
const PORT = process.env.PORT || 3000;

(async () => {
  try {
    await createWorker();
    
    server.listen(PORT, () => {
      console.log(`🚀 Unified WebRTC Server running on port ${PORT}`);
      console.log(`📡 Signaling namespace: /signaling`);
      console.log(`🎥 MediaSoup namespace: /mediasoup`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
})();
