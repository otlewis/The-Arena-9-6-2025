import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:appwrite/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Service for creating and managing 30-second audio clips from debates
class AudioClipService {
  static final AudioClipService _instance = AudioClipService._internal();
  factory AudioClipService() => _instance;
  AudioClipService._internal();

  final AppLogger _logger = AppLogger();
  final AppwriteService _appwriteService = AppwriteService();
  
  // IONOS server configuration for audio storage
  static const String ionosServerUrl = 'http://50.21.187.76/api/audio-clips';
  
  // Recording state
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;

  /// Start recording a 30-second audio clip
  Future<bool> startAudioClip({
    required String roomId,
    required String userId,
    required String clipTitle,
  }) async {
    try {
      _logger.info('🎙️ Starting 30-second audio clip recording');
      
      // TODO: Implement actual audio recording
      // For now, simulate the recording process
      
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      
      // Auto-stop after 30 seconds
      _recordingTimer = Timer(const Duration(seconds: 30), () {
        _stopAudioClip(roomId: roomId, userId: userId, clipTitle: clipTitle);
      });
      
      _logger.info('✅ Audio clip recording started (30s limit) - SIMULATION MODE');
      return true;
      
    } catch (e) {
      _logger.error('Error starting audio clip: $e');
      return false;
    }
  }

  /// Stop recording and save the audio clip
  Future<String?> _stopAudioClip({
    required String roomId,
    required String userId,
    required String clipTitle,
  }) async {
    try {
      if (!_isRecording) {
        _logger.warning('No active recording to stop');
        return null;
      }
      
      _logger.info('🛑 Stopping audio clip recording');
      
      // Stop recording
      _recordingTimer?.cancel();
      _isRecording = false;
      
      final duration = DateTime.now().difference(_recordingStartTime!);
      _logger.info('Recording stopped after ${duration.inSeconds}s - SIMULATION MODE');
      
      // TODO: Upload to IONOS server
      // For now, simulate successful upload
      final clipUrl = 'https://ionos-server.com/clips/simulated_${DateTime.now().millisecondsSinceEpoch}.opus';
      
      // Save clip metadata to Appwrite
      await _saveClipMetadata(
        roomId: roomId,
        userId: userId,
        clipTitle: clipTitle,
        clipUrl: clipUrl,
        duration: duration,
      );
      
      return clipUrl;
      
    } catch (e) {
      _logger.error('Error stopping audio clip: $e');
      return null;
    }
  }


  /// Save clip metadata to Appwrite database
  Future<void> _saveClipMetadata({
    required String roomId,
    required String userId,
    required String clipTitle,
    required String clipUrl,
    required Duration duration,
  }) async {
    try {
      await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'audio_clips',
        documentId: 'unique()',
        data: {
          'roomId': roomId,
          'userId': userId,
          'clipTitle': clipTitle,
          'clipUrl': clipUrl,
          'duration': duration.inSeconds,
          'createdAt': DateTime.now().toIso8601String(),
          'isPublic': true, // Default to public for sharing
        },
      );
      
      _logger.info('✅ Audio clip metadata saved to database');
      
    } catch (e) {
      _logger.error('Error saving clip metadata: $e');
    }
  }


  /// Cancel ongoing recording
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        _recordingTimer?.cancel();
        _isRecording = false;
        
        _logger.info('Audio clip recording cancelled - SIMULATION MODE');
      }
    } catch (e) {
      _logger.error('Error cancelling recording: $e');
    }
  }

  /// Get user's audio clips for a room
  Future<List<Map<String, dynamic>>> getRoomAudioClips(String roomId) async {
    try {
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'audio_clips',
        queries: [
          Query.equal('roomId', roomId),
          Query.equal('isPublic', true),
          Query.orderDesc('createdAt'),
          Query.limit(50),
        ],
      );
      
      return response.documents.map((doc) => doc.data).toList();
      
    } catch (e) {
      _logger.error('Error fetching audio clips: $e');
      return [];
    }
  }

  /// Share audio clip to social media
  Future<void> shareAudioClip({
    required String clipUrl,
    required String clipTitle,
    required String roomName,
  }) async {
    try {
      final shareText = '''🎙️ Listen to this highlight from our debate!

"$clipTitle"

From: $roomName

🔗 $clipUrl

#ArenaDebate #AudioClip #Debate #Highlight''';

      // Use Share Plus plugin
      await Share.share(shareText, subject: 'Arena Debate Highlight');
      
    } catch (e) {
      _logger.error('Error sharing audio clip: $e');
    }
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;
  
  /// Get remaining recording time
  Duration? get remainingTime {
    if (!_isRecording || _recordingStartTime == null) return null;
    
    final elapsed = DateTime.now().difference(_recordingStartTime!);
    final remaining = const Duration(seconds: 30) - elapsed;
    
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Audio clip model
class AudioClip {
  final String id;
  final String roomId;
  final String userId;
  final String clipTitle;
  final String clipUrl;
  final int duration;
  final DateTime createdAt;
  final bool isPublic;

  AudioClip({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.clipTitle,
    required this.clipUrl,
    required this.duration,
    required this.createdAt,
    required this.isPublic,
  });

  factory AudioClip.fromMap(Map<String, dynamic> map) {
    return AudioClip(
      id: map['\$id'] ?? '',
      roomId: map['roomId'] ?? '',
      userId: map['userId'] ?? '',
      clipTitle: map['clipTitle'] ?? '',
      clipUrl: map['clipUrl'] ?? '',
      duration: map['duration'] ?? 0,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      isPublic: map['isPublic'] ?? false,
    );
  }
}