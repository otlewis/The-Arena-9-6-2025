import 'package:freezed_annotation/freezed_annotation.dart';

part 'debate_source.freezed.dart';
part 'debate_source.g.dart';

@freezed
class DebateSource with _$DebateSource {
  const factory DebateSource({
    required String id,
    required String url,
    required String title,
    String? description,
    String? faviconUrl,
    required DateTime sharedAt,
    required String sharedBy,
    String? sharedByName,
    @Default(false) bool isSecure,
    @Default(false) bool isPinned,
    @Default('web') String type, // 'web', 'pdf', 'document'
  }) = _DebateSource;

  factory DebateSource.fromJson(Map<String, dynamic> json) =>
      _$DebateSourceFromJson(json);
}

@freezed
class SlideData with _$SlideData {
  const factory SlideData({
    required String fileId,
    required String fileName,
    required int currentSlide,
    required int totalSlides,
    String? pdfUrl,
    required String uploadedBy,
    String? uploadedByName,
    required DateTime uploadedAt,
  }) = _SlideData;

  factory SlideData.fromJson(Map<String, dynamic> json) =>
      _$SlideDataFromJson(json);
}

@freezed
class DebateMaterialSync with _$DebateMaterialSync {
  const factory DebateMaterialSync({
    required String type, // 'slide_change', 'source_share', 'pdf_upload'
    String? slideFileId,
    int? currentSlide,
    int? totalSlides,
    String? sourceUrl,
    String? sourceTitle,
    String? userId,
    String? userName,
    required DateTime timestamp,
  }) = _DebateMaterialSync;

  factory DebateMaterialSync.fromJson(Map<String, dynamic> json) =>
      _$DebateMaterialSyncFromJson(json);
}