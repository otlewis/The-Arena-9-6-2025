import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import '../core/logging/app_logger.dart';
import 'chapter_detection_service.dart';

/// Professional audio playback service for Arena recordings
/// Implements Clubhouse-style replay features: chapter navigation, speed control, background playback
class ArenaPlaybackService extends ChangeNotifier {
  static final ArenaPlaybackService _instance = ArenaPlaybackService._internal();
  factory ArenaPlaybackService() => _instance;
  ArenaPlaybackService._internal();

  final AudioPlayer _player = AudioPlayer();
  final ChapterDetectionService _chapterService = ChapterDetectionService();

  // Playback state
  String? _currentPlaybackId;
  String? _currentTitle;
  String? _currentRoomName;
  List<Chapter> _chapters = [];
  bool _isInitialized = false;

  // Getters for reactive UI
  String? get currentPlaybackId => _currentPlaybackId;
  String? get currentTitle => _currentTitle;
  String? get currentRoomName => _currentRoomName;
  List<Chapter> get chapters => _chapters;
  bool get isInitialized => _isInitialized;

  // Audio player streams
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<double> get speedStream => _player.speedStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  // Audio player properties
  bool get playing => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  double get speed => _player.speed;

  /// Initialize audio session and background playback
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger().info('🎵 Initializing Arena Playback Service');

      // Initialize just_audio_background for lock screen controls
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.thearenadtd.app.arena_playback',
        androidNotificationChannelName: 'Arena Audio Playback',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
      );

      // Configure audio session for speech content
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      // Handle audio interruptions (phone calls, etc.)
      session.interruptionEventStream.listen((event) {
        AppLogger().debug('🔊 Audio interruption: ${event.type}');
        if (event.begin) {
          _player.pause();
        } else {
          if (event.type == AudioInterruptionType.pause) {
            // Auto-resume after interruption unless user paused manually
            _player.play();
          }
        }
      });

      // Handle becoming noisy (headphones disconnected)
      session.becomingNoisyEventStream.listen((_) {
        AppLogger().debug('🔊 Audio becoming noisy - pausing playback');
        _player.pause();
      });

      _isInitialized = true;
      AppLogger().info('✅ Arena Playback Service initialized');

    } catch (e) {
      AppLogger().error('❌ Failed to initialize Arena Playback Service: $e');
    }
  }

  /// Load and play Arena recording
  Future<void> loadPlayback({
    required String playbackId,
    required String audioUrl,
    required String title,
    required String roomName,
    List<Chapter>? chapters,
  }) async {
    try {
      await initialize();

      AppLogger().info('🎵 Loading Arena playback: $title');
      AppLogger().debug('📎 Audio URL: $audioUrl');

      _currentPlaybackId = playbackId;
      _currentTitle = title;
      _currentRoomName = roomName;

      // Load chapters from database if not provided
      if (chapters == null || chapters.isEmpty) {
        _chapters = await _chapterService.getChapters(playbackId);
        AppLogger().info('📚 Loaded ${_chapters.length} chapters from database');
      } else {
        _chapters = chapters;
      }

      // Create audio source with metadata for lock screen
      final audioSource = AudioSource.uri(
        Uri.parse(audioUrl),
        tag: MediaItem(
          id: playbackId,
          title: title,
          album: 'Arena Debates',
          artist: roomName,
          genre: 'Debate',
          duration: duration, // Will be updated once loaded
          artUri: Uri.parse('https://thearenadtd.com/icon-512.png'), // Your app icon
          extras: {
            'playbackId': playbackId,
            'roomName': roomName,
          },
        ),
      );

      await _player.setAudioSource(audioSource);
      notifyListeners();

      AppLogger().info('✅ Arena playback loaded successfully');

    } catch (e) {
      AppLogger().error('❌ Failed to load Arena playback: $e');
      rethrow;
    }
  }

  /// Play the current recording
  Future<void> play() async {
    try {
      await _player.play();
      AppLogger().debug('▶️ Arena playback started');
    } catch (e) {
      AppLogger().error('❌ Failed to play Arena recording: $e');
      rethrow;
    }
  }

  /// Pause the current recording
  Future<void> pause() async {
    try {
      await _player.pause();
      AppLogger().debug('⏸️ Arena playback paused');
    } catch (e) {
      AppLogger().error('❌ Failed to pause Arena recording: $e');
    }
  }

  /// Seek to specific position
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      AppLogger().debug('⏭️ Arena playback seeked to ${_formatDuration(position)}');
    } catch (e) {
      AppLogger().error('❌ Failed to seek Arena recording: $e');
    }
  }

  /// Set playback speed (0.5x to 3.0x)
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      AppLogger().debug('🏃 Arena playback speed set to ${speed}x');
      notifyListeners();
    } catch (e) {
      AppLogger().error('❌ Failed to set Arena playback speed: $e');
    }
  }

  /// Skip forward by duration
  Future<void> skipForward(Duration duration) async {
    final newPosition = position + duration;
    if (this.duration != null && newPosition < this.duration!) {
      await seek(newPosition);
    }
  }

  /// Skip backward by duration
  Future<void> skipBackward(Duration duration) async {
    final newPosition = position - duration;
    await seek(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  /// Get current chapter based on playback position
  Chapter? getCurrentChapter() {
    if (_chapters.isEmpty) return null;

    return _chapters.lastWhere(
      (chapter) => position >= chapter.startTime,
      orElse: () => _chapters.first,
    );
  }

  /// Jump to next chapter
  Future<void> nextChapter() async {
    if (_chapters.isEmpty) return;

    final current = getCurrentChapter();
    if (current != null) {
      final currentIndex = _chapters.indexOf(current);
      if (currentIndex < _chapters.length - 1) {
        await seek(_chapters[currentIndex + 1].startTime);
        AppLogger().debug('⏭️ Jumped to next chapter: ${_chapters[currentIndex + 1].speakerName}');
      }
    }
  }

  /// Jump to previous chapter
  Future<void> previousChapter() async {
    if (_chapters.isEmpty) return;

    final current = getCurrentChapter();
    if (current != null) {
      final currentIndex = _chapters.indexOf(current);
      if (currentIndex > 0) {
        await seek(_chapters[currentIndex - 1].startTime);
        AppLogger().debug('⏮️ Jumped to previous chapter: ${_chapters[currentIndex - 1].speakerName}');
      }
    }
  }

  /// Jump to specific chapter
  Future<void> seekToChapter(Chapter chapter) async {
    await seek(chapter.startTime);
    AppLogger().debug('🎯 Jumped to chapter: ${chapter.speakerName}');
  }

  /// Refresh chapters from database
  Future<void> refreshChapters() async {
    if (_currentPlaybackId == null) return;

    try {
      final newChapters = await _chapterService.getChapters(_currentPlaybackId!);
      _chapters = newChapters;
      notifyListeners();
      AppLogger().info('🔄 Refreshed ${_chapters.length} chapters');
    } catch (e) {
      AppLogger().error('Failed to refresh chapters: $e');
    }
  }

  /// Generate chapters for current playback
  Future<void> generateChapters() async {
    if (_currentPlaybackId == null) return;

    try {
      AppLogger().info('🎭 Generating chapters for current playback');
      await _chapterService.processPlaybackChapters(_currentPlaybackId!);
      await refreshChapters();
    } catch (e) {
      AppLogger().error('Failed to generate chapters: $e');
    }
  }

  /// Stop playback and clear current recording
  Future<void> stop() async {
    try {
      await _player.stop();
      _currentPlaybackId = null;
      _currentTitle = null;
      _currentRoomName = null;
      _chapters.clear();
      notifyListeners();
      AppLogger().debug('⏹️ Arena playback stopped');
    } catch (e) {
      AppLogger().error('❌ Failed to stop Arena playback: $e');
    }
  }

  /// Format duration for display
  String formatDuration(Duration duration) {
    return _formatDuration(duration);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '$minutes:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

/// Chapter model for speaker-based navigation
class Chapter {
  final String speakerName;
  final String speakerId;
  final Duration startTime;
  final Duration? endTime;
  final String? avatarUrl;

  Chapter({
    required this.speakerName,
    required this.speakerId,
    required this.startTime,
    this.endTime,
    this.avatarUrl,
  });

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      speakerName: map['speakerName'] ?? 'Unknown Speaker',
      speakerId: map['speakerId'] ?? '',
      startTime: Duration(milliseconds: map['startTimeMs'] ?? 0),
      endTime: map['endTimeMs'] != null ? Duration(milliseconds: map['endTimeMs']) : null,
      avatarUrl: map['avatarUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'speakerName': speakerName,
      'speakerId': speakerId,
      'startTimeMs': startTime.inMilliseconds,
      'endTimeMs': endTime?.inMilliseconds,
      'avatarUrl': avatarUrl,
    };
  }
}