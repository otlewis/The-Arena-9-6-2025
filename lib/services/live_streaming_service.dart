import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../core/logging/app_logger.dart';
import 'livekit_service.dart';
import 'appwrite_service.dart';

/// Service for managing live streaming to external platforms
/// Integrates with LiveKit Egress API for RTMP streaming
class LiveStreamingService {
  static final LiveStreamingService _instance = LiveStreamingService._internal();
  factory LiveStreamingService() => _instance;
  LiveStreamingService._internal();

  final AppLogger _logger = AppLogger();
  final LiveKitService _liveKitService = LiveKitService();
  final AppwriteService _appwriteService = AppwriteService();
  
  // LiveKit server configuration - GCS Credentials
  static const String livekitServerUrl = 'wss://34.171.185.205:7880';
  static const String livekitApiKey = 'APIwzQr7qFmXHcy';
  static const String livekitApiSecret = '2gVhXTdGbSJ4bPSpomxfaHjCA8PBdmJ4N7h89dZAJT9';
  
  // Stream state
  final Map<String, StreamingSession> _activeSessions = {};
  
  /// Platform streaming configurations
  static const Map<String, StreamConfig> platformConfigs = {
    'facebook': StreamConfig(
      name: 'Facebook Live',
      rtmpUrl: 'rtmps://live-api-s.facebook.com:443/rtmp/',
      requiresKey: true,
    ),
    'youtube': StreamConfig(
      name: 'YouTube Live',
      rtmpUrl: 'rtmp://a.rtmp.youtube.com/live2/',
      requiresKey: true,
    ),
    'instagram': StreamConfig(
      name: 'Instagram Live',
      rtmpUrl: 'rtmps://live-upload.instagram.com:443/rtmp/',
      requiresKey: true,
    ),
    'x': StreamConfig(
      name: 'X (Twitter) Live',
      rtmpUrl: 'rtmps://production.pscp.tv:443/x/',
      requiresKey: true,
    ),
    'twitch': StreamConfig(
      name: 'Twitch',
      rtmpUrl: 'rtmp://live.twitch.tv/app/',
      requiresKey: true,
    ),
    'tiktok': StreamConfig(
      name: 'TikTok Live',
      rtmpUrl: 'rtmps://push.ttlivecdn.com/live/',
      requiresKey: true,
    ),
  };

  /// Start streaming to multiple platforms
  Future<Map<String, bool>> startMultiPlatformStream({
    required String roomId,
    required String roomName,
    required Map<String, String> streamKeys, // platform -> streamKey
  }) async {
    _logger.info('🎥 Starting multi-platform stream for room: $roomId');
    
    final results = <String, bool>{};
    
    for (final entry in streamKeys.entries) {
      final platform = entry.key;
      final streamKey = entry.value;
      
      if (streamKey.isEmpty) continue;
      
      try {
        final success = await startStreamToPlatform(
          roomId: roomId,
          roomName: roomName,
          platform: platform,
          streamKey: streamKey,
        );
        results[platform] = success;
      } catch (e) {
        _logger.error('Failed to start stream to $platform: $e');
        results[platform] = false;
      }
    }
    
    return results;
  }

  /// Start streaming to a specific platform
  Future<bool> startStreamToPlatform({
    required String roomId,
    required String roomName,
    required String platform,
    required String streamKey,
  }) async {
    try {
      final config = platformConfigs[platform];
      if (config == null) {
        _logger.error('Unknown platform: $platform');
        return false;
      }
      
      _logger.info('🎥 Starting stream to ${config.name}');
      
      // Get the LiveKit room token for egress
      final room = _liveKitService.room;
      if (room == null) {
        _logger.error('No active LiveKit room');
        return false;
      }
      
      // Construct RTMP URL with stream key
      final rtmpUrl = '${config.rtmpUrl}$streamKey';
      
      // Create egress request to LiveKit server
      final egressId = await _startLiveKitEgress(
        roomName: room.name ?? 'arena-room',
        rtmpUrl: rtmpUrl,
        streamTitle: '$roomName - Live on ${config.name}',
      );
      
      if (egressId != null) {
        // Store session info
        _activeSessions[platform] = StreamingSession(
          platform: platform,
          roomId: roomId,
          egressId: egressId,
          startTime: DateTime.now(),
          rtmpUrl: rtmpUrl,
        );
        
        // Update room status in database
        await _updateRoomStreamStatus(roomId, true, [platform]);
        
        _logger.info('✅ Stream started to ${config.name}');
        return true;
      }
      
      return false;
    } catch (e) {
      _logger.error('Error starting stream to $platform: $e');
      return false;
    }
  }

  /// Start LiveKit egress for RTMP streaming
  Future<String?> _startLiveKitEgress({
    required String roomName,
    required String rtmpUrl,
    required String streamTitle,
  }) async {
    try {
      // LiveKit Egress API endpoint - using HTTP since Egress is on same server
      final url = Uri.parse('http://34.171.185.205:7880/twirp/livekit.Egress/StartRoomCompositeEgress');
      
      // Create JWT token for API authentication
      final token = _generateLiveKitApiToken();
      
      // Egress configuration for RTMP output
      final body = {
        'room_name': roomName,
        'layout': 'speaker-dark', // or 'grid-dark' for grid layout
        'audio_only': false,
        'video_only': false,
        'stream_outputs': [
          {
            'protocol': 'rtmp',
            'url': rtmpUrl,
          }
        ],
        'preset': 'H264_720P_30', // 720p at 30fps
      };
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['egress_id'];
      } else {
        _logger.error('Failed to start egress: ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.error('Error starting LiveKit egress: $e');
      return null;
    }
  }

  /// Stop streaming to a specific platform
  Future<bool> stopStreamToPlatform(String platform) async {
    try {
      final session = _activeSessions[platform];
      if (session == null) {
        _logger.warning('No active stream for platform: $platform');
        return false;
      }
      
      _logger.info('🛑 Stopping stream to $platform');
      
      // Stop LiveKit egress
      final success = await _stopLiveKitEgress(session.egressId);
      
      if (success) {
        _activeSessions.remove(platform);
        
        // Update room status if no more active streams
        if (_activeSessions.isEmpty) {
          await _updateRoomStreamStatus(session.roomId, false, []);
        } else {
          await _updateRoomStreamStatus(
            session.roomId, 
            true, 
            _activeSessions.keys.toList(),
          );
        }
        
        _logger.info('✅ Stream stopped for $platform');
      }
      
      return success;
    } catch (e) {
      _logger.error('Error stopping stream for $platform: $e');
      return false;
    }
  }

  /// Stop all active streams
  Future<void> stopAllStreams(String roomId) async {
    _logger.info('🛑 Stopping all streams for room: $roomId');
    
    final platforms = _activeSessions.keys.toList();
    for (final platform in platforms) {
      await stopStreamToPlatform(platform);
    }
  }

  /// Stop LiveKit egress
  Future<bool> _stopLiveKitEgress(String egressId) async {
    try {
      final url = Uri.parse('$livekitServerUrl/twirp/livekit.Egress/StopEgress');
      final token = _generateLiveKitApiToken();
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'egress_id': egressId}),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      _logger.error('Error stopping LiveKit egress: $e');
      return false;
    }
  }

  /// Update room streaming status in database
  Future<void> _updateRoomStreamStatus(
    String roomId, 
    bool isStreaming,
    List<String> platforms,
  ) async {
    try {
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'debate_discussion_rooms',
        documentId: roomId,
        data: {
          'isStreaming': isStreaming,
          'streamingPlatforms': platforms,
          'streamStartTime': isStreaming ? DateTime.now().toIso8601String() : null,
        },
      );
    } catch (e) {
      _logger.error('Error updating room stream status: $e');
    }
  }

  /// Generate LiveKit API token for server requests
  String _generateLiveKitApiToken() {
    try {
      // Create JWT payload for LiveKit API
      final jwt = JWT({
        'iss': livekitApiKey,
        'sub': livekitApiKey,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        'nbf': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'video': {
          'roomCreate': true,
          'roomList': true,
          'roomAdmin': true,
        },
      });

      // Sign the JWT with the API secret
      final token = jwt.sign(SecretKey(livekitApiSecret));
      return token;
    } catch (e) {
      _logger.error('Error generating LiveKit API token: $e');
      return 'invalid-token';
    }
  }

  /// Get active streaming sessions
  List<StreamingSession> getActiveSessions() {
    return _activeSessions.values.toList();
  }

  /// Check if streaming to a specific platform
  bool isStreamingToPlatform(String platform) {
    return _activeSessions.containsKey(platform);
  }

  /// Get stream statistics
  Future<StreamStats?> getStreamStats(String platform) async {
    final session = _activeSessions[platform];
    if (session == null) return null;
    
    // Could fetch real-time stats from LiveKit Egress API
    return StreamStats(
      platform: platform,
      duration: DateTime.now().difference(session.startTime),
      isActive: true,
      viewers: 0, // Would need platform API integration for real viewer count
    );
  }
}

/// Stream configuration for different platforms
class StreamConfig {
  final String name;
  final String rtmpUrl;
  final bool requiresKey;
  
  const StreamConfig({
    required this.name,
    required this.rtmpUrl,
    required this.requiresKey,
  });
}

/// Active streaming session
class StreamingSession {
  final String platform;
  final String roomId;
  final String egressId;
  final DateTime startTime;
  final String rtmpUrl;
  
  StreamingSession({
    required this.platform,
    required this.roomId,
    required this.egressId,
    required this.startTime,
    required this.rtmpUrl,
  });
}

/// Stream statistics
class StreamStats {
  final String platform;
  final Duration duration;
  final bool isActive;
  final int viewers;
  
  StreamStats({
    required this.platform,
    required this.duration,
    required this.isActive,
    required this.viewers,
  });
}