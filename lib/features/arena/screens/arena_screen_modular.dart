import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../widgets/arena_header.dart';
import '../widgets/arena_timer_with_controls.dart';
import '../widgets/simple_arena_debate_controls.dart';
import '../widgets/simple_arena_participants_panel.dart';
import '../widgets/arena_chat_panel.dart';
import '../providers/arena_provider.dart';
import '../models/arena_state.dart';
import '../../../core/error/app_error.dart';
import '../../../services/sound_service.dart';

/// A completely modular Arena Screen that replaces the massive 6,521-line original
/// 
/// Key improvements:
/// - Uses Riverpod providers instead of setState (38 → 0 setState calls)
/// - Modular widget composition instead of monolithic design
/// - Reactive state management with automatic UI updates
/// - Error boundaries and graceful failure handling
/// - Performance optimized with Consumer widgets for targeted rebuilds
class ArenaScreenModular extends ConsumerStatefulWidget {
  const ArenaScreenModular({
    super.key,
    required this.roomId,
    required this.challengeId,
    required this.topic,
    this.description,
    this.category,
    this.challengerId,
    this.challengedId,
  });

  final String roomId;
  final String challengeId;
  final String topic;
  final String? description;
  final String? category;
  final String? challengerId;
  final String? challengedId;

  @override
  ConsumerState<ArenaScreenModular> createState() => _ArenaScreenModularState();
}

class _ArenaScreenModularState extends ConsumerState<ArenaScreenModular>
    with WidgetsBindingObserver {
  late final SoundService _soundService;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _soundService = SoundService();
    
    // Initialize arena and start listening to state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeArena();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isExiting = true;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // Handle app going to background
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        // Handle app coming back to foreground
        _handleAppResumed();
        break;
      default:
        break;
    }
  }

  void _initializeArena() {
    if (_isExiting) return;
    
    // Initialize arena through provider
    ref.read(arenaProvider(widget.roomId).notifier).initialize(
      challengeId: widget.challengeId,
      topic: widget.topic,
      description: widget.description,
      category: widget.category,
      challengerId: widget.challengerId,
      challengedId: widget.challengedId,
    );
  }

  void _handleAppPaused() {
    // Pause any active audio/video
    _soundService.stopSound();
  }

  void _handleAppResumed() {
    if (_isExiting) return;
    
    // Refresh arena state
    ref.invalidate(arenaProvider(widget.roomId));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackPressed();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: _buildArenaContent(),
        ),
      ),
    );
  }

  Widget _buildArenaContent() {
    return Consumer(
      builder: (context, ref, child) {
        final arenaState = ref.watch(arenaProvider(widget.roomId));
        
        if (arenaState.isLoading) {
          return _buildLoadingState();
        }
        
        if (arenaState.error != null) {
          return _buildErrorState(arenaState.error!, StackTrace.current);
        }
        
        return _buildArenaLayout(context, arenaState);
      },
    );
  }

  Widget _buildArenaLayout(BuildContext context, ArenaState arenaState) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;

    if (isTablet) {
      return _buildTabletLayout(arenaState);
    } else {
      return _buildMobileLayout(arenaState);
    }
  }

  Widget _buildTabletLayout(ArenaState arenaState) {
    return Row(
      children: [
        // Left panel - Chat and participants
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: SimpleArenaParticipantsPanel(roomId: widget.roomId),
              ),
              Expanded(
                flex: 3,
                child: ArenaChatPanel(roomId: widget.roomId),
              ),
            ],
          ),
        ),
        
        // Main panel - Timer, controls, and debate content
        Expanded(
          flex: 2,
          child: Column(
            children: [
              ArenaHeader(roomId: widget.roomId),
              ArenaTimerWithControls(roomId: widget.roomId),
              Expanded(
                child: SimpleArenaDebateControls(roomId: widget.roomId),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ArenaState arenaState) {
    return Column(
      children: [
        // Header with basic info
        ArenaHeader(roomId: widget.roomId),
        
        // Main scrollable content
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                // Enhanced tab bar with better styling
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    labelColor: const Color(0xFF6B46C1), // Purple theme
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: const Color(0xFF6B46C1),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.gavel, size: 22),
                        text: 'Arena',
                      ),
                      Tab(
                        icon: Icon(Icons.people, size: 22),
                        text: 'People',
                      ),
                      Tab(
                        icon: Icon(Icons.chat_bubble, size: 22),
                        text: 'Chat',
                      ),
                    ],
                  ),
                ),
                
                // Tab views with optimized content
                Expanded(
                  child: TabBarView(
                    children: [
                      // Arena tab - main debate controls and timer
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), // Extra bottom padding for controls
                        child: Column(
                          children: [
                            ArenaTimerWithControls(roomId: widget.roomId),
                            const SizedBox(height: 16),
                            SimpleArenaDebateControls(roomId: widget.roomId),
                          ],
                        ),
                      ),
                      
                      // Participants tab with enhanced layout
                      SimpleArenaParticipantsPanel(roomId: widget.roomId),
                      
                      // Chat tab
                      ArenaChatPanel(roomId: widget.roomId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Initializing Arena...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait while we set up your debate arena',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error, StackTrace stackTrace) {
    final errorHandler = ErrorHandler.handleError(error, stackTrace);
    final userFriendlyMessage = ErrorHandler.getUserFriendlyMessage(errorHandler);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'Arena Unavailable',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              userFriendlyMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _retryConnection(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => _exitArena(),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Exit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _retryConnection() {
    if (_isExiting) return;
    
    // Refresh the arena provider to retry connection
    ref.invalidate(arenaProvider(widget.roomId));
  }

  Future<void> _handleBackPressed() async {
    final shouldExit = await _showExitConfirmation();
    if (shouldExit) {
      await _exitArena();
    }
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Arena'),
        content: const Text(
          'Are you sure you want to leave this arena? '
          'You may not be able to rejoin if the debate is in progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _exitArena() async {
    if (_isExiting) return;
    _isExiting = true;

    try {
      // Notify provider that user is leaving
      await ref.read(arenaProvider(widget.roomId).notifier).leaveArena();
      
      // Provide haptic feedback
      HapticFeedback.lightImpact();
      
      // Navigate back
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      // Even if leaving fails, still navigate back
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

/// Extension to add arena-specific state watchers
extension ArenaStateWatchers on WidgetRef {
  /// Watch for arena state changes and handle sound effects
  void watchArenaStateChanges(String roomId) {
    listen<ArenaState>(
      arenaProvider(roomId),
      (previous, current) {
        if (current.error == null && previous != null) {
          _handleArenaStateChange(previous, current);
        }
      },
    );
  }

  void _handleArenaStateChange(ArenaState? previous, ArenaState current) {
    if (previous == null) return;

    // Handle phase changes
    if (previous.currentPhase != current.currentPhase) {
      _handlePhaseChange(current.currentPhase);
    }

    // Handle timer warnings
    if (current.remainingSeconds == 30 && current.isTimerRunning) {
      SoundService().play30SecWarningSound();
    }

    // Handle speaker changes
    if (previous.currentSpeaker != current.currentSpeaker) {
      SoundService().playChallengeSound();
    }
  }

  void _handlePhaseChange(DebatePhase newPhase) {
    // Play appropriate sound for phase transition
    SoundService().playChallengeSound();
    
    // Show phase transition notification
    // This would typically be handled by a separate notification service
  }
}