import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import '../services/arena_playback_service.dart';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

class ArenaPlaybackScreen extends ConsumerStatefulWidget {
  final String playbackId;
  final String? initialTitle;

  const ArenaPlaybackScreen({
    super.key,
    required this.playbackId,
    this.initialTitle,
  });

  @override
  ConsumerState<ArenaPlaybackScreen> createState() => _ArenaPlaybackScreenState();
}

class _ArenaPlaybackScreenState extends ConsumerState<ArenaPlaybackScreen> {
  final ArenaPlaybackService _playbackService = ArenaPlaybackService();
  final AppwriteService _appwriteService = GetIt.instance<AppwriteService>();

  Map<String, dynamic>? _playbackData;
  List<Chapter> _chapters = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _showChapters = false;

  @override
  void initState() {
    super.initState();
    _initializePlayback();
  }

  Future<void> _initializePlayback() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Load playback data from Appwrite
      final playbackData = await _appwriteService.getPlayback(widget.playbackId);

      if (playbackData == null) {
        throw Exception('Playback not found');
      }

      // Extract chapters if available
      final chaptersData = playbackData['chapters'];
      if (chaptersData != null && chaptersData is String) {
        try {
          final List<dynamic> chaptersJson = jsonDecode(chaptersData);
          _chapters = chaptersJson.map((json) => Chapter.fromMap(json)).toList();
        } catch (e) {
          AppLogger().warning('Failed to parse chapters: $e');
        }
      }

      // Load audio into playback service
      await _playbackService.loadPlayback(
        playbackId: widget.playbackId,
        audioUrl: playbackData['audioUrl'] ?? '',
        title: playbackData['title'] ?? 'Arena Recording',
        roomName: playbackData['roomName'] ?? 'Unknown Room',
        chapters: _chapters,
      );

      // Increment view count
      await _appwriteService.incrementPlaybackViewCount(widget.playbackId);

      setState(() {
        _playbackData = playbackData;
        _isLoading = false;
      });

    } catch (e) {
      AppLogger().error('Error initializing playback: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _playbackService.stop();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Widget _buildHeader() {
    if (_playbackData == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.deepPurple.shade800,
            Colors.deepPurple.shade600,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _showChapters ? Icons.list : Icons.list_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() => _showChapters = !_showChapters),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {
                    // TODO: Implement sharing
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _playbackData!['title'] ?? 'Arena Recording',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _playbackData!['roomName'] ?? 'Unknown Room',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.visibility, size: 16, color: Colors.white.withOpacity(0.6)),
                const SizedBox(width: 4),
                Text(
                  '${_playbackData!['viewCount'] ?? 0} plays',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.schedule, size: 16, color: Colors.white.withOpacity(0.6)),
                const SizedBox(width: 4),
                StreamBuilder<Duration?>(
                  stream: _playbackService.durationStream,
                  builder: (context, snapshot) {
                    final duration = snapshot.data ?? Duration.zero;
                    return Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: _playbackService.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: _playbackService.durationStream,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                    activeTrackColor: Colors.deepPurple,
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: Colors.deepPurple,
                    overlayColor: Colors.deepPurple.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: duration.inMilliseconds > 0
                        ? position.inMilliseconds.toDouble()
                        : 0.0,
                    max: duration.inMilliseconds.toDouble(),
                    onChanged: (value) {
                      _playbackService.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlaybackControls() {
    return StreamBuilder<PlayerState>(
      stream: _playbackService.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final playing = playerState?.playing ?? false;
        final processingState = playerState?.processingState ?? ProcessingState.idle;

        Widget playButton;
        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          playButton = Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(16),
            child: const CircularProgressIndicator(color: Colors.white),
          );
        } else {
          playButton = IconButton(
            icon: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
            onPressed: () {
              if (playing) {
                _playbackService.pause();
              } else {
                _playbackService.play();
              }
            },
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, -2),
                blurRadius: 8,
                color: Colors.black.withOpacity(0.1),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Previous chapter
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 28),
                  onPressed: _chapters.isNotEmpty ? () => _playbackService.previousChapter() : null,
                ),

                // Rewind 10s
                IconButton(
                  icon: const Icon(Icons.replay_10, size: 28),
                  onPressed: () => _playbackService.skipBackward(const Duration(seconds: 10)),
                ),

                // Play/Pause
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: playButton,
                ),

                // Forward 30s
                IconButton(
                  icon: const Icon(Icons.forward_30, size: 28),
                  onPressed: () => _playbackService.skipForward(const Duration(seconds: 30)),
                ),

                // Next chapter
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 28),
                  onPressed: _chapters.isNotEmpty ? () => _playbackService.nextChapter() : null,
                ),

                // Speed control
                StreamBuilder<double>(
                  stream: _playbackService.speedStream,
                  builder: (context, snapshot) {
                    final speed = snapshot.data ?? 1.0;
                    return PopupMenuButton<double>(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('${speed}x', style: const TextStyle(fontSize: 14)),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                        const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                        const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                        const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                        const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                      ],
                      onSelected: (speed) => _playbackService.setSpeed(speed),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChaptersList() {
    if (_chapters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No chapters available for this recording',
            style: TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _chapters.length,
      itemBuilder: (context, index) {
        final chapter = _chapters[index];

        return StreamBuilder<Duration>(
          stream: _playbackService.positionStream,
          builder: (context, snapshot) {
            final isCurrentChapter = _playbackService.getCurrentChapter() == chapter;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isCurrentChapter ? Colors.deepPurple : Colors.grey.shade300,
                child: Text(
                  chapter.speakerName.isNotEmpty ? chapter.speakerName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isCurrentChapter ? Colors.white : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                chapter.speakerName,
                style: TextStyle(
                  fontWeight: isCurrentChapter ? FontWeight.bold : FontWeight.normal,
                  color: isCurrentChapter ? Colors.deepPurple : Colors.black,
                ),
              ),
              subtitle: Text(_formatDuration(chapter.startTime)),
              trailing: isCurrentChapter
                  ? Icon(Icons.volume_up, color: Colors.deepPurple)
                  : null,
              onTap: () => _playbackService.seekToChapter(chapter),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Failed to load recording',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializePlayback,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),

          Expanded(
            child: _showChapters
                ? _buildChaptersList()
                : Column(
                    children: [
                      const SizedBox(height: 40),
                      // Album art placeholder
                      Container(
                        width: 200,
                        height: 200,
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                              color: Colors.black.withOpacity(0.1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.mic,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                      ),

                      const SizedBox(height: 40),
                      _buildProgressBar(),

                      const Spacer(),
                    ],
                  ),
          ),

          _buildPlaybackControls(),
        ],
      ),
    );
  }
}