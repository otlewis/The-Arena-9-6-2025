// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'discussion_chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DiscussionChatMessage _$DiscussionChatMessageFromJson(
    Map<String, dynamic> json) {
  return _DiscussionChatMessage.fromJson(json);
}

/// @nodoc
mixin _$DiscussionChatMessage {
  String get id => throw _privateConstructorUsedError;
  String get roomId => throw _privateConstructorUsedError;
  String get senderId => throw _privateConstructorUsedError;
  String get senderName => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  DiscussionMessageType get type => throw _privateConstructorUsedError;
  String? get senderAvatar => throw _privateConstructorUsedError;
  String? get replyToId =>
      throw _privateConstructorUsedError; // For threaded conversations
  String? get replyToContent =>
      throw _privateConstructorUsedError; // Preview of replied message
  String? get replyToSender =>
      throw _privateConstructorUsedError; // Name of original sender
  Map<String, int>? get reactions =>
      throw _privateConstructorUsedError; // emoji -> count mapping
  List<String>? get mentions =>
      throw _privateConstructorUsedError; // @user mentions
  List<String>? get attachments =>
      throw _privateConstructorUsedError; // File URLs
  Map<String, dynamic>? get metadata =>
      throw _privateConstructorUsedError; // Extensible data
  bool get isEdited => throw _privateConstructorUsedError;
  bool get isDeleted => throw _privateConstructorUsedError;
  DateTime? get editedAt => throw _privateConstructorUsedError;
  DateTime? get deletedAt => throw _privateConstructorUsedError;

  /// Serializes this DiscussionChatMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DiscussionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DiscussionChatMessageCopyWith<DiscussionChatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DiscussionChatMessageCopyWith<$Res> {
  factory $DiscussionChatMessageCopyWith(DiscussionChatMessage value,
          $Res Function(DiscussionChatMessage) then) =
      _$DiscussionChatMessageCopyWithImpl<$Res, DiscussionChatMessage>;
  @useResult
  $Res call(
      {String id,
      String roomId,
      String senderId,
      String senderName,
      String content,
      DateTime timestamp,
      DiscussionMessageType type,
      String? senderAvatar,
      String? replyToId,
      String? replyToContent,
      String? replyToSender,
      Map<String, int>? reactions,
      List<String>? mentions,
      List<String>? attachments,
      Map<String, dynamic>? metadata,
      bool isEdited,
      bool isDeleted,
      DateTime? editedAt,
      DateTime? deletedAt});
}

/// @nodoc
class _$DiscussionChatMessageCopyWithImpl<$Res,
        $Val extends DiscussionChatMessage>
    implements $DiscussionChatMessageCopyWith<$Res> {
  _$DiscussionChatMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DiscussionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? senderId = null,
    Object? senderName = null,
    Object? content = null,
    Object? timestamp = null,
    Object? type = null,
    Object? senderAvatar = freezed,
    Object? replyToId = freezed,
    Object? replyToContent = freezed,
    Object? replyToSender = freezed,
    Object? reactions = freezed,
    Object? mentions = freezed,
    Object? attachments = freezed,
    Object? metadata = freezed,
    Object? isEdited = null,
    Object? isDeleted = null,
    Object? editedAt = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      senderName: null == senderName
          ? _value.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as DiscussionMessageType,
      senderAvatar: freezed == senderAvatar
          ? _value.senderAvatar
          : senderAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToId: freezed == replyToId
          ? _value.replyToId
          : replyToId // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToContent: freezed == replyToContent
          ? _value.replyToContent
          : replyToContent // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToSender: freezed == replyToSender
          ? _value.replyToSender
          : replyToSender // ignore: cast_nullable_to_non_nullable
              as String?,
      reactions: freezed == reactions
          ? _value.reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, int>?,
      mentions: freezed == mentions
          ? _value.mentions
          : mentions // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      attachments: freezed == attachments
          ? _value.attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      isEdited: null == isEdited
          ? _value.isEdited
          : isEdited // ignore: cast_nullable_to_non_nullable
              as bool,
      isDeleted: null == isDeleted
          ? _value.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool,
      editedAt: freezed == editedAt
          ? _value.editedAt
          : editedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DiscussionChatMessageImplCopyWith<$Res>
    implements $DiscussionChatMessageCopyWith<$Res> {
  factory _$$DiscussionChatMessageImplCopyWith(
          _$DiscussionChatMessageImpl value,
          $Res Function(_$DiscussionChatMessageImpl) then) =
      __$$DiscussionChatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String roomId,
      String senderId,
      String senderName,
      String content,
      DateTime timestamp,
      DiscussionMessageType type,
      String? senderAvatar,
      String? replyToId,
      String? replyToContent,
      String? replyToSender,
      Map<String, int>? reactions,
      List<String>? mentions,
      List<String>? attachments,
      Map<String, dynamic>? metadata,
      bool isEdited,
      bool isDeleted,
      DateTime? editedAt,
      DateTime? deletedAt});
}

/// @nodoc
class __$$DiscussionChatMessageImplCopyWithImpl<$Res>
    extends _$DiscussionChatMessageCopyWithImpl<$Res,
        _$DiscussionChatMessageImpl>
    implements _$$DiscussionChatMessageImplCopyWith<$Res> {
  __$$DiscussionChatMessageImplCopyWithImpl(_$DiscussionChatMessageImpl _value,
      $Res Function(_$DiscussionChatMessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of DiscussionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? roomId = null,
    Object? senderId = null,
    Object? senderName = null,
    Object? content = null,
    Object? timestamp = null,
    Object? type = null,
    Object? senderAvatar = freezed,
    Object? replyToId = freezed,
    Object? replyToContent = freezed,
    Object? replyToSender = freezed,
    Object? reactions = freezed,
    Object? mentions = freezed,
    Object? attachments = freezed,
    Object? metadata = freezed,
    Object? isEdited = null,
    Object? isDeleted = null,
    Object? editedAt = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(_$DiscussionChatMessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      senderName: null == senderName
          ? _value.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as DiscussionMessageType,
      senderAvatar: freezed == senderAvatar
          ? _value.senderAvatar
          : senderAvatar // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToId: freezed == replyToId
          ? _value.replyToId
          : replyToId // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToContent: freezed == replyToContent
          ? _value.replyToContent
          : replyToContent // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToSender: freezed == replyToSender
          ? _value.replyToSender
          : replyToSender // ignore: cast_nullable_to_non_nullable
              as String?,
      reactions: freezed == reactions
          ? _value._reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, int>?,
      mentions: freezed == mentions
          ? _value._mentions
          : mentions // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      attachments: freezed == attachments
          ? _value._attachments
          : attachments // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      isEdited: null == isEdited
          ? _value.isEdited
          : isEdited // ignore: cast_nullable_to_non_nullable
              as bool,
      isDeleted: null == isDeleted
          ? _value.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool,
      editedAt: freezed == editedAt
          ? _value.editedAt
          : editedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DiscussionChatMessageImpl
    with DiagnosticableTreeMixin
    implements _DiscussionChatMessage {
  const _$DiscussionChatMessageImpl(
      {required this.id,
      required this.roomId,
      required this.senderId,
      required this.senderName,
      required this.content,
      required this.timestamp,
      required this.type,
      this.senderAvatar,
      this.replyToId,
      this.replyToContent,
      this.replyToSender,
      final Map<String, int>? reactions,
      final List<String>? mentions,
      final List<String>? attachments,
      final Map<String, dynamic>? metadata,
      this.isEdited = false,
      this.isDeleted = false,
      this.editedAt,
      this.deletedAt})
      : _reactions = reactions,
        _mentions = mentions,
        _attachments = attachments,
        _metadata = metadata;

  factory _$DiscussionChatMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$DiscussionChatMessageImplFromJson(json);

  @override
  final String id;
  @override
  final String roomId;
  @override
  final String senderId;
  @override
  final String senderName;
  @override
  final String content;
  @override
  final DateTime timestamp;
  @override
  final DiscussionMessageType type;
  @override
  final String? senderAvatar;
  @override
  final String? replyToId;
// For threaded conversations
  @override
  final String? replyToContent;
// Preview of replied message
  @override
  final String? replyToSender;
// Name of original sender
  final Map<String, int>? _reactions;
// Name of original sender
  @override
  Map<String, int>? get reactions {
    final value = _reactions;
    if (value == null) return null;
    if (_reactions is EqualUnmodifiableMapView) return _reactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

// emoji -> count mapping
  final List<String>? _mentions;
// emoji -> count mapping
  @override
  List<String>? get mentions {
    final value = _mentions;
    if (value == null) return null;
    if (_mentions is EqualUnmodifiableListView) return _mentions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// @user mentions
  final List<String>? _attachments;
// @user mentions
  @override
  List<String>? get attachments {
    final value = _attachments;
    if (value == null) return null;
    if (_attachments is EqualUnmodifiableListView) return _attachments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// File URLs
  final Map<String, dynamic>? _metadata;
// File URLs
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

// Extensible data
  @override
  @JsonKey()
  final bool isEdited;
  @override
  @JsonKey()
  final bool isDeleted;
  @override
  final DateTime? editedAt;
  @override
  final DateTime? deletedAt;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'DiscussionChatMessage(id: $id, roomId: $roomId, senderId: $senderId, senderName: $senderName, content: $content, timestamp: $timestamp, type: $type, senderAvatar: $senderAvatar, replyToId: $replyToId, replyToContent: $replyToContent, replyToSender: $replyToSender, reactions: $reactions, mentions: $mentions, attachments: $attachments, metadata: $metadata, isEdited: $isEdited, isDeleted: $isDeleted, editedAt: $editedAt, deletedAt: $deletedAt)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'DiscussionChatMessage'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('roomId', roomId))
      ..add(DiagnosticsProperty('senderId', senderId))
      ..add(DiagnosticsProperty('senderName', senderName))
      ..add(DiagnosticsProperty('content', content))
      ..add(DiagnosticsProperty('timestamp', timestamp))
      ..add(DiagnosticsProperty('type', type))
      ..add(DiagnosticsProperty('senderAvatar', senderAvatar))
      ..add(DiagnosticsProperty('replyToId', replyToId))
      ..add(DiagnosticsProperty('replyToContent', replyToContent))
      ..add(DiagnosticsProperty('replyToSender', replyToSender))
      ..add(DiagnosticsProperty('reactions', reactions))
      ..add(DiagnosticsProperty('mentions', mentions))
      ..add(DiagnosticsProperty('attachments', attachments))
      ..add(DiagnosticsProperty('metadata', metadata))
      ..add(DiagnosticsProperty('isEdited', isEdited))
      ..add(DiagnosticsProperty('isDeleted', isDeleted))
      ..add(DiagnosticsProperty('editedAt', editedAt))
      ..add(DiagnosticsProperty('deletedAt', deletedAt));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DiscussionChatMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.senderAvatar, senderAvatar) ||
                other.senderAvatar == senderAvatar) &&
            (identical(other.replyToId, replyToId) ||
                other.replyToId == replyToId) &&
            (identical(other.replyToContent, replyToContent) ||
                other.replyToContent == replyToContent) &&
            (identical(other.replyToSender, replyToSender) ||
                other.replyToSender == replyToSender) &&
            const DeepCollectionEquality()
                .equals(other._reactions, _reactions) &&
            const DeepCollectionEquality().equals(other._mentions, _mentions) &&
            const DeepCollectionEquality()
                .equals(other._attachments, _attachments) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            (identical(other.isEdited, isEdited) ||
                other.isEdited == isEdited) &&
            (identical(other.isDeleted, isDeleted) ||
                other.isDeleted == isDeleted) &&
            (identical(other.editedAt, editedAt) ||
                other.editedAt == editedAt) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        roomId,
        senderId,
        senderName,
        content,
        timestamp,
        type,
        senderAvatar,
        replyToId,
        replyToContent,
        replyToSender,
        const DeepCollectionEquality().hash(_reactions),
        const DeepCollectionEquality().hash(_mentions),
        const DeepCollectionEquality().hash(_attachments),
        const DeepCollectionEquality().hash(_metadata),
        isEdited,
        isDeleted,
        editedAt,
        deletedAt
      ]);

  /// Create a copy of DiscussionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DiscussionChatMessageImplCopyWith<_$DiscussionChatMessageImpl>
      get copyWith => __$$DiscussionChatMessageImplCopyWithImpl<
          _$DiscussionChatMessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DiscussionChatMessageImplToJson(
      this,
    );
  }
}

abstract class _DiscussionChatMessage implements DiscussionChatMessage {
  const factory _DiscussionChatMessage(
      {required final String id,
      required final String roomId,
      required final String senderId,
      required final String senderName,
      required final String content,
      required final DateTime timestamp,
      required final DiscussionMessageType type,
      final String? senderAvatar,
      final String? replyToId,
      final String? replyToContent,
      final String? replyToSender,
      final Map<String, int>? reactions,
      final List<String>? mentions,
      final List<String>? attachments,
      final Map<String, dynamic>? metadata,
      final bool isEdited,
      final bool isDeleted,
      final DateTime? editedAt,
      final DateTime? deletedAt}) = _$DiscussionChatMessageImpl;

  factory _DiscussionChatMessage.fromJson(Map<String, dynamic> json) =
      _$DiscussionChatMessageImpl.fromJson;

  @override
  String get id;
  @override
  String get roomId;
  @override
  String get senderId;
  @override
  String get senderName;
  @override
  String get content;
  @override
  DateTime get timestamp;
  @override
  DiscussionMessageType get type;
  @override
  String? get senderAvatar;
  @override
  String? get replyToId; // For threaded conversations
  @override
  String? get replyToContent; // Preview of replied message
  @override
  String? get replyToSender; // Name of original sender
  @override
  Map<String, int>? get reactions; // emoji -> count mapping
  @override
  List<String>? get mentions; // @user mentions
  @override
  List<String>? get attachments; // File URLs
  @override
  Map<String, dynamic>? get metadata; // Extensible data
  @override
  bool get isEdited;
  @override
  bool get isDeleted;
  @override
  DateTime? get editedAt;
  @override
  DateTime? get deletedAt;

  /// Create a copy of DiscussionChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DiscussionChatMessageImplCopyWith<_$DiscussionChatMessageImpl>
      get copyWith => throw _privateConstructorUsedError;
}

ChatParticipant _$ChatParticipantFromJson(Map<String, dynamic> json) {
  return _ChatParticipant.fromJson(json);
}

/// @nodoc
mixin _$ChatParticipant {
  String get userId => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String get role =>
      throw _privateConstructorUsedError; // moderator, speaker, audience
  String? get avatar => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;
  DateTime? get lastSeen => throw _privateConstructorUsedError;
  DateTime? get joinedAt => throw _privateConstructorUsedError;

  /// Serializes this ChatParticipant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatParticipant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatParticipantCopyWith<ChatParticipant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatParticipantCopyWith<$Res> {
  factory $ChatParticipantCopyWith(
          ChatParticipant value, $Res Function(ChatParticipant) then) =
      _$ChatParticipantCopyWithImpl<$Res, ChatParticipant>;
  @useResult
  $Res call(
      {String userId,
      String username,
      String role,
      String? avatar,
      bool isOnline,
      DateTime? lastSeen,
      DateTime? joinedAt});
}

/// @nodoc
class _$ChatParticipantCopyWithImpl<$Res, $Val extends ChatParticipant>
    implements $ChatParticipantCopyWith<$Res> {
  _$ChatParticipantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatParticipant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? username = null,
    Object? role = null,
    Object? avatar = freezed,
    Object? isOnline = null,
    Object? lastSeen = freezed,
    Object? joinedAt = freezed,
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
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      avatar: freezed == avatar
          ? _value.avatar
          : avatar // ignore: cast_nullable_to_non_nullable
              as String?,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSeen: freezed == lastSeen
          ? _value.lastSeen
          : lastSeen // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      joinedAt: freezed == joinedAt
          ? _value.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatParticipantImplCopyWith<$Res>
    implements $ChatParticipantCopyWith<$Res> {
  factory _$$ChatParticipantImplCopyWith(_$ChatParticipantImpl value,
          $Res Function(_$ChatParticipantImpl) then) =
      __$$ChatParticipantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String userId,
      String username,
      String role,
      String? avatar,
      bool isOnline,
      DateTime? lastSeen,
      DateTime? joinedAt});
}

/// @nodoc
class __$$ChatParticipantImplCopyWithImpl<$Res>
    extends _$ChatParticipantCopyWithImpl<$Res, _$ChatParticipantImpl>
    implements _$$ChatParticipantImplCopyWith<$Res> {
  __$$ChatParticipantImplCopyWithImpl(
      _$ChatParticipantImpl _value, $Res Function(_$ChatParticipantImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatParticipant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? username = null,
    Object? role = null,
    Object? avatar = freezed,
    Object? isOnline = null,
    Object? lastSeen = freezed,
    Object? joinedAt = freezed,
  }) {
    return _then(_$ChatParticipantImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      avatar: freezed == avatar
          ? _value.avatar
          : avatar // ignore: cast_nullable_to_non_nullable
              as String?,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSeen: freezed == lastSeen
          ? _value.lastSeen
          : lastSeen // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      joinedAt: freezed == joinedAt
          ? _value.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatParticipantImpl
    with DiagnosticableTreeMixin
    implements _ChatParticipant {
  const _$ChatParticipantImpl(
      {required this.userId,
      required this.username,
      required this.role,
      this.avatar,
      this.isOnline = true,
      this.lastSeen,
      this.joinedAt});

  factory _$ChatParticipantImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatParticipantImplFromJson(json);

  @override
  final String userId;
  @override
  final String username;
  @override
  final String role;
// moderator, speaker, audience
  @override
  final String? avatar;
  @override
  @JsonKey()
  final bool isOnline;
  @override
  final DateTime? lastSeen;
  @override
  final DateTime? joinedAt;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ChatParticipant(userId: $userId, username: $username, role: $role, avatar: $avatar, isOnline: $isOnline, lastSeen: $lastSeen, joinedAt: $joinedAt)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ChatParticipant'))
      ..add(DiagnosticsProperty('userId', userId))
      ..add(DiagnosticsProperty('username', username))
      ..add(DiagnosticsProperty('role', role))
      ..add(DiagnosticsProperty('avatar', avatar))
      ..add(DiagnosticsProperty('isOnline', isOnline))
      ..add(DiagnosticsProperty('lastSeen', lastSeen))
      ..add(DiagnosticsProperty('joinedAt', joinedAt));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatParticipantImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.avatar, avatar) || other.avatar == avatar) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.lastSeen, lastSeen) ||
                other.lastSeen == lastSeen) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, userId, username, role, avatar,
      isOnline, lastSeen, joinedAt);

  /// Create a copy of ChatParticipant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatParticipantImplCopyWith<_$ChatParticipantImpl> get copyWith =>
      __$$ChatParticipantImplCopyWithImpl<_$ChatParticipantImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatParticipantImplToJson(
      this,
    );
  }
}

abstract class _ChatParticipant implements ChatParticipant {
  const factory _ChatParticipant(
      {required final String userId,
      required final String username,
      required final String role,
      final String? avatar,
      final bool isOnline,
      final DateTime? lastSeen,
      final DateTime? joinedAt}) = _$ChatParticipantImpl;

  factory _ChatParticipant.fromJson(Map<String, dynamic> json) =
      _$ChatParticipantImpl.fromJson;

  @override
  String get userId;
  @override
  String get username;
  @override
  String get role; // moderator, speaker, audience
  @override
  String? get avatar;
  @override
  bool get isOnline;
  @override
  DateTime? get lastSeen;
  @override
  DateTime? get joinedAt;

  /// Create a copy of ChatParticipant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatParticipantImplCopyWith<_$ChatParticipantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChatSession _$ChatSessionFromJson(Map<String, dynamic> json) {
  return _ChatSession.fromJson(json);
}

/// @nodoc
mixin _$ChatSession {
  String get id => throw _privateConstructorUsedError;
  ChatSessionType get type => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  List<ChatParticipant>? get participants => throw _privateConstructorUsedError;
  String? get lastMessage => throw _privateConstructorUsedError;
  DateTime? get lastMessageTime => throw _privateConstructorUsedError;
  int get unreadCount => throw _privateConstructorUsedError;
  String? get roomId => throw _privateConstructorUsedError; // For room chats
  String? get conversationId => throw _privateConstructorUsedError; // For DMs
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this ChatSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatSessionCopyWith<ChatSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatSessionCopyWith<$Res> {
  factory $ChatSessionCopyWith(
          ChatSession value, $Res Function(ChatSession) then) =
      _$ChatSessionCopyWithImpl<$Res, ChatSession>;
  @useResult
  $Res call(
      {String id,
      ChatSessionType type,
      String title,
      List<ChatParticipant>? participants,
      String? lastMessage,
      DateTime? lastMessageTime,
      int unreadCount,
      String? roomId,
      String? conversationId,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$ChatSessionCopyWithImpl<$Res, $Val extends ChatSession>
    implements $ChatSessionCopyWith<$Res> {
  _$ChatSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? participants = freezed,
    Object? lastMessage = freezed,
    Object? lastMessageTime = freezed,
    Object? unreadCount = null,
    Object? roomId = freezed,
    Object? conversationId = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ChatSessionType,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      participants: freezed == participants
          ? _value.participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<ChatParticipant>?,
      lastMessage: freezed == lastMessage
          ? _value.lastMessage
          : lastMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      lastMessageTime: freezed == lastMessageTime
          ? _value.lastMessageTime
          : lastMessageTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      unreadCount: null == unreadCount
          ? _value.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      roomId: freezed == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String?,
      conversationId: freezed == conversationId
          ? _value.conversationId
          : conversationId // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatSessionImplCopyWith<$Res>
    implements $ChatSessionCopyWith<$Res> {
  factory _$$ChatSessionImplCopyWith(
          _$ChatSessionImpl value, $Res Function(_$ChatSessionImpl) then) =
      __$$ChatSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      ChatSessionType type,
      String title,
      List<ChatParticipant>? participants,
      String? lastMessage,
      DateTime? lastMessageTime,
      int unreadCount,
      String? roomId,
      String? conversationId,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$$ChatSessionImplCopyWithImpl<$Res>
    extends _$ChatSessionCopyWithImpl<$Res, _$ChatSessionImpl>
    implements _$$ChatSessionImplCopyWith<$Res> {
  __$$ChatSessionImplCopyWithImpl(
      _$ChatSessionImpl _value, $Res Function(_$ChatSessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? participants = freezed,
    Object? lastMessage = freezed,
    Object? lastMessageTime = freezed,
    Object? unreadCount = null,
    Object? roomId = freezed,
    Object? conversationId = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_$ChatSessionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ChatSessionType,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      participants: freezed == participants
          ? _value._participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<ChatParticipant>?,
      lastMessage: freezed == lastMessage
          ? _value.lastMessage
          : lastMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      lastMessageTime: freezed == lastMessageTime
          ? _value.lastMessageTime
          : lastMessageTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      unreadCount: null == unreadCount
          ? _value.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      roomId: freezed == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String?,
      conversationId: freezed == conversationId
          ? _value.conversationId
          : conversationId // ignore: cast_nullable_to_non_nullable
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
class _$ChatSessionImpl with DiagnosticableTreeMixin implements _ChatSession {
  const _$ChatSessionImpl(
      {required this.id,
      required this.type,
      required this.title,
      final List<ChatParticipant>? participants,
      this.lastMessage,
      this.lastMessageTime,
      this.unreadCount = 0,
      this.roomId,
      this.conversationId,
      final Map<String, dynamic>? metadata})
      : _participants = participants,
        _metadata = metadata;

  factory _$ChatSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatSessionImplFromJson(json);

  @override
  final String id;
  @override
  final ChatSessionType type;
  @override
  final String title;
  final List<ChatParticipant>? _participants;
  @override
  List<ChatParticipant>? get participants {
    final value = _participants;
    if (value == null) return null;
    if (_participants is EqualUnmodifiableListView) return _participants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? lastMessage;
  @override
  final DateTime? lastMessageTime;
  @override
  @JsonKey()
  final int unreadCount;
  @override
  final String? roomId;
// For room chats
  @override
  final String? conversationId;
// For DMs
  final Map<String, dynamic>? _metadata;
// For DMs
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
    return 'ChatSession(id: $id, type: $type, title: $title, participants: $participants, lastMessage: $lastMessage, lastMessageTime: $lastMessageTime, unreadCount: $unreadCount, roomId: $roomId, conversationId: $conversationId, metadata: $metadata)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ChatSession'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('type', type))
      ..add(DiagnosticsProperty('title', title))
      ..add(DiagnosticsProperty('participants', participants))
      ..add(DiagnosticsProperty('lastMessage', lastMessage))
      ..add(DiagnosticsProperty('lastMessageTime', lastMessageTime))
      ..add(DiagnosticsProperty('unreadCount', unreadCount))
      ..add(DiagnosticsProperty('roomId', roomId))
      ..add(DiagnosticsProperty('conversationId', conversationId))
      ..add(DiagnosticsProperty('metadata', metadata));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatSessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            const DeepCollectionEquality()
                .equals(other._participants, _participants) &&
            (identical(other.lastMessage, lastMessage) ||
                other.lastMessage == lastMessage) &&
            (identical(other.lastMessageTime, lastMessageTime) ||
                other.lastMessageTime == lastMessageTime) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      title,
      const DeepCollectionEquality().hash(_participants),
      lastMessage,
      lastMessageTime,
      unreadCount,
      roomId,
      conversationId,
      const DeepCollectionEquality().hash(_metadata));

  /// Create a copy of ChatSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatSessionImplCopyWith<_$ChatSessionImpl> get copyWith =>
      __$$ChatSessionImplCopyWithImpl<_$ChatSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatSessionImplToJson(
      this,
    );
  }
}

abstract class _ChatSession implements ChatSession {
  const factory _ChatSession(
      {required final String id,
      required final ChatSessionType type,
      required final String title,
      final List<ChatParticipant>? participants,
      final String? lastMessage,
      final DateTime? lastMessageTime,
      final int unreadCount,
      final String? roomId,
      final String? conversationId,
      final Map<String, dynamic>? metadata}) = _$ChatSessionImpl;

  factory _ChatSession.fromJson(Map<String, dynamic> json) =
      _$ChatSessionImpl.fromJson;

  @override
  String get id;
  @override
  ChatSessionType get type;
  @override
  String get title;
  @override
  List<ChatParticipant>? get participants;
  @override
  String? get lastMessage;
  @override
  DateTime? get lastMessageTime;
  @override
  int get unreadCount;
  @override
  String? get roomId; // For room chats
  @override
  String? get conversationId; // For DMs
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of ChatSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatSessionImplCopyWith<_$ChatSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
