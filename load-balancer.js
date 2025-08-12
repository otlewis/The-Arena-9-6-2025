const express = require('express');
const httpProxy = require('http-proxy-middleware');
const Redis = require('ioredis');
const crypto = require('crypto');

const app = express();
const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
});

// Track server health
const servers = new Map();
const HEALTH_CHECK_INTERVAL = 5000;
const SERVER_TIMEOUT = 15000;

// Discover and monitor servers
async function discoverServers() {
  try {
    const keys = await redis.keys('server:*');
    
    for (const key of keys) {
      const serverId = key.split(':')[1];
      const metrics = await redis.hgetall(key);
      
      if (metrics && metrics.timestamp) {
        const age = Date.now() - parseInt(metrics.timestamp);
        
        if (age < SERVER_TIMEOUT) {
          servers.set(serverId, {
            id: serverId,
            metrics,
            healthy: true,
            lastSeen: Date.now(),
          });
        } else {
          servers.delete(serverId);
        }
      }
    }
    
    console.log(`📊 Active servers: ${servers.size}`);
  } catch (error) {
    console.error('❌ Server discovery error:', error);
  }
}

// Get least loaded server
function getLeastLoadedServer() {
  let bestServer = null;
  let lowestLoad = Infinity;
  
  for (const [id, server] of servers) {
    if (!server.healthy) continue;
    
    const load = parseInt(server.metrics.peers || 0) + 
                  parseInt(server.metrics.rooms || 0) * 10;
    
    if (load < lowestLoad) {
      lowestLoad = load;
      bestServer = server;
    }
  }
  
  return bestServer;
}

// Get server for specific room (consistent hashing)
async function getServerForRoom(roomId) {
  // Check if room already exists
  const roomInfo = await redis.hgetall(`room:${roomId}`);
  
  if (roomInfo && roomInfo.serverId) {
    const server = servers.get(roomInfo.serverId);
    if (server && server.healthy) {
      return server;
    }
  }
  
  // Use consistent hashing for new rooms
  const hash = crypto.createHash('md5').update(roomId).digest('hex');
  const serverArray = Array.from(servers.values()).filter(s => s.healthy);
  
  if (serverArray.length === 0) {
    throw new Error('No healthy servers available');
  }
  
  const index = parseInt(hash.substring(0, 8), 16) % serverArray.length;
  return serverArray[index];
}

// Room assignment endpoint
app.post('/api/room-assignment', express.json(), async (req, res) => {
  try {
    const { roomId, roomType } = req.body;
    
    if (!roomId || !roomType) {
      return res.status(400).json({ error: 'Missing roomId or roomType' });
    }
    
    const server = await getServerForRoom(roomId);
    
    if (!server) {
      return res.status(503).json({ error: 'No servers available' });
    }
    
    res.json({
      serverId: server.id,
      url: `ws://${server.ip || 'localhost'}:${server.port || 3001}`,
      metrics: {
        rooms: server.metrics.rooms,
        peers: server.metrics.peers,
      }
    });
    
  } catch (error) {
    console.error('❌ Room assignment error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  const healthy = servers.size > 0;
  
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'unhealthy',
    servers: servers.size,
    timestamp: Date.now(),
  });
});

// Server metrics endpoint
app.get('/api/metrics', async (req, res) => {
  const metrics = {
    servers: [],
    totals: {
      rooms: 0,
      peers: 0,
      producers: 0,
      consumers: 0,
    }
  };
  
  for (const [id, server] of servers) {
    const serverMetrics = {
      id,
      healthy: server.healthy,
      ...server.metrics,
    };
    
    metrics.servers.push(serverMetrics);
    
    if (server.healthy) {
      metrics.totals.rooms += parseInt(server.metrics.rooms || 0);
      metrics.totals.peers += parseInt(server.metrics.peers || 0);
      metrics.totals.producers += parseInt(server.metrics.producers || 0);
      metrics.totals.consumers += parseInt(server.metrics.consumers || 0);
    }
  }
  
  res.json(metrics);
});

// Dynamic proxy for WebSocket connections
app.use('/socket.io', (req, res, next) => {
  const server = getLeastLoadedServer();
  
  if (!server) {
    return res.status(503).json({ error: 'No servers available' });
  }
  
  const proxy = httpProxy.createProxyMiddleware({
    target: `http://${server.ip || 'localhost'}:${server.port || 3001}`,
    ws: true,
    changeOrigin: true,
    onError: (err, req, res) => {
      console.error('❌ Proxy error:', err);
      res.status(502).json({ error: 'Proxy error' });
    },
  });
  
  proxy(req, res, next);
});

// Start health checks
setInterval(discoverServers, HEALTH_CHECK_INTERVAL);
discoverServers();

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Load balancer running on port ${PORT}`);
});