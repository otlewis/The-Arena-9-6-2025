#!/bin/bash

# IONOS Audio Clip Server Setup Script
# Server IP: 50.21.187.76
# This script sets up the audio clip storage server on your IONOS VPS

echo "========================================="
echo "Arena Audio Clip Server Setup for IONOS"
echo "Server IP: 50.21.187.76"
echo "========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
SERVER_IP="50.21.187.76"
DOMAIN="audio.arena-app.com"  # Change this to your actual domain
NODE_PORT="3001"
APP_DIR="/opt/arena-audio-clips"

echo -e "${YELLOW}This script will set up the audio clip server on your IONOS VPS.${NC}"
echo "Please make sure you have:"
echo "1. SSH access to your server (root@$SERVER_IP)"
echo "2. A domain pointing to $SERVER_IP (optional but recommended)"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Function to execute commands on remote server
execute_remote() {
    ssh root@$SERVER_IP "$1"
}

echo -e "${GREEN}Step 1: Updating system packages...${NC}"
execute_remote "apt update && apt upgrade -y"

echo -e "${GREEN}Step 2: Installing required packages...${NC}"
execute_remote "apt install -y nodejs npm nginx certbot python3-certbot-nginx git"

echo -e "${GREEN}Step 3: Creating application directory...${NC}"
execute_remote "mkdir -p $APP_DIR && cd $APP_DIR"

echo -e "${GREEN}Step 4: Creating Node.js server file...${NC}"
# Create the server.js file
cat << 'EOF' | ssh root@$SERVER_IP "cat > $APP_DIR/server.js"
const express = require('express');
const multer = require('multer');
const fs = require('fs-extra');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3001;

// Security middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

// Create uploads directory
const UPLOADS_DIR = path.join(__dirname, 'audio-clips');
fs.ensureDirSync(UPLOADS_DIR);

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, UPLOADS_DIR);
  },
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    const roomId = req.body.room_id || 'unknown';
    const userId = req.body.user_id || 'unknown';
    const extension = path.extname(file.originalname) || '.opus';
    cb(null, `clip_${roomId}_${userId}_${timestamp}${extension}`);
  }
});

const upload = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    // Accept audio files
    if (file.mimetype.startsWith('audio/') || file.mimetype === 'application/octet-stream') {
      cb(null, true);
    } else {
      cb(new Error('Only audio files are allowed'));
    }
  }
});

// Audio clip upload endpoint
app.post('/api/audio-clips', upload.single('audio_clip'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file uploaded' });
    }

    const { room_id, user_id, clip_title, duration, created_at } = req.body;

    // Validate required fields
    if (!room_id || !user_id || !clip_title) {
      return res.status(400).json({ 
        error: 'Missing required fields: room_id, user_id, clip_title' 
      });
    }

    // Use IP address if no domain is configured
    const host = req.get('host') || '50.21.187.76:3001';
    const protocol = req.secure ? 'https' : 'http';
    const clipUrl = `${protocol}://${host}/clips/${req.file.filename}`;

    // Log successful upload
    console.log(`Audio clip uploaded: ${req.file.filename} for room ${room_id}`);

    res.json({
      success: true,
      clip_url: clipUrl,
      filename: req.file.filename,
      file_size: req.file.size,
      duration: duration || 0,
      uploaded_at: new Date().toISOString()
    });

  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ error: 'Upload failed: ' + error.message });
  }
});

// Serve audio files
app.use('/clips', express.static(UPLOADS_DIR, {
  setHeaders: (res, path) => {
    res.setHeader('Content-Type', 'audio/opus');
    res.setHeader('Cache-Control', 'public, max-age=31536000'); // 1 year cache
    res.setHeader('Access-Control-Allow-Origin', '*');
  }
}));

// List all clips endpoint (for testing/debugging)
app.get('/api/audio-clips', (req, res) => {
  try {
    const files = fs.readdirSync(UPLOADS_DIR);
    const clips = files.map(file => ({
      filename: file,
      url: `${req.protocol}://${req.get('host')}/clips/${file}`,
      size: fs.statSync(path.join(UPLOADS_DIR, file)).size,
      created: fs.statSync(path.join(UPLOADS_DIR, file)).mtime
    }));
    res.json({ clips, count: clips.length });
  } catch (error) {
    res.status(500).json({ error: 'Failed to list clips' });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    server: 'Arena Audio Clip Server',
    uptime: process.uptime()
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'Arena Audio Clip Server',
    endpoints: {
      upload: 'POST /api/audio-clips',
      list: 'GET /api/audio-clips',
      health: 'GET /health',
      clips: 'GET /clips/:filename'
    }
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Arena Audio Clip Server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});
EOF

echo -e "${GREEN}Step 5: Creating package.json...${NC}"
cat << 'EOF' | ssh root@$SERVER_IP "cat > $APP_DIR/package.json"
{
  "name": "arena-audio-clips",
  "version": "1.0.0",
  "description": "Audio clip storage server for Arena app",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "multer": "^1.4.5-lts.1",
    "fs-extra": "^11.1.1",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "express-rate-limit": "^6.10.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

echo -e "${GREEN}Step 6: Installing Node.js dependencies...${NC}"
execute_remote "cd $APP_DIR && npm install"

echo -e "${GREEN}Step 7: Installing PM2 process manager...${NC}"
execute_remote "npm install -g pm2"

echo -e "${GREEN}Step 8: Starting the server with PM2...${NC}"
execute_remote "cd $APP_DIR && pm2 stop arena-audio-clips 2>/dev/null; pm2 delete arena-audio-clips 2>/dev/null; pm2 start server.js --name arena-audio-clips"
execute_remote "pm2 startup systemd -u root --hp /root"
execute_remote "pm2 save"

echo -e "${GREEN}Step 9: Configuring Nginx...${NC}"
# Create Nginx configuration
cat << EOF | ssh root@$SERVER_IP "cat > /etc/nginx/sites-available/arena-audio-clips"
server {
    listen 80;
    server_name $SERVER_IP;
    
    client_max_body_size 10M;
    
    location / {
        proxy_pass http://localhost:$NODE_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300s;
    }
}
EOF

echo -e "${GREEN}Step 10: Enabling Nginx site...${NC}"
execute_remote "ln -sf /etc/nginx/sites-available/arena-audio-clips /etc/nginx/sites-enabled/"
execute_remote "nginx -t && systemctl restart nginx"

echo -e "${GREEN}Step 11: Setting up firewall...${NC}"
execute_remote "ufw allow 22/tcp"
execute_remote "ufw allow 80/tcp"
execute_remote "ufw allow 443/tcp"
execute_remote "ufw --force enable"

echo -e "${GREEN}Step 12: Creating test script...${NC}"
cat << 'EOF' | ssh root@$SERVER_IP "cat > $APP_DIR/test-server.sh"
#!/bin/bash
echo "Testing Arena Audio Clip Server..."
echo ""
echo "1. Health Check:"
curl -s http://localhost:3001/health | python3 -m json.tool
echo ""
echo "2. Server Info:"
curl -s http://localhost:3001/ | python3 -m json.tool
echo ""
echo "3. List Clips:"
curl -s http://localhost:3001/api/audio-clips | python3 -m json.tool
echo ""
echo "Server Logs:"
pm2 logs arena-audio-clips --lines 10 --nostream
EOF
execute_remote "chmod +x $APP_DIR/test-server.sh"

echo ""
echo "========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "========================================="
echo ""
echo "Server is now running at:"
echo -e "${YELLOW}http://$SERVER_IP${NC}"
echo ""
echo "Test endpoints:"
echo "  Health: http://$SERVER_IP/health"
echo "  Info: http://$SERVER_IP/"
echo "  Upload: POST http://$SERVER_IP/api/audio-clips"
echo ""
echo "To test the server:"
echo "  ssh root@$SERVER_IP"
echo "  cd $APP_DIR"
echo "  ./test-server.sh"
echo ""
echo "To view logs:"
echo "  ssh root@$SERVER_IP"
echo "  pm2 logs arena-audio-clips"
echo ""
echo "To monitor server:"
echo "  ssh root@$SERVER_IP"
echo "  pm2 monit"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update your Flutter app with the server URL:"
echo "   http://$SERVER_IP/api/audio-clips"
echo "2. (Optional) Configure a domain name for SSL"
echo "3. Test audio clip uploads from your app"