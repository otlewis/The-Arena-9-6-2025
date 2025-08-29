#!/bin/bash

# LiveKit SSL/TLS Configuration Script
# This script configures SSL/TLS for LiveKit server to enable secure WebSocket connections (wss://)

set -e  # Exit on any error

echo "🔒 LiveKit SSL/TLS Configuration Script"
echo "======================================="

# Configuration variables
LIVEKIT_DIR="/opt/livekit"
CONFIG_FILE="$LIVEKIT_DIR/livekit.yaml"
DOMAIN="172.236.109.9"  # Using IP address - in production, use a domain name
CERT_DIR="/etc/livekit/certs"
SSL_PORT=7881  # Secure port for HTTPS/WSS
HTTP_PORT=7880  # Keep HTTP port for backward compatibility

echo "📋 Configuration Summary:"
echo "  • Domain/IP: $DOMAIN"
echo "  • HTTP Port: $HTTP_PORT"
echo "  • HTTPS/WSS Port: $SSL_PORT"
echo "  • Certificate Directory: $CERT_DIR"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Create certificate directory
echo "📁 Creating certificate directory..."
mkdir -p "$CERT_DIR"

# Option 1: Self-signed certificate (for testing/development)
echo "🔑 Generating self-signed SSL certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$CERT_DIR/key.pem" \
    -out "$CERT_DIR/cert.pem" \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

# Set appropriate permissions
chmod 600 "$CERT_DIR/key.pem"
chmod 644 "$CERT_DIR/cert.pem"

echo "✅ SSL certificate generated successfully"

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
    echo "💾 Backing up existing LiveKit configuration..."
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Create SSL-enabled LiveKit configuration
echo "📝 Creating SSL-enabled LiveKit configuration..."
cat > "$CONFIG_FILE" << EOF
# LiveKit Server Configuration with SSL/TLS Support
# Generated on $(date)

# Server binding configuration
port: $HTTP_PORT          # HTTP port (for API calls)
bind_addresses: ["0.0.0.0"]

# TLS Configuration for Secure WebSocket (WSS)
tls:
  cert_file: $CERT_DIR/cert.pem
  key_file: $CERT_DIR/key.pem
  port: $SSL_PORT          # HTTPS/WSS port

# API Keys (same as before)
keys:
  LKAPI1234567890: 7e9fb42854e466daf92dabbc9b88e98f7811486704338e062d30815a592de45d

# WebRTC Configuration
webrtc:
  # ICE servers for WebRTC connectivity
  ice_servers:
    - urls: ["stun:stun.l.google.com:19302"]
  
  # Port range for UDP connections
  port_range_start: 50000
  port_range_end: 60000
  
  # Use external IP for ICE candidates
  use_external_ip: true

# Room settings
room:
  # Auto-create rooms when participants join
  auto_create: true
  
  # Empty timeout (cleanup empty rooms)
  empty_timeout: 300s
  
  # Departure timeout (remove disconnected participants)
  departure_timeout: 20s

# Redis configuration (optional, for clustering)
# redis:
#   address: localhost:6379

# Logging configuration
log_level: info
log_file: /var/log/livekit/livekit.log

# Development settings
development: false
EOF

echo "✅ LiveKit configuration created with SSL/TLS support"

# Create systemd service file
echo "🔧 Creating systemd service..."
cat > /etc/systemd/system/livekit.service << EOF
[Unit]
Description=LiveKit Server
After=network.target

[Service]
Type=simple
User=livekit
Group=livekit
ExecStart=/usr/local/bin/livekit-server --config $CONFIG_FILE
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create livekit user if it doesn't exist
if ! id "livekit" &>/dev/null; then
    echo "👤 Creating livekit user..."
    useradd -r -s /bin/false livekit
fi

# Set ownership and permissions
echo "🔒 Setting permissions..."
mkdir -p /var/log/livekit
chown -R livekit:livekit "$LIVEKIT_DIR"
chown -R livekit:livekit "$CERT_DIR"
chown -R livekit:livekit /var/log/livekit

# Configure firewall (UFW)
echo "🔥 Configuring firewall..."
if command -v ufw >/dev/null 2>&1; then
    ufw allow $HTTP_PORT/tcp
    ufw allow $SSL_PORT/tcp
    ufw allow 50000:60000/udp  # WebRTC UDP port range
    echo "✅ Firewall rules added"
else
    echo "⚠️ UFW not found - configure firewall manually:"
    echo "  • Allow TCP $HTTP_PORT (HTTP)"
    echo "  • Allow TCP $SSL_PORT (HTTPS/WSS)"
    echo "  • Allow UDP 50000-60000 (WebRTC)"
fi

# Reload systemd and restart LiveKit
echo "🔄 Restarting LiveKit service..."
systemctl daemon-reload
systemctl enable livekit
systemctl restart livekit

# Wait for service to start
sleep 3

# Check service status
echo "📊 Checking LiveKit service status..."
if systemctl is-active --quiet livekit; then
    echo "✅ LiveKit service is running"
else
    echo "❌ LiveKit service failed to start"
    echo "📝 Check logs with: journalctl -u livekit -f"
fi

# Test SSL certificate
echo "🧪 Testing SSL certificate..."
openssl x509 -in "$CERT_DIR/cert.pem" -text -noout | grep "Subject:"

echo ""
echo "🎉 SSL/TLS Configuration Complete!"
echo "=================================="
echo ""
echo "📋 Configuration Summary:"
echo "  • HTTP/API Endpoint: http://$DOMAIN:$HTTP_PORT"
echo "  • WebSocket Endpoint: ws://$DOMAIN:$HTTP_PORT"
echo "  • Secure WebSocket: wss://$DOMAIN:$SSL_PORT"
echo "  • Certificate: $CERT_DIR/cert.pem"
echo "  • Private Key: $CERT_DIR/key.pem"
echo ""
echo "📱 Update Flutter app configuration:"
echo "  • Change 'ws://172.236.109.9:7880' to 'wss://172.236.109.9:7881'"
echo ""
echo "🔍 Monitoring:"
echo "  • Service status: systemctl status livekit"
echo "  • View logs: journalctl -u livekit -f"
echo "  • Test SSL: openssl s_client -connect $DOMAIN:$SSL_PORT"
echo ""
echo "⚠️ Important Notes:"
echo "  • Self-signed certificate will show warnings in browsers"
echo "  • For production, use a proper SSL certificate from Let's Encrypt or CA"
echo "  • iOS will require certificate trust or ATS exception"
EOF