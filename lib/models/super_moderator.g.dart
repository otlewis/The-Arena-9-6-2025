// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'super_moderator.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SuperModeratorImpl _$$SuperModeratorImplFromJson(Map<String, dynamic> json) =>
    _$SuperModeratorImpl(
      id: json['id'] as String?,
      userId: json['userId'] as String,
      username: json['username'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      grantedAt: DateTime.parse(json['grantedAt'] as String),
      grantedBy: json['grantedBy'] as String?,
      isActive: json['isActive'] as bool,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$$SuperModeratorImplToJson(
        _$SuperModeratorImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'username': instance.username,
      'profileImageUrl': instance.profileImageUrl,
      'grantedAt': instance.grantedAt.toIso8601String(),
      'grantedBy': instance.grantedBy,
      'isActive': instance.isActive,
      'permissions': instance.permissions,
      'metadata': instance.metadata,
    };
