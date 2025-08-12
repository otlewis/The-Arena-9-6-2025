# Mediasoup Scaling Architecture for 10,000+ Users

## Architecture Overview

### 1. Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Load Balancer (Nginx)                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────────────┐
        │              │                      │
┌───────▼─────┐ ┌──────▼──────┐ ┌───────────▼────┐
│  Signal #1  │ │  Signal #2  │ │   Signal #N    │
│  WebSocket  │ │  WebSocket  │ │   WebSocket    │
└──────┬──────┘ └──────┬──────┘ └───────┬────────┘
       │               │                 │
┌──────▼───────────────▼─────────────────▼────────┐
│                    Redis Pub/Sub                 │
│            (Shared State & Messaging)            │
└──────┬───────────────┬─────────────────┬────────┘
       │               │                 │
┌──────▼──────┐ ┌──────▼──────┐ ┌───────▼────────┐
│ MediaSoup   │ │ MediaSoup   │ │  MediaSoup     │
│ Server #1   │ │ Server #2   │ │  Server #N     │
│ (Workers)   │ │ (Workers)   │ │  (Workers)     │
└─────────────┘ └─────────────┘ └────────────────┘
```

### 2. Scaling Strategy

#### Per Server Capacity
- **Workers**: 4-8 per server (based on CPU cores)
- **Routers**: 1 per worker
- **Transports**: ~500 per router
- **Producers/Consumers**: ~2000 per router

#### Server Requirements for 10,000 Users
- **Signaling Servers**: 3-5 instances
- **MediaSoup Servers**: 5-10 instances (8 core, 16GB RAM each)
- **Redis Cluster**: 3 nodes for HA
- **Load Balancer**: 2 instances (active/passive)

### 3. Room Distribution Strategy

```javascript
// Consistent hashing for room assignment
function getMediaServerForRoom(roomId) {
  const hash = crypto.createHash('md5').update(roomId).digest('hex');
  const serverIndex = parseInt(hash.substring(0, 8), 16) % servers.length;
  return servers[serverIndex];
}
```

### 4. Implementation Phases

#### Phase 1: Single Server Optimization (100-500 users)
- Optimize current mediasoup server
- Add worker management
- Implement proper resource cleanup

#### Phase 2: Horizontal Scaling (500-2000 users)
- Add Redis for state management
- Implement server discovery
- Add basic load balancing

#### Phase 3: Full Scale (2000-10,000+ users)
- Multi-region deployment
- Advanced load balancing
- Auto-scaling based on metrics

### 5. Key Features for Scale

#### Connection Management
```javascript
class ConnectionManager {
  constructor() {
    this.workers = [];
    this.routers = new Map();
    this.transports = new Map();
    this.producers = new Map();
    this.consumers = new Map();
  }

  async createWorker() {
    const worker = await mediasoup.createWorker({
      rtcMinPort: 10000,
      rtcMaxPort: 10100,
      logLevel: 'warn',
      dtlsCertificateFile: '/path/to/cert.pem',
      dtlsPrivateKeyFile: '/path/to/key.pem',
    });

    worker.on('died', () => {
      console.error('Worker died, restarting...');
      this.createWorker();
    });

    return worker;
  }
}
```

#### Room Management with Redis
```javascript
class RoomManager {
  constructor(redis) {
    this.redis = redis;
    this.localRooms = new Map();
  }

  async createRoom(roomId, roomType) {
    const serverInfo = {
      serverId: process.env.SERVER_ID,
      ip: process.env.PUBLIC_IP,
      port: process.env.PORT,
      load: await this.getServerLoad()
    };

    await this.redis.hset(`room:${roomId}`, {
      type: roomType,
      server: JSON.stringify(serverInfo),
      created: Date.now()
    });

    return this.localRooms.set(roomId, {
      router: await this.createRouter(),
      peers: new Map()
    });
  }
}
```

### 6. Performance Optimizations

#### Transport Reuse
- Reuse transports for multiple producers/consumers
- Implement transport pooling

#### Selective Forwarding
```javascript
// Only forward audio to listeners who need it
async updateConsumers(room, producerId) {
  const producer = room.producers.get(producerId);
  const producerPeer = room.peers.get(producer.peerId);
  
  for (const [peerId, peer] of room.peers) {
    // Skip self and check if should consume
    if (peerId === producer.peerId) continue;
    
    // For Arena: only judges and participants get audio
    if (room.type === 'arena' && 
        peer.role !== 'judge' && 
        peer.role !== 'participant') {
      continue;
    }
    
    await createConsumer(peer, producer);
  }
}
```

### 7. Monitoring & Metrics

```javascript
class MetricsCollector {
  constructor() {
    this.metrics = {
      workers: 0,
      routers: 0,
      transports: 0,
      producers: 0,
      consumers: 0,
      rooms: 0,
      peers: 0
    };
  }

  async reportToRedis() {
    await redis.hset(`server:${SERVER_ID}:metrics`, this.metrics);
    await redis.expire(`server:${SERVER_ID}:metrics`, 10);
  }
}
```

### 8. Database Optimization

#### Indexes for Appwrite Collections
```javascript
// participants collection
- roomId + userId (compound unique)
- roomId + status
- userId + status

// rooms collection  
- type + status
- createdAt (for cleanup)
```

### 9. Cost Estimation (Monthly)

For 10,000 concurrent users:
- **Servers**: 10x 8-core Linodes = $600/month
- **Load Balancer**: 2x 2-core = $40/month
- **Redis**: 3x 4GB = $60/month
- **Bandwidth**: ~5TB = $50/month
- **Total**: ~$750/month

### 10. Implementation Timeline

- **Week 1-2**: Optimize single server, add monitoring
- **Week 3-4**: Implement Redis, basic horizontal scaling
- **Week 5-6**: Load testing, optimization
- **Week 7-8**: Multi-region setup, auto-scaling