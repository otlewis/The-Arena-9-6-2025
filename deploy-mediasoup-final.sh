#!/bin/bash

# Deploy MediaSoup Server to Linode via SSH
# Usage: ./deploy-mediasoup-final.sh [server-address]

set -e

# Configuration - UPDATE THESE VALUES
SERVER=${1:-"jitsi.dialecticlabs.com"}  # Your Linode server address
USER="root"  # SSH user
REMOTE_DIR="/opt/arena-mediasoup"
LOCAL_DIR="/Users/otislewis/arena2"
PORT="3005"

echo "=€ Deploying MediaSoup server to $SERVER"
echo "=Á Remote directory: $REMOTE_DIR"
echo "= Port: $PORT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if server address needs to be updated
if [ "$SERVER" = "jitsi.dialecticlabs.com" ]; then
    print_warning "Using default server address: $SERVER"
    echo "To use a different server, run: $0 your-server.com"
    echo ""
fi

# Test SSH connection
print_status "Testing SSH connection to $SERVER..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes $USER@$SERVER exit 2>/dev/null; then
    print_error "SSH connection failed. Please check:"
    echo "  - Server address: $SERVER"
    echo "  - SSH key is configured"
    echo "  - User: $USER"
    exit 1
fi
print_success "SSH connection successful"

# Stop existing service first
print_status "Stopping existing MediaSoup service..."
ssh $USER@$SERVER "
    pm2 stop arena-mediasoup 2>/dev/null || true
    pm2 delete arena-mediasoup 2>/dev/null || true
    pkill -f mediasoup-production-server.cjs 2>/dev/null || true
    sleep 2
" || true

# Create remote directory
print_status "Creating remote directory..."
ssh $USER@$SERVER "mkdir -p $REMOTE_DIR/logs"

# Copy server files
print_status "Copying MediaSoup server files..."
scp $LOCAL_DIR/mediasoup-production-server.cjs $USER@$SERVER:$REMOTE_DIR/
scp $LOCAL_DIR/package.json $USER@$SERVER:$REMOTE_DIR/
print_success "Server files copied"

# Install dependencies on remote server
print_status "Installing Node.js and dependencies..."
ssh $USER@$SERVER << 'EOF'
# Install Node.js 18 LTS if not present
if ! command -v node &> /dev/null || [ "$(node -v | cut -d'.' -f1 | sed 's/v//')" -lt "18" ]; then
    echo "Installing Node.js 18 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi

# Install PM2 globally
if ! command -v pm2 &> /dev/null; then
    echo "Installing PM2..."
    npm install -g pm2
fi

# Navigate to app directory and install dependencies
cd /opt/arena-mediasoup
echo "Installing npm dependencies..."
npm install --production

echo " Node.js version: $(node -v)"
echo " NPM version: $(npm -v)"
echo " PM2 version: $(pm2 -v)"
EOF

print_success "Dependencies installed"

# Create PM2 ecosystem configuration
print_status "Creating PM2 configuration..."
cat > /tmp/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'arena-mediasoup',
    script: 'mediasoup-production-server.cjs',
    cwd: '/opt/arena-mediasoup',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: $PORT,
      ANNOUNCED_IP: '$SERVER'
    },
    log_file: '/opt/arena-mediasoup/logs/combined.log',
    out_file: '/opt/arena-mediasoup/logs/out.log',
    error_file: '/opt/arena-mediasoup/logs/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    max_restarts: 10,
    min_uptime: '10s',
    restart_delay: 4000,
    watch: false,
    ignore_watch: ['logs', 'node_modules'],
    max_memory_restart: '500M'
  }]
};
EOF

scp /tmp/ecosystem.config.js $USER@$SERVER:$REMOTE_DIR/
rm /tmp/ecosystem.config.js

# Configure server environment
print_status "Configuring server environment..."
ssh $USER@$SERVER << EOF
cd $REMOTE_DIR

# Configure firewall for MediaSoup
echo "Configuring firewall..."
ufw allow $PORT/tcp  # MediaSoup signaling
ufw allow 10000:10100/udp  # WebRTC media ports
ufw allow 80/tcp     # HTTP
ufw allow 443/tcp    # HTTPS
ufw --force enable

# Set proper permissions
chown -R root:root $REMOTE_DIR
chmod +x mediasoup-production-server.cjs

# Check system resources
echo "System Info:"
echo "Memory: \$(free -h | grep Mem | awk '{print \$2}')"
echo "CPU: \$(nproc) cores"
echo "Disk: \$(df -h / | tail -1 | awk '{print \$4}') available"
EOF

print_success "Server environment configured"

# Start the MediaSoup service
print_status "Starting MediaSoup server..."
ssh $USER@$SERVER << 'EOF'
cd /opt/arena-mediasoup

# Start with PM2
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Setup PM2 startup script
pm2 startup --silent

# Show status
echo ""
echo "=Ê PM2 Status:"
pm2 status

echo ""
echo "=Ë Recent logs:"
pm2 logs arena-mediasoup --lines 5 --nostream
EOF

print_success "MediaSoup server started!"

# Test the deployment
print_status "Testing deployment..."
sleep 5

# Test HTTP connection
if curl -f -s --connect-timeout 10 http://$SERVER:$PORT > /dev/null; then
    print_success " MediaSoup server is responding on http://$SERVER:$PORT"
else
    print_warning "   Server may still be starting. Checking logs..."
    ssh $USER@$SERVER "pm2 logs arena-mediasoup --lines 10 --nostream"
fi

# Update Flutter app configuration
print_status "Updating Flutter app configuration..."
if [ -f "$LOCAL_DIR/lib/services/simple_mediasoup_service.dart" ]; then
    # Create backup
    cp "$LOCAL_DIR/lib/services/simple_mediasoup_service.dart" "$LOCAL_DIR/lib/services/simple_mediasoup_service.dart.backup"
    
    # Update server URL in Flutter app
    sed -i.bak "s/192\.168\.4\.94:3005/$SERVER:$PORT/g" "$LOCAL_DIR/lib/services/simple_mediasoup_service.dart"
    
    print_success "Flutter app updated to use $SERVER:$PORT"
else
    print_warning "Flutter service file not found - update manually"
fi

echo ""
print_success "<‰ Deployment complete!"
echo ""
echo "=Ë Summary:"
echo "  " Server: $SERVER:$PORT"
echo "  " Status: $(curl -s -o /dev/null -w '%{http_code}' http://$SERVER:$PORT 2>/dev/null || echo 'Connection failed')"
echo "  " PM2 Process: arena-mediasoup"
echo ""
echo "=Ê Management commands:"
echo "  " Check status: ssh $USER@$SERVER 'pm2 status'"
echo "  " View logs: ssh $USER@$SERVER 'pm2 logs arena-mediasoup'"
echo "  " Restart: ssh $USER@$SERVER 'pm2 restart arena-mediasoup'"
echo "  " Stop: ssh $USER@$SERVER 'pm2 stop arena-mediasoup'"
echo ""
echo "=€ Next steps:"
echo "  1. Test Flutter app with new server"
echo "  2. Monitor logs for any issues"
echo "  3. Configure SSL certificate (optional)"
echo ""

print_warning "If Socket.IO issues persist, we can implement WebSocket fallback"