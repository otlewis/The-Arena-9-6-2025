// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'super_moderator.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SuperModerator _$SuperModeratorFromJson(Map<String, dynamic> json) {
  return _SuperModerator.fromJson(json);
}

/// @nodoc
mixin _$SuperModerator {
  String? get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String? get profileImageUrl => throw _privateConstructorUsedError;
  DateTime get grantedAt => throw _privateConstructorUsedError;
  String? get grantedBy =>
      throw _privateConstructorUsedError; // User ID of who granted super mod status
  bool get isActive => throw _privateConstructorUsedError;
  List<String> get permissions => throw _privateConstructorUsedError;
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SuperModeratorCopyWith<SuperModerator> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SuperModeratorCopyWith<$Res> {
  factory $SuperModeratorCopyWith(
          SuperModerator value, $Res Function(SuperModerator) then) =
      _$SuperModeratorCopyWithImpl<$Res, SuperModerator>;
  @useResult
  $Res call(
      {String? id,
      String userId,
      String username,
      String? profileImageUrl,
      DateTime grantedAt,
      String? grantedBy,
      bool isActive,
      List<String> permissions,
      Map<String, dynamic> metadata});
}

/// @nodoc
class _$SuperModeratorCopyWithImpl<$Res, $Val extends SuperModerator>
    implements $SuperModeratorCopyWith<$Res> {
  _$SuperModeratorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? userId = null,
    Object? username = null,
    Object? profileImageUrl = freezed,
    Object? grantedAt = null,
    Object? grantedBy = freezed,
    Object? isActive = null,
    Object? permissions = null,
    Object? metadata = null,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      profileImageUrl: freezed == profileImageUrl
          ? _value.profileImageUrl
          : profileImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      grantedAt: null == grantedAt
          ? _value.grantedAt
          : grantedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      grantedBy: freezed == grantedBy
          ? _value.grantedBy
          : grantedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      permissions: null == permissions
          ? _value.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      metadata: null == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SuperModeratorImplCopyWith<$Res>
    implements $SuperModeratorCopyWith<$Res> {
  factory _$$SuperModeratorImplCopyWith(_$SuperModeratorImpl value,
          $Res Function(_$SuperModeratorImpl) then) =
      __$$SuperModeratorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      String userId,
      String username,
      String? profileImageUrl,
      DateTime grantedAt,
      String? grantedBy,
      bool isActive,
      List<String> permissions,
      Map<String, dynamic> metadata});
}

/// @nodoc
class __$$SuperModeratorImplCopyWithImpl<$Res>
    extends _$SuperModeratorCopyWithImpl<$Res, _$SuperModeratorImpl>
    implements _$$SuperModeratorImplCopyWith<$Res> {
  __$$SuperModeratorImplCopyWithImpl(
      _$SuperModeratorImpl _value, $Res Function(_$SuperModeratorImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? userId = null,
    Object? username = null,
    Object? profileImageUrl = freezed,
    Object? grantedAt = null,
    Object? grantedBy = freezed,
    Object? isActive = null,
    Object? permissions = null,
    Object? metadata = null,
  }) {
    return _then(_$SuperModeratorImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      profileImageUrl: freezed == profileImageUrl
          ? _value.profileImageUrl
          : profileImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      grantedAt: null == grantedAt
          ? _value.grantedAt
          : grantedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      grantedBy: freezed == grantedBy
          ? _value.grantedBy
          : grantedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      permissions: null == permissions
          ? _value._permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      metadata: null == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SuperModeratorImpl implements _SuperModerator {
  const _$SuperModeratorImpl(
      {this.id,
      required this.userId,
      required this.username,
      this.profileImageUrl,
      required this.grantedAt,
      this.grantedBy,
      required this.isActive,
      final List<String> permissions = const [],
      final Map<String, dynamic> metadata = const {}})
      : _permissions = permissions,
        _metadata = metadata;

  factory _$SuperModeratorImpl.fromJson(Map<String, dynamic> json) =>
      _$$SuperModeratorImplFromJson(json);

  @override
  final String? id;
  @override
  final String userId;
  @override
  final String username;
  @override
  final String? profileImageUrl;
  @override
  final DateTime grantedAt;
  @override
  final String? grantedBy;
// User ID of who granted super mod status
  @override
  final bool isActive;
  final List<String> _permissions;
  @override
  @JsonKey()
  List<String> get permissions {
    if (_permissions is EqualUnmodifiableListView) return _permissions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_permissions);
  }

  final Map<String, dynamic> _metadata;
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  String toString() {
    return 'SuperModerator(id: $id, userId: $userId, username: $username, profileImageUrl: $profileImageUrl, grantedAt: $grantedAt, grantedBy: $grantedBy, isActive: $isActive, permissions: $permissions, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SuperModeratorImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.profileImageUrl, profileImageUrl) ||
                other.profileImageUrl == profileImageUrl) &&
            (identical(other.grantedAt, grantedAt) ||
                other.grantedAt == grantedAt) &&
            (identical(other.grantedBy, grantedBy) ||
                other.grantedBy == grantedBy) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            const DeepCollectionEquality()
                .equals(other._permissions, _permissions) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      username,
      profileImageUrl,
      grantedAt,
      grantedBy,
      isActive,
      const DeepCollectionEquality().hash(_permissions),
      const DeepCollectionEquality().hash(_metadata));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SuperModeratorImplCopyWith<_$SuperModeratorImpl> get copyWith =>
      __$$SuperModeratorImplCopyWithImpl<_$SuperModeratorImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SuperModeratorImplToJson(
      this,
    );
  }
}

abstract class _SuperModerator implements SuperModerator {
  const factory _SuperModerator(
      {final String? id,
      required final String userId,
      required final String username,
      final String? profileImageUrl,
      required final DateTime grantedAt,
      final String? grantedBy,
      required final bool isActive,
      final List<String> permissions,
      final Map<String, dynamic> metadata}) = _$SuperModeratorImpl;

  factory _SuperModerator.fromJson(Map<String, dynamic> json) =
      _$SuperModeratorImpl.fromJson;

  @override
  String? get id;
  @override
  String get userId;
  @override
  String get username;
  @override
  String? get profileImageUrl;
  @override
  DateTime get grantedAt;
  @override
  String? get grantedBy;
  @override // User ID of who granted super mod status
  bool get isActive;
  @override
  List<String> get permissions;
  @override
  Map<String, dynamic> get metadata;
  @override
  @JsonKey(ignore: true)
  _$$SuperModeratorImplCopyWith<_$SuperModeratorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
