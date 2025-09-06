import 'dart:convert';

/// Achievement Model for Arena Gamification System
/// Represents badges and achievements users can earn
class Achievement {
  final String id;
  final String userId;
  final String achievementId;
  final String title;
  final String description;
  final String category; // combat, community, streak, special
  final String rarity; // common, rare, epic, legendary
  final String iconAsset;
  final int xpReward;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final Map<String, dynamic> metadata; // Additional data for achievement
  final DateTime createdAt;

  Achievement({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.title,
    required this.description,
    required this.category,
    this.rarity = 'common',
    required this.iconAsset,
    this.xpReward = 0,
    this.isUnlocked = false,
    this.unlockedAt,
    this.metadata = const {},
    required this.createdAt,
  });

  /// Get rarity color for UI
  String get rarityColor {
    switch (rarity.toLowerCase()) {
      case 'common':
        return '#9CA3AF'; // Gray
      case 'rare':
        return '#3B82F6'; // Blue
      case 'epic':
        return '#8B5CF6'; // Purple
      case 'legendary':
        return '#F59E0B'; // Gold
      default:
        return '#9CA3AF';
    }
  }

  /// Get rarity emoji
  String get rarityEmoji {
    switch (rarity.toLowerCase()) {
      case 'common':
        return '⚪';
      case 'rare':
        return '🔵';
      case 'epic':
        return '🟣';
      case 'legendary':
        return '🟡';
      default:
        return '⚪';
    }
  }

  /// Get category emoji
  String get categoryEmoji {
    switch (category.toLowerCase()) {
      case 'combat':
        return '⚔️';
      case 'community':
        return '🤝';
      case 'streak':
        return '🔥';
      case 'special':
        return '⭐';
      default:
        return '🏆';
    }
  }

  /// Format unlock date
  String get formattedUnlockDate {
    if (!isUnlocked || unlockedAt == null) return 'Not unlocked';
    
    final now = DateTime.now();
    final difference = now.difference(unlockedAt!);
    
    if (difference.inDays > 30) {
      return '${unlockedAt!.day}/${unlockedAt!.month}/${unlockedAt!.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Create Achievement from Appwrite document data
  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] ?? map['\$id'] ?? '',
      userId: map['userId'] ?? '',
      achievementId: map['achievementId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'combat',
      rarity: map['rarity'] ?? 'common',
      iconAsset: map['iconAsset'] ?? '',
      xpReward: _safeParseInt(map['xpReward'], 0),
      isUnlocked: map['isUnlocked'] ?? false,
      unlockedAt: DateTime.tryParse(map['unlockedAt'] ?? ''),
      metadata: _safeParseMap(map['metadata']),
      createdAt: DateTime.tryParse(
        map['createdAt'] ?? map['\$createdAt'] ?? ''
      ) ?? DateTime.now(),
    );
  }

  /// Convert Achievement to Map for Appwrite operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'achievementId': achievementId,
      'title': title,
      'description': description,
      'category': category,
      'rarity': rarity,
      'iconAsset': iconAsset,
      'xpReward': xpReward,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'metadata': json.encode(metadata),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Achievement copyWith({
    String? id,
    String? userId,
    String? achievementId,
    String? title,
    String? description,
    String? category,
    String? rarity,
    String? iconAsset,
    int? xpReward,
    bool? isUnlocked,
    DateTime? unlockedAt,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return Achievement(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      achievementId: achievementId ?? this.achievementId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      rarity: rarity ?? this.rarity,
      iconAsset: iconAsset ?? this.iconAsset,
      xpReward: xpReward ?? this.xpReward,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      metadata: metadata ?? this.metadata,
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

  static Map<String, dynamic> _safeParseMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = json.decode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (e) {
        // If JSON parsing fails, return empty map
      }
    }
    return {};
  }

  @override
  String toString() {
    return 'Achievement(id: $id, title: $title, category: $category, unlocked: $isUnlocked)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Achievement && 
           other.id == id &&
           other.achievementId == achievementId;
  }

  @override
  int get hashCode => id.hashCode ^ achievementId.hashCode;
}

/// Predefined achievement templates
class AchievementTemplates {
  static const List<Map<String, dynamic>> templates = [
    // Combat Achievements
    {
      'achievementId': 'first_win',
      'title': 'First Victory',
      'description': 'Win your first debate',
      'category': 'combat',
      'rarity': 'common',
      'iconAsset': 'assets/icons/first_win.png',
      'xpReward': 50,
    },
    {
      'achievementId': 'win_streak_3',
      'title': 'Triple Threat',
      'description': 'Win 3 debates in a row',
      'category': 'streak',
      'rarity': 'rare',
      'iconAsset': 'assets/icons/win_streak.png',
      'xpReward': 100,
    },
    {
      'achievementId': 'win_streak_5',
      'title': 'Unstoppable',
      'description': 'Win 5 debates in a row',
      'category': 'streak',
      'rarity': 'epic',
      'iconAsset': 'assets/icons/unstoppable.png',
      'xpReward': 250,
    },
    {
      'achievementId': 'win_streak_10',
      'title': 'Legendary Streak',
      'description': 'Win 10 debates in a row',
      'category': 'streak',
      'rarity': 'legendary',
      'iconAsset': 'assets/icons/legendary_streak.png',
      'xpReward': 500,
    },
    {
      'achievementId': 'perfect_score',
      'title': 'Flawless Victory',
      'description': 'Win with a perfect 100% judge score',
      'category': 'combat',
      'rarity': 'epic',
      'iconAsset': 'assets/icons/perfect_score.png',
      'xpReward': 200,
    },
    
    // Community Achievements
    {
      'achievementId': 'gift_giver',
      'title': 'Generous Soul',
      'description': 'Send 10 gifts to other users',
      'category': 'community',
      'rarity': 'rare',
      'iconAsset': 'assets/icons/gift_giver.png',
      'xpReward': 150,
    },
    {
      'achievementId': 'room_creator',
      'title': 'Arena Builder',
      'description': 'Create 5 debate rooms',
      'category': 'community',
      'rarity': 'common',
      'iconAsset': 'assets/icons/room_creator.png',
      'xpReward': 75,
    },
    {
      'achievementId': 'community_helper',
      'title': 'Community Helper',
      'description': 'Maintain 95%+ reputation for a full month',
      'category': 'community',
      'rarity': 'legendary',
      'iconAsset': 'assets/icons/community_helper.png',
      'xpReward': 300,
    },
    
    // Special Achievements
    {
      'achievementId': 'monthly_champion',
      'title': 'Monthly Champion',
      'description': 'Finish #1 in monthly rankings',
      'category': 'special',
      'rarity': 'legendary',
      'iconAsset': 'assets/icons/monthly_champion.png',
      'xpReward': 1000,
    },
    {
      'achievementId': 'top_tier',
      'title': 'Diamond Elite',
      'description': 'Reach Diamond tier',
      'category': 'special',
      'rarity': 'legendary',
      'iconAsset': 'assets/icons/diamond_tier.png',
      'xpReward': 750,
    },
  ];
}