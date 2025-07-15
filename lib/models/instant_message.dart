import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

part 'instant_message.freezed.dart';
part 'instant_message.g.dart';

/// Model for instant messages between users
@freezed
class InstantMessage with _$InstantMessage {
  const factory InstantMessage({
    required String id,
    required String senderId,
    required String receiverId,
    required String content,
    required DateTime timestamp,
    required bool isRead,
    String? senderUsername,
    String? senderAvatar,
    String? conversationId, // For grouping messages
    Map<String, dynamic>? metadata,
  }) = _InstantMessage;

  factory InstantMessage.fromJson(Map<String, dynamic> json) =>
      _$InstantMessageFromJson(json);
}

/// Model for conversation metadata
@freezed
class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    required List<String> participantIds,
    required DateTime lastMessageTime,
    String? lastMessage,
    required int unreadCount,
    required Map<String, UserInfo> participants,
    Map<String, dynamic>? metadata,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
}

/// Minimal user info for conversations
@freezed
class UserInfo with _$UserInfo {
  const factory UserInfo({
    required String id,
    required String username,
    String? avatar,
    bool? isOnline,
    DateTime? lastSeen,
  }) = _UserInfo;

  factory UserInfo.fromJson(Map<String, dynamic> json) =>
      _$UserInfoFromJson(json);
}

// Extension methods for Appwrite integration
extension InstantMessageAppwrite on InstantMessage {
  Map<String, dynamic> toAppwrite() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'senderUsername': senderUsername,
      'senderAvatar': senderAvatar,
      'conversationId': conversationId ?? InstantMessageAppwrite.generateConversationId(senderId, receiverId),
      // 'metadata': metadata, // Removed for now - add attribute to collection if needed
    };
  }

  static InstantMessage fromAppwrite(Map<String, dynamic> data, String documentId) {
    return InstantMessage(
      id: documentId,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] != null 
          ? DateTime.parse(data['timestamp'])
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
      senderUsername: data['senderUsername'],
      senderAvatar: data['senderAvatar'],
      conversationId: data['conversationId'],
      metadata: data['metadata'],
    );
  }

  static String generateConversationId(String userId1, String userId2) {
    // Sort user IDs to ensure consistent conversation ID regardless of sender/receiver
    final sortedIds = [userId1, userId2]..sort();
    final combined = '${sortedIds[0]}_${sortedIds[1]}';
    return sha256.convert(utf8.encode(combined)).toString().substring(0, 20);
  }
}

extension ConversationAppwrite on Conversation {
  Map<String, dynamic> toAppwrite() {
    return {
      'participantIds': participantIds,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'participants': participants.map((key, value) => MapEntry(key, value.toJson())),
      // 'metadata': metadata, // Removed for now - add attribute to collection if needed
    };
  }

  static Conversation fromAppwrite(Map<String, dynamic> data, String documentId) {
    return Conversation(
      id: documentId,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      lastMessageTime: data['lastMessageTime'] != null
          ? DateTime.parse(data['lastMessageTime'])
          : DateTime.now(),
      lastMessage: data['lastMessage'],
      unreadCount: data['unreadCount'] ?? 0,
      participants: (data['participants'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, UserInfo.fromJson(value)),
      ) ?? {},
      metadata: data['metadata'],
    );
  }
}