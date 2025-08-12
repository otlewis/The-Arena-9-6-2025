import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'discussion_chat_message.freezed.dart';
part 'discussion_chat_message.g.dart';

/// Discussion room chat message model with Mattermost-inspired features
@freezed
class DiscussionChatMessage with _$DiscussionChatMessage {
  const factory DiscussionChatMessage({
    required String id,
    required String roomId,
    required String senderId,
    required String senderName,
    required String content,
    required DateTime timestamp,
    required DiscussionMessageType type,
    String? senderAvatar,
    String? replyToId, // For threaded conversations
    String? replyToContent, // Preview of replied message
    String? replyToSender, // Name of original sender
    Map<String, int>? reactions, // emoji -> count mapping
    List<String>? mentions, // @user mentions
    List<String>? attachments, // File URLs
    Map<String, dynamic>? metadata, // Extensible data
    @Default(false) bool isEdited,
    @Default(false) bool isDeleted,
    DateTime? editedAt,
    DateTime? deletedAt,
  }) = _DiscussionChatMessage;

  factory DiscussionChatMessage.fromJson(Map<String, dynamic> json) =>
      _$DiscussionChatMessageFromJson(json);
}

/// Message types for discussion chat
enum DiscussionMessageType {
  text,
  image,
  video,
  voice,
  file,
  system, // For system messages (user joined, role changed, etc.)
  announcement; // For moderator announcements

  String get displayName {
    switch (this) {
      case DiscussionMessageType.text:
        return 'Text';
      case DiscussionMessageType.image:
        return 'Image';
      case DiscussionMessageType.video:
        return 'Video';
      case DiscussionMessageType.voice:
        return 'Voice';
      case DiscussionMessageType.file:
        return 'File';
      case DiscussionMessageType.system:
        return 'System';
      case DiscussionMessageType.announcement:
        return 'Announcement';
    }
  }

  bool get isMedia => [image, video, voice].contains(this);
  bool get isSystemMessage => [system, announcement].contains(this);
}

/// Chat participant model for room context
@freezed
class ChatParticipant with _$ChatParticipant {
  const factory ChatParticipant({
    required String userId,
    required String username,
    required String role, // moderator, speaker, audience
    String? avatar,
    @Default(true) bool isOnline,
    DateTime? lastSeen,
    DateTime? joinedAt,
  }) = _ChatParticipant;

  factory ChatParticipant.fromJson(Map<String, dynamic> json) =>
      _$ChatParticipantFromJson(json);
}

/// Unified chat session model (supports both room and DM)
@freezed
class ChatSession with _$ChatSession {
  const factory ChatSession({
    required String id,
    required ChatSessionType type,
    required String title,
    List<ChatParticipant>? participants,
    String? lastMessage,
    DateTime? lastMessageTime,
    @Default(0) int unreadCount,
    String? roomId, // For room chats
    String? conversationId, // For DMs
    Map<String, dynamic>? metadata,
  }) = _ChatSession;

  factory ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);
}

/// Chat session types
enum ChatSessionType {
  roomChat,    // Public room discussion
  directMessage; // Private 1:1 chat

  String get displayName {
    switch (this) {
      case ChatSessionType.roomChat:
        return 'Room Chat';
      case ChatSessionType.directMessage:
        return 'Direct Message';
    }
  }
}

// Appwrite integration extensions
extension DiscussionChatMessageAppwrite on DiscussionChatMessage {
  Map<String, dynamic> toAppwrite() {
    // Only include attributes that exist in the collection
    final data = <String, dynamic>{
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
    };
    
    // Add optional attributes only if they have values and exist in collection
    if (senderAvatar != null) data['senderAvatar'] = senderAvatar;
    if (replyToId != null) data['replyToId'] = replyToId;
    if (replyToContent != null) data['replyToContent'] = replyToContent;
    if (replyToSender != null) data['replyToSender'] = replyToSender;
    
    // Skip attributes that don't exist in collection yet:
    // timestamp, type, reactions, mentions, attachments, isEdited, isDeleted, etc.
    
    return data;
  }

  static DiscussionChatMessage fromAppwrite(Map<String, dynamic> data, String documentId) {
    return DiscussionChatMessage(
      id: documentId,
      roomId: data['roomId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown User',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] != null 
          ? DateTime.parse(data['timestamp'])
          : (data['\$createdAt'] != null 
              ? DateTime.parse(data['\$createdAt'])
              : DateTime.now()),
      type: data['type'] != null
          ? DiscussionMessageType.values.firstWhere(
              (t) => t.name == data['type'],
              orElse: () => DiscussionMessageType.text,
            )
          : DiscussionMessageType.text,
      senderAvatar: data['senderAvatar'],
      replyToId: data['replyToId'],
      replyToContent: data['replyToContent'],
      replyToSender: data['replyToSender'],
      // Set default values for missing attributes
      reactions: null,
      mentions: null,
      attachments: null,
      metadata: null,
      isEdited: false,
      isDeleted: false,
      editedAt: null,
      deletedAt: null,
    );
  }
}