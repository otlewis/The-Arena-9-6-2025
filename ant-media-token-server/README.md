# Ant Media Token Server

This server generates JWT tokens for Ant Media Server authentication.

## Setup

1. Install dependencies:
```bash
cd ant-media-token-server
npm install
```

2. Configure environment variables:
```bash
export ANT_MEDIA_SECRET="your-ant-media-secret-key"
export PORT=3001
```

3. Run the server:
```bash
npm start
# or for development with auto-reload
npm run dev
```

## API Endpoints

### Generate Token
```bash
POST http://localhost:3001/api/token
Content-Type: application/json

{
  "streamId": "test-stream-123",
  "type": "publish_play"  // Options: "publish", "play", "publish_play"
}
```

### Generate Conference Token
```bash
POST http://localhost:3001/api/conference-token
Content-Type: application/json

{
  "roomId": "conference-room-1",
  "streamId": "participant-123"
}
```

### Health Check
```bash
GET http://localhost:3001/api/health
```

## Ant Media Server Configuration

1. Enable JWT token security in Ant Media Server:
   - Go to Application Settings
   - Enable "Token Control Enabled"
   - Set the same secret key as used in this token server

2. Use the generated tokens in your WebRTC connections:
```dart
AntMediaFlutter.connect(
  serverUrl,
  streamId,
  roomId,
  token,  // Use the generated token here
  AntMediaType.Conference,
  // ...
);
```

## Token Format

The JWT tokens contain:
- `streamId`: The stream identifier
- `type`: Permission type (publish, play, or publish_play)
- `roomId`: (Optional) For conference mode
- `exp`: Expiration timestamp (1 hour from generation)

## Security Notes

- Always use HTTPS in production
- Keep the secret key secure and use environment variables
- Implement additional authentication before generating tokens
- Consider adding rate limiting to prevent abuse