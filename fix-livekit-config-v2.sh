#!/bin/bash

# Fix LiveKit server configuration with v1.5.2 compatible format
SERVER_IP="172.236.109.9"
SERVER_USER="root"

echo "🔧 Creating LiveKit v1.5.2 compatible configuration..."
echo "📡 Server: $SERVER_IP"

# Create v1.5.2 compatible LiveKit configuration
cat > livekit-v152-fix.yaml << EOF
# LiveKit Production Configuration for Arena - v1.5.2 Compatible
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
  empty_timeout: 600  # 10 minutes in seconds
  
# Production logging
log_level: debug

# Security settings for production
development: false

EOF

echo "📤 Uploading v1.5.2 compatible configuration to server..."
scp livekit-v152-fix.yaml $SERVER_USER@$SERVER_IP:/opt/livekit-arena/livekit-production.yaml

echo "🔄 Restarting LiveKit server with fixed configuration..."
ssh $SERVER_USER@$SERVER_IP "cd /opt/livekit-arena && docker-compose down && docker-compose up -d"

echo "⏳ Waiting for server to restart..."
sleep 15

echo "🔍 Checking server status..."
ssh $SERVER_USER@$SERVER_IP "cd /opt/livekit-arena && docker-compose ps && echo '--- LOGS ---' && docker-compose logs --tail=30"

echo "✅ LiveKit server configuration fixed with v1.5.2 compatibility!"
echo "🔗 Server URL: ws://$SERVER_IP:7880"
echo "🔑 API Key: LKAPI1234567890"

# Clean up local file
rm livekit-v152-fix.yaml

echo ""
echo "🧪 If there are still errors, check the server logs:"
echo "ssh $SERVER_USER@$SERVER_IP 'cd /opt/livekit-arena && docker-compose logs -f'"