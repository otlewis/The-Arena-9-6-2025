// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instant_chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InstantChatMessageImpl _$$InstantChatMessageImplFromJson(
        Map<String, dynamic> json) =>
    _$InstantChatMessageImpl(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool,
      senderName: json['senderName'] as String?,
      senderAvatar: json['senderAvatar'] as String?,
      type:
          $enumDecodeNullable(_$InstantChatMessageTypeEnumMap, json['type']) ??
              InstantChatMessageType.text,
    );

Map<String, dynamic> _$$InstantChatMessageImplToJson(
        _$InstantChatMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'receiverId': instance.receiverId,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
      'isRead': instance.isRead,
      'senderName': instance.senderName,
      'senderAvatar': instance.senderAvatar,
      'type': _$InstantChatMessageTypeEnumMap[instance.type]!,
    };

const _$InstantChatMessageTypeEnumMap = {
  InstantChatMessageType.text: 'text',
  InstantChatMessageType.image: 'image',
  InstantChatMessageType.video: 'video',
  InstantChatMessageType.voice: 'voice',
  InstantChatMessageType.file: 'file',
};
