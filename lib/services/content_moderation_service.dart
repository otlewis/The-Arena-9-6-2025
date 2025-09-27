import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:appwrite/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Comprehensive content moderation service with AI and human moderation
class ContentModerationService {
  static final ContentModerationService _instance = ContentModerationService._internal();
  factory ContentModerationService() => _instance;
  ContentModerationService._internal();

  final AppwriteService _appwrite = AppwriteService();
  final AppLogger _logger = AppLogger();
  
  // Database configuration
  static const String _databaseId = 'arena_db';
  
  // OpenAI Moderation API configuration (free tier available)
  static const String _openaiModerationUrl = 'https://api.openai.com/v1/moderations';
  static const String _openaiApiKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: ''); // Set via environment variable

  // Google Perspective API configuration (fallback)
  static const String _perspectiveApiUrl = 'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze';
  static const String _perspectiveApiKey = 'YOUR_PERSPECTIVE_API_KEY'; // Replace with actual key

  /// Report a user for inappropriate behavior
  Future<String> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String roomId,
    required String reportType,
    required String description,
    String? messageId,
    String? screenshot,
  }) async {
    try {
      final evidenceMap = {
        'messageId': messageId,
        'screenshot': screenshot,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final reportData = {
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'roomId': roomId,
        'reportType': reportType,
        'description': description,
        'evidence': json.encode(evidenceMap),
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final result = await _appwrite.databases.createDocument(
        databaseId: _databaseId,
        collectionId: 'user_reports',
        documentId: 'unique()',
        data: reportData,
      );

      _logger.info('🚨 User report created: ${result.$id}');
      
      // Add to moderation queue for review
      await _addToModerationQueue(
        itemType: 'user',
        itemId: reportedUserId,
        reason: 'User reported for $reportType',
        priority: _calculatePriority(reportType),
      );

      // Check if this user has multiple recent reports
      await _checkForMultipleReports(reportedUserId);

      return result.$id;
    } catch (e) {
      _logger.error('Failed to create user report: $e');
      rethrow;
    }
  }

  /// Analyze message content using Google Perspective API
  Future<Map<String, double>> analyzeContent(String content) async {
    try {
      // Try OpenAI Moderation API first
      if (_openaiApiKey != 'YOUR_OPENAI_API_KEY') {
        return await _analyzeWithOpenAI(content);
      }

      // Fallback to Google Perspective if OpenAI not configured
      if (_perspectiveApiKey != 'YOUR_PERSPECTIVE_API_KEY') {
        return await _analyzeWithPerspective(content);
      }

      // Use mock analysis if no APIs configured
      _logger.warning('🤖 No AI API keys configured - using mock moderation for testing');
      return _mockContentAnalysis(content);
    } catch (e) {
      _logger.error('Content analysis failed: $e');
      return _mockContentAnalysis(content); // Fallback to mock
    }
  }

  /// Analyze content using OpenAI Moderation API
  Future<Map<String, double>> _analyzeWithOpenAI(String content) async {
    try {
      _logger.info('🤖 Using OpenAI Moderation API for content analysis');

      final requestBody = {
        'input': content,
      };

      final response = await http.post(
        Uri.parse(_openaiModerationUrl),
        headers: {
          'Authorization': 'Bearer $_openaiApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'][0];

        // Map OpenAI categories to our scoring system
        final scores = <String, double>{
          'toxicity': _getBoolScore(results['categories']['hate']) * 0.8 +
                     _getBoolScore(results['categories']['harassment']) * 0.9,
          'threat': _getBoolScore(results['categories']['violence']) * 0.9 +
                   _getBoolScore(results['categories']['violence/graphic']) * 0.7,
          'insult': _getBoolScore(results['categories']['harassment']) * 0.8,
          'profanity': _getBoolScore(results['categories']['hate']) * 0.5,
          'identity_attack': _getBoolScore(results['categories']['hate']) * 0.9,
          'self_harm': _getBoolScore(results['categories']['self-harm']) * 1.0,
        };

        // Ensure scores don't exceed 1.0
        scores.updateAll((key, value) => value > 1.0 ? 1.0 : value);

        _logger.info('🤖 OpenAI analysis: $scores');
        return scores;
      } else {
        _logger.error('OpenAI API error: ${response.statusCode} - ${response.body}');
        return _mockContentAnalysis(content); // Fallback to mock
      }
    } catch (e) {
      _logger.error('OpenAI analysis failed: $e');
      return _mockContentAnalysis(content); // Fallback to mock
    }
  }

  /// Analyze content using Google Perspective API (fallback)
  Future<Map<String, double>> _analyzeWithPerspective(String content) async {
    try {
      _logger.info('🤖 Using Google Perspective API for content analysis');

      final requestBody = {
        'requestedAttributes': {
          'TOXICITY': {},
          'SEVERE_TOXICITY': {},
          'IDENTITY_ATTACK': {},
          'INSULT': {},
          'PROFANITY': {},
          'THREAT': {},
        },
        'comment': {'text': content},
        'languages': ['en'],
      };

      final response = await http.post(
        Uri.parse('$_perspectiveApiUrl?key=$_perspectiveApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final scores = <String, double>{};

        final attributeScores = data['attributeScores'] as Map<String, dynamic>;
        for (final entry in attributeScores.entries) {
          final score = entry.value['summaryScore']['value'] as double;
          scores[entry.key.toLowerCase()] = score;
        }

        _logger.info('🤖 Perspective analysis: $scores');
        return scores;
      } else {
        _logger.error('Perspective API error: ${response.statusCode}');
        return _mockContentAnalysis(content); // Fallback to mock
      }
    } catch (e) {
      _logger.error('Perspective analysis failed: $e');
      return _mockContentAnalysis(content); // Fallback to mock
    }
  }

  /// Convert OpenAI boolean results to scores
  double _getBoolScore(dynamic value) {
    if (value is bool) return value ? 1.0 : 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  /// Mock content analysis for testing when API key is not configured
  Map<String, double> _mockContentAnalysis(String content) {
    final contentLower = content.toLowerCase();

    // Simple hostile word detection for testing
    final hostileWords = [
      'hate', 'stupid', 'idiot', 'moron', 'damn', 'hell', 'shut up',
      'you suck', 'loser', 'pathetic', 'worthless', 'garbage', 'trash',
      'kill yourself', 'die', 'terrorist', 'nazi', 'fascist', 'fuck', 'shit'
    ];

    double toxicityScore = 0.0;
    double threatScore = 0.0;
    double insultScore = 0.0;
    double profanityScore = 0.0;
    double identityAttackScore = 0.0;

    // Check for hostile content
    for (final word in hostileWords) {
      if (contentLower.contains(word)) {
        if (word.contains('kill') || word.contains('die') || word.contains('terrorist')) {
          threatScore = 0.95; // Very high threat
          toxicityScore = 0.9;
          identityAttackScore = 0.8;
        } else if (word.contains('nazi') || word.contains('fascist')) {
          identityAttackScore = 0.9; // High identity attack
          toxicityScore = 0.85;
        } else if (word.contains('hate')) {
          toxicityScore = 0.8; // High toxicity
          insultScore = 0.7;
        } else if (word.contains('stupid') || word.contains('idiot') || word.contains('moron') || word.contains('loser') || word.contains('pathetic')) {
          insultScore = 0.8; // High insult
          toxicityScore = 0.7;
        } else if (word.contains('fuck') || word.contains('shit')) {
          profanityScore = 0.85; // High profanity
          toxicityScore = 0.6;
        } else if (word.contains('damn') || word.contains('hell')) {
          profanityScore = 0.6; // Moderate profanity
          toxicityScore = 0.5;
        } else {
          toxicityScore = 0.4; // Default mild toxicity
          insultScore = 0.3;
        }
        break; // Stop after first match to avoid overscoring
      }
    }

    final scores = {
      'toxicity': toxicityScore,
      'threat': threatScore,
      'insult': insultScore,
      'profanity': profanityScore,
      'identity_attack': identityAttackScore,
    };

    _logger.info('🤖 Mock AI Analysis: "${content.substring(0, content.length > 30 ? 30 : content.length)}..." -> $scores');

    return scores;
  }

  /// Take moderation action against a user
  Future<void> takeAction({
    required String moderatorId,
    required String targetUserId,
    required String action,
    required String reason,
    String? roomId,
    int? durationMinutes,
    String? reportId,
    bool automated = false,
    Map<String, double>? aiScores,
  }) async {
    try {
      final actionData = {
        'moderatorId': moderatorId,
        'targetUserId': targetUserId,
        'roomId': roomId,
        'action': action,
        'duration': durationMinutes,
        'reason': reason,
        'reportId': reportId,
        'automated': automated,
        'aiScore': aiScores != null ? {
          'toxicity': aiScores['toxicity'],
          'threat': aiScores['threat'],
          'profanity': aiScores['profanity'],
        } : null,
        'expiresAt': durationMinutes != null 
            ? DateTime.now().add(Duration(minutes: durationMinutes)).toIso8601String()
            : null,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _appwrite.databases.createDocument(
        databaseId: _databaseId,
        collectionId: 'moderation_actions',
        documentId: 'unique()',
        data: actionData,
      );

      // Update user violation record
      await _updateUserViolations(targetUserId, action, reason);

      // Execute the action
      await _executeAction(action, targetUserId, roomId, durationMinutes);

      _logger.info('⚖️ Moderation action taken: $action against $targetUserId');
    } catch (e) {
      _logger.error('Failed to take moderation action: $e');
      rethrow;
    }
  }

  /// Check if user should be automatically moderated
  Future<void> autoModerateContent(String content, String userId, String roomId) async {
    final scores = await analyzeContent(content);
    
    // Define thresholds
    const highToxicity = 0.8;
    const mediumToxicity = 0.6;
    const highThreat = 0.7;
    const highProfanity = 0.8;

    final toxicity = scores['toxicity'] ?? 0.0;
    final threat = scores['threat'] ?? 0.0;
    final profanity = scores['profanity'] ?? 0.0;

    if (toxicity > highToxicity || threat > highThreat) {
      // High severity - immediate action
      await takeAction(
        moderatorId: 'system',
        targetUserId: userId,
        action: 'mute',
        reason: 'Automated: High toxicity/threat detected',
        roomId: roomId,
        durationMinutes: 30,
        automated: true,
        aiScores: scores,
      );
    } else if (toxicity > mediumToxicity || profanity > highProfanity) {
      // Medium severity - warning
      await takeAction(
        moderatorId: 'system',
        targetUserId: userId,
        action: 'warning',
        reason: 'Automated: Inappropriate content detected',
        roomId: roomId,
        automated: true,
        aiScores: scores,
      );
    }

    // Always flag for human review if any scores are concerning
    if (toxicity > 0.5 || threat > 0.5 || profanity > 0.6) {
      await _addToModerationQueue(
        itemType: 'message',
        itemId: 'content-${DateTime.now().millisecondsSinceEpoch}',
        reason: 'AI flagged content for review',
        priority: toxicity > 0.8 ? 'high' : 'medium',
        aiAnalysis: scores,
      );
    }
  }

  /// Block another user (personal block, not global ban)
  Future<void> blockUser(String userId, String blockedUserId, {String? reason}) async {
    try {
      final blockData = {
        'userId': userId,
        'blockedUserId': blockedUserId,
        'reason': reason,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _appwrite.databases.createDocument(
        databaseId: _databaseId,
        collectionId: 'blocked_users',
        documentId: 'unique()',
        data: blockData,
      );

      _logger.info('🚫 User $userId blocked $blockedUserId');
    } catch (e) {
      _logger.error('Failed to block user: $e');
      rethrow;
    }
  }

  /// Submit an appeal for a ban/suspension
  Future<String> submitAppeal({
    required String userId,
    required String actionId,
    required String appealReason,
    String? evidence,
  }) async {
    try {
      final appealData = {
        'userId': userId,
        'actionId': actionId,
        'appealReason': appealReason,
        'evidence': evidence,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final result = await _appwrite.databases.createDocument(
        databaseId: _databaseId,
        collectionId: 'appeals',
        documentId: 'unique()',
        data: appealData,
      );

      _logger.info('📝 Appeal submitted: ${result.$id}');
      return result.$id;
    } catch (e) {
      _logger.error('Failed to submit appeal: $e');
      rethrow;
    }
  }

  /// Get user's moderation status
  Future<Map<String, dynamic>> getUserModerationStatus(String userId) async {
    try {
      // Get user violations
      final violations = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: 'user_violations',
        queries: [Query.equal('userId', userId)],
      );

      // Get active moderation actions
      final actions = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: 'moderation_actions',
        queries: [
          Query.equal('targetUserId', userId),
          Query.orderDesc('createdAt'),
          Query.limit(10),
        ],
      );

      final violationData = violations.documents.isNotEmpty 
          ? violations.documents.first.data 
          : null;

      return {
        'isBanned': violationData?['status'] == 'banned',
        'isMuted': violationData?['status'] == 'muted',
        'warningCount': violationData?['warningCount'] ?? 0,
        'strikeCount': violationData?['strikeCount'] ?? 0,
        'banExpiresAt': violationData?['banExpiresAt'],
        'muteExpiresAt': violationData?['muteExpiresAt'],
        'recentActions': actions.documents.map((doc) => doc.data).toList(),
      };
    } catch (e) {
      _logger.error('Failed to get user moderation status: $e');
      return {};
    }
  }

  /// Helper methods

  String _calculatePriority(String reportType) {
    switch (reportType) {
      case 'threat':
      case 'doxxing':
        return 'urgent';
      case 'harassment':
      case 'hate_speech':
        return 'high';
      case 'spam':
      case 'inappropriate':
        return 'medium';
      default:
        return 'low';
    }
  }

  Future<void> _addToModerationQueue({
    required String itemType,
    required String itemId,
    required String reason,
    required String priority,
    Map<String, double>? aiAnalysis,
  }) async {
    final queueData = {
      'itemType': itemType,
      'itemId': itemId,
      'reason': reason,
      'priority': priority,
      'aiAnalysis': aiAnalysis != null ? json.encode(aiAnalysis) : null,
      'reportCount': 1,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    };

    await _appwrite.databases.createDocument(
      databaseId: _databaseId,
      collectionId: 'moderation_queue',
      documentId: 'unique()',
      data: queueData,
    );
  }

  Future<void> _checkForMultipleReports(String userId) async {
    // Check for reports in last 24 hours
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    
    final recentReports = await _appwrite.databases.listDocuments(
      databaseId: _databaseId,
      collectionId: 'user_reports',
      queries: [
        Query.equal('reportedUserId', userId),
        Query.greaterThan('createdAt', yesterday.toIso8601String()),
      ],
    );

    // If 3+ reports in 24 hours, escalate
    if (recentReports.documents.length >= 3) {
      await _addToModerationQueue(
        itemType: 'user',
        itemId: userId,
        reason: 'Multiple reports (${recentReports.documents.length}) in 24 hours',
        priority: 'high',
      );
    }
  }

  Future<void> _updateUserViolations(String userId, String action, String reason) async {
    try {
      // Get existing violations or create new
      final existing = await _appwrite.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: 'user_violations',
        queries: [Query.equal('userId', userId)],
      );

      final violationData = existing.documents.isNotEmpty 
          ? Map<String, dynamic>.from(existing.documents.first.data)
          : {
            'userId': userId,
            'violationType': 'various',
            'severity': 'medium',
            'warningCount': 0,
            'strikeCount': 0,
            'status': 'active',
            'createdAt': DateTime.now().toIso8601String(),
          };

      // Update counts based on action
      if (action == 'warning') {
        violationData['warningCount'] = (violationData['warningCount'] ?? 0) + 1;
      } else if (['mute', 'kick', 'ban'].contains(action)) {
        violationData['strikeCount'] = (violationData['strikeCount'] ?? 0) + 1;
      }

      violationData['lastViolation'] = DateTime.now().toIso8601String();
      violationData['updatedAt'] = DateTime.now().toIso8601String();

      if (existing.documents.isNotEmpty) {
        await _appwrite.databases.updateDocument(
          databaseId: _databaseId,
          collectionId: 'user_violations',
          documentId: existing.documents.first.$id,
          data: violationData,
        );
      } else {
        await _appwrite.databases.createDocument(
          databaseId: _databaseId,
          collectionId: 'user_violations',
          documentId: 'unique()',
          data: violationData,
        );
      }
    } catch (e) {
      _logger.error('Failed to update user violations: $e');
    }
  }

  Future<void> _executeAction(String action, String userId, String? roomId, int? durationMinutes) async {
    // Implementation depends on your specific needs
    // For now, this is a placeholder for actual enforcement
    switch (action) {
      case 'kick':
        // Remove user from current room
        _logger.info('🥾 Kicking user $userId from room $roomId');
        break;
      case 'mute':
        // Disable user's ability to speak/chat
        _logger.info('🔇 Muting user $userId for ${durationMinutes ?? 'indefinite'} minutes');
        break;
      case 'ban':
        // Prevent user from accessing the platform
        _logger.info('🚫 Banning user $userId for ${durationMinutes ?? 'indefinite'} minutes');
        break;
      case 'warning':
        // Send warning notification to user
        _logger.info('⚠️ Warning issued to user $userId');
        break;
    }
  }
}