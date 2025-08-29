import 'dart:convert';
import '../core/logging/app_logger.dart';

/// Utility class to debug and verify LiveKit tokens
class TokenDebugger {
  /// Decode and log a LiveKit JWT token for debugging
  static void debugToken(String token, {String? label}) {
    try {
      AppLogger().debug('🔍 ===== TOKEN DEBUG${label != null ? " - $label" : ""} =====');
      
      final parts = token.split('.');
      if (parts.length != 3) {
        AppLogger().debug('❌ Invalid token format (expected 3 parts, got ${parts.length})');
        return;
      }
      
      // Decode header
      final headerJson = utf8.decode(base64Url.decode(_addPadding(parts[0])));
      final header = jsonDecode(headerJson) as Map<String, dynamic>;
      AppLogger().debug('📄 Header: $header');
      
      // Decode payload
      final payloadJson = utf8.decode(base64Url.decode(_addPadding(parts[1])));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      
      // Extract key information
      AppLogger().debug('🔑 API Key (iss): ${payload['iss']}');
      AppLogger().debug('👤 Identity (sub): ${payload['sub']}');
      
      // Check expiry
      final exp = payload['exp'] as int;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      final isExpired = expiry.isBefore(now);
      AppLogger().debug('⏰ Expires: $expiry ${isExpired ? "❌ EXPIRED" : "✅ VALID"}');
      
      // Check video grants
      final videoGrants = payload['video'] as Map<String, dynamic>?;
      if (videoGrants != null) {
        AppLogger().debug('🎥 Video Grants:');
        AppLogger().debug('  • roomJoin: ${videoGrants['roomJoin']} ${videoGrants['roomJoin'] == true ? "✅" : "❌"}');
        AppLogger().debug('  • room: ${videoGrants['room']}');
        AppLogger().debug('  • canSubscribe: ${videoGrants['canSubscribe']}');
        AppLogger().debug('  • canPublish: ${videoGrants['canPublish']} ${videoGrants['canPublish'] == true ? "🎤 CAN SPEAK" : "🔇 LISTEN ONLY"}');
        AppLogger().debug('  • canPublishData: ${videoGrants['canPublishData']}');
      } else {
        AppLogger().debug('❌ No video grants found in token!');
      }
      
      // Check metadata
      if (payload['metadata'] != null) {
        final metadataStr = payload['metadata'] as String;
        final metadata = jsonDecode(metadataStr) as Map<String, dynamic>;
        AppLogger().debug('📋 Metadata:');
        AppLogger().debug('  • role: ${metadata['role']}');
        AppLogger().debug('  • roomType: ${metadata['roomType']}');
        AppLogger().debug('  • userId: ${metadata['userId']}');
        
        // Role-based verification
        final role = metadata['role'] as String;
        final roomType = metadata['roomType'] as String;
        final canPublish = videoGrants?['canPublish'] as bool?;
        
        _verifyRolePermissions(role, roomType, canPublish);
      }
      
      AppLogger().debug('🔍 ===== END TOKEN DEBUG =====');
      
    } catch (e) {
      AppLogger().debug('❌ Error decoding token: $e');
    }
  }
  
  /// Verify that role permissions match expected values
  static void _verifyRolePermissions(String role, String roomType, bool? canPublish) {
    AppLogger().debug('🎯 Role Permission Check:');
    
    bool expectedCanPublish = false;
    
    switch (roomType) {
      case 'debate_discussion':
      case 'open_discussion':
        expectedCanPublish = (role == 'moderator' || role == 'speaker');
        AppLogger().debug('  • Room Type: $roomType');
        AppLogger().debug('  • Role: $role');
        AppLogger().debug('  • Expected canPublish: $expectedCanPublish');
        AppLogger().debug('  • Actual canPublish: $canPublish');
        break;
        
      case 'arena':
        expectedCanPublish = [
          'moderator', 'affirmative', 'negative', 
          'affirmative2', 'negative2', 'judge', 
          'judge1', 'judge2', 'judge3'
        ].contains(role);
        AppLogger().debug('  • Room Type: $roomType');
        AppLogger().debug('  • Role: $role');
        AppLogger().debug('  • Expected canPublish: $expectedCanPublish');
        AppLogger().debug('  • Actual canPublish: $canPublish');
        break;
        
      default:
        AppLogger().debug('  • Unknown room type: $roomType');
    }
    
    if (canPublish == expectedCanPublish) {
      AppLogger().debug('  ✅ Permissions are CORRECT for $role in $roomType');
    } else {
      AppLogger().debug('  ❌ PERMISSION MISMATCH! $role should ${expectedCanPublish ? "CAN" : "CANNOT"} publish in $roomType');
    }
  }
  
  /// Add padding to base64 string if needed
  static String _addPadding(String base64) {
    final padding = 4 - (base64.length % 4);
    if (padding == 4) return base64;
    return base64 + ('=' * padding);
  }
  
  /// Quick check if a token allows publishing
  static bool canPublishFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      final payloadJson = utf8.decode(base64Url.decode(_addPadding(parts[1])));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      final videoGrants = payload['video'] as Map<String, dynamic>?;
      
      return videoGrants?['canPublish'] == true;
    } catch (e) {
      return false;
    }
  }
  
  /// Extract role from token
  static String? getRoleFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payloadJson = utf8.decode(base64Url.decode(_addPadding(parts[1])));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      
      if (payload['metadata'] != null) {
        final metadata = jsonDecode(payload['metadata'] as String) as Map<String, dynamic>;
        return metadata['role'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}