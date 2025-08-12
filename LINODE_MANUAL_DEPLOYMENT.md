# Manual MediaSoup Server Deployment to Linode

Since SSH deployment failed, here's the complete manual deployment guide.

## Step 1: Upload Server Files

You need to upload these 2 files to your Linode server at `172.236.109.9`:

### File 1: mediasoup-production-server.cjs
- **Source**: `/Users/otislewis/arena2/mediasoup-production-server.cjs`
- **Destination**: `/opt/arena-mediasoup/mediasoup-production-server.cjs`

### File 2: package.json  
- **Source**: `/Users/otislewis/arena2/package.json`
- **Destination**: `/opt/arena-mediasoup/package.json`

### Upload Methods

**Method 1: SCP (if SSH keys work)**
```bash
scp /Users/otislewis/arena2/mediasoup-production-server.cjs root@172.236.109.9:/opt/arena-mediasoup/
scp /Users/otislewis/arena2/package.json root@172.236.109.9:/opt/arena-mediasoup/
```

**Method 2: File Transfer via Panel**
- Use your Linode control panel's file manager
- Or use FTP/SFTP client like FileZilla

## Step 2: SSH into Your Server

Connect to your Linode server:
```bash
ssh root@172.236.109.9
# OR
ssh root@jitsi.dialecticlabs.com
```

## Step 3: Server Setup Commands

Run these commands **in order** on your Linode server:

### 3.1 Create Directory and Install Node.js
```bash
# Create deployment directory
mkdir -p /opt/arena-mediasoup
cd /opt/arena-mediasoup

# Install Node.js 18 LTS (if not already installed)
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# Verify installation
node --version  # Should show v18.x.x or higher
npm --version
```

### 3.2 Install Dependencies
```bash
# Navigate to app directory
cd /opt/arena-mediasoup

# Install npm dependencies
npm install --production

# If MediaSoup fails to install, run:
apt-get update
apt-get install -y python3 python3-pip build-essential node-gyp
npm install --production
```

### 3.3 Configure Firewall Ports
```bash
# MediaSoup signaling port (HTTP/WebSocket)
ufw allow 3005/tcp

# WebRTC media ports (UDP)
ufw allow 10000:10100/udp

# Standard web ports (if not already open)
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall if not already enabled
ufw --force enable

# Check firewall status
ufw status
```

### 3.4 Install PM2 Process Manager
```bash
# Install PM2 globally
npm install -g pm2

# Verify PM2 installation
pm2 --version
```

### 3.5 Create PM2 Configuration
Create `/opt/arena-mediasoup/ecosystem.config.js`:
```bash
cat > /opt/arena-mediasoup/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'arena-mediasoup',
    script: 'mediasoup-production-server.cjs',
    cwd: '/opt/arena-mediasoup',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3005,
      ANNOUNCED_IP: '172.236.109.9'
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
```

### 3.6 Create Log Directory and Set Permissions
```bash
# Create logs directory
mkdir -p /opt/arena-mediasoup/logs

# Set proper permissions
chown -R root:root /opt/arena-mediasoup
chmod +x /opt/arena-mediasoup/mediasoup-production-server.cjs
```

### 3.7 Start MediaSoup Server
```bash
# Navigate to app directory
cd /opt/arena-mediasoup

# Stop any existing processes
pm2 stop arena-mediasoup 2>/dev/null || true
pm2 delete arena-mediasoup 2>/dev/null || true
pkill -f mediasoup-production-server.cjs 2>/dev/null || true

# Start with PM2
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
# Follow the instructions PM2 shows you

# Show PM2 status
pm2 status
```

## Step 4: Test the Deployment

### 4.1 Check Server Health
```bash
# Test locally on server
curl http://localhost:3005

# Should return something like:
# {"message":"Arena MediaSoup SFU Server","status":"running","workers":4,"rooms":0,"timestamp":"..."}
```

### 4.2 Check from Your Local Machine
```bash
# Test from your local machine
curl http://172.236.109.9:3005

# Should return the same JSON response
```

### 4.3 View Server Logs
```bash
# View real-time logs
pm2 logs arena-mediasoup

# View recent logs
pm2 logs arena-mediasoup --lines 20
```

## Step 5: Update Flutter App

Once the server is running, update your Flutter app:

### 5.1 Update Server URL
In `/Users/otislewis/arena2/lib/services/simple_mediasoup_service.dart`, change:
```dart
// FROM:
'192.168.4.94:3005'

// TO:
'172.236.109.9:3005'
```

### 5.2 Test Connection
1. Run your Flutter app
2. Go to debug video setup screen
3. Try "Video P2P" button
4. Check connection logs

## Troubleshooting

### Server Won't Start
```bash
# Check detailed logs
journalctl -f | grep mediasoup

# Check if port is already in use
netstat -tulpn | grep 3005

# Kill conflicting processes
pkill -f mediasoup
pm2 kill
```

### MediaSoup Installation Fails
```bash
# Install all build dependencies
apt-get update
apt-get install -y python3 python3-pip build-essential node-gyp make g++

# Clear npm cache
npm cache clean --force

# Try installing MediaSoup alone
npm install mediasoup --production
```

### Connection Issues
```bash
# Check firewall
ufw status

# Check if server is listening
netstat -tulpn | grep 3005

# Test local connection
curl -v http://localhost:3005
```

## Success Checklist

- [ ] ✅ Files uploaded to `/opt/arena-mediasoup/`
- [ ] ✅ Node.js 18+ installed (`node --version`)
- [ ] ✅ Dependencies installed (`npm install` succeeded)
- [ ] ✅ Firewall ports open (3005/tcp, 10000:10100/udp)
- [ ] ✅ PM2 installed (`pm2 --version`)
- [ ] ✅ Server started (`pm2 status` shows running)
- [ ] ✅ Health check works (`curl http://localhost:3005`)
- [ ] ✅ External access works (`curl http://172.236.109.9:3005`)
- [ ] ✅ Flutter app connects successfully

## Management Commands

```bash
# Check server status
pm2 status

# View logs
pm2 logs arena-mediasoup

# Restart server
pm2 restart arena-mediasoup

# Stop server
pm2 stop arena-mediasoup

# Start server
pm2 start arena-mediasoup

# Monitor resources
pm2 monit
```

Once you complete these steps, your MediaSoup server will be running on your Linode server and ready for video testing!