import 'dart:convert';

/// Enhanced user profile model for Arena app
/// Contains detailed profile information beyond basic authentication
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? bio;
  final String? avatar;
  final String? location;
  final String? website;
  final String? xHandle;
  final String? linkedinHandle;
  final String? youtubeHandle;
  final String? facebookHandle;
  final String? instagramHandle;
  final Map<String, dynamic> preferences;
  final int reputation;
  final int totalDebates;
  final int totalWins;
  final int totalRoomsCreated;
  final int totalRoomsJoined;
  final int coinBalance;
  final int totalGiftsSent;
  final int totalGiftsReceived;
  final List<String> interests;
  final List<String> joinedClubs;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerified;
  final bool isPublicProfile;
  final bool isAvailableAsModerator;
  final bool isAvailableAsJudge;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.bio,
    this.avatar,
    this.location,
    this.website,
    this.xHandle,
    this.linkedinHandle,
    this.youtubeHandle,
    this.facebookHandle,
    this.instagramHandle,
    this.preferences = const {},
    this.reputation = 0,
    this.totalDebates = 0,
    this.totalWins = 0,
    this.totalRoomsCreated = 0,
    this.totalRoomsJoined = 0,
    this.coinBalance = 100, // Start new users with 100 coins
    this.totalGiftsSent = 0,
    this.totalGiftsReceived = 0,
    this.interests = const [],
    this.joinedClubs = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isVerified = false,
    this.isPublicProfile = true,
    this.isAvailableAsModerator = false,
    this.isAvailableAsJudge = false,
  });

  /// Safely parse preferences field with proper error handling
  static Map<String, dynamic> _safeParsePreferences(dynamic preferences) {
    try {
      if (preferences == null) return {};
      if (preferences is Map<String, dynamic>) return preferences;
      if (preferences is String) {
        if (preferences.isEmpty) return {};
        return Map<String, dynamic>.from(json.decode(preferences));
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Safely parse integer field with proper error handling
  static int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    try {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String && value.isNotEmpty) {
        final parsed = int.tryParse(value);
        return parsed ?? defaultValue;
      }
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Create UserProfile from Appwrite document data
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? map['\$id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      bio: map['bio'],
      avatar: map['avatar'] ?? map['profileImageUrl'], // Support both field names
      location: map['location'],
      website: map['website'],
      xHandle: map['xHandle'],
      linkedinHandle: map['linkedinHandle'],
      youtubeHandle: map['youtubeHandle'],
      facebookHandle: map['facebookHandle'],
      instagramHandle: map['instagramHandle'],
      preferences: _safeParsePreferences(map['preferences']),
      reputation: _safeParseInt(map['reputation'], defaultValue: 0),
      totalDebates: _safeParseInt(map['totalDebates'], defaultValue: 0),
      totalWins: _safeParseInt(map['totalWins'], defaultValue: 0),
      totalRoomsCreated: _safeParseInt(map['totalRoomsCreated'], defaultValue: 0),
      totalRoomsJoined: _safeParseInt(map['totalRoomsJoined'], defaultValue: 0),
      coinBalance: _safeParseInt(map['coinBalance'], defaultValue: 100),
      totalGiftsSent: _safeParseInt(map['totalGiftsSent'], defaultValue: 0),
      totalGiftsReceived: _safeParseInt(map['totalGiftsReceived'], defaultValue: 0),
      interests: (map['interests'] as List?)?.cast<String>() ?? [],
      joinedClubs: (map['joinedClubs'] as List?)?.cast<String>() ?? [],
      createdAt: DateTime.tryParse(
        map['createdAt'] ?? map['\$createdAt'] ?? ''
      ) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(
        map['updatedAt'] ?? map['\$updatedAt'] ?? ''
      ) ?? DateTime.now(),
      isVerified: map['isVerified'] ?? false,
      isPublicProfile: map['isPublicProfile'] ?? true,
      isAvailableAsModerator: map['isAvailableAsModerator'] ?? false,
      isAvailableAsJudge: map['isAvailableAsJudge'] ?? false,
    );
  }

  /// Convert UserProfile to Map for Appwrite operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'bio': bio,
      'avatar': avatar,
      'location': location,
      'website': website,
      'xHandle': xHandle,
      'linkedinHandle': linkedinHandle,
      'youtubeHandle': youtubeHandle,
      'facebookHandle': facebookHandle,
      'instagramHandle': instagramHandle,
      'preferences': json.encode(preferences),
      'reputation': reputation,
      'totalDebates': totalDebates,
      'totalWins': totalWins,
      'totalRoomsCreated': totalRoomsCreated,
      'totalRoomsJoined': totalRoomsJoined,
      'coinBalance': coinBalance,
      'totalGiftsSent': totalGiftsSent,
      'totalGiftsReceived': totalGiftsReceived,
      'interests': interests,
      'joinedClubs': joinedClubs,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isVerified': isVerified,
      'isPublicProfile': isPublicProfile,
      'isAvailableAsModerator': isAvailableAsModerator,
      'isAvailableAsJudge': isAvailableAsJudge,
    };
  }

  /// Create a copy of this profile with updated fields
  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? bio,
    String? avatar,
    String? location,
    String? website,
    String? xHandle,
    String? linkedinHandle,
    String? youtubeHandle,
    String? facebookHandle,
    String? instagramHandle,
    Map<String, dynamic>? preferences,
    int? reputation,
    int? totalDebates,
    int? totalWins,
    int? totalRoomsCreated,
    int? totalRoomsJoined,
    int? coinBalance,
    int? totalGiftsSent,
    int? totalGiftsReceived,
    List<String>? interests,
    List<String>? joinedClubs,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerified,
    bool? isPublicProfile,
    bool? isAvailableAsModerator,
    bool? isAvailableAsJudge,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      avatar: avatar ?? this.avatar,
      location: location ?? this.location,
      website: website ?? this.website,
      xHandle: xHandle ?? this.xHandle,
      linkedinHandle: linkedinHandle ?? this.linkedinHandle,
      youtubeHandle: youtubeHandle ?? this.youtubeHandle,
      facebookHandle: facebookHandle ?? this.facebookHandle,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      preferences: preferences ?? this.preferences,
      reputation: reputation ?? this.reputation,
      totalDebates: totalDebates ?? this.totalDebates,
      totalWins: totalWins ?? this.totalWins,
      totalRoomsCreated: totalRoomsCreated ?? this.totalRoomsCreated,
      totalRoomsJoined: totalRoomsJoined ?? this.totalRoomsJoined,
      coinBalance: coinBalance ?? this.coinBalance,
      totalGiftsSent: totalGiftsSent ?? this.totalGiftsSent,
      totalGiftsReceived: totalGiftsReceived ?? this.totalGiftsReceived,
      interests: interests ?? this.interests,
      joinedClubs: joinedClubs ?? this.joinedClubs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerified: isVerified ?? this.isVerified,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      isAvailableAsModerator: isAvailableAsModerator ?? this.isAvailableAsModerator,
      isAvailableAsJudge: isAvailableAsJudge ?? this.isAvailableAsJudge,
    );
  }

  /// Get win percentage as a double between 0 and 1
  double get winPercentage {
    if (totalDebates == 0) return 0.0;
    return totalWins / totalDebates;
  }

  /// Get display name - prefer name, fallback to email prefix
  String get displayName {
    if (name.isNotEmpty) return name;
    return email.split('@').first;
  }

  /// Get initials for avatar fallback
  String get initials {
    if (name.isEmpty) return email.substring(0, 1).toUpperCase();
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  /// Check if profile has avatar
  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;

  /// Get formatted reputation display
  String get formattedReputation {
    if (reputation >= 1000000) {
      return '${(reputation / 1000000).toStringAsFixed(1)}M';
    } else if (reputation >= 1000) {
      return '${(reputation / 1000).toStringAsFixed(1)}K';
    }
    return reputation.toString();
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $name, email: $email, reputation: $reputation)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 