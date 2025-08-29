#!/bin/bash

# LiveKit Production Deployment Script for Linode
# This script sets up LiveKit server on your Linode production server

set -e

echo "🚀 LiveKit Production Deployment for Arena"
echo "=========================================="

# Configuration
LINODE_SERVER="172.236.109.9"
LIVEKIT_VERSION="v1.5.2"
DOMAIN="your-domain.com"  # Replace with your actual domain
LIVEKIT_PORT="7880"
RTC_PORT="7881"

echo "📋 Deployment Configuration:"
echo "   Server: $LINODE_SERVER"
echo "   LiveKit Version: $LIVEKIT_VERSION"
echo "   WebSocket Port: $LIVEKIT_PORT"
echo "   RTC Port: $RTC_PORT"
echo ""

# Create deployment directory
echo "📁 Creating deployment files..."
mkdir -p livekit-production

# Create production LiveKit configuration
cat > livekit-production/livekit-production.yaml << EOF
# LiveKit Production Configuration for Arena
port: $LIVEKIT_PORT
bind_addresses: [""]

rtc:
  tcp_port: $RTC_PORT
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
  stun_servers:
    - "stun:stun.l.google.com:19302"

# Production API keys (same as development for consistency)
keys:
  LKAPI1234567890: 7e9fb42854e466daf92dabbc9b88e98f7811486704338e062d30815a592de45d

room:
  max_participants: 100
  empty_timeout: 10m
  departure_timeout: 20s
  enable_stats: true

# Production logging
log_level: info

# Security settings for production
development: false

# WebRTC configuration for production
webrtc:
  ice_server:
    - urls:
        - "stun:stun.l.google.com:19302"

# Optional: Enable recording and ingress for production features
# recording:
#   enabled: true
#   s3:
#     access_key: YOUR_S3_ACCESS_KEY
#     secret: YOUR_S3_SECRET
#     region: us-east-1
#     bucket: arena-recordings

EOF

# Create Docker Compose file for production
cat > livekit-production/docker-compose.yml << EOF
version: '3.8'
services:
  livekit:
    image: livekit/livekit-server:$LIVEKIT_VERSION
    container_name: livekit-arena-production
    ports:
      - "$LIVEKIT_PORT:$LIVEKIT_PORT"
      - "$RTC_PORT:$RTC_PORT"
      - "50000-50100:50000-50100/udp"
    volumes:
      - ./livekit-production.yaml:/etc/livekit.yaml:ro
    command: --config /etc/livekit.yaml
    restart: unless-stopped
    environment:
      - LIVEKIT_CONFIG=/etc/livekit.yaml
    networks:
      - livekit-network

networks:
  livekit-network:
    driver: bridge
EOF

# Create deployment script for remote server
cat > livekit-production/deploy-to-server.sh << 'EOF'
#!/bin/bash

# This script runs on the Linode server

set -e

echo "📦 Installing Docker and Docker Compose..."

# Update system
sudo apt update

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker installed"
else
    echo "✅ Docker already installed"
fi

# Install Docker Compose if not already installed
if ! command -v docker-compose &> /dev/null; then
    echo "🐳 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed"
else
    echo "✅ Docker Compose already installed"
fi

echo "🔥 Setting up firewall rules..."
# Open required ports
sudo ufw allow 7880/tcp  # LiveKit WebSocket
sudo ufw allow 7881/tcp  # LiveKit RTC TCP
sudo ufw allow 50000:50100/udp  # LiveKit RTC UDP range

echo "🚀 Starting LiveKit server..."
# Stop any existing containers
docker-compose down 2>/dev/null || true

# Start LiveKit
docker-compose up -d

echo "⏳ Waiting for LiveKit to start..."
sleep 10

echo "🔍 Checking LiveKit status..."
docker-compose ps
docker-compose logs --tail=20

echo ""
echo "🎉 LiveKit deployment complete!"
echo "📡 Server should be running at: ws://$HOSTNAME:7880"
echo "🔍 Check logs: docker-compose logs -f"
echo "🛑 Stop server: docker-compose down"

EOF

chmod +x livekit-production/deploy-to-server.sh

# Create sync script to copy files to server
cat > livekit-production/sync-to-linode.sh << EOF
#!/bin/bash

echo "📤 Syncing LiveKit configuration to Linode server..."

# Copy files to server
scp -r . root@$LINODE_SERVER:/opt/livekit-arena/

echo "🚀 Running deployment on server..."
ssh root@$LINODE_SERVER "cd /opt/livekit-arena && ./deploy-to-server.sh"

echo "✅ LiveKit deployed to production server!"
echo "🔗 Production LiveKit URL: ws://$LINODE_SERVER:7880"

EOF

chmod +x livekit-production/sync-to-linode.sh

echo "✅ LiveKit production deployment files created!"
echo ""
echo "📋 Next Steps:"
echo "1. Review the configuration in livekit-production/"
echo "2. Update domain/server settings if needed"
echo "3. Run: cd livekit-production && ./sync-to-linode.sh"
echo ""
echo "🔧 Files created:"
echo "   - livekit-production/livekit-production.yaml (LiveKit config)"
echo "   - livekit-production/docker-compose.yml (Docker setup)"
echo "   - livekit-production/deploy-to-server.sh (Server deployment)"
echo "   - livekit-production/sync-to-linode.sh (Upload to server)"