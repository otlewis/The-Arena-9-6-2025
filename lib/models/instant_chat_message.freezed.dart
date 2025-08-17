// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'instant_chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

InstantChatMessage _$InstantChatMessageFromJson(Map<String, dynamic> json) {
  return _InstantChatMessage.fromJson(json);
}

/// @nodoc
mixin _$InstantChatMessage {
  String get id => throw _privateConstructorUsedError;
  String get senderId => throw _privateConstructorUsedError;
  String get receiverId => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  bool get isRead => throw _privateConstructorUsedError;
  String? get senderName => throw _privateConstructorUsedError;
  String? get senderAvatar => throw _privateConstructorUsedError;
  InstantChatMessageType get type => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $InstantChatMessageCopyWith<InstantChatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InstantChatMessageCopyWith<$Res> {
  factory $InstantChatMessageCopyWith(
          InstantChatMessage value, $Res Function(InstantChatMessage) then) =
      _$InstantChatMessageCopyWithImpl<$Res, InstantChatMessage>;
  @useResult
  $Res call(
      {String id,
      String senderId,
      String receiverId,
      String content,
      DateTime timestamp,
      bool isRead,
      String? senderName,
      String? senderAvatar,
      InstantChatMessageType type});
}

/// @nodoc
class _$InstantChatMessageCopyWithImpl<$Res, $Val extends InstantChatMessage>
    implements $InstantChatMessageCopyWith<$Res> {
  _$InstantChatMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? receiverId = null,
    Object? content = null,
    Object? timestamp = null,
    Object? isRead = null,
    Object? senderName = freezed,
    Object? senderAvatar = freezed,
    Object? type = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      receiverId: null == receiverId
          ? _value.receiverId
          : receiverId // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      senderName: freezed == senderName
          ? _value.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String?,
      senderAvatar: freezed == senderAvatar
          ? _value.senderAvatar
          : senderAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as InstantChatMessageType,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InstantChatMessageImplCopyWith<$Res>
    implements $InstantChatMessageCopyWith<$Res> {
  factory _$$InstantChatMessageImplCopyWith(_$InstantChatMessageImpl value,
          $Res Function(_$InstantChatMessageImpl) then) =
      __$$InstantChatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String senderId,
      String receiverId,
      String content,
      DateTime timestamp,
      bool isRead,
      String? senderName,
      String? senderAvatar,
      InstantChatMessageType type});
}

/// @nodoc
class __$$InstantChatMessageImplCopyWithImpl<$Res>
    extends _$InstantChatMessageCopyWithImpl<$Res, _$InstantChatMessageImpl>
    implements _$$InstantChatMessageImplCopyWith<$Res> {
  __$$InstantChatMessageImplCopyWithImpl(_$InstantChatMessageImpl _value,
      $Res Function(_$InstantChatMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? receiverId = null,
    Object? content = null,
    Object? timestamp = null,
    Object? isRead = null,
    Object? senderName = freezed,
    Object? senderAvatar = freezed,
    Object? type = null,
  }) {
    return _then(_$InstantChatMessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      receiverId: null == receiverId
          ? _value.receiverId
          : receiverId // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      senderName: freezed == senderName
          ? _value.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String?,
      senderAvatar: freezed == senderAvatar
          ? _value.senderAvatar
          : senderAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as InstantChatMessageType,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InstantChatMessageImpl
    with DiagnosticableTreeMixin
    implements _InstantChatMessage {
  const _$InstantChatMessageImpl(
      {required this.id,
      required this.senderId,
      required this.receiverId,
      required this.content,
      required this.timestamp,
      required this.isRead,
      this.senderName,
      this.senderAvatar,
      this.type = InstantChatMessageType.text});

  factory _$InstantChatMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$InstantChatMessageImplFromJson(json);

  @override
  final String id;
  @override
  final String senderId;
  @override
  final String receiverId;
  @override
  final String content;
  @override
  final DateTime timestamp;
  @override
  final bool isRead;
  @override
  final String? senderName;
  @override
  final String? senderAvatar;
  @override
  @JsonKey()
  final InstantChatMessageType type;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'InstantChatMessage(id: $id, senderId: $senderId, receiverId: $receiverId, content: $content, timestamp: $timestamp, isRead: $isRead, senderName: $senderName, senderAvatar: $senderAvatar, type: $type)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'InstantChatMessage'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('senderId', senderId))
      ..add(DiagnosticsProperty('receiverId', receiverId))
      ..add(DiagnosticsProperty('content', content))
      ..add(DiagnosticsProperty('timestamp', timestamp))
      ..add(DiagnosticsProperty('isRead', isRead))
      ..add(DiagnosticsProperty('senderName', senderName))
      ..add(DiagnosticsProperty('senderAvatar', senderAvatar))
      ..add(DiagnosticsProperty('type', type));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InstantChatMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.receiverId, receiverId) ||
                other.receiverId == receiverId) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName) &&
            (identical(other.senderAvatar, senderAvatar) ||
                other.senderAvatar == senderAvatar) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, senderId, receiverId,
      content, timestamp, isRead, senderName, senderAvatar, type);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$InstantChatMessageImplCopyWith<_$InstantChatMessageImpl> get copyWith =>
      __$$InstantChatMessageImplCopyWithImpl<_$InstantChatMessageImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InstantChatMessageImplToJson(
      this,
    );
  }
}

abstract class _InstantChatMessage implements InstantChatMessage {
  const factory _InstantChatMessage(
      {required final String id,
      required final String senderId,
      required final String receiverId,
      required final String content,
      required final DateTime timestamp,
      required final bool isRead,
      final String? senderName,
      final String? senderAvatar,
      final InstantChatMessageType type}) = _$InstantChatMessageImpl;

  factory _InstantChatMessage.fromJson(Map<String, dynamic> json) =
      _$InstantChatMessageImpl.fromJson;

  @override
  String get id;
  @override
  String get senderId;
  @override
  String get receiverId;
  @override
  String get content;
  @override
  DateTime get timestamp;
  @override
  bool get isRead;
  @override
  String? get senderName;
  @override
  String? get senderAvatar;
  @override
  InstantChatMessageType get type;
  @override
  @JsonKey(ignore: true)
  _$$InstantChatMessageImplCopyWith<_$InstantChatMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
