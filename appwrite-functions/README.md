# Appwrite Functions - Arena Security Implementation

This directory contains server-side Appwrite Functions that provide secure, authorized access to critical operations. These functions **must be deployed** before the Arena app can be used in production.

---

## 📋 Functions Overview

### 1. **ban-user**
Bans users from rooms with proper super moderator authorization.

**Endpoint**: `POST /v1/functions/{functionId}/executions`

**Request**:
```json
{
  "targetUserId": "user123",
  "roomId": "room456",
  "roomType": "arena",
  "reason": "Inappropriate behavior",
  "durationMinutes": 60
}
```

**Response**:
```json
{
  "success": true,
  "banId": "ban789",
  "expiresAt": "2025-10-05T15:30:00Z"
}
```

---

### 2. **kick-user**
Temporarily removes users from rooms.

**Request**:
```json
{
  "targetUserId": "user123",
  "roomId": "room456",
  "reason": "Disrupting debate"
}
```

**Response**:
```json
{
  "success": true,
  "eventId": "event789"
}
```

---

### 3. **lock-microphones**
Locks/unlocks microphones in a room.

**Request**:
```json
{
  "roomId": "room456",
  "locked": true,
  "exemptUserIds": ["user111", "user222"]
}
```

**Response**:
```json
{
  "success": true,
  "eventId": "event789",
  "locked": true
}
```

---

### 4. **generate-livekit-token**
Generates LiveKit access tokens with role-based permissions.

**Request**:
```json
{
  "roomName": "arena_room_123",
  "roomId": "room456",
  "identity": "user123"
}
```

**Response**:
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "url": "wss://your-server.livekit.cloud",
  "userRole": "speaker",
  "permissions": {
    "canPublish": true,
    "canSubscribe": true
  }
}
```

---

### 5. **generate-upload-url**
Generates pre-signed S3 upload URLs.

**Request**:
```json
{
  "fileName": "recording.mp4",
  "fileSize": 104857600,
  "contentType": "video/mp4",
  "purpose": "recording",
  "roomId": "room456"
}
```

**Response**:
```json
{
  "success": true,
  "uploadUrl": "https://s3.example.com/presigned-url...",
  "key": "recordings/2025/10/room456_abc123.mp4",
  "expiresIn": 3600,
  "bucket": "arena-recordings"
}
```

---

## 🚀 Deployment Instructions

### Prerequisites
1. Appwrite Cloud account or self-hosted Appwrite instance (v1.4+)
2. Appwrite CLI installed: `npm install -g appwrite`
3. Project created in Appwrite Console

### Step 1: Login to Appwrite CLI
```bash
appwrite login
```

### Step 2: Initialize Appwrite in this directory
```bash
cd appwrite-functions
appwrite init project
```

Follow prompts to select your project.

### Step 3: Deploy Each Function

#### Deploy ban-user
```bash
cd ban-user
appwrite deploy function \
  --function-id "ban-user" \
  --name "Ban User" \
  --runtime "node-18.0" \
  --entrypoint "index.js" \
  --timeout 15
```

#### Deploy kick-user
```bash
cd ../kick-user
appwrite deploy function \
  --function-id "kick-user" \
  --name "Kick User" \
  --runtime "node-18.0" \
  --entrypoint "index.js" \
  --timeout 15
```

#### Deploy lock-microphones
```bash
cd ../lock-microphones
appwrite deploy function \
  --function-id "lock-microphones" \
  --name "Lock Microphones" \
  --runtime "node-18.0" \
  --entrypoint "index.js" \
  --timeout 15
```

#### Deploy generate-livekit-token
```bash
cd ../generate-livekit-token
appwrite deploy function \
  --function-id "generate-livekit-token" \
  --name "Generate LiveKit Token" \
  --runtime "node-18.0" \
  --entrypoint "index.js" \
  --timeout 15
```

**Set Environment Variables**:
```bash
appwrite functions updateVariable \
  --function-id generate-livekit-token \
  --key LIVEKIT_API_KEY \
  --value "your_livekit_api_key"

appwrite functions updateVariable \
  --function-id generate-livekit-token \
  --key LIVEKIT_API_SECRET \
  --value "your_livekit_api_secret"

appwrite functions updateVariable \
  --function-id generate-livekit-token \
  --key LIVEKIT_URL \
  --value "wss://your-server.livekit.cloud"
```

#### Deploy generate-upload-url
```bash
cd ../generate-upload-url
appwrite deploy function \
  --function-id "generate-upload-url" \
  --name "Generate Upload URL" \
  --runtime "node-18.0" \
  --entrypoint "index.js" \
  --timeout 15
```

**Set Environment Variables**:
```bash
appwrite functions updateVariable \
  --function-id generate-upload-url \
  --key IONOS_ACCESS_KEY \
  --value "your_ionos_access_key"

appwrite functions updateVariable \
  --function-id generate-upload-url \
  --key IONOS_SECRET_KEY \
  --value "your_ionos_secret_key"

appwrite functions updateVariable \
  --function-id generate-upload-url \
  --key IONOS_BUCKET \
  --value "arena-recordings"

appwrite functions updateVariable \
  --function-id generate-upload-url \
  --key IONOS_REGION \
  --value "eu-central-1"

appwrite functions updateVariable \
  --function-id generate-upload-url \
  --key IONOS_ENDPOINT \
  --value "https://s3.eu-central-1.ionoscloud.com"
```

### Step 4: Configure Function Permissions

Each function needs appropriate execute permissions. Set via Appwrite Console:

1. Go to Functions → [Function Name] → Settings → Permissions
2. Add execute permission: `users` (any authenticated user)
3. Save

### Step 5: Test Functions

Test each function via Appwrite Console or API:

```bash
curl -X POST \
  https://cloud.appwrite.io/v1/functions/{functionId}/executions \
  -H "Content-Type: application/json" \
  -H "X-Appwrite-Project: YOUR_PROJECT_ID" \
  -H "X-Appwrite-Key: YOUR_API_KEY" \
  -d '{"targetUserId": "test123", "roomId": "room456", "roomType": "arena"}'
```

---

## 📦 Database Collections Required

Ensure these collections exist in your Appwrite database (`arena_db`):

### Collections
- `super_moderators` - Super moderator records
- `room_bans` - User ban records
- `room_events` - Room event stream (kicks, mic locks)
- `security_audit_log` - Security event audit trail
- `arena_participants` - Arena room participants
- `room_participants` - Discussion room participants
- `debate_discussion_participants` - Debate room participants

### Collection: `security_audit_log`

Create this collection with the following attributes:

```bash
appwrite databases createCollection \
  --database-id arena_db \
  --collection-id security_audit_log \
  --name "Security Audit Log"

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key eventType \
  --size 50 \
  --required true

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key userId \
  --size 50 \
  --required true

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key targetUserId \
  --size 50 \
  --required false

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key resourceId \
  --size 50 \
  --required false

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key resourceType \
  --size 50 \
  --required false

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key action \
  --size 50 \
  --required true

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key reason \
  --size 500 \
  --required false

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key timestamp \
  --size 50 \
  --required true

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key ipAddress \
  --size 50 \
  --required false

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key userAgent \
  --size 500 \
  --required false

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key severity \
  --size 20 \
  --required false

appwrite databases createStringAttribute \
  --database-id arena_db \
  --collection-id security_audit_log \
  --key metadata \
  --size 10000 \
  --required false
```

---

## 🔐 Security Notes

1. **Never commit `.env` files** with actual credentials
2. **Rotate secrets regularly** (every 90 days minimum)
3. **Monitor function logs** for suspicious activity
4. **Set up alerts** for failed authorization attempts
5. **Review audit logs** weekly for security events
6. **Test functions** in staging before production deployment

---

## 🐛 Troubleshooting

### Function returns 401 Unauthorized
- Check that user is authenticated
- Verify JWT token is being sent in request headers
- Check Appwrite session is still valid

### Function returns 403 Forbidden
- User doesn't have super moderator status
- User lacks specific permission (e.g., `ban_users`)
- Check `super_moderators` collection for user record

### Function returns 500 Internal Server Error
- Check function logs in Appwrite Console
- Verify environment variables are set correctly
- Ensure database collections exist
- Check network connectivity to external services (LiveKit, S3)

### LiveKit token generation fails
- Verify `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET` are correct
- Check LiveKit URL is accessible
- Ensure `livekit-server-sdk` npm package is installed

### Upload URL generation fails
- Verify IONOS/S3 credentials are correct
- Check bucket exists and is accessible
- Verify region and endpoint are correct
- Ensure `@aws-sdk/client-s3` npm packages are installed

---

## 📝 Client Integration

Update the Flutter app to call these functions instead of direct database access.

Example client code:

```dart
// lib/services/super_moderator_service.dart

Future<bool> banUserFromRoom({
  required String targetUserId,
  required String roomId,
  required String roomType,
  String? reason,
  int? durationMinutes,
}) async {
  try {
    final result = await _appwrite.functions.createExecution(
      functionId: 'ban-user',  // Use actual function ID from Appwrite
      body: jsonEncode({
        'targetUserId': targetUserId,
        'roomId': roomId,
        'roomType': roomType,
        'reason': reason,
        'durationMinutes': durationMinutes,
      }),
    );

    final response = jsonDecode(result.responseBody);
    return response['success'] == true;
  } catch (e) {
    _logger.error('Failed to ban user: $e');
    return false;
  }
}
```

---

## 📚 Additional Resources

- [Appwrite Functions Documentation](https://appwrite.io/docs/functions)
- [Appwrite CLI Documentation](https://appwrite.io/docs/command-line)
- [LiveKit Server SDK](https://docs.livekit.io/realtime/server/generating-tokens/)
- [AWS S3 Pre-signed URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/PresignedUrlUploadObject.html)

---

## 📞 Support

For questions or issues:
- Check Appwrite Discord: https://appwrite.io/discord
- Review Arena documentation: `/SECURITY_IMPROVEMENTS.md`
- Contact development team

---

**Last Updated**: October 5, 2025
