# Arena Analytics MCP Server Setup Guide

## Quick Start

### 1. Prerequisites

- Node.js 18+ 
- Access to Arena's Appwrite database
- Claude Code with MCP support

### 2. Installation

```bash
# Navigate to the Arena project
cd arena2

# Install MCP server dependencies
cd arena-analytics-mcp
npm install
```

### 3. Environment Configuration

```bash
# Copy environment template
cp config/.env.example .env

# Edit with your credentials
nano .env
```

**Required Configuration:**
```env
APPWRITE_ENDPOINT=https://your-appwrite-endpoint.com/v1
APPWRITE_PROJECT_ID=your-arena-project-id
APPWRITE_API_KEY=your-api-key-with-read-access
APPWRITE_DATABASE_ID=your-database-id
```

### 4. Test Connection

```bash
# Test the server
npm start
```

You should see: `Arena Analytics MCP server running on stdio`

### 5. Claude Code Integration

Add to your Claude Code MCP configuration:

**macOS/Linux:** `~/.config/claude-code/mcp.json`
**Windows:** `%APPDATA%/claude-code/mcp.json`

```json
{
  "mcpServers": {
    "arena-analytics": {
      "command": "node",
      "args": ["/full/path/to/arena2/arena-analytics-mcp/src/index.js"],
      "env": {
        "APPWRITE_ENDPOINT": "https://your-appwrite-endpoint.com/v1",
        "APPWRITE_PROJECT_ID": "your-project-id",
        "APPWRITE_API_KEY": "your-api-key",
        "APPWRITE_DATABASE_ID": "your-database-id"
      }
    }
  }
}
```

## Detailed Setup

### Appwrite API Key Setup

1. **Login to Appwrite Console**
   - Navigate to your Arena project
   - Go to Settings → API Keys

2. **Create Analytics Key**
   - Name: "Arena Analytics MCP"
   - Scopes: 
     - `databases.read`
     - `documents.read`
   - Expiration: Set appropriate expiration date

3. **Database Permissions**
   Ensure the API key has read access to these collections:
   - `users`
   - `arena_rooms`
   - `arena_participants` 
   - `arena_judgments`
   - `debate_discussion_rooms`
   - `debate_discussion_participants`
   - `room_hand_raises`
   - `timers`
   - `timer_events`

### Collection Verification

Run this verification script to ensure all required collections exist:

```bash
# Create verification script
cat > verify-collections.js << 'EOF'
import { Client, Databases } from 'node-appwrite';

const client = new Client()
  .setEndpoint(process.env.APPWRITE_ENDPOINT)
  .setProject(process.env.APPWRITE_PROJECT_ID)
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);

const requiredCollections = [
  'users',
  'arena_rooms',
  'arena_participants',
  'arena_judgments', 
  'debate_discussion_rooms',
  'debate_discussion_participants',
  'room_hand_raises',
  'timers',
  'timer_events'
];

async function verifyCollections() {
  try {
    const response = await databases.listCollections(process.env.APPWRITE_DATABASE_ID);
    const existingCollections = response.collections.map(c => c.$id);
    
    console.log('✅ Found collections:', existingCollections);
    
    const missingCollections = requiredCollections.filter(
      required => !existingCollections.includes(required)
    );
    
    if (missingCollections.length > 0) {
      console.log('❌ Missing collections:', missingCollections);
      process.exit(1);
    } else {
      console.log('✅ All required collections found!');
    }
  } catch (error) {
    console.error('❌ Verification failed:', error.message);
    process.exit(1);
  }
}

verifyCollections();
EOF

# Run verification
node verify-collections.js
```

### Testing the Server

1. **Basic Connectivity Test**
```bash
# Test server startup
timeout 5s npm start
echo "Exit code: $?"
# Should show server startup message and exit gracefully
```

2. **Data Access Test**
```bash
# Create test script
cat > test-data-access.js << 'EOF'
import { AppwriteClient } from './src/db/appwrite-client.js';

async function testDataAccess() {
  const client = new AppwriteClient();
  
  try {
    // Test users collection
    const users = await client.queryCollection('users', [], 5);
    console.log('✅ Users access:', users.total, 'total users');
    
    // Test rooms collection
    const rooms = await client.queryCollection('arena_rooms', [], 5);
    console.log('✅ Arena rooms access:', rooms.total, 'total rooms');
    
    console.log('✅ Data access test passed!');
  } catch (error) {
    console.error('❌ Data access test failed:', error.message);
    process.exit(1);
  }
}

testDataAccess();
EOF

node test-data-access.js
```

3. **Full Analytics Test**
```bash
# Test analytics functionality
cat > test-analytics.js << 'EOF'
import { ArenaAnalytics } from './src/analytics/arena-analytics.js';
import { AppwriteClient } from './src/db/appwrite-client.js';

async function testAnalytics() {
  const client = new AppwriteClient();
  const analytics = new ArenaAnalytics(client);
  
  try {
    const analysis = await analytics.analyzeArenaRooms('day');
    console.log('✅ Arena analytics test passed!');
    console.log('Total rooms analyzed:', analysis.overview.totalRooms);
    console.log('Completion rate:', analysis.overview.completionRate + '%');
  } catch (error) {
    console.error('❌ Analytics test failed:', error.message);
    process.exit(1);
  }
}

testAnalytics();
EOF

node test-analytics.js
```

## Claude Code Usage

Once configured, you can use these commands in Claude Code:

### Quick Health Check
```
Use the arena-analytics tool to get a quick overview of all room types from the past week
```

### Launch Readiness
```
Use the assess_launch_readiness tool to check if Arena is ready for the September 12 launch
```

### Specific Analysis
```
Use analyze_arena_rooms with focus on "judging" to check for bias in judge scoring
```

### Performance Monitoring
```
Use get_realtime_metrics to see current system performance
```

## Troubleshooting

### Common Issues

#### "Collection not found" Error
```bash
# Check collection exists
curl -X GET \
  'https://your-endpoint/v1/databases/your-db-id/collections' \
  -H 'X-Appwrite-Project: your-project-id' \
  -H 'X-Appwrite-Key: your-api-key'
```

#### "Insufficient permissions" Error
- Verify API key has `databases.read` and `documents.read` scopes
- Check collection-level permissions allow API key access

#### "Connection timeout" Error
- Verify Appwrite endpoint URL is correct
- Check network connectivity and firewall rules
- Ensure Appwrite instance is running and accessible

#### MCP Server Not Found
- Verify file paths in MCP configuration are absolute
- Check Node.js version (requires 18+)
- Ensure all npm dependencies are installed

### Debug Mode

Enable detailed logging:

```bash
# Set debug environment
export LOG_LEVEL=debug
export NODE_ENV=development

# Run server with debug output
npm start
```

### Performance Optimization

For large datasets:

1. **Add Database Indexes**
```sql
-- Recommended indexes for better performance
CREATE INDEX idx_rooms_created_at ON arena_rooms(createdAt);
CREATE INDEX idx_rooms_status ON arena_rooms(status);
CREATE INDEX idx_participants_room_id ON arena_participants(roomId);
CREATE INDEX idx_participants_user_id ON arena_participants(userId);
```

2. **Enable Caching** (Future Enhancement)
```env
# Add to .env for caching support
REDIS_URL=redis://localhost:6379
CACHE_TTL=300
```

## Security Considerations

1. **API Key Security**
   - Use environment variables, never hardcode keys
   - Set appropriate expiration dates
   - Regularly rotate API keys
   - Use minimum required permissions

2. **Network Security**
   - Use HTTPS endpoints only
   - Consider IP whitelisting for production
   - Monitor API key usage and rate limits

3. **Data Privacy**
   - Ensure analytics don't expose personal information
   - Follow data retention policies
   - Implement proper access controls

## Production Deployment

### Process Management
```bash
# Using PM2 for production
npm install -g pm2

# Create ecosystem file
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'arena-analytics-mcp',
    script: 'src/index.js',
    env: {
      NODE_ENV: 'production',
      LOG_LEVEL: 'info'
    },
    env_production: {
      NODE_ENV: 'production',
      LOG_LEVEL: 'error'
    }
  }]
};
EOF

# Start with PM2
pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup
```

### Monitoring
```bash
# Health check endpoint (future enhancement)
curl http://localhost:3000/health

# Log monitoring
tail -f ~/.pm2/logs/arena-analytics-mcp-out.log
```

## Next Steps

1. ✅ Complete setup and testing
2. 📊 Run initial analytics to establish baselines
3. 🎯 Configure automated monitoring
4. 🚀 Integrate with launch preparation workflow
5. 📈 Set up regular reporting schedule

## Support

- **Documentation Issues**: Update this guide or README.md
- **Technical Issues**: Check Appwrite console and server logs
- **Feature Requests**: Submit via GitHub issues
- **Urgent Issues**: Contact Arena development team