import '../core/logging/app_logger.dart';

/// Client-side rate limiting service
///
/// Provides basic rate limiting for client-side operations.
/// For production, implement server-side rate limiting via API gateway or Appwrite Functions.
///
/// This client-side implementation helps prevent:
/// - Accidental rapid-fire requests
/// - Basic abuse scenarios
/// - UI responsiveness issues from spam clicks
///
/// It does NOT prevent:
/// - Determined attackers (can bypass client code)
/// - Distributed attacks (multiple devices/IPs)
/// - API-level abuse
class RateLimitService {
  static final RateLimitService _instance = RateLimitService._internal();
  factory RateLimitService() => _instance;
  RateLimitService._internal();

  final AppLogger _logger = AppLogger();

  // Track action timestamps per user
  final Map<String, List<DateTime>> _actionHistory = {};

  // Rate limit configurations (action type → max requests per time window)
  static const Map<String, RateLimitConfig> _limits = {
    'login': RateLimitConfig(maxRequests: 5, windowMinutes: 15),
    'create_room': RateLimitConfig(maxRequests: 3, windowMinutes: 1),
    'send_message': RateLimitConfig(maxRequests: 10, windowMinutes: 1),
    'send_gift': RateLimitConfig(maxRequests: 20, windowMinutes: 1),
    'raise_hand': RateLimitConfig(maxRequests: 5, windowMinutes: 1),
    'join_room': RateLimitConfig(maxRequests: 10, windowMinutes: 1),
    'ban_user': RateLimitConfig(maxRequests: 10, windowMinutes: 5),
    'kick_user': RateLimitConfig(maxRequests: 20, windowMinutes: 5),
    'upload_file': RateLimitConfig(maxRequests: 5, windowMinutes: 10),
    'update_profile': RateLimitConfig(maxRequests: 5, windowMinutes: 5),
    'default': RateLimitConfig(maxRequests: 30, windowMinutes: 1),
  };

  /// Check if an action is allowed under rate limits
  ///
  /// Returns true if action is allowed, false if rate limited.
  /// Throws RateLimitExceededException with details if rate limit exceeded.
  bool checkRateLimit({
    required String userId,
    required String action,
  }) {
    final key = '${userId}_$action';
    final config = _limits[action] ?? _limits['default']!;
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(minutes: config.windowMinutes));

    // Initialize history if needed
    _actionHistory[key] ??= [];

    // Remove old entries outside the time window
    _actionHistory[key]!.removeWhere((timestamp) => timestamp.isBefore(windowStart));

    // Check if limit exceeded
    if (_actionHistory[key]!.length >= config.maxRequests) {
      final oldestAction = _actionHistory[key]!.first;
      final retryAfter = oldestAction.add(Duration(minutes: config.windowMinutes));
      final waitSeconds = retryAfter.difference(now).inSeconds;

      _logger.warning(
        '⚠️ Rate limit exceeded for user $userId, action: $action '
        '(${_actionHistory[key]!.length}/${config.maxRequests} in ${config.windowMinutes}min)'
      );

      throw RateLimitExceededException(
        action: action,
        maxRequests: config.maxRequests,
        windowMinutes: config.windowMinutes,
        retryAfterSeconds: waitSeconds > 0 ? waitSeconds : 0,
      );
    }

    // Record this action
    _actionHistory[key]!.add(now);
    return true;
  }

  /// Get remaining requests for an action
  int getRemainingRequests({
    required String userId,
    required String action,
  }) {
    final key = '${userId}_$action';
    final config = _limits[action] ?? _limits['default']!;
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(minutes: config.windowMinutes));

    // Clean up old entries
    _actionHistory[key]?.removeWhere((timestamp) => timestamp.isBefore(windowStart));

    final used = _actionHistory[key]?.length ?? 0;
    return config.maxRequests - used;
  }

  /// Clear rate limit history for a user (use after successful auth, etc.)
  void clearHistory({String? userId, String? action}) {
    if (userId != null && action != null) {
      _actionHistory.remove('${userId}_$action');
    } else if (userId != null) {
      _actionHistory.removeWhere((key, _) => key.startsWith('${userId}_'));
    } else {
      _actionHistory.clear();
    }
  }

  /// Cleanup old entries (call periodically to prevent memory leaks)
  void cleanup() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 1));

    _actionHistory.forEach((key, timestamps) {
      timestamps.removeWhere((timestamp) => timestamp.isBefore(cutoff));
    });

    _actionHistory.removeWhere((_, timestamps) => timestamps.isEmpty);
  }
}

/// Rate limit configuration
class RateLimitConfig {
  final int maxRequests;
  final int windowMinutes;

  const RateLimitConfig({
    required this.maxRequests,
    required this.windowMinutes,
  });
}

/// Exception thrown when rate limit is exceeded
class RateLimitExceededException implements Exception {
  final String action;
  final int maxRequests;
  final int windowMinutes;
  final int retryAfterSeconds;

  RateLimitExceededException({
    required this.action,
    required this.maxRequests,
    required this.windowMinutes,
    required this.retryAfterSeconds,
  });

  @override
  String toString() {
    final minutes = retryAfterSeconds > 60
        ? '${(retryAfterSeconds / 60).ceil()} minute(s)'
        : '$retryAfterSeconds second(s)';

    return 'Rate limit exceeded for $action. '
        'Maximum $maxRequests requests per $windowMinutes minute(s). '
        'Try again in $minutes.';
  }

  String get userMessage {
    if (retryAfterSeconds > 60) {
      final minutes = (retryAfterSeconds / 60).ceil();
      return 'Slow down! Please try again in $minutes minute${minutes > 1 ? 's' : ''}.';
    } else {
      return 'Slow down! Please wait $retryAfterSeconds seconds before trying again.';
    }
  }
}
