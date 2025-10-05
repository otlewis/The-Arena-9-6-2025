import 'package:freezed_annotation/freezed_annotation.dart';

part 'super_moderator.freezed.dart';
part 'super_moderator.g.dart';

@freezed
class SuperModerator with _$SuperModerator {
  const SuperModerator._();

  const factory SuperModerator({
    String? id,
    required String userId,
    required String username,
    String? profileImageUrl,
    required DateTime grantedAt,
    String? grantedBy, // User ID of who granted super mod status
    required bool isActive,
    @Default([]) List<String> permissions,
    @Default({}) Map<String, dynamic> metadata,
  }) = _SuperModerator;

  factory SuperModerator.fromJson(Map<String, dynamic> json) =>
      _$SuperModeratorFromJson(json);

  factory SuperModerator.fromDocument(dynamic doc) {
    final data = doc.data as Map<String, dynamic>;
    return SuperModerator(
      id: doc.$id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      grantedAt: data['grantedAt'] != null
          ? DateTime.parse(data['grantedAt'])
          : DateTime.now(),
      grantedBy: data['grantedBy'],
      isActive: data['isActive'] ?? true,
      permissions: data['permissions'] != null
          ? List<String>.from(data['permissions'])
          : [],
      metadata: data['metadata'] is Map
          ? Map<String, dynamic>.from(data['metadata'])
          : {},
    );
  }
}

// Super Moderator permissions
class SuperModPermissions {
  static const String accessReports = 'access_reports';
  static const String takeModActions = 'take_mod_actions';
  static const String speakerImmunity = 'speaker_immunity';
  static const String instantSpeaker = 'instant_speaker';
  static const String closeRooms = 'close_rooms';
  static const String lockMics = 'lock_mics';
  static const String kickUsers = 'kick_users';
  static const String banUsers = 'ban_users';
  static const String promoteSupermods = 'promote_supermods';
  
  static const List<String> allPermissions = [
    accessReports,
    takeModActions,
    speakerImmunity,
    instantSpeaker,
    closeRooms,
    lockMics,
    kickUsers,
    banUsers,
    promoteSupermods,
  ];
}