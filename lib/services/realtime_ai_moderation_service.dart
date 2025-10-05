import 'dart:async';
import 'package:livekit_client/livekit_client.dart';
import 'package:appwrite/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';
import 'livekit_service.dart';
import 'content_moderation_service.dart';

/// Real-time AI moderation for hostile speech in Arena rooms
/// Monitors audio and text for violations and takes automatic action
class RealtimeAIModerationService {
  static final RealtimeAIModerationService _instance = RealtimeAIModerationService._internal();
  factory RealtimeAIModerationService() => _instance;
  RealtimeAIModerationService._internal();

  final AppLogger _logger = AppLogger();
  final ContentModerationService _contentModeration = ContentModerationService();
  final AppwriteService _appwrite = AppwriteService();
  final LiveKitService _livekit = LiveKitService();

  // Configuration - Temporarily disabled auto-mute to fix user reports of unwanted muting
  static const bool _enableAutoMute = false; // TODO: Re-enable with better thresholds after testing
  static const bool _enableAutoBan = true;
  static const double _hostilityThreshold = 0.7;
  static const double _severeHostilityThreshold = 0.9;

  // Tracking
  final Map<String, int> _userViolations = {};
  final Map<String, DateTime> _lastViolation = {};
  final Map<String, StreamSubscription> _audioStreams = {};

  // Deepgram API for speech-to-text (free tier available)
  // static const String _deepgramApiKey = 'YOUR_DEEPGRAM_API_KEY'; // Add to env
  // static const String _deepgramUrl = 'wss://api.deepgram.com/v1/listen';

  /// Start monitoring a room for hostile speech
  Future<void> startRoomMonitoring(String roomId) async {
    try {
      print('DEBUG: startRoomMonitoring called with roomId: $roomId');
      _logger.info('🛡️ Starting AI moderation for room: $roomId (${roomId.runtimeType})');
      _logger.info('🛡️ Room ID length: ${roomId.length}');

      // Test OpenAI API immediately
      print('DEBUG: About to test OpenAI API');
      _logger.info('🤖 Testing OpenAI API connection...');
      final testScores = await _contentModeration.analyzeContent('test message');
      print('DEBUG: OpenAI test completed with scores: $testScores');
      _logger.info('🤖 OpenAI test successful: $testScores');

      // Monitor text messages
      print('DEBUG: About to setup chat monitoring');
      _monitorChatMessages(roomId);

      // Monitor audio streams
      await _monitorAudioStreams(roomId);

      print('DEBUG: AI moderation setup completed');
      _logger.info('✅ AI moderation active for room: $roomId');
    } catch (e) {
      print('DEBUG: ERROR in startRoomMonitoring: $e');
      _logger.error('Failed to start room monitoring: $e');
    }
  }

  /// Monitor chat messages for hostile content
  void _monitorChatMessages(String roomId) {
    _logger.info('🛡️ Setting up chat monitoring for room: $roomId');
    _logger.info('🛡️ Room ID type: ${roomId.runtimeType}, length: ${roomId.length}');

    // Subscribe to room messages via Appwrite realtime
    _appwrite.realtimeInstance.subscribe([
      'databases.arena_db.collections.discussion_chat_messages.documents'
    ]).stream.listen((event) async {
      _logger.info('🛡️ ===== CHAT EVENT RECEIVED =====');
      _logger.info('🛡️ Event type: ${event.events}');
      _logger.info('🛡️ Full payload: ${event.payload}');

      final eventRoomId = event.payload['roomId'] as String?;
      _logger.info('🛡️ Event roomId: "$eventRoomId" (${eventRoomId?.runtimeType})');
      _logger.info('🛡️ Target roomId: "$roomId" (${roomId.runtimeType})');
      _logger.info('🛡️ Room IDs match: ${eventRoomId == roomId}');

      if (eventRoomId != roomId) {
        _logger.warning('🛡️ SKIPPING EVENT - Room ID mismatch!');
        _logger.warning('🛡️ Expected: "$roomId"');
        _logger.warning('🛡️ Received: "$eventRoomId"');
        return;
      }

      final message = event.payload['message'] as String? ?? '';
      final userId = event.payload['userId'] as String? ?? '';
      final userName = event.payload['userName'] as String? ?? 'Unknown';

      _logger.info('🛡️ ===== PROCESSING MESSAGE =====');
      _logger.info('🛡️ User: $userName ($userId)');
      _logger.info('🛡️ Message: "$message"');
      _logger.info('🛡️ Room: $roomId');

      await _moderateTextContent(
        content: message,
        userId: userId,
        userName: userName,
        roomId: roomId,
        source: 'chat',
      );
    }, onError: (error) {
      _logger.error('🛡️ Chat monitoring error: $error');
    });

    _logger.info('🛡️ Chat monitoring subscription established for room: $roomId');
  }

  /// Monitor audio streams for hostile speech
  Future<void> _monitorAudioStreams(String roomId) async {
    if (_livekit.room == null) return;

    // Monitor each participant's audio
    for (final participant in _livekit.room!.remoteParticipants.values) {
      await _monitorParticipantAudio(participant, roomId);
    }

    // Listen for new participants - simplified approach
    // Note: Advanced event listening will be added when LiveKit SDK supports it
    _logger.info('Audio monitoring setup complete for ${_livekit.room!.remoteParticipants.length} participants');
  }

  /// Monitor individual participant's audio
  Future<void> _monitorParticipantAudio(
    RemoteParticipant participant,
    String roomId,
  ) async {
    try {
      // For now, simplified audio monitoring without direct track access
      // Future enhancement: Add real-time audio transcription when available
      _logger.info('🎤 Audio monitoring setup for ${participant.identity}');

      // Note: Real-time audio transcription will be implemented when
      // LiveKit SDK provides better access to audio streams

    } catch (e) {
      _logger.error('Failed to monitor participant audio: $e');
    }
  }


  /// Moderate text content for hostility
  Future<void> _moderateTextContent({
    required String content,
    required String userId,
    required String userName,
    required String roomId,
    required String source,
  }) async {
    try {
      _logger.info('🤖 Analyzing content from $userName: "$content"');

      // Analyze content using Google Perspective API
      final scores = await _contentModeration.analyzeContent(content);

      _logger.debug('🤖 AI scores received: $scores');

      final toxicity = scores['toxicity'] ?? 0.0;
      final threat = scores['threat'] ?? 0.0;
      final insult = scores['insult'] ?? 0.0;
      final profanity = scores['profanity'] ?? 0.0;

      // Calculate overall hostility score
      final hostilityScore = [toxicity, threat * 1.5, insult, profanity].reduce((a, b) => a > b ? a : b);

      _logger.debug('🔍 Moderation scores for $userName: '
          'Toxicity: ${(toxicity * 100).toInt()}%, '
          'Threat: ${(threat * 100).toInt()}%, '
          'Hostility: ${(hostilityScore * 100).toInt()}%');

      // Take action based on severity
      if (hostilityScore >= _severeHostilityThreshold) {
        await _handleSevereViolation(userId, userName, roomId, content, scores, source);
      } else if (hostilityScore >= _hostilityThreshold) {
        await _handleModerateViolation(userId, userName, roomId, content, scores, source);
      } else if (hostilityScore >= 0.5) {
        await _issueWarning(userId, userName, roomId, content, scores, source);
      }

    } catch (e) {
      _logger.error('Content moderation failed: $e');
    }
  }

  /// Handle severe violations (immediate mute + possible ban)
  Future<void> _handleSevereViolation(
    String userId,
    String userName,
    String roomId,
    String content,
    Map<String, double> scores,
    String source,
  ) async {
    _logger.warning('🚨 SEVERE VIOLATION by $userName: ${_censorContent(content)}');

    // Track violation
    _userViolations[userId] = (_userViolations[userId] ?? 0) + 3;
    _lastViolation[userId] = DateTime.now();

    // Immediate mute
    if (_enableAutoMute) {
      await _muteUser(userId, roomId);
      _logger.info('🔇 Auto-muted $userName for severe hostility');
    }

    // Ban after multiple severe violations
    if (_enableAutoBan && (_userViolations[userId] ?? 0) >= 5) {
      await _banUser(userId, roomId, 'Multiple severe violations');
      _logger.info('🚫 Auto-banned $userName for repeated violations');
    }

    // Log to database
    await _logViolation(
      userId: userId,
      userName: userName,
      roomId: roomId,
      content: content,
      severity: 'severe',
      action: 'mute',
      scores: scores,
      source: source,
    );

    // Notify moderators
    await _notifyModerators(
      roomId: roomId,
      message: '🚨 Severe violation by $userName (auto-muted)',
      userId: userId,
      content: content,
    );
  }

  /// Handle moderate violations (warning + temp mute)
  Future<void> _handleModerateViolation(
    String userId,
    String userName,
    String roomId,
    String content,
    Map<String, double> scores,
    String source,
  ) async {
    _logger.warning('⚠️ Moderate violation by $userName');

    // Track violation
    _userViolations[userId] = (_userViolations[userId] ?? 0) + 1;
    _lastViolation[userId] = DateTime.now();

    // Mute after 2 violations in 5 minutes
    final recentViolations = _isRecentViolation(userId);
    if (recentViolations && (_userViolations[userId] ?? 0) >= 2) {
      if (_enableAutoMute) {
        await _muteUser(userId, roomId);
        _logger.info('🔇 Temp-muted $userName for repeated violations');
      }
    }

    // Log violation
    await _logViolation(
      userId: userId,
      userName: userName,
      roomId: roomId,
      content: content,
      severity: 'moderate',
      action: recentViolations ? 'mute' : 'warning',
      scores: scores,
      source: source,
    );

    // Send warning to user
    await _sendWarningToUser(userId, userName, 'hostile speech');
  }

  /// Issue warning for mild violations
  Future<void> _issueWarning(
    String userId,
    String userName,
    String roomId,
    String content,
    Map<String, double> scores,
    String source,
  ) async {
    _logger.info('📢 Warning issued to $userName');

    // Log warning
    await _logViolation(
      userId: userId,
      userName: userName,
      roomId: roomId,
      content: content,
      severity: 'mild',
      action: 'warning',
      scores: scores,
      source: source,
    );

    // Send warning
    await _sendWarningToUser(userId, userName, 'inappropriate language');
  }

  /// Mute user in LiveKit room
  Future<void> _muteUser(String userId, String roomId) async {
    try {
      // Mute via LiveKit service
      await _livekit.muteParticipant(userId);

      // Also update room participant status
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        documentId: '$roomId-$userId',
        data: {
          'isMuted': true,
          'mutedAt': DateTime.now().toIso8601String(),
          'muteReason': 'AI: Hostile speech detected',
        },
      );
    } catch (e) {
      _logger.error('Failed to mute user: $e');
    }
  }

  /// Ban user from room
  Future<void> _banUser(String userId, String roomId, String reason) async {
    try {
      // For now, we'll mark as banned in database
      // LiveKit participant removal will be implemented with proper admin API
      _logger.warning('Banning user $userId: $reason');

      // Update database
      await _appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_participants',
        documentId: '$roomId-$userId',
        data: {
          'status': 'banned',
          'bannedAt': DateTime.now().toIso8601String(),
          'banReason': reason,
        },
      );
    } catch (e) {
      _logger.error('Failed to ban user: $e');
    }
  }

  /// Log violation to database
  Future<void> _logViolation({
    required String userId,
    required String userName,
    required String roomId,
    required String content,
    required String severity,
    required String action,
    required Map<String, double> scores,
    required String source,
  }) async {
    try {
      await _appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'ai_moderation_logs',
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'userName': userName,
          'roomId': roomId,
          'content': _censorContent(content),
          'severity': severity,
          'action': action,
          'scores': scores,
          'source': source,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      _logger.error('Failed to log violation: $e');
    }
  }

  /// Send warning to user
  Future<void> _sendWarningToUser(String userId, String userName, String reason) async {
    // Send via your notification system
    _logger.info('⚠️ Warning sent to $userName: Please avoid $reason');
  }

  /// Notify moderators of violations
  Future<void> _notifyModerators({
    required String roomId,
    required String message,
    required String userId,
    required String content,
  }) async {
    // Send to moderator dashboard
    _logger.info('📨 Moderator notification: $message');
  }

  /// Check if user had recent violation
  bool _isRecentViolation(String userId) {
    final lastTime = _lastViolation[userId];
    if (lastTime == null) return false;
    return DateTime.now().difference(lastTime).inMinutes < 5;
  }

  /// Censor inappropriate content for logs
  String _censorContent(String content) {
    // Replace bad words with asterisks
    return content.replaceAll(RegExp(r'\b(fuck|shit|damn|hell)\b', caseSensitive: false), '***');
  }

  /// Stop monitoring room
  void stopRoomMonitoring(String roomId) {
    _logger.info('🛑 Stopping AI moderation for room: $roomId');

    // Cancel audio streams
    for (final stream in _audioStreams.values) {
      stream.cancel();
    }
    _audioStreams.clear();

    // Clear violation tracking
    _userViolations.clear();
    _lastViolation.clear();
  }
}