import 'dart:convert';
import '../core/logging/app_logger.dart';

enum MessageType {
  text('text'),
  system('system'),
  voice('voice'),
  emoji('emoji'),
  poll('poll'),
  moderatorAction('moderator_action'),
  gift('gift');

  const MessageType(this.value);
  final String value;

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => MessageType.text,
    );
  }
}

class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final MessageType type;
  final String content;
  final DateTime timestamp;
  final String? replyToMessageId;
  final List<String> mentions;
  final Map<String, dynamic> metadata;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.type = MessageType.text,
    required this.content,
    required this.timestamp,
    this.replyToMessageId,
    this.mentions = const [],
    this.metadata = const {},
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    // Handle metadata parsing - could be string (from Appwrite) or Map (from local)
    Map<String, dynamic> parsedMetadata = {};
    final metadataValue = map['metadata'];
    if (metadataValue != null) {
      if (metadataValue is String && metadataValue.isNotEmpty) {
        try {
          parsedMetadata = Map<String, dynamic>.from(jsonDecode(metadataValue));
        } catch (e) {
          AppLogger().warning('Error parsing message metadata JSON', e);
        }
      } else if (metadataValue is Map) {
        parsedMetadata = Map<String, dynamic>.from(metadataValue);
      }
    }

    return Message(
      id: map['id'] ?? '',
      roomId: map['roomId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderAvatar: map['senderAvatar'],
      type: MessageType.fromString(map['type'] ?? 'text'),
      content: map['content'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      replyToMessageId: map['replyToMessageId'],
      mentions: List<String>.from(map['mentions'] ?? []),
      metadata: parsedMetadata,
      isEdited: map['isEdited'] ?? false,
      editedAt: map['editedAt'] != null ? DateTime.parse(map['editedAt']) : null,
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // Don't include 'id' - Appwrite generates document IDs automatically
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'type': type.value,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'replyToMessageId': replyToMessageId,
      'mentions': mentions,
      'metadata': metadata.isNotEmpty ? jsonEncode(metadata) : '', // Convert to JSON string
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  Message copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    MessageType? type,
    String? content,
    DateTime? timestamp,
    String? replyToMessageId,
    List<String>? mentions,
    Map<String, dynamic>? metadata,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      mentions: mentions ?? this.mentions,
      metadata: metadata ?? this.metadata,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  // Helper methods
  bool get isTextMessage => type == MessageType.text;
  bool get isSystemMessage => type == MessageType.system;
  bool get isVoiceMessage => type == MessageType.voice;
  bool get isEmojiMessage => type == MessageType.emoji;
  bool get isPollMessage => type == MessageType.poll;
  bool get isModeratorAction => type == MessageType.moderatorAction;
  bool get isGiftMessage => type == MessageType.gift;
  
  bool get isReply => replyToMessageId != null;
  bool get hasMentions => mentions.isNotEmpty;
  
  String get displayContent {
    if (isDeleted) return '[Message deleted]';
    if (isSystemMessage) return content;
    return content;
  }
  
  // Factory methods for specific message types
  static Message systemMessage({
    required String roomId,
    required String content,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: roomId,
      senderId: 'system',
      senderName: 'System',
      type: MessageType.system,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
    );
  }
  
  static Message moderatorAction({
    required String roomId,
    required String moderatorId,
    required String moderatorName,
    required String action,
    String? targetUserId,
    String? targetUserName,
  }) {
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: roomId,
      senderId: moderatorId,
      senderName: moderatorName,
      type: MessageType.moderatorAction,
      content: action,
      timestamp: DateTime.now(),
      metadata: {
        'action': action,
        'targetUserId': targetUserId,
        'targetUserName': targetUserName,
      },
    );
  }
  
  static Message giftMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String giftId,
    required String giftName,
    required String recipientId,
    required String recipientName,
    required int cost,
    String? giftMessage,
  }) {
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      type: MessageType.gift,
      content: '🎁 $senderName sent a $giftName gift to $recipientName${giftMessage != null ? ' • "$giftMessage"' : ''}',
      timestamp: DateTime.now(),
      metadata: {
        'giftId': giftId,
        'giftName': giftName,
        'recipientId': recipientId,
        'recipientName': recipientName,
        'cost': cost,
        'giftMessage': giftMessage,
      },
    );
  }
} 