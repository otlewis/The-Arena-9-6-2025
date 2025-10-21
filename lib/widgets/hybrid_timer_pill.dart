import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Hybrid Timer Pill with n8n Authority + Local Interpolation
///
/// - n8n provides canonical timer state (every 2 seconds)
/// - Local interpolation provides smooth display (every 100ms)
/// - Appwrite Realtime for instant state changes (start/pause/resume)
class HybridTimerPill extends StatefulWidget {
  final String roomId;
  final String roomType;
  final String userRole;
  final String userId;
  final Function()? onTap;
  final Function()? onLongPress;

  const HybridTimerPill({
    Key? key,
    required this.roomId,
    required this.roomType,
    required this.userRole,
    required this.userId,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<HybridTimerPill> createState() => _HybridTimerPillState();
}

class _HybridTimerPillState extends State<HybridTimerPill> with SingleTickerProviderStateMixin {
  final AppwriteService _appwrite = AppwriteService();

  // n8n endpoint
  static const String _n8nUrl = 'https://50.21.187.76/webhook/timer-get/timer';

  // Server state (source of truth from n8n)
  double _serverRemaining = 0;
  DateTime _lastSyncTime = DateTime.now();
  String _timerState = 'stopped';
  String _currentPhase = 'Waiting';

  // Local display state (interpolated)
  double _displayRemaining = 0;

  // UI state
  Offset _position = const Offset(20, 100);
  bool _isDragging = false;

  // Animation for warnings
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Timers
  Timer? _authoritySync; // Sync with n8n every 2 seconds
  Timer? _displayUpdate; // Update display every 100ms

  // Subscription for instant state changes
  RealtimeSubscription? _realtimeSubscription;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation for warnings
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _initializeHybridTimer();
  }

  Future<void> _initializeHybridTimer() async {
    try {
      final documentId = '${widget.roomId}_${widget.roomType}';

      AppLogger().info('🕐 Initializing hybrid timer for document ID: $documentId');

      // Subscribe to Appwrite Realtime for instant state changes
      final channel = 'databases.arena_db.collections.timers.documents.$documentId';
      AppLogger().info('🕐 Subscribing to timer channel: $channel');

      _realtimeSubscription = _appwrite.realtime.subscribe([channel]);

      _realtimeSubscription!.stream.listen(
        (response) {
          AppLogger().debug('🕐 Timer realtime update received');
          if (mounted) {
            _handleRealtimeUpdate(response.payload);
          }
        },
        onError: (error) {
          AppLogger().error('🕐 Timer subscription error: $error');
        },
      );

      // Initial sync with n8n
      await _syncWithN8n();

      // Start authority sync timer (every 2 seconds)
      _authoritySync = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _syncWithN8n(),
      );

      // Start display update timer (every 100ms for smooth countdown)
      _displayUpdate = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _updateDisplay(),
      );

      AppLogger().info('🕐 Hybrid timer initialized successfully');
    } catch (e) {
      AppLogger().error('🕐 Failed to initialize hybrid timer: $e');
    }
  }

  /// Sync with n8n for canonical timer state
  Future<void> _syncWithN8n() async {
    try {
      final response = await http.get(
        Uri.parse('$_n8nUrl/${widget.roomId}'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _serverRemaining = (data['remaining'] as num).toDouble();
            _displayRemaining = _serverRemaining;
            _lastSyncTime = DateTime.now();
            _timerState = data['state'] ?? 'stopped';
            _currentPhase = data['current_phase'] ?? 'Waiting';
          });
        }

        AppLogger().debug('🕐 Synced with n8n: $_serverRemaining seconds remaining');

        // Trigger pulse animation for warnings
        if (_serverRemaining <= 30 && _serverRemaining > 0 && _timerState == 'running') {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.value = 1.0;
        }
      }
    } catch (e) {
      AppLogger().warning('🕐 Failed to sync with n8n (using last known state): $e');
    }
  }

  /// Update display with local interpolation
  void _updateDisplay() {
    if (!mounted || _timerState != 'running') return;

    // Calculate elapsed time since last n8n sync
    final elapsed = DateTime.now().difference(_lastSyncTime).inMilliseconds / 1000;

    // Interpolate remaining time
    final interpolated = _serverRemaining - elapsed;

    setState(() {
      _displayRemaining = interpolated > 0 ? interpolated : 0;
    });
  }

  /// Handle Appwrite Realtime updates (instant state changes)
  void _handleRealtimeUpdate(Map<String, dynamic> payload) {
    try {
      final state = payload['state'];
      AppLogger().info('🕐 Realtime state change: $state');

      // Immediately sync with n8n to get accurate time
      _syncWithN8n();
    } catch (e) {
      AppLogger().error('🕐 Error handling realtime update: $e');
    }
  }

  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    if (_displayRemaining <= 10 && _timerState == 'running') {
      return Colors.red.shade300;
    } else if (_displayRemaining <= 30 && _timerState == 'running') {
      return Colors.orange.shade300;
    } else if (_timerState == 'running') {
      return Colors.green.shade300;
    } else if (_timerState == 'paused') {
      return Colors.blue.shade300;
    } else {
      return Colors.grey.shade300;
    }
  }

  IconData _getStateIcon() {
    switch (_timerState) {
      case 'running':
        return Icons.play_arrow;
      case 'paused':
        return Icons.pause;
      case 'completed':
        return Icons.check;
      default:
        return Icons.timer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position.dx + details.delta.dx,
              _position.dy + details.delta.dy,
            );
          });
        },
        onPanEnd: (_) {
          setState(() {
            _isDragging = false;
          });
        },
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: ScaleTransition(
          scale: _pulseAnimation,
          child: Material(
            elevation: _isDragging ? 8 : 4,
            borderRadius: BorderRadius.circular(25),
            color: _getTimerColor(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStateIcon(),
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTime(_displayRemaining),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (_currentPhase.isNotEmpty)
                        Text(
                          _currentPhase,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authoritySync?.cancel();
    _displayUpdate?.cancel();
    _realtimeSubscription?.close();
    _pulseController.dispose();
    super.dispose();
  }
}
