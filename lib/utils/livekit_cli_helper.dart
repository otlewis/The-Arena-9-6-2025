import 'dart:io';
import 'dart:convert';
import '../core/logging/app_logger.dart';
import '../services/livekit_config_service.dart';

/// Helper class for integrating LiveKit CLI operations with Arena
class LiveKitCliHelper {
  static final LiveKitCliHelper _instance = LiveKitCliHelper._internal();
  factory LiveKitCliHelper() => _instance;
  LiveKitCliHelper._internal();

  final LiveKitConfigService _config = LiveKitConfigService.instance;

  /// Create a LiveKit room using CLI
  Future<Map<String, dynamic>?> createRoom(String roomName) async {
    try {
      AppLogger().debug('🎮 Creating LiveKit room via CLI: $roomName');
      
      final result = await Process.run('lk', [
        'room',
        'create',
        roomName,
        '--url',
        _config.serverUrl,
        '--api-key',
        _config.apiKey,
        '--api-secret',
        _config.secretKey,
        '--output',
        'json',
      ]);

      if (result.exitCode == 0) {
        final roomData = json.decode(result.stdout);
        AppLogger().debug('✅ LiveKit room created: ${roomData['sid']}');
        return roomData;
      } else {
        AppLogger().error('❌ Failed to create LiveKit room: ${result.stderr}');
        return null;
      }
    } catch (e) {
      AppLogger().error('❌ Error creating LiveKit room: $e');
      return null;
    }
  }

  /// Delete a LiveKit room using CLI
  Future<bool> deleteRoom(String roomId) async {
    try {
      AppLogger().debug('🗑️ Deleting LiveKit room via CLI: $roomId');
      
      final result = await Process.run('lk', [
        'room',
        'delete',
        roomId,
        '--url',
        _config.serverUrl,
        '--api-key',
        _config.apiKey,
        '--api-secret',
        _config.secretKey,
      ]);

      if (result.exitCode == 0) {
        AppLogger().debug('✅ LiveKit room deleted: $roomId');
        return true;
      } else {
        AppLogger().error('❌ Failed to delete LiveKit room: ${result.stderr}');
        return false;
      }
    } catch (e) {
      AppLogger().error('❌ Error deleting LiveKit room: $e');
      return false;
    }
  }

  /// List all LiveKit rooms
  Future<List<Map<String, dynamic>>> listRooms() async {
    try {
      AppLogger().debug('📋 Listing LiveKit rooms via CLI');
      
      final result = await Process.run('lk', [
        'room',
        'list',
        '--url',
        _config.serverUrl,
        '--api-key',
        _config.apiKey,
        '--api-secret',
        _config.secretKey,
        '--output',
        'json',
      ]);

      if (result.exitCode == 0) {
        final rooms = json.decode(result.stdout) as List;
        AppLogger().debug('📋 Found ${rooms.length} LiveKit rooms');
        return rooms.cast<Map<String, dynamic>>();
      } else {
        AppLogger().error('❌ Failed to list LiveKit rooms: ${result.stderr}');
        return [];
      }
    } catch (e) {
      AppLogger().error('❌ Error listing LiveKit rooms: $e');
      return [];
    }
  }

  /// Get room participants
  Future<List<Map<String, dynamic>>> getRoomParticipants(String roomId) async {
    try {
      AppLogger().debug('👥 Getting LiveKit room participants via CLI: $roomId');
      
      final result = await Process.run('lk', [
        'room',
        'list-participants',
        roomId,
        '--url',
        _config.serverUrl,
        '--api-key',
        _config.apiKey,
        '--api-secret',
        _config.secretKey,
        '--output',
        'json',
      ]);

      if (result.exitCode == 0) {
        final participants = json.decode(result.stdout) as List;
        AppLogger().debug('👥 Found ${participants.length} participants in room $roomId');
        return participants.cast<Map<String, dynamic>>();
      } else {
        AppLogger().error('❌ Failed to get room participants: ${result.stderr}');
        return [];
      }
    } catch (e) {
      AppLogger().error('❌ Error getting room participants: $e');
      return [];
    }
  }

  /// Generate access token for a room
  Future<String?> generateToken({
    required String roomName,
    required String identity,
    String role = 'participant',
    int? ttl,
  }) async {
    try {
      AppLogger().debug('🎫 Generating LiveKit token via CLI for $identity in $roomName');
      
      final args = [
        'token',
        'create',
        '--room',
        roomName,
        '--identity',
        identity,
        '--role',
        role,
        '--url',
        _config.serverUrl,
        '--api-key',
        _config.apiKey,
        '--api-secret',
        _config.secretKey,
      ];

      if (ttl != null) {
        args.addAll(['--valid-for', '${ttl}s']);
      }

      final result = await Process.run('lk', args);

      if (result.exitCode == 0) {
        final token = result.stdout.trim();
        AppLogger().debug('✅ LiveKit token generated for $identity');
        return token;
      } else {
        AppLogger().error('❌ Failed to generate LiveKit token: ${result.stderr}');
        return null;
      }
    } catch (e) {
      AppLogger().error('❌ Error generating LiveKit token: $e');
      return null;
    }
  }

  /// Test server connectivity
  Future<bool> testConnection() async {
    try {
      AppLogger().debug('🔄 Testing LiveKit server connectivity via CLI');
      
      final result = await Process.run('lk', [
        'room',
        'list',
        '--url',
        _config.serverUrl,
        '--api-key',
        _config.apiKey,
        '--api-secret',
        _config.secretKey,
      ]);

      final isConnected = result.exitCode == 0;
      AppLogger().debug(isConnected ? '✅ LiveKit server connection successful' : '❌ LiveKit server connection failed');
      return isConnected;
    } catch (e) {
      AppLogger().error('❌ Error testing LiveKit connection: $e');
      return false;
    }
  }

  /// Clean up empty rooms
  Future<int> cleanupEmptyRooms() async {
    try {
      AppLogger().debug('🧹 Cleaning up empty LiveKit rooms');
      
      final rooms = await listRooms();
      int deletedCount = 0;
      
      for (final room in rooms) {
        final participantCount = room['numParticipants'] ?? 0;
        if (participantCount == 0) {
          final roomId = room['sid'];
          if (await deleteRoom(roomId)) {
            deletedCount++;
          }
        }
      }
      
      AppLogger().debug('🧹 Cleaned up $deletedCount empty rooms');
      return deletedCount;
    } catch (e) {
      AppLogger().error('❌ Error cleaning up empty rooms: $e');
      return 0;
    }
  }

  /// Get room info
  Future<Map<String, dynamic>?> getRoomInfo(String roomId) async {
    try {
      AppLogger().debug('ℹ️ Getting LiveKit room info via CLI: $roomId');
      
      final result = await Process.run('lk', [
        'room',
        'info',
        roomId,
        '--url',
        _config.serverUrl,
        '--api-key',
        _config.apiKey,
        '--api-secret',
        _config.secretKey,
        '--output',
        'json',
      ]);

      if (result.exitCode == 0) {
        final roomInfo = json.decode(result.stdout);
        AppLogger().debug('✅ Got LiveKit room info for $roomId');
        return roomInfo;
      } else {
        AppLogger().error('❌ Failed to get room info: ${result.stderr}');
        return null;
      }
    } catch (e) {
      AppLogger().error('❌ Error getting room info: $e');
      return null;
    }
  }
}