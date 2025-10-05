import 'dart:async';
import 'dart:convert';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';
import 'arena_playback_service.dart';

/// Service for detecting speakers and generating chapters in Arena recordings
/// Implements AI-powered speaker diarization and chapter generation
class ChapterDetectionService {
  static final ChapterDetectionService _instance = ChapterDetectionService._internal();
  factory ChapterDetectionService() => _instance;
  ChapterDetectionService._internal();

  final AppwriteService _appwriteService = AppwriteService();

  // Speaker detection configuration
  static const Duration _minimumChapterDuration = Duration(seconds: 10);
  static const int _maxChaptersPerRecording = 50;

  /// Generate chapters for a recording using AI speaker detection
  Future<List<Chapter>> generateChapters({
    required String playbackId,
    required String audioUrl,
    required String roomName,
    List<Map<String, dynamic>>? participantHistory,
  }) async {
    try {
      AppLogger().info('🎯 Generating chapters for playback: $playbackId');

      // For now, we'll implement a mock chapter generation
      // In production, this would integrate with:
      // - Assembly.AI Speaker Diarization API
      // - Google Cloud Speech-to-Text with speaker detection
      // - Azure Cognitive Services Speaker Recognition
      // - AWS Transcribe with speaker identification

      final chapters = await _generateMockChapters(roomName, participantHistory);

      // Store chapters in the playback record
      await _storeChapters(playbackId, chapters);

      AppLogger().info('✅ Generated ${chapters.length} chapters for playback: $playbackId');
      return chapters;

    } catch (e) {
      AppLogger().error('❌ Failed to generate chapters for playback $playbackId: $e');
      return [];
    }
  }

  /// Mock chapter generation based on participant history
  /// In production, this would be replaced with actual AI speaker detection
  Future<List<Chapter>> _generateMockChapters(String roomName, List<Map<String, dynamic>>? participantHistory) async {
    final chapters = <Chapter>[];

    if (participantHistory == null || participantHistory.isEmpty) {
      // Generate basic chapters based on time segments
      return _generateTimeBasedChapters();
    }

    // Generate chapters based on participant speaking patterns
    Duration currentTime = Duration.zero;
    const Duration averageSpeakingTime = Duration(minutes: 2);

    for (int i = 0; i < participantHistory.length && chapters.length < _maxChaptersPerRecording; i++) {
      final participant = participantHistory[i];
      final speakerName = participant['name'] as String? ?? 'Speaker ${i + 1}';
      final speakerId = participant['userId'] as String? ?? 'speaker_$i';
      final avatarUrl = participant['avatarUrl'] as String?;

      final startTime = currentTime;
      final endTime = i < participantHistory.length - 1
          ? currentTime + averageSpeakingTime
          : null;

      chapters.add(Chapter(
        speakerName: speakerName,
        speakerId: speakerId,
        startTime: startTime,
        endTime: endTime,
        avatarUrl: avatarUrl,
      ));

      currentTime += averageSpeakingTime;
    }

    return chapters;
  }

  /// Generate time-based chapters when participant data is unavailable
  List<Chapter> _generateTimeBasedChapters() {
    final chapters = <Chapter>[];
    const int maxChapters = 12; // Max 1 hour recording

    for (int i = 0; i < maxChapters; i++) {
      final startTime = Duration(minutes: i * 5);
      final endTime = Duration(minutes: (i + 1) * 5);

      chapters.add(Chapter(
        speakerName: 'Chapter ${i + 1}',
        speakerId: 'chapter_$i',
        startTime: startTime,
        endTime: endTime,
        avatarUrl: null,
      ));
    }

    return chapters;
  }

  /// Store generated chapters in the playback record
  Future<void> _storeChapters(String playbackId, List<Chapter> chapters) async {
    try {
      final chaptersJson = chapters.map((chapter) => chapter.toMap()).toList();
      final chaptersString = jsonEncode(chaptersJson);

      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_playbacks',
        documentId: playbackId,
        data: {
          'chapters': chaptersString,
          'chapterCount': chapters.length,
          'hasChapters': chapters.isNotEmpty,
          'chaptersGeneratedAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      AppLogger().info('💾 Stored ${chapters.length} chapters for playback: $playbackId');

    } catch (e) {
      AppLogger().error('Failed to store chapters: $e');
      rethrow;
    }
  }

  /// Generate chapters from participant join/leave events during recording
  Future<List<Chapter>> generateChaptersFromRoomEvents({
    required String roomName,
    required DateTime recordingStartTime,
    required DateTime recordingEndTime,
  }) async {
    try {
      AppLogger().info('🎭 Generating chapters from room events for: $roomName');

      // Query participant events during the recording period
      final participantEvents = await _getParticipantEvents(
        roomName,
        recordingStartTime,
        recordingEndTime,
      );

      if (participantEvents.isEmpty) {
        AppLogger().info('No participant events found, generating time-based chapters');
        return _generateTimeBasedChapters();
      }

      // Build chapters from speaking turns
      final chapters = <Chapter>[];

      for (final event in participantEvents) {
        final eventType = event['eventType'] as String;
        final speakerName = event['participantName'] as String? ?? 'Unknown Speaker';
        final speakerId = event['participantId'] as String? ?? 'unknown';
        final avatarUrl = event['avatarUrl'] as String?;
        final eventTime = DateTime.parse(event['timestamp'] as String);

        if (eventType == 'speaker_joined' || eventType == 'became_speaker') {
          // Calculate time offset from recording start
          final timeOffset = eventTime.difference(recordingStartTime);

          if (timeOffset.isNegative) continue;
          if (timeOffset > recordingEndTime.difference(recordingStartTime)) break;

          chapters.add(Chapter(
            speakerName: speakerName,
            speakerId: speakerId,
            startTime: timeOffset,
            endTime: null, // Will be set when next speaker starts
            avatarUrl: avatarUrl,
          ));
        }
      }

      // Set end times for chapters
      for (int i = 0; i < chapters.length - 1; i++) {
        chapters[i] = Chapter(
          speakerName: chapters[i].speakerName,
          speakerId: chapters[i].speakerId,
          startTime: chapters[i].startTime,
          endTime: chapters[i + 1].startTime,
          avatarUrl: chapters[i].avatarUrl,
        );
      }

      AppLogger().info('✅ Generated ${chapters.length} chapters from room events');
      return chapters;

    } catch (e) {
      AppLogger().error('Failed to generate chapters from room events: $e');
      return _generateTimeBasedChapters();
    }
  }

  /// Get participant events during recording period
  Future<List<Map<String, dynamic>>> _getParticipantEvents(
    String roomName,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      // Query room event logs or participant history
      // This would typically come from a dedicated events collection

      // For now, return mock events
      return [
        {
          'eventType': 'speaker_joined',
          'participantName': 'Moderator',
          'participantId': 'mod_1',
          'timestamp': startTime.toIso8601String(),
          'avatarUrl': null,
        },
        {
          'eventType': 'became_speaker',
          'participantName': 'Speaker 1',
          'participantId': 'speaker_1',
          'timestamp': startTime.add(const Duration(minutes: 2)).toIso8601String(),
          'avatarUrl': null,
        },
        {
          'eventType': 'became_speaker',
          'participantName': 'Speaker 2',
          'participantId': 'speaker_2',
          'timestamp': startTime.add(const Duration(minutes: 8)).toIso8601String(),
          'avatarUrl': null,
        },
      ];

    } catch (e) {
      AppLogger().error('Failed to get participant events: $e');
      return [];
    }
  }

  /// Regenerate chapters for existing playback
  Future<bool> regenerateChapters(String playbackId) async {
    try {
      AppLogger().info('🔄 Regenerating chapters for playback: $playbackId');

      // Get existing playback record
      final playback = await _appwriteService.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_playbacks',
        documentId: playbackId,
      );

      final roomName = playback.data['roomName'] as String;
      final audioUrl = playback.data['audioUrl'] as String;

      // Generate new chapters
      final chapters = await generateChapters(
        playbackId: playbackId,
        audioUrl: audioUrl,
        roomName: roomName,
      );

      return chapters.isNotEmpty;

    } catch (e) {
      AppLogger().error('Failed to regenerate chapters: $e');
      return false;
    }
  }

  /// Update speaker information in existing chapters
  Future<bool> updateChapterSpeakers(String playbackId, Map<String, Map<String, dynamic>> speakerUpdates) async {
    try {
      AppLogger().info('👥 Updating speaker info for playback: $playbackId');

      // Get existing playback record
      final playback = await _appwriteService.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_playbacks',
        documentId: playbackId,
      );

      final chaptersStr = playback.data['chapters'] as String?;
      if (chaptersStr == null) {
        AppLogger().warning('No chapters found for playback: $playbackId');
        return false;
      }

      // Parse existing chapters
      final chaptersJson = jsonDecode(chaptersStr) as List<dynamic>;
      final chapters = chaptersJson.map((json) => Chapter.fromMap(json as Map<String, dynamic>)).toList();

      // Update speaker information
      bool hasUpdates = false;
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        final speakerUpdate = speakerUpdates[chapter.speakerId];

        if (speakerUpdate != null) {
          chapters[i] = Chapter(
            speakerName: speakerUpdate['name'] ?? chapter.speakerName,
            speakerId: chapter.speakerId,
            startTime: chapter.startTime,
            endTime: chapter.endTime,
            avatarUrl: speakerUpdate['avatarUrl'] ?? chapter.avatarUrl,
          );
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await _storeChapters(playbackId, chapters);
        AppLogger().info('✅ Updated speaker information for ${chapters.length} chapters');
      }

      return hasUpdates;

    } catch (e) {
      AppLogger().error('Failed to update chapter speakers: $e');
      return false;
    }
  }

  /// Get chapters for a playback
  Future<List<Chapter>> getChapters(String playbackId) async {
    try {
      final playback = await _appwriteService.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_playbacks',
        documentId: playbackId,
      );

      final chaptersStr = playback.data['chapters'] as String?;
      if (chaptersStr == null || chaptersStr.isEmpty) {
        return [];
      }

      final chaptersJson = jsonDecode(chaptersStr) as List<dynamic>;
      return chaptersJson.map((json) => Chapter.fromMap(json as Map<String, dynamic>)).toList();

    } catch (e) {
      AppLogger().error('Failed to get chapters: $e');
      return [];
    }
  }

  /// Clean up and merge short chapters
  List<Chapter> _optimizeChapters(List<Chapter> chapters) {
    if (chapters.isEmpty) return chapters;

    final optimized = <Chapter>[];
    Chapter? currentChapter = chapters.first;

    for (int i = 1; i < chapters.length; i++) {
      final nextChapter = chapters[i];
      final currentDuration = (currentChapter!.endTime ?? Duration.zero) - currentChapter.startTime;

      // Merge short chapters with the same speaker
      if (currentDuration < _minimumChapterDuration &&
          currentChapter.speakerId == nextChapter.speakerId) {
        // Extend current chapter to include next chapter
        currentChapter = Chapter(
          speakerName: currentChapter.speakerName,
          speakerId: currentChapter.speakerId,
          startTime: currentChapter.startTime,
          endTime: nextChapter.endTime,
          avatarUrl: currentChapter.avatarUrl,
        );
      } else {
        // Keep current chapter and move to next
        optimized.add(currentChapter);
        currentChapter = nextChapter;
      }
    }

    // Add the last chapter
    if (currentChapter != null) {
      optimized.add(currentChapter);
    }

    return optimized;
  }

  /// Process playback after recording completion to generate chapters
  Future<void> processPlaybackChapters(String playbackId) async {
    try {
      AppLogger().info('🎬 Processing chapters for completed playback: $playbackId');

      // Get playback record
      final playback = await _appwriteService.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'arena_playbacks',
        documentId: playbackId,
      );

      final roomName = playback.data['roomName'] as String;
      final audioUrl = playback.data['audioUrl'] as String;
      final recordingStartedAt = playback.data['recordingStartedAt'] as String?;
      final recordingCompletedAt = playback.data['recordingCompletedAt'] as String?;

      if (recordingStartedAt != null && recordingCompletedAt != null) {
        // Generate chapters from room events
        final chapters = await generateChaptersFromRoomEvents(
          roomName: roomName,
          recordingStartTime: DateTime.parse(recordingStartedAt),
          recordingEndTime: DateTime.parse(recordingCompletedAt),
        );

        // Optimize chapters
        final optimizedChapters = _optimizeChapters(chapters);

        // Store chapters
        await _storeChapters(playbackId, optimizedChapters);
      } else {
        // Generate chapters using mock data
        await generateChapters(
          playbackId: playbackId,
          audioUrl: audioUrl,
          roomName: roomName,
        );
      }

    } catch (e) {
      AppLogger().error('Failed to process playback chapters: $e');
    }
  }
}