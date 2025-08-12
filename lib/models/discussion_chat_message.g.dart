// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discussion_chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DiscussionChatMessageImpl _$$DiscussionChatMessageImplFromJson(
        Map<String, dynamic> json) =>
    _$DiscussionChatMessageImpl(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: $enumDecode(_$DiscussionMessageTypeEnumMap, json['type']),
      senderAvatar: json['senderAvatar'] as String?,
      replyToId: json['replyToId'] as String?,
      replyToContent: json['replyToContent'] as String?,
      replyToSender: json['replyToSender'] as String?,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ),
      mentions: (json['mentions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      isEdited: json['isEdited'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      editedAt: json['editedAt'] == null
          ? null
          : DateTime.parse(json['editedAt'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
    );

Map<String, dynamic> _$$DiscussionChatMessageImplToJson(
        _$DiscussionChatMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'roomId': instance.roomId,
      'senderId': instance.senderId,
      'senderName': instance.senderName,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': _$DiscussionMessageTypeEnumMap[instance.type]!,
      'senderAvatar': instance.senderAvatar,
      'replyToId': instance.replyToId,
      'replyToContent': instance.replyToContent,
      'replyToSender': instance.replyToSender,
      'reactions': instance.reactions,
      'mentions': instance.mentions,
      'attachments': instance.attachments,
      'metadata': instance.metadata,
      'isEdited': instance.isEdited,
      'isDeleted': instance.isDeleted,
      'editedAt': instance.editedAt?.toIso8601String(),
      'deletedAt': instance.deletedAt?.toIso8601String(),
    };

const _$DiscussionMessageTypeEnumMap = {
  DiscussionMessageType.text: 'text',
  DiscussionMessageType.image: 'image',
  DiscussionMessageType.video: 'video',
  DiscussionMessageType.voice: 'voice',
  DiscussionMessageType.file: 'file',
  DiscussionMessageType.system: 'system',
  DiscussionMessageType.announcement: 'announcement',
};

_$ChatParticipantImpl _$$ChatParticipantImplFromJson(
        Map<String, dynamic> json) =>
    _$ChatParticipantImpl(
      userId: json['userId'] as String,
      username: json['username'] as String,
      role: json['role'] as String,
      avatar: json['avatar'] as String?,
      isOnline: json['isOnline'] as bool? ?? true,
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
      joinedAt: json['joinedAt'] == null
          ? null
          : DateTime.parse(json['joinedAt'] as String),
    );

Map<String, dynamic> _$$ChatParticipantImplToJson(
        _$ChatParticipantImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'username': instance.username,
      'role': instance.role,
      'avatar': instance.avatar,
      'isOnline': instance.isOnline,
      'lastSeen': instance.lastSeen?.toIso8601String(),
      'joinedAt': instance.joinedAt?.toIso8601String(),
    };

_$ChatSessionImpl _$$ChatSessionImplFromJson(Map<String, dynamic> json) =>
    _$ChatSessionImpl(
      id: json['id'] as String,
      type: $enumDecode(_$ChatSessionTypeEnumMap, json['type']),
      title: json['title'] as String,
      participants: (json['participants'] as List<dynamic>?)
          ?.map((e) => ChatParticipant.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] == null
          ? null
          : DateTime.parse(json['lastMessageTime'] as String),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      roomId: json['roomId'] as String?,
      conversationId: json['conversationId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$ChatSessionImplToJson(_$ChatSessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ChatSessionTypeEnumMap[instance.type]!,
      'title': instance.title,
      'participants': instance.participants,
      'lastMessage': instance.lastMessage,
      'lastMessageTime': instance.lastMessageTime?.toIso8601String(),
      'unreadCount': instance.unreadCount,
      'roomId': instance.roomId,
      'conversationId': instance.conversationId,
      'metadata': instance.metadata,
    };

const _$ChatSessionTypeEnumMap = {
  ChatSessionType.roomChat: 'roomChat',
  ChatSessionType.directMessage: 'directMessage',
};
