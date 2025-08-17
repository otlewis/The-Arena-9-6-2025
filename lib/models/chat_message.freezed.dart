// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) {
  return _ChatMessage.fromJson(json);
}

/// @nodoc
mixin _$ChatMessage {
  String get id => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get chatRoomId => throw _privateConstructorUsedError;
  String get roomType => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  String? get userAvatar => throw _privateConstructorUsedError;
  String? get userRole =>
      throw _privateConstructorUsedError; // 'moderator', 'speaker', 'judge', 'participant'
  bool? get isSystemMessage => throw _privateConstructorUsedError;
  String? get messageType =>
      throw _privateConstructorUsedError; // 'text', 'image', 'system_notification'
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChatMessageCopyWith<ChatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatMessageCopyWith<$Res> {
  factory $ChatMessageCopyWith(
          ChatMessage value, $Res Function(ChatMessage) then) =
      _$ChatMessageCopyWithImpl<$Res, ChatMessage>;
  @useResult
  $Res call(
      {String id,
      String content,
      String username,
      String userId,
      String chatRoomId,
      String roomType,
      DateTime timestamp,
      String? userAvatar,
      String? userRole,
      bool? isSystemMessage,
      String? messageType,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$ChatMessageCopyWithImpl<$Res, $Val extends ChatMessage>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? content = null,
    Object? username = null,
    Object? userId = null,
    Object? chatRoomId = null,
    Object? roomType = null,
    Object? timestamp = null,
    Object? userAvatar = freezed,
    Object? userRole = freezed,
    Object? isSystemMessage = freezed,
    Object? messageType = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      chatRoomId: null == chatRoomId
          ? _value.chatRoomId
          : chatRoomId // ignore: cast_nullable_to_non_nullable
              as String,
      roomType: null == roomType
          ? _value.roomType
          : roomType // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      userAvatar: freezed == userAvatar
          ? _value.userAvatar
          : userAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      userRole: freezed == userRole
          ? _value.userRole
          : userRole // ignore: cast_nullable_to_non_nullable
              as String?,
      isSystemMessage: freezed == isSystemMessage
          ? _value.isSystemMessage
          : isSystemMessage // ignore: cast_nullable_to_non_nullable
              as bool?,
      messageType: freezed == messageType
          ? _value.messageType
          : messageType // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatMessageImplCopyWith<$Res>
    implements $ChatMessageCopyWith<$Res> {
  factory _$$ChatMessageImplCopyWith(
          _$ChatMessageImpl value, $Res Function(_$ChatMessageImpl) then) =
      __$$ChatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String content,
      String username,
      String userId,
      String chatRoomId,
      String roomType,
      DateTime timestamp,
      String? userAvatar,
      String? userRole,
      bool? isSystemMessage,
      String? messageType,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$$ChatMessageImplCopyWithImpl<$Res>
    extends _$ChatMessageCopyWithImpl<$Res, _$ChatMessageImpl>
    implements _$$ChatMessageImplCopyWith<$Res> {
  __$$ChatMessageImplCopyWithImpl(
      _$ChatMessageImpl _value, $Res Function(_$ChatMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? content = null,
    Object? username = null,
    Object? userId = null,
    Object? chatRoomId = null,
    Object? roomType = null,
    Object? timestamp = null,
    Object? userAvatar = freezed,
    Object? userRole = freezed,
    Object? isSystemMessage = freezed,
    Object? messageType = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_$ChatMessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      chatRoomId: null == chatRoomId
          ? _value.chatRoomId
          : chatRoomId // ignore: cast_nullable_to_non_nullable
              as String,
      roomType: null == roomType
          ? _value.roomType
          : roomType // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      userAvatar: freezed == userAvatar
          ? _value.userAvatar
          : userAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      userRole: freezed == userRole
          ? _value.userRole
          : userRole // ignore: cast_nullable_to_non_nullable
              as String?,
      isSystemMessage: freezed == isSystemMessage
          ? _value.isSystemMessage
          : isSystemMessage // ignore: cast_nullable_to_non_nullable
              as bool?,
      messageType: freezed == messageType
          ? _value.messageType
          : messageType // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatMessageImpl with DiagnosticableTreeMixin implements _ChatMessage {
  const _$ChatMessageImpl(
      {required this.id,
      required this.content,
      required this.username,
      required this.userId,
      required this.chatRoomId,
      required this.roomType,
      required this.timestamp,
      this.userAvatar,
      this.userRole,
      this.isSystemMessage,
      this.messageType,
      final Map<String, dynamic>? metadata})
      : _metadata = metadata;

  factory _$ChatMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatMessageImplFromJson(json);

  @override
  final String id;
  @override
  final String content;
  @override
  final String username;
  @override
  final String userId;
  @override
  final String chatRoomId;
  @override
  final String roomType;
  @override
  final DateTime timestamp;
  @override
  final String? userAvatar;
  @override
  final String? userRole;
// 'moderator', 'speaker', 'judge', 'participant'
  @override
  final bool? isSystemMessage;
  @override
  final String? messageType;
// 'text', 'image', 'system_notification'
  final Map<String, dynamic>? _metadata;
// 'text', 'image', 'system_notification'
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ChatMessage(id: $id, content: $content, username: $username, userId: $userId, chatRoomId: $chatRoomId, roomType: $roomType, timestamp: $timestamp, userAvatar: $userAvatar, userRole: $userRole, isSystemMessage: $isSystemMessage, messageType: $messageType, metadata: $metadata)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ChatMessage'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('content', content))
      ..add(DiagnosticsProperty('username', username))
      ..add(DiagnosticsProperty('userId', userId))
      ..add(DiagnosticsProperty('chatRoomId', chatRoomId))
      ..add(DiagnosticsProperty('roomType', roomType))
      ..add(DiagnosticsProperty('timestamp', timestamp))
      ..add(DiagnosticsProperty('userAvatar', userAvatar))
      ..add(DiagnosticsProperty('userRole', userRole))
      ..add(DiagnosticsProperty('isSystemMessage', isSystemMessage))
      ..add(DiagnosticsProperty('messageType', messageType))
      ..add(DiagnosticsProperty('metadata', metadata));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.chatRoomId, chatRoomId) ||
                other.chatRoomId == chatRoomId) &&
            (identical(other.roomType, roomType) ||
                other.roomType == roomType) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.userAvatar, userAvatar) ||
                other.userAvatar == userAvatar) &&
            (identical(other.userRole, userRole) ||
                other.userRole == userRole) &&
            (identical(other.isSystemMessage, isSystemMessage) ||
                other.isSystemMessage == isSystemMessage) &&
            (identical(other.messageType, messageType) ||
                other.messageType == messageType) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      content,
      username,
      userId,
      chatRoomId,
      roomType,
      timestamp,
      userAvatar,
      userRole,
      isSystemMessage,
      messageType,
      const DeepCollectionEquality().hash(_metadata));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      __$$ChatMessageImplCopyWithImpl<_$ChatMessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatMessageImplToJson(
      this,
    );
  }
}

abstract class _ChatMessage implements ChatMessage {
  const factory _ChatMessage(
      {required final String id,
      required final String content,
      required final String username,
      required final String userId,
      required final String chatRoomId,
      required final String roomType,
      required final DateTime timestamp,
      final String? userAvatar,
      final String? userRole,
      final bool? isSystemMessage,
      final String? messageType,
      final Map<String, dynamic>? metadata}) = _$ChatMessageImpl;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) =
      _$ChatMessageImpl.fromJson;

  @override
  String get id;
  @override
  String get content;
  @override
  String get username;
  @override
  String get userId;
  @override
  String get chatRoomId;
  @override
  String get roomType;
  @override
  DateTime get timestamp;
  @override
  String? get userAvatar;
  @override
  String? get userRole;
  @override // 'moderator', 'speaker', 'judge', 'participant'
  bool? get isSystemMessage;
  @override
  String? get messageType;
  @override // 'text', 'image', 'system_notification'
  Map<String, dynamic>? get metadata;
  @override
  @JsonKey(ignore: true)
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChatUserPresence _$ChatUserPresenceFromJson(Map<String, dynamic> json) {
  return _ChatUserPresence.fromJson(json);
}

/// @nodoc
mixin _$ChatUserPresence {
  String get userId => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String get chatRoomId => throw _privateConstructorUsedError;
  DateTime get lastSeen => throw _privateConstructorUsedError;
  String? get userAvatar => throw _privateConstructorUsedError;
  String? get userRole => throw _privateConstructorUsedError;
  bool? get isOnline => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChatUserPresenceCopyWith<ChatUserPresence> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatUserPresenceCopyWith<$Res> {
  factory $ChatUserPresenceCopyWith(
          ChatUserPresence value, $Res Function(ChatUserPresence) then) =
      _$ChatUserPresenceCopyWithImpl<$Res, ChatUserPresence>;
  @useResult
  $Res call(
      {String userId,
      String username,
      String chatRoomId,
      DateTime lastSeen,
      String? userAvatar,
      String? userRole,
      bool? isOnline});
}

/// @nodoc
class _$ChatUserPresenceCopyWithImpl<$Res, $Val extends ChatUserPresence>
    implements $ChatUserPresenceCopyWith<$Res> {
  _$ChatUserPresenceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? username = null,
    Object? chatRoomId = null,
    Object? lastSeen = null,
    Object? userAvatar = freezed,
    Object? userRole = freezed,
    Object? isOnline = freezed,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      chatRoomId: null == chatRoomId
          ? _value.chatRoomId
          : chatRoomId // ignore: cast_nullable_to_non_nullable
              as String,
      lastSeen: null == lastSeen
          ? _value.lastSeen
          : lastSeen // ignore: cast_nullable_to_non_nullable
              as DateTime,
      userAvatar: freezed == userAvatar
          ? _value.userAvatar
          : userAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      userRole: freezed == userRole
          ? _value.userRole
          : userRole // ignore: cast_nullable_to_non_nullable
              as String?,
      isOnline: freezed == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatUserPresenceImplCopyWith<$Res>
    implements $ChatUserPresenceCopyWith<$Res> {
  factory _$$ChatUserPresenceImplCopyWith(_$ChatUserPresenceImpl value,
          $Res Function(_$ChatUserPresenceImpl) then) =
      __$$ChatUserPresenceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String userId,
      String username,
      String chatRoomId,
      DateTime lastSeen,
      String? userAvatar,
      String? userRole,
      bool? isOnline});
}

/// @nodoc
class __$$ChatUserPresenceImplCopyWithImpl<$Res>
    extends _$ChatUserPresenceCopyWithImpl<$Res, _$ChatUserPresenceImpl>
    implements _$$ChatUserPresenceImplCopyWith<$Res> {
  __$$ChatUserPresenceImplCopyWithImpl(_$ChatUserPresenceImpl _value,
      $Res Function(_$ChatUserPresenceImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? username = null,
    Object? chatRoomId = null,
    Object? lastSeen = null,
    Object? userAvatar = freezed,
    Object? userRole = freezed,
    Object? isOnline = freezed,
  }) {
    return _then(_$ChatUserPresenceImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      chatRoomId: null == chatRoomId
          ? _value.chatRoomId
          : chatRoomId // ignore: cast_nullable_to_non_nullable
              as String,
      lastSeen: null == lastSeen
          ? _value.lastSeen
          : lastSeen // ignore: cast_nullable_to_non_nullable
              as DateTime,
      userAvatar: freezed == userAvatar
          ? _value.userAvatar
          : userAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      userRole: freezed == userRole
          ? _value.userRole
          : userRole // ignore: cast_nullable_to_non_nullable
              as String?,
      isOnline: freezed == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatUserPresenceImpl
    with DiagnosticableTreeMixin
    implements _ChatUserPresence {
  const _$ChatUserPresenceImpl(
      {required this.userId,
      required this.username,
      required this.chatRoomId,
      required this.lastSeen,
      this.userAvatar,
      this.userRole,
      this.isOnline});

  factory _$ChatUserPresenceImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatUserPresenceImplFromJson(json);

  @override
  final String userId;
  @override
  final String username;
  @override
  final String chatRoomId;
  @override
  final DateTime lastSeen;
  @override
  final String? userAvatar;
  @override
  final String? userRole;
  @override
  final bool? isOnline;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ChatUserPresence(userId: $userId, username: $username, chatRoomId: $chatRoomId, lastSeen: $lastSeen, userAvatar: $userAvatar, userRole: $userRole, isOnline: $isOnline)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ChatUserPresence'))
      ..add(DiagnosticsProperty('userId', userId))
      ..add(DiagnosticsProperty('username', username))
      ..add(DiagnosticsProperty('chatRoomId', chatRoomId))
      ..add(DiagnosticsProperty('lastSeen', lastSeen))
      ..add(DiagnosticsProperty('userAvatar', userAvatar))
      ..add(DiagnosticsProperty('userRole', userRole))
      ..add(DiagnosticsProperty('isOnline', isOnline));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatUserPresenceImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.chatRoomId, chatRoomId) ||
                other.chatRoomId == chatRoomId) &&
            (identical(other.lastSeen, lastSeen) ||
                other.lastSeen == lastSeen) &&
            (identical(other.userAvatar, userAvatar) ||
                other.userAvatar == userAvatar) &&
            (identical(other.userRole, userRole) ||
                other.userRole == userRole) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, userId, username, chatRoomId,
      lastSeen, userAvatar, userRole, isOnline);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatUserPresenceImplCopyWith<_$ChatUserPresenceImpl> get copyWith =>
      __$$ChatUserPresenceImplCopyWithImpl<_$ChatUserPresenceImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatUserPresenceImplToJson(
      this,
    );
  }
}

abstract class _ChatUserPresence implements ChatUserPresence {
  const factory _ChatUserPresence(
      {required final String userId,
      required final String username,
      required final String chatRoomId,
      required final DateTime lastSeen,
      final String? userAvatar,
      final String? userRole,
      final bool? isOnline}) = _$ChatUserPresenceImpl;

  factory _ChatUserPresence.fromJson(Map<String, dynamic> json) =
      _$ChatUserPresenceImpl.fromJson;

  @override
  String get userId;
  @override
  String get username;
  @override
  String get chatRoomId;
  @override
  DateTime get lastSeen;
  @override
  String? get userAvatar;
  @override
  String? get userRole;
  @override
  bool? get isOnline;
  @override
  @JsonKey(ignore: true)
  _$$ChatUserPresenceImplCopyWith<_$ChatUserPresenceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
