// Models for moderator and judge system

/// Available debate categories
enum DebateCategory {
  politics('Politics'),
  technology('Technology'),
  science('Science'),
  philosophy('Philosophy'),
  economics('Economics'),
  education('Education'),
  health('Health'),
  environment('Environment'),
  sports('Sports'),
  entertainment('Entertainment'),
  religion('Religion'),
  history('History'),
  any('Any Category');

  const DebateCategory(this.displayName);
  final String displayName;
}

/// Moderator profile for debate moderation
class ModeratorProfile {
  final String id;
  final String userId;
  final String username;
  final String displayName;
  final String? avatar;
  final List<DebateCategory> categories;
  final bool isAvailable;
  final int totalModerated;
  final double rating;
  final int ratingCount;
  final String? bio;
  final DateTime createdAt;
  final DateTime lastActive;
  final List<String> specializations;
  final int experienceYears;

  ModeratorProfile({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatar,
    required this.categories,
    required this.isAvailable,
    required this.totalModerated,
    required this.rating,
    required this.ratingCount,
    this.bio,
    required this.createdAt,
    required this.lastActive,
    this.specializations = const [],
    this.experienceYears = 0,
  });

  factory ModeratorProfile.fromJson(Map<String, dynamic> json) {
    return ModeratorProfile(
      id: json['\$id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      avatar: json['avatar'],
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => DebateCategory.values.firstWhere(
                (cat) => cat.name == e,
                orElse: () => DebateCategory.any,
              ))
          .toList() ?? [],
      isAvailable: json['isAvailable'] ?? false,
      totalModerated: json['totalModerated'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
      ratingCount: json['ratingCount'] ?? 0,
      bio: json['bio'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastActive: json['lastActive'] != null 
          ? DateTime.parse(json['lastActive'])
          : DateTime.now(),
      specializations: (json['specializations'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      experienceYears: json['experienceYears'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'avatar': avatar,
      'categories': categories.map((e) => e.name).toList(),
      'isAvailable': isAvailable,
      'totalModerated': totalModerated,
      'rating': rating,
      'ratingCount': ratingCount,
      'bio': bio,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
      'specializations': specializations,
      'experienceYears': experienceYears,
    };
  }
}

/// Judge profile for debate judging
class JudgeProfile {
  final String id;
  final String userId;
  final String username;
  final String displayName;
  final String? avatar;
  final List<DebateCategory> categories;
  final bool isAvailable;
  final int totalJudged;
  final double rating;
  final int ratingCount;
  final String? bio;
  final DateTime createdAt;
  final DateTime lastActive;
  final List<String> specializations;
  final int experienceYears;
  final List<String> certifications;

  JudgeProfile({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatar,
    required this.categories,
    required this.isAvailable,
    required this.totalJudged,
    required this.rating,
    required this.ratingCount,
    this.bio,
    required this.createdAt,
    required this.lastActive,
    this.specializations = const [],
    this.experienceYears = 0,
    this.certifications = const [],
  });

  factory JudgeProfile.fromJson(Map<String, dynamic> json) {
    return JudgeProfile(
      id: json['\$id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      avatar: json['avatar'],
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => DebateCategory.values.firstWhere(
                (cat) => cat.name == e,
                orElse: () => DebateCategory.any,
              ))
          .toList() ?? [],
      isAvailable: json['isAvailable'] ?? false,
      totalJudged: json['totalJudged'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
      ratingCount: json['ratingCount'] ?? 0,
      bio: json['bio'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastActive: json['lastActive'] != null 
          ? DateTime.parse(json['lastActive'])
          : DateTime.now(),
      specializations: (json['specializations'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      experienceYears: json['experienceYears'] ?? 0,
      certifications: (json['certifications'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'avatar': avatar,
      'categories': categories.map((e) => e.name).toList(),
      'isAvailable': isAvailable,
      'totalJudged': totalJudged,
      'rating': rating,
      'ratingCount': ratingCount,
      'bio': bio,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
      'specializations': specializations,
      'experienceYears': experienceYears,
      'certifications': certifications,
    };
  }
}

/// Ping request to moderator/judge
class PingRequest {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String toUserId;
  final String toUsername;
  final String roleType; // 'moderator' or 'judge'
  final String debateTitle;
  final String debateDescription;
  final DebateCategory category;
  final DateTime scheduledTime;
  final String status; // 'pending', 'accepted', 'declined', 'expired'
  final String? message;
  final String? response;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? arenaRoomId;

  PingRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.toUserId,
    required this.toUsername,
    required this.roleType,
    required this.debateTitle,
    required this.debateDescription,
    required this.category,
    required this.scheduledTime,
    required this.status,
    this.message,
    this.response,
    required this.createdAt,
    this.respondedAt,
    this.arenaRoomId,
  });

  factory PingRequest.fromJson(Map<String, dynamic> json) {
    return PingRequest(
      id: json['\$id'] ?? json['id'] ?? '',
      fromUserId: json['fromUserId'] ?? '',
      fromUsername: json['fromUsername'] ?? '',
      toUserId: json['toUserId'] ?? '',
      toUsername: json['toUsername'] ?? '',
      roleType: json['roleType'] ?? '',
      debateTitle: json['debateTitle'] ?? '',
      debateDescription: json['debateDescription'] ?? '',
      category: DebateCategory.values.firstWhere(
        (cat) => cat.name == json['category'],
        orElse: () => DebateCategory.any,
      ),
      scheduledTime: json['scheduledTime'] != null 
          ? DateTime.parse(json['scheduledTime'])
          : DateTime.now(),
      status: json['status'] ?? 'pending',
      message: json['message'],
      response: json['response'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      respondedAt: json['respondedAt'] != null 
          ? DateTime.parse(json['respondedAt'])
          : null,
      arenaRoomId: json['arenaRoomId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'toUserId': toUserId,
      'toUsername': toUsername,
      'roleType': roleType,
      'debateTitle': debateTitle,
      'debateDescription': debateDescription,
      'category': category.name,
      'scheduledTime': scheduledTime.toIso8601String(),
      'status': status,
      'message': message,
      'response': response,
      'createdAt': createdAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'arenaRoomId': arenaRoomId,
    };
  }
}

/// Rating and review for moderator/judge
class ModeratorJudgeRating {
  final String id;
  final String ratedUserId;
  final String raterUserId;
  final String raterUsername;
  final String roleType; // 'moderator' or 'judge'
  final int rating; // 1-5 stars
  final String? review;
  final String arenaRoomId;
  final DateTime createdAt;

  ModeratorJudgeRating({
    required this.id,
    required this.ratedUserId,
    required this.raterUserId,
    required this.raterUsername,
    required this.roleType,
    required this.rating,
    this.review,
    required this.arenaRoomId,
    required this.createdAt,
  });

  factory ModeratorJudgeRating.fromJson(Map<String, dynamic> json) {
    return ModeratorJudgeRating(
      id: json['\$id'] ?? json['id'] ?? '',
      ratedUserId: json['ratedUserId'] ?? '',
      raterUserId: json['raterUserId'] ?? '',
      raterUsername: json['raterUsername'] ?? '',
      roleType: json['roleType'] ?? '',
      rating: json['rating'] ?? 0,
      review: json['review'],
      arenaRoomId: json['arenaRoomId'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ratedUserId': ratedUserId,
      'raterUserId': raterUserId,
      'raterUsername': raterUsername,
      'roleType': roleType,
      'rating': rating,
      'review': review,
      'arenaRoomId': arenaRoomId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}