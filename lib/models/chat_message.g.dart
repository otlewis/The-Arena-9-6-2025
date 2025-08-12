// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatMessageImpl _$$ChatMessageImplFromJson(Map<String, dynamic> json) =>
    _$ChatMessageImpl(
      id: json['id'] as String,
      content: json['content'] as String,
      username: json['username'] as String,
      userId: json['userId'] as String,
      chatRoomId: json['chatRoomId'] as String,
      roomType: json['roomType'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userAvatar: json['userAvatar'] as String?,
      userRole: json['userRole'] as String?,
      isSystemMessage: json['isSystemMessage'] as bool?,
      messageType: json['messageType'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$ChatMessageImplToJson(_$ChatMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'username': instance.username,
      'userId': instance.userId,
      'chatRoomId': instance.chatRoomId,
      'roomType': instance.roomType,
      'timestamp': instance.timestamp.toIso8601String(),
      'userAvatar': instance.userAvatar,
      'userRole': instance.userRole,
      'isSystemMessage': instance.isSystemMessage,
      'messageType': instance.messageType,
      'metadata': instance.metadata,
    };

_$ChatUserPresenceImpl _$$ChatUserPresenceImplFromJson(
        Map<String, dynamic> json) =>
    _$ChatUserPresenceImpl(
      userId: json['userId'] as String,
      username: json['username'] as String,
      chatRoomId: json['chatRoomId'] as String,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      userAvatar: json['userAvatar'] as String?,
      userRole: json['userRole'] as String?,
      isOnline: json['isOnline'] as bool?,
    );

Map<String, dynamic> _$$ChatUserPresenceImplToJson(
        _$ChatUserPresenceImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'username': instance.username,
      'chatRoomId': instance.chatRoomId,
      'lastSeen': instance.lastSeen.toIso8601String(),
      'userAvatar': instance.userAvatar,
      'userRole': instance.userRole,
      'isOnline': instance.isOnline,
    };
