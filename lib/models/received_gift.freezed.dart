// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'received_gift.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ReceivedGift _$ReceivedGiftFromJson(Map<String, dynamic> json) {
  return _ReceivedGift.fromJson(json);
}

/// @nodoc
mixin _$ReceivedGift {
  String get id => throw _privateConstructorUsedError;
  String get giftId => throw _privateConstructorUsedError;
  String get senderId => throw _privateConstructorUsedError;
  String get senderName => throw _privateConstructorUsedError;
  String? get senderAvatar => throw _privateConstructorUsedError;
  String get receiverId => throw _privateConstructorUsedError;
  String get receiverName => throw _privateConstructorUsedError;
  String? get message =>
      throw _privateConstructorUsedError; // Optional message from sender
  String? get roomId =>
      throw _privateConstructorUsedError; // If sent during a room session
  String? get roomType =>
      throw _privateConstructorUsedError; // arena, debate_discussion, open_discussion
  String? get roomName =>
      throw _privateConstructorUsedError; // Name of the room where gift was sent
  DateTime get createdAt => throw _privateConstructorUsedError;
  bool get isRead =>
      throw _privateConstructorUsedError; // Whether recipient has seen the gift
  bool get isNotified => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ReceivedGiftCopyWith<ReceivedGift> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReceivedGiftCopyWith<$Res> {
  factory $ReceivedGiftCopyWith(
          ReceivedGift value, $Res Function(ReceivedGift) then) =
      _$ReceivedGiftCopyWithImpl<$Res, ReceivedGift>;
  @useResult
  $Res call(
      {String id,
      String giftId,
      String senderId,
      String senderName,
      String? senderAvatar,
      String receiverId,
      String receiverName,
      String? message,
      String? roomId,
      String? roomType,
      String? roomName,
      DateTime createdAt,
      bool isRead,
      bool isNotified});
}

/// @nodoc
class _$ReceivedGiftCopyWithImpl<$Res, $Val extends ReceivedGift>
    implements $ReceivedGiftCopyWith<$Res> {
  _$ReceivedGiftCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? giftId = null,
    Object? senderId = null,
    Object? senderName = null,
    Object? senderAvatar = freezed,
    Object? receiverId = null,
    Object? receiverName = null,
    Object? message = freezed,
    Object? roomId = freezed,
    Object? roomType = freezed,
    Object? roomName = freezed,
    Object? createdAt = null,
    Object? isRead = null,
    Object? isNotified = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      giftId: null == giftId
          ? _value.giftId
          : giftId // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      senderName: null == senderName
          ? _value.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String,
      senderAvatar: freezed == senderAvatar
          ? _value.senderAvatar
          : senderAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      receiverId: null == receiverId
          ? _value.receiverId
          : receiverId // ignore: cast_nullable_to_non_nullable
              as String,
      receiverName: null == receiverName
          ? _value.receiverName
          : receiverName // ignore: cast_nullable_to_non_nullable
              as String,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      roomId: freezed == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String?,
      roomType: freezed == roomType
          ? _value.roomType
          : roomType // ignore: cast_nullable_to_non_nullable
              as String?,
      roomName: freezed == roomName
          ? _value.roomName
          : roomName // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      isNotified: null == isNotified
          ? _value.isNotified
          : isNotified // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReceivedGiftImplCopyWith<$Res>
    implements $ReceivedGiftCopyWith<$Res> {
  factory _$$ReceivedGiftImplCopyWith(
          _$ReceivedGiftImpl value, $Res Function(_$ReceivedGiftImpl) then) =
      __$$ReceivedGiftImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String giftId,
      String senderId,
      String senderName,
      String? senderAvatar,
      String receiverId,
      String receiverName,
      String? message,
      String? roomId,
      String? roomType,
      String? roomName,
      DateTime createdAt,
      bool isRead,
      bool isNotified});
}

/// @nodoc
class __$$ReceivedGiftImplCopyWithImpl<$Res>
    extends _$ReceivedGiftCopyWithImpl<$Res, _$ReceivedGiftImpl>
    implements _$$ReceivedGiftImplCopyWith<$Res> {
  __$$ReceivedGiftImplCopyWithImpl(
      _$ReceivedGiftImpl _value, $Res Function(_$ReceivedGiftImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? giftId = null,
    Object? senderId = null,
    Object? senderName = null,
    Object? senderAvatar = freezed,
    Object? receiverId = null,
    Object? receiverName = null,
    Object? message = freezed,
    Object? roomId = freezed,
    Object? roomType = freezed,
    Object? roomName = freezed,
    Object? createdAt = null,
    Object? isRead = null,
    Object? isNotified = null,
  }) {
    return _then(_$ReceivedGiftImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      giftId: null == giftId
          ? _value.giftId
          : giftId // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      senderName: null == senderName
          ? _value.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String,
      senderAvatar: freezed == senderAvatar
          ? _value.senderAvatar
          : senderAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      receiverId: null == receiverId
          ? _value.receiverId
          : receiverId // ignore: cast_nullable_to_non_nullable
              as String,
      receiverName: null == receiverName
          ? _value.receiverName
          : receiverName // ignore: cast_nullable_to_non_nullable
              as String,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      roomId: freezed == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String?,
      roomType: freezed == roomType
          ? _value.roomType
          : roomType // ignore: cast_nullable_to_non_nullable
              as String?,
      roomName: freezed == roomName
          ? _value.roomName
          : roomName // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      isNotified: null == isNotified
          ? _value.isNotified
          : isNotified // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReceivedGiftImpl implements _ReceivedGift {
  const _$ReceivedGiftImpl(
      {required this.id,
      required this.giftId,
      required this.senderId,
      required this.senderName,
      this.senderAvatar,
      required this.receiverId,
      required this.receiverName,
      this.message,
      this.roomId,
      this.roomType,
      this.roomName,
      required this.createdAt,
      this.isRead = false,
      this.isNotified = false});

  factory _$ReceivedGiftImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReceivedGiftImplFromJson(json);

  @override
  final String id;
  @override
  final String giftId;
  @override
  final String senderId;
  @override
  final String senderName;
  @override
  final String? senderAvatar;
  @override
  final String receiverId;
  @override
  final String receiverName;
  @override
  final String? message;
// Optional message from sender
  @override
  final String? roomId;
// If sent during a room session
  @override
  final String? roomType;
// arena, debate_discussion, open_discussion
  @override
  final String? roomName;
// Name of the room where gift was sent
  @override
  final DateTime createdAt;
  @override
  @JsonKey()
  final bool isRead;
// Whether recipient has seen the gift
  @override
  @JsonKey()
  final bool isNotified;

  @override
  String toString() {
    return 'ReceivedGift(id: $id, giftId: $giftId, senderId: $senderId, senderName: $senderName, senderAvatar: $senderAvatar, receiverId: $receiverId, receiverName: $receiverName, message: $message, roomId: $roomId, roomType: $roomType, roomName: $roomName, createdAt: $createdAt, isRead: $isRead, isNotified: $isNotified)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReceivedGiftImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.giftId, giftId) || other.giftId == giftId) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName) &&
            (identical(other.senderAvatar, senderAvatar) ||
                other.senderAvatar == senderAvatar) &&
            (identical(other.receiverId, receiverId) ||
                other.receiverId == receiverId) &&
            (identical(other.receiverName, receiverName) ||
                other.receiverName == receiverName) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.roomType, roomType) ||
                other.roomType == roomType) &&
            (identical(other.roomName, roomName) ||
                other.roomName == roomName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.isNotified, isNotified) ||
                other.isNotified == isNotified));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      giftId,
      senderId,
      senderName,
      senderAvatar,
      receiverId,
      receiverName,
      message,
      roomId,
      roomType,
      roomName,
      createdAt,
      isRead,
      isNotified);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReceivedGiftImplCopyWith<_$ReceivedGiftImpl> get copyWith =>
      __$$ReceivedGiftImplCopyWithImpl<_$ReceivedGiftImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReceivedGiftImplToJson(
      this,
    );
  }
}

abstract class _ReceivedGift implements ReceivedGift {
  const factory _ReceivedGift(
      {required final String id,
      required final String giftId,
      required final String senderId,
      required final String senderName,
      final String? senderAvatar,
      required final String receiverId,
      required final String receiverName,
      final String? message,
      final String? roomId,
      final String? roomType,
      final String? roomName,
      required final DateTime createdAt,
      final bool isRead,
      final bool isNotified}) = _$ReceivedGiftImpl;

  factory _ReceivedGift.fromJson(Map<String, dynamic> json) =
      _$ReceivedGiftImpl.fromJson;

  @override
  String get id;
  @override
  String get giftId;
  @override
  String get senderId;
  @override
  String get senderName;
  @override
  String? get senderAvatar;
  @override
  String get receiverId;
  @override
  String get receiverName;
  @override
  String? get message;
  @override // Optional message from sender
  String? get roomId;
  @override // If sent during a room session
  String? get roomType;
  @override // arena, debate_discussion, open_discussion
  String? get roomName;
  @override // Name of the room where gift was sent
  DateTime get createdAt;
  @override
  bool get isRead;
  @override // Whether recipient has seen the gift
  bool get isNotified;
  @override
  @JsonKey(ignore: true)
  _$$ReceivedGiftImplCopyWith<_$ReceivedGiftImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
