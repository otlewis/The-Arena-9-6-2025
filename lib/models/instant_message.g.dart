// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instant_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InstantMessageImpl _$$InstantMessageImplFromJson(Map<String, dynamic> json) =>
    _$InstantMessageImpl(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool,
      senderUsername: json['senderUsername'] as String?,
      senderAvatar: json['senderAvatar'] as String?,
      conversationId: json['conversationId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$InstantMessageImplToJson(
        _$InstantMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'receiverId': instance.receiverId,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
      'isRead': instance.isRead,
      'senderUsername': instance.senderUsername,
      'senderAvatar': instance.senderAvatar,
      'conversationId': instance.conversationId,
      'metadata': instance.metadata,
    };

_$ConversationImpl _$$ConversationImplFromJson(Map<String, dynamic> json) =>
    _$ConversationImpl(
      id: json['id'] as String,
      participantIds: (json['participantIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      lastMessageTime: DateTime.parse(json['lastMessageTime'] as String),
      lastMessage: json['lastMessage'] as String?,
      unreadCount: (json['unreadCount'] as num).toInt(),
      participants: (json['participants'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, UserInfo.fromJson(e as Map<String, dynamic>)),
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$ConversationImplToJson(_$ConversationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'participantIds': instance.participantIds,
      'lastMessageTime': instance.lastMessageTime.toIso8601String(),
      'lastMessage': instance.lastMessage,
      'unreadCount': instance.unreadCount,
      'participants': instance.participants,
      'metadata': instance.metadata,
    };

_$UserInfoImpl _$$UserInfoImplFromJson(Map<String, dynamic> json) =>
    _$UserInfoImpl(
      id: json['id'] as String,
      username: json['username'] as String,
      avatar: json['avatar'] as String?,
      isOnline: json['isOnline'] as bool?,
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
    );

Map<String, dynamic> _$$UserInfoImplToJson(_$UserInfoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'avatar': instance.avatar,
      'isOnline': instance.isOnline,
      'lastSeen': instance.lastSeen?.toIso8601String(),
    };
