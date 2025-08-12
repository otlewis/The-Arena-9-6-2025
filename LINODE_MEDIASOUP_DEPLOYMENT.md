# Arena MediaSoup Deployment on Linode 4GB

## Current Server Specs
- **1 Linode VPS** (not 10 servers - just 1 server)
- **2 CPU cores** (within that 1 server)
- **4GB RAM**
- **80GB SSD storage**
- **$24/month plan**

**Estimated Capacity**: 1,000-1,500 concurrent users with audio-only rooms

## Deployment Steps

### 1. Connect to Your Linode Server
```bash
ssh root@172.236.109.9
```

### 2. Install Node.js and Dependencies
```bash
# Install Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Install PM2 globally
npm install -g pm2

# Install Redis (optional for now)
apt-get install redis-server -y
```

### 3. Upload Arena Files
```bash
# On your local machine, copy files to server
scp -r /Users/otislewis/arena2/start-mediasoup-single.cjs root@172.236.109.9:/var/www/arena/
scp -r /Users/otislewis/arena2/package.json root@172.236.109.9:/var/www/arena/
```

### 4. Install Node Packages on Server
```bash
# On the server
cd /var/www/arena
npm install express socket.io mediasoup cors
```

### 5. Configure Firewall
```bash
# Open required ports
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw allow 3001  # MediaSoup server
ufw allow 10000:10100/udp  # WebRTC media
ufw enable
```

### 6. Start MediaSoup Server
```bash
# Start with PM2 for production
pm2 start start-mediasoup-single.cjs --name arena-mediasoup
pm2 save
pm2 startup
```

### 7. Monitor Server
```bash
# Check logs
pm2 logs arena-mediasoup

# Check status
pm2 status

# Monitor resources
pm2 monit
```

## Testing Connection

### Test Server Health
```bash
curl http://172.236.109.9:3001/health
```

Expected response:
```json
{
  "status": "ok",
  "serverId": "abc123...",
  "uptime": 123.45,
  "workers": 2,
  "metrics": {
    "rooms": 0,
    "peers": 0,
    "producers": 0,
    "consumers": 0
  }
}
```

## Flutter Integration

Update your Flutter app to use the new MediaSoup service:

```dart
// In your room screen
import 'package:arena/services/single_mediasoup_service.dart';

final _mediasoupService = SingleMediasoupService();

// Connect to MediaSoup instead of Agora
await _mediasoupService.connect(
  roomId: widget.roomId,
  userId: userId,
  roomType: 'discussion',
  role: userRole,
  audioOnly: true,
);
```

## Scaling Path

### Current Setup (1 Server)
- **Capacity**: 1,000-1,500 users
- **Cost**: $24/month
- **Architecture**: Single MediaSoup server

### Next Scale (2-3 Servers)
- **Capacity**: 3,000-5,000 users
- **Cost**: $48-72/month
- **Architecture**: Load balancer + MediaSoup servers

### Full Scale (5+ Servers)
- **Capacity**: 10,000+ users
- **Cost**: $120+/month
- **Architecture**: Load balancer + Redis + Multiple MediaSoup servers

## Performance Monitoring

### Key Metrics to Watch
- **CPU Usage**: Should stay under 80%
- **Memory Usage**: Should stay under 3GB
- **Active Rooms**: Track concurrent rooms
- **Active Peers**: Track concurrent users
- **Network I/O**: Monitor bandwidth usage

### Alerts
Set up alerts for:
- CPU > 80%
- Memory > 3GB
- Server downtime
- High error rates

## Troubleshooting

### Common Issues
1. **Port blocked**: Check firewall settings
2. **Memory issues**: Restart server with `pm2 restart arena-mediasoup`
3. **Worker crashes**: Check logs with `pm2 logs`
4. **Connection timeout**: Verify announced IP is correct

### Log Locations
- PM2 logs: `~/.pm2/logs/`
- System logs: `/var/log/`
- Application logs: Console output via `pm2 logs`

## Security

### Basic Security Setup
```bash
# Disable root login
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Create app user
useradd -m -s /bin/bash arena
usermod -aG sudo arena

# Use app user for deployment
chown -R arena:arena /var/www/arena
```

## Next Steps

1. ✅ **Deploy single server** - Start with current 2-CPU setup
2. 🔄 **Test with Flutter app** - Verify audio works
3. 📊 **Monitor performance** - Track user capacity
4. 🚀 **Scale when needed** - Add more servers at 80% capacity

Your current Linode 4GB setup is perfect to start with. You can handle hundreds of users before needing to scale to multiple servers.