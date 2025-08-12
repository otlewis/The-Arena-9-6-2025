import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'instant_chat_message.freezed.dart';
part 'instant_chat_message.g.dart';

/// Instant chat message model for Agora Chat integration
@freezed
class InstantChatMessage with _$InstantChatMessage {
  const factory InstantChatMessage({
    required String id,
    required String senderId,
    required String receiverId,
    required String content,
    required DateTime timestamp,
    required bool isRead,
    String? senderName,
    String? senderAvatar,
    @Default(InstantChatMessageType.text) InstantChatMessageType type,
  }) = _InstantChatMessage;

  factory InstantChatMessage.fromJson(Map<String, dynamic> json) =>
      _$InstantChatMessageFromJson(json);
}

/// Message types for instant chat
enum InstantChatMessageType {
  text,
  image,
  video,
  voice,
  file;

  String get displayName {
    switch (this) {
      case InstantChatMessageType.text:
        return 'Text';
      case InstantChatMessageType.image:
        return 'Image';
      case InstantChatMessageType.video:
        return 'Video';
      case InstantChatMessageType.voice:
        return 'Voice';
      case InstantChatMessageType.file:
        return 'File';
    }
  }
}