import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Service for generating LiveKit JWT tokens with role-based permissions
/// This handles token generation for Arena, Debates & Discussions, and Open Discussion rooms
class LiveKitTokenService {
  // Development/Production credentials matching Linode deployment
  static const String _apiKey = 'LKAPI1234567890'; // Matches deployment script
  static const String _secretKey = 'your-secret-key-here'; // Matches deployment script
  
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
      debugPrint('🔑 Generating LiveKit token for $identity in $roomName');
      debugPrint('👤 Role: $userRole, Type: $roomType');
      
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiry = ttl != null 
          ? now + ttl.inSeconds
          : now + (6 * 60 * 60); // Default 6 hours
      
      // Create metadata with role and room type
      final metadata = {
        'role': userRole,
        'roomType': roomType,
        if (userId != null) 'userId': userId,
        ...?additionalMetadata,
      };
      
      // Create video grants based on role and room type
      final videoGrants = _createVideoGrants(userRole, roomType, roomName);
      
      // Create JWT payload
      final payload = {
        'iss': _apiKey,
        'sub': identity,
        'iat': now,
        'exp': expiry,
        'video': videoGrants,
        'metadata': jsonEncode(metadata),
      };
      
      debugPrint('🔧 JWT Payload: $payload');
      debugPrint('🔧 Video Grants: $videoGrants');
      
      // Generate JWT
      final token = _generateJWT(payload);
      
      debugPrint('🔑 Generated LiveKit token: ${token.substring(0, 50)}...');
      debugPrint('⏰ Expires: ${DateTime.fromMillisecondsSinceEpoch(expiry * 1000)}');
      
      return token;
      
    } catch (error) {
      debugPrint('❌ Failed to generate LiveKit token: $error');
      rethrow;
    }
  }
  
  /// Create video grants based on user role and room type
  static Map<String, dynamic> _createVideoGrants(String userRole, String roomType, String roomName) {
    final grants = <String, dynamic>{
      'roomJoin': true,
      'room': roomName,
    };
    
    // Set permissions based on role and room type
    switch (roomType) {
      case 'arena':
        _setArenaPermissions(grants, userRole);
        break;
      case 'debate_discussion':
        _setDebateDiscussionPermissions(grants, userRole);
        break;
      case 'open_discussion':
        _setOpenDiscussionPermissions(grants, userRole);
        break;
      default:
        // Default permissions - very restrictive
        grants['canSubscribe'] = true;
        grants['canPublish'] = false;
    }
    
    return grants;
  }
  
  /// Set permissions for Arena rooms
  static void _setArenaPermissions(Map<String, dynamic> grants, String userRole) {
    grants['canSubscribe'] = true;
    
    switch (userRole) {
      case 'affirmative':
      case 'negative':
        // Debaters can publish audio (video optional)
        grants['canPublish'] = true;
        grants['canPublishData'] = true;
        break;
        
      case 'judge':
        // Judges can publish and moderate
        grants['canPublish'] = true;
        grants['canPublishData'] = true;
        grants['hidden'] = false; // Judges are visible
        break;
        
      case 'moderator':
        // Moderators have full control
        grants['canPublish'] = true;
        grants['canPublishData'] = true;
        grants['roomAdmin'] = true;
        grants['roomRecord'] = true;
        break;
        
      case 'audience':
      default:
        // Audience can only listen
        grants['canPublish'] = false;
        grants['canPublishData'] = false;
    }
  }
  
  /// Set permissions for Debates & Discussions rooms
  static void _setDebateDiscussionPermissions(Map<String, dynamic> grants, String userRole) {
    grants['canSubscribe'] = true;
    
    switch (userRole) {
      case 'moderator':
        // Moderators have full control
        grants['canPublish'] = true;
        grants['canPublishData'] = true;
        grants['roomAdmin'] = true;
        grants['roomRecord'] = true;
        break;
        
      case 'speaker':
        // Speakers can publish when approved
        grants['canPublish'] = true;
        grants['canPublishData'] = true;
        break;
        
      case 'pending':
        // Pending speakers can listen but not publish yet
        grants['canPublish'] = false;
        grants['canPublishData'] = true; // Can send hand-raise data
        break;
        
      case 'audience':
      default:
        // Audience can only listen and potentially raise hand
        grants['canPublish'] = false;
        grants['canPublishData'] = true; // Can send hand-raise data
    }
  }
  
  /// Set permissions for Open Discussion rooms
  static void _setOpenDiscussionPermissions(Map<String, dynamic> grants, String userRole) {
    grants['canSubscribe'] = true;
    
    switch (userRole) {
      case 'moderator':
        // Moderators have full control
        grants['canPublish'] = true;
        grants['canPublishData'] = true;
        grants['roomAdmin'] = true;
        grants['roomRecord'] = true;
        break;
        
      case 'speaker':
        // Approved speakers can publish
        grants['canPublish'] = true;
        grants['canPublishData'] = true;
        break;
        
      case 'audience':
      default:
        // Audience starts with limited permissions
        grants['canPublish'] = false;
        grants['canPublishData'] = true; // Can send hand-raise data
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
  static String _generateJWT(Map<String, dynamic> payload) {
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
      debugPrint('❌ Failed to validate token: $error');
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
      debugPrint('❌ Failed to extract token metadata: $error');
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
    debugPrint('🔄 Generating upgrade token: $identity -> $newRole');
    
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

/// Configuration class for LiveKit server settings
class LiveKitConfig {
  final String serverUrl;
  final String apiKey;
  final String secretKey;
  
  const LiveKitConfig({
    required this.serverUrl,
    required this.apiKey,
    required this.secretKey,
  });
  
  /// Default development configuration
  static const LiveKitConfig development = LiveKitConfig(
    serverUrl: 'wss://localhost:7880',
    apiKey: 'LKAPI1234567890',
    secretKey: 'your-secret-key-here',
  );
  
  /// Production configuration (set via environment variables)
  static LiveKitConfig production = const LiveKitConfig(
    serverUrl: String.fromEnvironment('LIVEKIT_SERVER_URL', 
        defaultValue: 'wss://your-domain.com'),
    apiKey: String.fromEnvironment('LIVEKIT_API_KEY', 
        defaultValue: 'LKAPI1234567890'),
    secretKey: String.fromEnvironment('LIVEKIT_SECRET_KEY', 
        defaultValue: 'your-secret-key-here'),
  );
}