// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'received_gift.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReceivedGiftImpl _$$ReceivedGiftImplFromJson(Map<String, dynamic> json) =>
    _$ReceivedGiftImpl(
      id: json['id'] as String,
      giftId: json['giftId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderAvatar: json['senderAvatar'] as String?,
      receiverId: json['receiverId'] as String,
      receiverName: json['receiverName'] as String,
      message: json['message'] as String?,
      roomId: json['roomId'] as String?,
      roomType: json['roomType'] as String?,
      roomName: json['roomName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      isNotified: json['isNotified'] as bool? ?? false,
    );

Map<String, dynamic> _$$ReceivedGiftImplToJson(_$ReceivedGiftImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'giftId': instance.giftId,
      'senderId': instance.senderId,
      'senderName': instance.senderName,
      'senderAvatar': instance.senderAvatar,
      'receiverId': instance.receiverId,
      'receiverName': instance.receiverName,
      'message': instance.message,
      'roomId': instance.roomId,
      'roomType': instance.roomType,
      'roomName': instance.roomName,
      'createdAt': instance.createdAt.toIso8601String(),
      'isRead': instance.isRead,
      'isNotified': instance.isNotified,
    };
