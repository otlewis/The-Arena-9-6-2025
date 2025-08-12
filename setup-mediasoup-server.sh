#!/bin/bash

# MediaSoup Server Setup Script for Linode Ubuntu
# Run this on your Linode server: 172.236.109.9

echo "🚀 Setting up MediaSoup server on Ubuntu..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18.x (required for MediaSoup)
echo "📦 Installing Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install build essentials for native modules
sudo apt-get install -y build-essential python3-dev

# Verify Node.js version
node_version=$(node --version)
echo "✅ Node.js version: $node_version"

# Create MediaSoup server directory
mkdir -p ~/mediasoup-server
cd ~/mediasoup-server

# Initialize npm project
cat > package.json << 'EOF'
{
  "name": "arena-mediasoup-server",
  "version": "1.0.0",
  "description": "MediaSoup server for Arena audio conferencing",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "mediasoup": "^3.13.24",
    "socket.io": "^4.7.5",
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "https": "^1.0.0",
    "fs": "^0.0.1-security"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  }
}
EOF

# Install dependencies
echo "📦 Installing MediaSoup dependencies..."
npm install

# Create MediaSoup server
cat > server.js << 'EOF'
const express = require('express');
const https = require('https');
const fs = require('fs');
const socketIo = require('socket.io');
const mediasoup = require('mediasoup');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// SSL certificates (you'll need to generate these)
const options = {
  key: fs.existsSync('./ssl/privkey.pem') ? fs.readFileSync('./ssl/privkey.pem') : null,
  cert: fs.existsSync('./ssl/fullchain.pem') ? fs.readFileSync('./ssl/fullchain.pem') : null
};

let server;
if (options.key && options.cert) {
  server = https.createServer(options, app);
  console.log('🔒 HTTPS server created with SSL certificates');
} else {
  server = require('http').createServer(app);
  console.log('⚠️  HTTP server created (SSL certificates not found)');
}

const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
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
    kind: 'audio',
    mimeType: 'audio/PCMU',
    clockRate: 8000,
    channels: 1,
  }
];

let worker;
let router;
const rooms = new Map();

// Initialize MediaSoup
async function initializeMediaSoup() {
  try {
    console.log('🎬 Initializing MediaSoup worker...');
    
    worker = await mediasoup.createWorker({
      rtcMinPort: 40000,
      rtcMaxPort: 49999,
    });

    worker.on('died', () => {
      console.error('❌ MediaSoup worker died, exiting...');
      process.exit(1);
    });

    console.log('✅ MediaSoup worker created');

    // Create router
    router = await worker.createRouter({ mediaCodecs });
    console.log('✅ MediaSoup router created');

  } catch (error) {
    console.error('❌ Failed to initialize MediaSoup:', error);
    process.exit(1);
  }
}

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`🔌 Client connected: ${socket.id}`);

  socket.on('join-room', async ({ roomId, userId, userName }) => {
    try {
      console.log(`👥 ${userName} (${userId}) joining room: ${roomId}`);
      
      socket.join(roomId);
      
      // Add to room participants
      if (!rooms.has(roomId)) {
        rooms.set(roomId, new Map());
      }
      
      const roomParticipants = rooms.get(roomId);
      roomParticipants.set(socket.id, {
        userId,
        userName,
        socketId: socket.id
      });

      // Send router RTP capabilities
      socket.emit('router-rtp-capabilities', {
        rtpCapabilities: router.rtpCapabilities
      });

      // Notify other participants
      socket.to(roomId).emit('participant-joined', {
        userId,
        userName,
        socketId: socket.id
      });

      console.log(`✅ ${userName} joined room ${roomId}`);

    } catch (error) {
      console.error('❌ Error joining room:', error);
      socket.emit('error', { message: error.message });
    }
  });

  socket.on('create-transport', async ({ roomId, direction }) => {
    try {
      const transport = await router.createWebRtcTransport({
        listenIps: [{ ip: '0.0.0.0', announcedIp: '172.236.109.9' }], // Your server IP
        enableUdp: true,
        enableTcp: true,
        preferUdp: true,
      });

      socket.emit('transport-created', {
        id: transport.id,
        iceParameters: transport.iceParameters,
        iceCandidates: transport.iceCandidates,
        dtlsParameters: transport.dtlsParameters,
      });

      // Store transport reference
      socket.transport = transport;

    } catch (error) {
      console.error('❌ Error creating transport:', error);
      socket.emit('error', { message: error.message });
    }
  });

  socket.on('produce', async ({ roomId, transportId, kind, rtpParameters }) => {
    try {
      const producer = await socket.transport.produce({
        kind,
        rtpParameters,
      });

      socket.emit('producer-created', { id: producer.id });

      // Notify other participants about new producer
      socket.to(roomId).emit('new-producer', {
        producerId: producer.id,
        socketId: socket.id
      });

    } catch (error) {
      console.error('❌ Error producing:', error);
      socket.emit('error', { message: error.message });
    }
  });

  socket.on('disconnect', () => {
    console.log(`🔌 Client disconnected: ${socket.id}`);
    
    // Clean up room participants
    rooms.forEach((participants, roomId) => {
      if (participants.has(socket.id)) {
        const participant = participants.get(socket.id);
        participants.delete(socket.id);
        
        // Notify others
        socket.to(roomId).emit('participant-left', {
          socketId: socket.id,
          userId: participant.userId
        });
        
        console.log(`👋 ${participant.userName} left room ${roomId}`);
      }
    });
  });
});

// Health check endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Arena MediaSoup Server',
    status: 'running',
    rooms: rooms.size,
    timestamp: new Date().toISOString()
  });
});

// Start server
const PORT = process.env.PORT || 4443;

async function startServer() {
  await initializeMediaSoup();
  
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 MediaSoup server running on port ${PORT}`);
    console.log(`📡 WebSocket endpoint: ${options.key ? 'wss' : 'ws'}://172.236.109.9:${PORT}`);
    console.log(`🔗 Health check: ${options.key ? 'https' : 'http'}://172.236.109.9:${PORT}/`);
  });
}

startServer().catch(console.error);
EOF

# Create SSL certificate generation script
cat > generate-ssl.sh << 'EOF'
#!/bin/bash

# Generate self-signed SSL certificates for MediaSoup server
# For production, use Let's Encrypt instead

mkdir -p ssl

# Generate private key
openssl genrsa -out ssl/privkey.pem 2048

# Generate certificate signing request
openssl req -new -key ssl/privkey.pem -out ssl/cert.csr -subj "/C=US/ST=State/L=City/O=Arena/OU=IT Department/CN=172.236.109.9"

# Generate self-signed certificate
openssl x509 -req -days 365 -in ssl/cert.csr -signkey ssl/privkey.pem -out ssl/fullchain.pem

echo "✅ SSL certificates generated in ssl/ directory"
echo "⚠️  These are self-signed certificates for testing only"
echo "🔒 For production, use Let's Encrypt or proper CA certificates"
EOF

chmod +x generate-ssl.sh

# Create systemd service file
sudo tee /etc/systemd/system/mediasoup-server.service > /dev/null << EOF
[Unit]
Description=Arena MediaSoup Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$HOME/mediasoup-server
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo "🔧 Created systemd service file"

# Create startup script
cat > start-server.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting MediaSoup server..."

# Generate SSL certificates if they don't exist
if [ ! -f ssl/privkey.pem ]; then
    echo "🔒 Generating SSL certificates..."
    ./generate-ssl.sh
fi

# Start the server
npm start
EOF

chmod +x start-server.sh

echo ""
echo "✅ MediaSoup server setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Generate SSL certificates: ./generate-ssl.sh"
echo "2. Start the server: ./start-server.sh"
echo "3. Or use systemd: sudo systemctl enable mediasoup-server && sudo systemctl start mediasoup-server"
echo ""
echo "🔗 Server will be available at:"
echo "   - HTTPS: https://172.236.109.9:4443"
echo "   - WebSocket: wss://172.236.109.9:4443"
echo ""
echo "🔥 Open firewall ports 4443 and 40000-49999:"
echo "   sudo ufw allow 4443"
echo "   sudo ufw allow 40000:49999/udp"
echo "   sudo ufw allow 40000:49999/tcp"