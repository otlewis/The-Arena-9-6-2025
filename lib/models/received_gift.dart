import 'package:freezed_annotation/freezed_annotation.dart';
import 'gift.dart';

part 'received_gift.freezed.dart';
part 'received_gift.g.dart';

@freezed
class ReceivedGift with _$ReceivedGift {
  const factory ReceivedGift({
    required String id,
    required String giftId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String receiverId,
    required String receiverName,
    String? message, // Optional message from sender
    String? roomId, // If sent during a room session
    String? roomType, // arena, debate_discussion, open_discussion
    String? roomName, // Name of the room where gift was sent
    required DateTime createdAt,
    @Default(false) bool isRead, // Whether recipient has seen the gift
    @Default(false) bool isNotified, // Whether recipient was notified
  }) = _ReceivedGift;

  factory ReceivedGift.fromJson(Map<String, dynamic> json) => _$ReceivedGiftFromJson(json);
}

extension ReceivedGiftExtension on ReceivedGift {
  /// Get the gift details from the gift catalog
  Gift? get giftDetails => GiftConstants.getGiftById(giftId);
  
  /// Get display text for where the gift was sent
  String get contextText {
    if (roomId != null && roomName != null) {
      return 'in $roomName';
    } else if (roomType != null) {
      switch (roomType) {
        case 'arena':
          return 'during an Arena debate';
        case 'debate_discussion':
          return 'during a Debates & Discussion';
        case 'open_discussion':
          return 'during an Open Discussion';
        default:
          return 'in a discussion room';
      }
    }
    return 'on your profile';
  }
  
  /// Get formatted time ago text
  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}