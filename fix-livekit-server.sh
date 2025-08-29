#!/bin/bash

# Fix LiveKit server configuration with correct API key
SERVER_IP="172.236.109.9"
SERVER_USER="root"

echo "🔧 Fixing LiveKit server configuration..."
echo "📡 Server: $SERVER_IP"

# Create corrected LiveKit configuration
cat > livekit-fix.yaml << EOF
# LiveKit Production Configuration for Arena - FIXED
port: 7880
bind_addresses: [""]

rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
  stun_servers:
    - "stun:stun.l.google.com:19302"

# FIXED: Corrected API keys matching Flutter app
keys:
  LKAPI1234567890: 7e9fb42854e466daf92dabbc9b88e98f7811486704338e062d30815a592de45d

room:
  max_participants: 100
  empty_timeout: 10m
  departure_timeout: 20s
  enable_stats: true

# Production logging
log_level: debug

# Security settings for production
development: false

# WebRTC configuration for production
webrtc:
  ice_server:
    - urls:
        - "stun:stun.l.google.com:19302"

EOF

echo "📤 Uploading fixed configuration to server..."
scp livekit-fix.yaml $SERVER_USER@$SERVER_IP:/opt/livekit-arena/livekit-production.yaml

echo "🔄 Restarting LiveKit server with fixed configuration..."
ssh $SERVER_USER@$SERVER_IP "cd /opt/livekit-arena && docker-compose down && docker-compose up -d"

echo "⏳ Waiting for server to restart..."
sleep 10

echo "🔍 Checking server status..."
ssh $SERVER_USER@$SERVER_IP "cd /opt/livekit-arena && docker-compose ps && docker-compose logs --tail=20"

echo "✅ LiveKit server configuration fixed!"
echo "🔗 Server URL: ws://$SERVER_IP:7880"
echo "🔑 API Key: LKAPI1234567890"

# Clean up local file
rm livekit-fix.yaml

echo ""
echo "🧪 Test the fix by:"
echo "1. Running the Arena app"
echo "2. Joining an Open Discussion room"
echo "3. Checking if audio connection works"