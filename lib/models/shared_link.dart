import 'package:freezed_annotation/freezed_annotation.dart';

part 'shared_link.freezed.dart';
part 'shared_link.g.dart';

@freezed
class SharedLink with _$SharedLink {
  const factory SharedLink({
    required String id,
    required String roomId,
    required String url,
    String? title,
    String? description,
    required String sharedBy,
    required String sharedByName,
    required DateTime sharedAt,
    @Default(true) bool isActive,
    @Default('link') String type, // 'video', 'docs', 'image', 'link'
  }) = _SharedLink;

  factory SharedLink.fromJson(Map<String, dynamic> json) =>
      _$SharedLinkFromJson(json);
}