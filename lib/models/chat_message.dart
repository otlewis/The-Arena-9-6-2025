import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// Chat message model for real-time messaging in Arena rooms
/// 
/// Supports messages across Arena, Debates & Discussions, and Open Discussion rooms
/// with user information, timestamps, and room association.
@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String content,
    required String username,
    required String userId,
    required String chatRoomId,
    required String roomType,
    required DateTime timestamp,
    String? userAvatar,
    String? userRole, // 'moderator', 'speaker', 'judge', 'participant'
    bool? isSystemMessage,
    String? messageType, // 'text', 'image', 'system_notification'
    Map<String, dynamic>? metadata,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  /// Create from Appwrite document
  factory ChatMessage.fromAppwrite(Map<String, dynamic> data) {
    return ChatMessage(
      id: data['\$id'] ?? '',
      content: data['content'] ?? '',
      username: data['username'] ?? 'Anonymous',
      userId: data['userId'] ?? '',
      chatRoomId: data['chatRoomId'] ?? '',
      roomType: data['roomType'] ?? 'arena',
      timestamp: data['timestamp'] != null 
          ? DateTime.parse(data['timestamp'])
          : data['\$createdAt'] != null
              ? DateTime.parse(data['\$createdAt'])
              : DateTime.now(),
      userAvatar: data['userAvatar'],
      userRole: data['userRole'],
      isSystemMessage: data['isSystemMessage'] ?? false,
      messageType: data['messageType'] ?? 'text',
      metadata: data['metadata'],
    );
  }

}

/// Extension methods for Appwrite integration
extension ChatMessageAppwrite on ChatMessage {
  /// Convert to Appwrite document format
  Map<String, dynamic> toAppwrite() {
    return {
      'content': content,
      'username': username,
      'userId': userId,
      'chatRoomId': chatRoomId,
      'roomType': roomType,
      'timestamp': timestamp.toIso8601String(),
      'userAvatar': userAvatar,
      'userRole': userRole,
      'isSystemMessage': isSystemMessage ?? false,
      'messageType': messageType ?? 'text',
      'metadata': metadata,
    };
  }
}

/// Chat room types enum
enum ChatRoomType {
  arena,
  debatesDiscussions,
  openDiscussion;

  String get displayName {
    switch (this) {
      case ChatRoomType.arena:
        return 'Arena';
      case ChatRoomType.debatesDiscussions:
        return 'Debates & Discussions';
      case ChatRoomType.openDiscussion:
        return 'Open Discussion';
    }
  }

  static ChatRoomType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'arena':
        return ChatRoomType.arena;
      case 'debates_discussions':
      case 'debatesdiscussions':
        return ChatRoomType.debatesDiscussions;
      case 'open_discussion':
      case 'opendiscussion':
        return ChatRoomType.openDiscussion;
      default:
        return ChatRoomType.arena;
    }
  }

  String get value {
    switch (this) {
      case ChatRoomType.arena:
        return 'arena';
      case ChatRoomType.debatesDiscussions:
        return 'debates_discussions';
      case ChatRoomType.openDiscussion:
        return 'open_discussion';
    }
  }
}

/// Chat user presence model for tracking active users
@freezed
class ChatUserPresence with _$ChatUserPresence {
  const factory ChatUserPresence({
    required String userId,
    required String username,
    required String chatRoomId,
    required DateTime lastSeen,
    String? userAvatar,
    String? userRole,
    bool? isOnline,
  }) = _ChatUserPresence;

  factory ChatUserPresence.fromJson(Map<String, dynamic> json) =>
      _$ChatUserPresenceFromJson(json);

  factory ChatUserPresence.fromAppwrite(Map<String, dynamic> data) {
    return ChatUserPresence(
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Anonymous',
      chatRoomId: data['chatRoomId'] ?? '',
      lastSeen: data['lastSeen'] != null 
          ? DateTime.parse(data['lastSeen'])
          : DateTime.now(),
      userAvatar: data['userAvatar'],
      userRole: data['userRole'],
      isOnline: data['isOnline'] ?? false,
    );
  }

}

/// Extension methods for Appwrite integration
extension ChatUserPresenceAppwrite on ChatUserPresence {
  Map<String, dynamic> toAppwrite() {
    return {
      'userId': userId,
      'username': username,
      'chatRoomId': chatRoomId,
      'lastSeen': lastSeen.toIso8601String(),
      'userAvatar': userAvatar,
      'userRole': userRole,
      'isOnline': isOnline ?? false,
    };
  }
}