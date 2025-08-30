// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debate_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DebateSourceImpl _$$DebateSourceImplFromJson(Map<String, dynamic> json) =>
    _$DebateSourceImpl(
      id: json['id'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      faviconUrl: json['faviconUrl'] as String?,
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      sharedBy: json['sharedBy'] as String,
      sharedByName: json['sharedByName'] as String?,
      isSecure: json['isSecure'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      type: json['type'] as String? ?? 'web',
    );

Map<String, dynamic> _$$DebateSourceImplToJson(_$DebateSourceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'title': instance.title,
      'description': instance.description,
      'faviconUrl': instance.faviconUrl,
      'sharedAt': instance.sharedAt.toIso8601String(),
      'sharedBy': instance.sharedBy,
      'sharedByName': instance.sharedByName,
      'isSecure': instance.isSecure,
      'isPinned': instance.isPinned,
      'type': instance.type,
    };

_$SlideDataImpl _$$SlideDataImplFromJson(Map<String, dynamic> json) =>
    _$SlideDataImpl(
      fileId: json['fileId'] as String,
      fileName: json['fileName'] as String,
      currentSlide: (json['currentSlide'] as num).toInt(),
      totalSlides: (json['totalSlides'] as num).toInt(),
      pdfUrl: json['pdfUrl'] as String?,
      uploadedBy: json['uploadedBy'] as String,
      uploadedByName: json['uploadedByName'] as String?,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );

Map<String, dynamic> _$$SlideDataImplToJson(_$SlideDataImpl instance) =>
    <String, dynamic>{
      'fileId': instance.fileId,
      'fileName': instance.fileName,
      'currentSlide': instance.currentSlide,
      'totalSlides': instance.totalSlides,
      'pdfUrl': instance.pdfUrl,
      'uploadedBy': instance.uploadedBy,
      'uploadedByName': instance.uploadedByName,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
    };

_$DebateMaterialSyncImpl _$$DebateMaterialSyncImplFromJson(
        Map<String, dynamic> json) =>
    _$DebateMaterialSyncImpl(
      type: json['type'] as String,
      slideFileId: json['slideFileId'] as String?,
      fileName: json['fileName'] as String?,
      pdfUrl: json['pdfUrl'] as String?,
      currentSlide: (json['currentSlide'] as num?)?.toInt(),
      totalSlides: (json['totalSlides'] as num?)?.toInt(),
      sourceUrl: json['sourceUrl'] as String?,
      sourceTitle: json['sourceTitle'] as String?,
      userId: json['userId'] as String?,
      userName: json['userName'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$DebateMaterialSyncImplToJson(
        _$DebateMaterialSyncImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'slideFileId': instance.slideFileId,
      'fileName': instance.fileName,
      'pdfUrl': instance.pdfUrl,
      'currentSlide': instance.currentSlide,
      'totalSlides': instance.totalSlides,
      'sourceUrl': instance.sourceUrl,
      'sourceTitle': instance.sourceTitle,
      'userId': instance.userId,
      'userName': instance.userName,
      'timestamp': instance.timestamp.toIso8601String(),
    };

_$UserSlideLibraryImpl _$$UserSlideLibraryImplFromJson(
        Map<String, dynamic> json) =>
    _$UserSlideLibraryImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      fileName: json['fileName'] as String,
      fileId: json['fileId'] as String,
      totalSlides: (json['totalSlides'] as num).toInt(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      description: json['description'] as String?,
      fileType: json['fileType'] as String? ?? 'pdf',
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.parse(json['lastUsedAt'] as String),
    );

Map<String, dynamic> _$$UserSlideLibraryImplToJson(
        _$UserSlideLibraryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'fileName': instance.fileName,
      'fileId': instance.fileId,
      'totalSlides': instance.totalSlides,
      'thumbnailUrl': instance.thumbnailUrl,
      'description': instance.description,
      'fileType': instance.fileType,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
      'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
    };
