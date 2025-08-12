# MediaSoup Server Setup Guide

## Quick Start (Manual Setup)

### 1. SSH into your server
```bash
ssh root@jitsi.dialecticlabs.com
```

### 2. Create directory and navigate to it
```bash
mkdir -p /opt/arena-mediasoup
cd /opt/arena-mediasoup
```

### 3. Create the server files

First, create `package.json`:
```bash
cat > package.json << 'EOF'
{
  "name": "arena-mediasoup-server",
  "version": "1.0.0",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.21.2",
    "socket.io": "^4.8.1",
    "mediasoup": "^3.16.7",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5"
  }
}
EOF
```

### 4. Copy server files
You'll need to upload these files from your local `mediasoup-server` directory:
- `server.js`
- `config.js`

You can use SCP:
```bash
# From your local machine:
scp mediasoup-server/server.js root@jitsi.dialecticlabs.com:/opt/arena-mediasoup/
scp mediasoup-server/config.js root@jitsi.dialecticlabs.com:/opt/arena-mediasoup/
```

### 5. Create environment file
```bash
cat > .env << 'EOF'
NODE_ENV=production
ANNOUNCED_IP=172.236.109.9
EOF
```

### 6. Install dependencies
```bash
npm install
```

### 7. Test the server
```bash
node server.js
```

If it starts successfully, you should see:
```
🚀 Arena MediaSoup SFU Server running on port 8443
📊 Workers: 2
🌐 Environment: production
```

Press Ctrl+C to stop.

### 8. Create systemd service for auto-start
```bash
cat > /etc/systemd/system/arena-mediasoup.service << 'EOF'
[Unit]
Description=Arena MediaSoup SFU Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/arena-mediasoup
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
```

### 9. Start and enable the service
```bash
systemctl daemon-reload
systemctl enable arena-mediasoup
systemctl start arena-mediasoup
```

### 10. Open firewall ports
```bash
# HTTPS port
ufw allow 8443/tcp

# MediaSoup RTC ports
ufw allow 10000:10100/tcp
ufw allow 10000:10100/udp
```

### 11. Check status
```bash
systemctl status arena-mediasoup
```

### 12. View logs
```bash
journalctl -u arena-mediasoup -f
```

## Testing

From your local machine:
```bash
curl -k https://jitsi.dialecticlabs.com:8443/health
```

Should return:
```json
{
  "status": "ok",
  "rooms": 0,
  "workers": 2
}
```

## Troubleshooting

### If the service won't start:
1. Check logs: `journalctl -u arena-mediasoup -n 50`
2. Check Node.js is installed: `node --version` (should be v18+)
3. Check ports are free: `netstat -tulpn | grep 8443`

### If clients can't connect:
1. Check firewall: `ufw status`
2. Check SSL certificate exists: `ls -la /etc/letsencrypt/live/jitsi.dialecticlabs.com/`
3. Test connectivity: `telnet jitsi.dialecticlabs.com 8443`

## Useful Commands

```bash
# Stop server
systemctl stop arena-mediasoup

# Restart server
systemctl restart arena-mediasoup

# View real-time logs
journalctl -u arena-mediasoup -f

# Check server health
curl -k https://localhost:8443/health

# Check active rooms
curl -k https://localhost:8443/rooms
```