import '../core/logging/app_logger.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'livekit_config_service.dart';

/// Service for generating LiveKit JWT tokens with role-based permissions
/// This handles token generation for Arena, Debates & Discussions, Open Discussion rooms, and lobby connections
class LiveKitTokenService {
  // Use centralized configuration service instead of hardcoded values
  static String get _apiKey => LiveKitConfigService.instance.apiKey;
  static String get _secretKey => LiveKitConfigService.instance.secretKey;
  
  /// Generate a JWT token for a user with specific permissions
  static String generateToken({
    required String roomName,
    required String identity,
    required String userRole,
    required String roomType,
    String? userId,
    Map<String, dynamic>? additionalMetadata,
    Duration? ttl,
  }) {
    try {
      // 1) Validate identity & keys (prevents silent bad tokens)
      if (identity.trim().isEmpty) {
        throw ArgumentError('identity cannot be empty');
      }
      if (_apiKey.isEmpty || _secretKey.isEmpty) {
        throw StateError('LiveKit API key/secret not configured');
      }
      
      // Log only the first/last 4 chars for sanity (avoid leaking secrets)
      AppLogger().debug('🔑 Generating LiveKit token for $identity in $roomName');
      AppLogger().debug('👤 Role: $userRole, Type: $roomType');
      AppLogger().debug('🔑 Using API key: $_apiKey');
      AppLogger().debug('🗝️  Secret starts/ends: '
          '${_secretKey.substring(0, 4)}…${_secretKey.substring(_secretKey.length - 4)}');
      
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiry = (ttl ?? const Duration(hours: 6)).inSeconds + now;
      
      // Create metadata with role and room type
      final metadata = {
        'role': userRole,
        'roomType': roomType,
        if (userId != null) 'userId': userId,
        ...?additionalMetadata,
      };
      
      // Create WebRTC grants based on role and room type (audio-only app)
      final videoGrants = _createVideoGrants(userRole, roomType, roomName);
      
      // Create JWT payload with nbf for skew tolerance
      final payload = {
        'iss': _apiKey,             // MUST equal server apiKey
        'sub': identity,            // non-empty
        'iat': now,
        'nbf': now - 10,            // small skew tolerance
        'exp': expiry,
        'video': videoGrants,
        'metadata': jsonEncode(metadata),
      };
      
      AppLogger().debug('🔧 JWT Payload: $payload');
      AppLogger().debug('🔧 Video Grants: $videoGrants');
      
      // Generate JWT
      final token = generateJWT(payload);
      
      AppLogger().debug('✅ Token minted for $identity (room=$roomName, role=$userRole)');
      AppLogger().debug('⏰ Expires: ${DateTime.fromMillisecondsSinceEpoch(expiry * 1000)}');
      
      return token;
      
    } catch (e, st) {
      AppLogger().error('❌ generateToken failed: $e\n$st');
      rethrow;
    }
  }
  
  /// Create WebRTC grants based on user role and room type (keep grants simple/valid)
  static Map<String, dynamic> _createVideoGrants(String userRole, String roomType, String roomName) {
    final grants = <String, dynamic>{
      'roomJoin': true,
      'room': roomName,
      'canSubscribe': true,
      'canPublishData': true, // used for hand-raise, metadata, etc.
    };
    
    bool canPublishAudio = false;
    
    switch (roomType) {
      case 'arena':
        canPublishAudio = [
          'affirmative', 'negative', 'affirmative2', 'negative2',
          'judge', 'judge1', 'judge2', 'judge3', 'moderator'
        ].contains(userRole);
        break;
        
      case 'debate_discussion':
      case 'open_discussion':
        canPublishAudio = (userRole == 'moderator' || userRole == 'speaker');
        // Remove canPublishSources for v1.5.2 compatibility
        if (canPublishAudio) {
          // grants['canPublishSources'] = ['mic']; // Removed - may cause v1.5.2 issues
          if (userRole == 'moderator') {
            grants['roomAdmin'] = true;
            grants['roomRecord'] = true;
          }
        }
        break;
        
      case 'server-api':
        // Server API tokens need full administrative permissions
        if (userRole == 'admin') {
          grants['roomAdmin'] = true;
          grants['roomCreate'] = true;
          grants['roomList'] = true;
          grants['roomRecord'] = true;
          grants['canUpdateOwnMetadata'] = true;
          grants['hidden'] = true;
          canPublishAudio = true;
        }
        break;
        
      default:
        canPublishAudio = false;
    }
    
    grants['canPublish'] = canPublishAudio;
    return grants;
  }
  
  /// Generate a lobby token for persistent connection
  /// This allows connection to the service but no room-specific permissions
  Future<String> generateLobbyToken(String userId) async {
    try {
      AppLogger().debug('🏠 Generating lobby token for user: $userId');
      
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiry = now + (24 * 60 * 60); // 24 hours for persistent connection
      
      // Lobby metadata - minimal permissions
      final metadata = {
        'role': 'lobby',
        'roomType': 'lobby',
        'userId': userId,
      };
      
      // Universal arena grants - allow access to any Arena room
      final videoGrants = {
        'roomJoin': true,
        'roomList': true,
        'canPublish': true, // Allow publishing for all Arena roles
        'canSubscribe': true, // Can receive all audio
        'canPublishData': true, // Can send metadata updates
        'roomAdmin': false, // Not an admin
        'roomRecord': false, // Cannot record
        // Note: No specific 'room' field means can join any room
      };
      
      final payload = {
        'iss': _apiKey,
        'sub': userId,
        'iat': now,
        'exp': expiry,
        'video': videoGrants,
        'metadata': jsonEncode(metadata),
      };
      
      final token = generateJWT(payload);
      AppLogger().debug('✅ Generated lobby token successfully');
      return token;
      
    } catch (error) {
      AppLogger().debug('❌ Failed to generate lobby token: $error');
      rethrow;
    }
  }

  /// Generate a test token for connectivity testing
  static String generateTestToken({
    required String roomName,
    String identity = 'test-user',
    Duration? ttl,
  }) {
    return generateToken(
      roomName: roomName,
      identity: identity,
      userRole: 'audience',
      roomType: 'test',
      ttl: ttl ?? const Duration(minutes: 10),
    );
  }
  
  /// Generate JWT token
  static String generateJWT(Map<String, dynamic> payload) {
    // JWT header
    final header = {
      'alg': 'HS256',
      'typ': 'JWT',
    };
    
    // Base64 encode header and payload
    final headerEncoded = _base64UrlEncode(utf8.encode(jsonEncode(header)));
    final payloadEncoded = _base64UrlEncode(utf8.encode(jsonEncode(payload)));
    
    // Create signature
    final message = '$headerEncoded.$payloadEncoded';
    final signature = _createSignature(message, _secretKey);
    
    return '$message.$signature';
  }
  
  /// Create HMAC-SHA256 signature
  static String _createSignature(String message, String secret) {
    final key = utf8.encode(secret);
    final messageBytes = utf8.encode(message);
    
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(messageBytes);
    
    return _base64UrlEncode(digest.bytes);
  }
  
  /// Base64 URL encode (without padding)
  static String _base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
  
  /// Validate token expiry
  static bool isTokenValid(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      // Decode payload
      final payloadJson = utf8.decode(base64Url.decode(_addPadding(parts[1])));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      
      final exp = payload['exp'] as int?;
      if (exp == null) return false;
      
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp > now;
      
    } catch (error) {
      AppLogger().debug('❌ Failed to validate token: $error');
      return false;
    }
  }
  
  /// Extract metadata from token
  static Map<String, dynamic>? getTokenMetadata(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      // Decode payload
      final payloadJson = utf8.decode(base64Url.decode(_addPadding(parts[1])));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      
      final metadataString = payload['metadata'] as String?;
      if (metadataString == null) return null;
      
      return jsonDecode(metadataString) as Map<String, dynamic>;
      
    } catch (error) {
      AppLogger().debug('❌ Failed to extract token metadata: $error');
      return null;
    }
  }
  
  /// Add padding to base64 string if needed
  static String _addPadding(String base64) {
    final padding = 4 - (base64.length % 4);
    if (padding == 4) return base64;
    return base64 + ('=' * padding);
  }
  
  /// Generate a token for role upgrade (e.g., audience -> speaker)
  static String generateUpgradeToken({
    required String roomName,
    required String identity,
    required String newRole,
    required String roomType,
    String? userId,
    Duration? ttl,
  }) {
    AppLogger().debug('🔄 Generating upgrade token: $identity -> $newRole');
    
    return generateToken(
      roomName: roomName,
      identity: identity,
      userRole: newRole,
      roomType: roomType,
      userId: userId,
      additionalMetadata: {
        'upgraded': true,
        'upgradeTime': DateTime.now().toIso8601String(),
      },
      ttl: ttl,
    );
  }
}