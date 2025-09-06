import 'dart:convert';

/// Monthly Ranking Model for Gamified Arena System
/// Tracks user's monthly performance, tier, and achievements
class MonthlyRanking {
  final String id;
  final String userId;
  final String monthKey; // Format: "2024-03"
  final int monthlyPoints;
  final int monthlyWins;
  final int monthlyLosses;
  final int currentWinStreak;
  final int bestWinStreak;
  final int activityXP;
  final String tier; // bronze, silver, gold, platinum, diamond
  final int globalRank;
  final List<String> achievementsEarned;
  final DateTime lastUpdated;
  final DateTime createdAt;

  MonthlyRanking({
    required this.id,
    required this.userId,
    required this.monthKey,
    this.monthlyPoints = 0,
    this.monthlyWins = 0,
    this.monthlyLosses = 0,
    this.currentWinStreak = 0,
    this.bestWinStreak = 0,
    this.activityXP = 0,
    this.tier = 'bronze',
    this.globalRank = 0,
    this.achievementsEarned = const [],
    required this.lastUpdated,
    required this.createdAt,
  });

  /// Get total monthly score (points + activity XP)
  int get totalScore => monthlyPoints + activityXP;

  /// Get win rate percentage
  double get winRate {
    final totalDebates = monthlyWins + monthlyLosses;
    if (totalDebates == 0) return 0.0;
    return (monthlyWins / totalDebates) * 100;
  }

  /// Get formatted tier display name
  String get formattedTier {
    return tier[0].toUpperCase() + tier.substring(1).toLowerCase();
  }

  /// Get tier emoji
  String get tierEmoji {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return '🥉';
      case 'silver':
        return '🥈';
      case 'gold':
        return '🥇';
      case 'platinum':
        return '💎';
      case 'diamond':
        return '💠';
      default:
        return '🥉';
    }
  }

  /// Get tier color for UI
  String get tierColor {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return '#CD7F32';
      case 'silver':
        return '#C0C0C0';
      case 'gold':
        return '#FFD700';
      case 'platinum':
        return '#E5E4E2';
      case 'diamond':
        return '#B9F2FF';
      default:
        return '#CD7F32';
    }
  }

  /// Check if user is in top 3
  bool get isTopThree => globalRank > 0 && globalRank <= 3;

  /// Check if user is in top 10
  bool get isTopTen => globalRank > 0 && globalRank <= 10;

  /// Create MonthlyRanking from Appwrite document data
  factory MonthlyRanking.fromMap(Map<String, dynamic> map) {
    return MonthlyRanking(
      id: map['id'] ?? map['\$id'] ?? '',
      userId: map['userId'] ?? '',
      monthKey: map['monthKey'] ?? '',
      monthlyPoints: _safeParseInt(map['monthlyPoints'], 0),
      monthlyWins: _safeParseInt(map['monthlyWins'], 0),
      monthlyLosses: _safeParseInt(map['monthlyLosses'], 0),
      currentWinStreak: _safeParseInt(map['currentWinStreak'], 0),
      bestWinStreak: _safeParseInt(map['bestWinStreak'], 0),
      activityXP: _safeParseInt(map['activityXP'], 0),
      tier: map['tier'] ?? 'bronze',
      globalRank: _safeParseInt(map['globalRank'], 0),
      achievementsEarned: _safeParseStringList(map['achievementsEarned']),
      lastUpdated: DateTime.tryParse(
        map['lastUpdated'] ?? map['\$updatedAt'] ?? ''
      ) ?? DateTime.now(),
      createdAt: DateTime.tryParse(
        map['createdAt'] ?? map['\$createdAt'] ?? ''
      ) ?? DateTime.now(),
    );
  }

  /// Convert MonthlyRanking to Map for Appwrite operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'monthKey': monthKey,
      'monthlyPoints': monthlyPoints,
      'monthlyWins': monthlyWins,
      'monthlyLosses': monthlyLosses,
      'currentWinStreak': currentWinStreak,
      'bestWinStreak': bestWinStreak,
      'activityXP': activityXP,
      'tier': tier,
      'globalRank': globalRank,
      'achievementsEarned': achievementsEarned,
      'lastUpdated': lastUpdated.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  MonthlyRanking copyWith({
    String? id,
    String? userId,
    String? monthKey,
    int? monthlyPoints,
    int? monthlyWins,
    int? monthlyLosses,
    int? currentWinStreak,
    int? bestWinStreak,
    int? activityXP,
    String? tier,
    int? globalRank,
    List<String>? achievementsEarned,
    DateTime? lastUpdated,
    DateTime? createdAt,
  }) {
    return MonthlyRanking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      monthKey: monthKey ?? this.monthKey,
      monthlyPoints: monthlyPoints ?? this.monthlyPoints,
      monthlyWins: monthlyWins ?? this.monthlyWins,
      monthlyLosses: monthlyLosses ?? this.monthlyLosses,
      currentWinStreak: currentWinStreak ?? this.currentWinStreak,
      bestWinStreak: bestWinStreak ?? this.bestWinStreak,
      activityXP: activityXP ?? this.activityXP,
      tier: tier ?? this.tier,
      globalRank: globalRank ?? this.globalRank,
      achievementsEarned: achievementsEarned ?? this.achievementsEarned,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods for safe parsing
  static int _safeParseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String && value.isNotEmpty) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static List<String> _safeParseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = json.decode(value);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
      } catch (e) {
        // If JSON parsing fails, return empty list
      }
    }
    return [];
  }

  @override
  String toString() {
    return 'MonthlyRanking(userId: $userId, monthKey: $monthKey, points: $monthlyPoints, tier: $tier, rank: $globalRank)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonthlyRanking && 
           other.id == id &&
           other.userId == userId &&
           other.monthKey == monthKey;
  }

  @override
  int get hashCode => id.hashCode ^ userId.hashCode ^ monthKey.hashCode;
}