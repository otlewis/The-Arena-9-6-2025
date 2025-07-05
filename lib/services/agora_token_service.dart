import 'dart:convert';
import 'appwrite_service.dart';
import '../core/logging/app_logger.dart';

class AgoraTokenService {
  static final AgoraTokenService _instance = AgoraTokenService._internal();
  factory AgoraTokenService() => _instance;
  AgoraTokenService._internal();

  final AppwriteService _appwrite = AppwriteService();
  
  // Cache token to avoid unnecessary requests
  String? _cachedToken;
  int? _tokenExpiresAt;
  String? _cachedChannel;
  
  /// Generate a fresh Agora token by calling the Appwrite Function
  Future<String> generateToken({
    String channel = 'arena',
    int uid = 0,
    String role = 'subscriber', // 'publisher' or 'subscriber'
    int expireTime = 3600, // 1 hour
  }) async {
    try {
      AppLogger().debug('🎙️ Generating fresh Agora token for channel: $channel, uid: $uid, role: $role');
      
      // Check if we have a cached valid token for the same channel
      if (_cachedToken != null && 
          _tokenExpiresAt != null && 
          _cachedChannel == channel &&
          DateTime.now().millisecondsSinceEpoch / 1000 < (_tokenExpiresAt! - 300)) { // 5 min buffer
        AppLogger().debug('🎙️ Using cached token (expires at: $_tokenExpiresAt)');
        return _cachedToken!;
      }
      
      // Call the Appwrite Function to generate token
      final execution = await _appwrite.functions.createExecution(
        functionId: 'agora-token-generator',
        body: jsonEncode({
          'channelName': channel,
          'uid': uid,
          'role': role,
        }),
      );
      
      AppLogger().debug('🔍 Function execution status: ${execution.status}');
      AppLogger().debug('🔍 Function response body: ${execution.responseBody}');
      
      if (execution.status != 'completed') {
        throw Exception('Token generation failed with status: ${execution.status}');
      }
      
      // Parse the response
      final Map<String, dynamic> response = jsonDecode(execution.responseBody);
      
      if (response['success'] != true) {
        throw Exception('Token generation failed: ${response['error'] ?? 'Unknown error'}');
      }
      
      final token = response['token'] as String;
      final expiresAt = response['expiration'] as int;
      final tokenUid = response['uid'];
      
      // Cache the token
      _cachedToken = token;
      _tokenExpiresAt = expiresAt;
      _cachedChannel = channel;
      
      AppLogger().info('Generated fresh Agora token (expires at: $expiresAt, uid: $tokenUid)');
      return token;
      
    } catch (e) {
      AppLogger().error('Error generating Agora token: $e');
      
      // Fallback to static token if function fails
      AppLogger().debug('🔄 Falling back to static token');
      return _getFallbackToken();
    }
  }
  
  /// Get the current cached token if available and valid
  String? getCachedToken() {
    if (_cachedToken != null && 
        _tokenExpiresAt != null &&
        DateTime.now().millisecondsSinceEpoch / 1000 < (_tokenExpiresAt! - 300)) {
      return _cachedToken;
    }
    return null;
  }
  
  /// Clear cached token (force refresh on next request)
  void clearCache() {
    _cachedToken = null;
    _tokenExpiresAt = null;
    _cachedChannel = null;
    AppLogger().debug('🎙️ Agora token cache cleared');
  }
  
  /// Fallback to static token if function fails
  String _getFallbackToken() {
    // This is your current static token as backup
    return "007eJxTYJggoMEalPEhLs/em1si2dQgcWPkiX0Chz99M5dzOhMr+k+BwTg5OdnIzCTJNM3SMC3R2NTcxDA10SzVIMliCq9dRkMgI0NzpCkDIxSC+KwMiUWpeYkMDAB98hyf";
  }
  
  /// Check if token is about to expire (within 5 minutes)
  bool isTokenExpiringSoon() {
    if (_tokenExpiresAt == null) return true;
    final currentTime = DateTime.now().millisecondsSinceEpoch / 1000;
    return currentTime >= (_tokenExpiresAt! - 300); // 5 min buffer
  }
} 