// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_link.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SharedLinkImpl _$$SharedLinkImplFromJson(Map<String, dynamic> json) =>
    _$SharedLinkImpl(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      url: json['url'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      sharedBy: json['sharedBy'] as String,
      sharedByName: json['sharedByName'] as String,
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
      type: json['type'] as String? ?? 'link',
    );

Map<String, dynamic> _$$SharedLinkImplToJson(_$SharedLinkImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'roomId': instance.roomId,
      'url': instance.url,
      'title': instance.title,
      'description': instance.description,
      'sharedBy': instance.sharedBy,
      'sharedByName': instance.sharedByName,
      'sharedAt': instance.sharedAt.toIso8601String(),
      'isActive': instance.isActive,
      'type': instance.type,
    };
