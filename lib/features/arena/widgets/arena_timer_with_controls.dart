import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/arena_state.dart';
import '../providers/arena_provider.dart';
import '../../../services/appwrite_service.dart';
import '../../../core/logging/app_logger.dart';

class ArenaTimerWithControls extends ConsumerStatefulWidget {
  const ArenaTimerWithControls({
    super.key,
    required this.roomId,
  });

  final String roomId;

  @override
  ConsumerState<ArenaTimerWithControls> createState() => _ArenaTimerWithControlsState();
}

class _ArenaTimerWithControlsState extends ConsumerState<ArenaTimerWithControls> {
  final AppwriteService _appwrite = AppwriteService();
  String? _currentUserId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _appwrite.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUserId = user?.$id;
        });
      }
    } catch (e) {
      AppLogger().warning('Failed to load current user: $e');
    }
  }

  bool _isUserModerator(ArenaState state) {
    if (_currentUserId == null) return false;
    final participant = state.participants[_currentUserId];
    return participant?.role == ArenaRole.moderator;
  }

  @override
  Widget build(BuildContext context) {
    final arenaState = ref.watch(arenaProvider(widget.roomId));
    final timerAsyncValue = ref.watch(arenaTimerProvider(widget.roomId));
    final isModerator = _isUserModerator(arenaState);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Phase Title
          Text(
            _getPhaseTitle(arenaState.currentPhase),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Timer Display - Visible to ALL users
          timerAsyncValue.when(
            data: (time) => _buildTimerDisplay(context, time, arenaState.isTimerRunning, arenaState.isPaused),
            loading: () => _buildTimerDisplay(context, arenaState.remainingSeconds, false, false),
            error: (_, __) => _buildTimerDisplay(context, 0, false, false),
          ),
          
          // Current Speaker - Visible to ALL users
          if (arenaState.currentSpeaker != null) ...[
            const SizedBox(height: 8),
            _buildCurrentSpeaker(context, arenaState),
          ],
          
          // Timer Controls - Only visible to MODERATORS
          if (isModerator) ...[
            const SizedBox(height: 16),
            _buildModeratorControls(context, arenaState),
          ] else ...[
            const SizedBox(height: 8),
            _buildViewOnlyNotice(context),
          ],
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(BuildContext context, int timeInSeconds, bool isRunning, bool isPaused) {
    final minutes = timeInSeconds ~/ 60;
    final seconds = timeInSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    Color timerColor;
    if (timeInSeconds <= 30) {
      timerColor = Colors.red;
    } else if (timeInSeconds <= 60) {
      timerColor = Colors.orange;
    } else {
      timerColor = Theme.of(context).primaryColor;
    }

    // Status indicator
    Widget statusIndicator;
    if (isPaused) {
      statusIndicator = Container(
        margin: const EdgeInsets.only(right: 8),
        child: Icon(Icons.pause, color: timerColor, size: 16),
      );
    } else if (isRunning) {
      statusIndicator = Container(
        margin: const EdgeInsets.only(right: 8),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: timerColor,
          shape: BoxShape.circle,
        ),
      );
    } else {
      statusIndicator = Container(
        margin: const EdgeInsets.only(right: 8),
        child: const Icon(Icons.stop, color: Colors.grey, size: 16),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: timerColor.withValues(alpha: 0.1),
        border: Border.all(color: timerColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          statusIndicator,
          Flexible(
            child: Text(
              timeString,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: timerColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSpeaker(BuildContext context, ArenaState state) {
    final currentSpeaker = state.participants[state.currentSpeaker];
    if (currentSpeaker == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            '${currentSpeaker.name} is speaking',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeratorControls(BuildContext context, ArenaState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Moderator Timer Controls',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Primary Controls Row
          Row(
            children: [
              _buildControlButton(
                icon: state.isTimerRunning && !state.isPaused ? Icons.pause : Icons.play_arrow,
                label: state.isTimerRunning && !state.isPaused ? 'Pause' : 'Start',
                color: state.isTimerRunning && !state.isPaused ? Colors.orange : Colors.green,
                onPressed: _isLoading ? null : () => _toggleTimer(state),
              ),
              _buildControlButton(
                icon: Icons.stop,
                label: 'Stop',
                color: Colors.red,
                onPressed: _isLoading ? null : () => _stopTimer(),
              ),
              _buildControlButton(
                icon: Icons.skip_next,
                label: 'Next Phase',
                color: Colors.purple,
                onPressed: _isLoading ? null : () => _nextPhase(),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Time Adjustment Row
          Row(
            children: [
              _buildTimeButton('-30s', () => _addTime(-30)),
              _buildTimeButton('+30s', () => _addTime(30)),
              _buildTimeButton('+1m', () => _addTime(60)),
              _buildTimeButton('+5m', () => _addTime(300)),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Set Timer Row
          Row(
            children: [
              _buildTimeButton('Set 1m', () => _setTimer(60)),
              _buildTimeButton('Set 2m', () => _setTimer(120)),
              _buildTimeButton('Set 5m', () => _setTimer(300)),
              _buildTimeButton('Set 10m', () => _setTimer(600)),
            ],
          ),
        ],
          ),
        );
      },
    );
  }

  Widget _buildViewOnlyNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            'Timer controlled by moderator',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeButton(String label, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: OutlinedButton(
          onPressed: _isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
      ),
    );
  }

  Future<void> _toggleTimer(ArenaState state) async {
    setState(() => _isLoading = true);
    
    try {
      final notifier = ref.read(arenaProvider(widget.roomId).notifier);
      
      if (state.isTimerRunning && !state.isPaused) {
        await notifier.pauseTimer();
      } else {
        // If timer has no time, set it to 5 minutes first
        if (state.remainingSeconds <= 0) {
          await _setTimer(300); // 5 minutes
        }
        await notifier.resumeTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stopTimer() async {
    setState(() => _isLoading = true);
    
    try {
      final notifier = ref.read(arenaProvider(widget.roomId).notifier);
      await notifier.pauseTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _nextPhase() async {
    setState(() => _isLoading = true);
    
    try {
      final notifier = ref.read(arenaProvider(widget.roomId).notifier);
      await notifier.nextPhase();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addTime(int seconds) async {
    setState(() => _isLoading = true);
    
    try {
      final notifier = ref.read(arenaProvider(widget.roomId).notifier);
      await notifier.addTime(seconds);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${seconds > 0 ? 'Added' : 'Removed'} ${seconds.abs()} seconds'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setTimer(int seconds) async {
    setState(() => _isLoading = true);
    
    try {
      final notifier = ref.read(arenaProvider(widget.roomId).notifier);
      await notifier.setTimer(seconds);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timer set to ${(seconds / 60).toStringAsFixed(1)} minutes'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getPhaseTitle(DebatePhase phase) {
    switch (phase) {
      case DebatePhase.preDebate:
        return 'Preparation Phase';
      case DebatePhase.openingAffirmative:
        return 'Opening - Affirmative';
      case DebatePhase.openingNegative:
        return 'Opening - Negative';
      case DebatePhase.rebuttalAffirmative:
        return 'Rebuttal - Affirmative';
      case DebatePhase.rebuttalNegative:
        return 'Rebuttal - Negative';
      case DebatePhase.crossExamAffirmative:
        return 'Cross-Exam - Affirmative';
      case DebatePhase.crossExamNegative:
        return 'Cross-Exam - Negative';
      case DebatePhase.finalRebuttalAffirmative:
        return 'Final Rebuttal - Affirmative';
      case DebatePhase.finalRebuttalNegative:
        return 'Final Rebuttal - Negative';
      case DebatePhase.closingAffirmative:
        return 'Closing - Affirmative';
      case DebatePhase.closingNegative:
        return 'Closing - Negative';
      case DebatePhase.judging:
        return 'Judging Phase';
    }
  }
}