import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:async';
import '../services/appwrite_service.dart';
import '../core/logging/app_logger.dart';

class FloatingTimerPill extends StatefulWidget {
  final String roomId;
  final String roomType;
  final String userRole;
  final String userId;
  final Function()? onTap;
  final Function()? onLongPress;

  const FloatingTimerPill({
    Key? key,
    required this.roomId,
    required this.roomType,
    required this.userRole,
    required this.userId,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<FloatingTimerPill> createState() => _FloatingTimerPillState();
}

class _FloatingTimerPillState extends State<FloatingTimerPill> with SingleTickerProviderStateMixin {
  final AppwriteService _appwrite = AppwriteService();
  
  // Timer state from server
  int _remainingSeconds = 0;
  String _currentPhase = 'Waiting';
  bool _isRunning = false;
  DateTime? _lastServerUpdate;
  bool _isLocallyControlled = false; // Flag to indicate this client controls the timer
  
  // UI state
  Offset _position = const Offset(20, 100); // Default position
  bool _isDragging = false;
  
  // Animation for warnings
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Subscription
  RealtimeSubscription? _timerSubscription;
  Timer? _localUpdateTimer;
  
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
    
    _initializeTimer();
  }
  
  Future<void> _initializeTimer() async {
    try {
      final documentId = '${widget.roomId}_${widget.roomType}';
      
      AppLogger().info('Initializing timer for document ID: $documentId');
      
      // Subscribe to timer updates
      final channel = 'databases.arena_db.collections.timers.documents.$documentId';
      
      AppLogger().info('Subscribing to timer channel: $channel');
      
      _timerSubscription = _appwrite.realtime.subscribe([channel]);
      
      _timerSubscription!.stream.listen(
        (response) {
          AppLogger().debug('Timer realtime update received: ${response.payload}');
          if (mounted) {
            _handleTimerUpdate(response.payload);
          }
        },
        onError: (error) {
          AppLogger().error('Timer subscription error: $error');
        },
        onDone: () {
          AppLogger().warning('Timer subscription ended');
        },
      );
      
      // Fetch initial timer state
      await _fetchTimerState();
      
      // Start local display updates (purely visual, not authoritative)
      _startLocalDisplayTimer();
      
      AppLogger().info('Timer initialization completed for document ID: $documentId');
      
    } catch (e) {
      AppLogger().error('Failed to initialize timer: $e');
    }
  }
  
  Future<void> _fetchTimerState() async {
    try {
      final documentId = '${widget.roomId}_${widget.roomType}';
      AppLogger().info('Fetching timer state for document ID: $documentId');
      
      final document = await _appwrite.databases.getDocument(
        databaseId: 'arena_db',
        collectionId: 'timers',
        documentId: documentId,
      );
      
      AppLogger().info('Timer state fetched: ${document.data}');
      _handleTimerUpdate(document.data);
    } catch (e) {
      AppLogger().info('Timer document not found, using defaults: $e');
      // Set default state
      setState(() {
        _remainingSeconds = 0;
        _currentPhase = 'Ready';
        _isRunning = false;
        _lastServerUpdate = DateTime.now();
      });
    }
  }
  
  void _handleTimerUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    
    final status = data['status'] ?? 'stopped';
    final newIsRunning = status == 'running';
    final durationSeconds = data['durationSeconds'] ?? 0;
    final remainingSeconds = data['remainingSeconds'] ?? durationSeconds;
    
    AppLogger().info('Timer update received - Status: $status, Duration: $durationSeconds, Remaining: $remainingSeconds');
    
    // Completely ignore server updates to remainingSeconds when locally controlled
    bool shouldUpdateRemainingSeconds = !_isLocallyControlled;
    
    // However, do respect status changes from server (pause/stop from other users)
    if (_isLocallyControlled && !newIsRunning && _isRunning) {
      // Timer was stopped/paused externally, give up local control
      _isLocallyControlled = false;
      shouldUpdateRemainingSeconds = true;
      AppLogger().info('Timer stopped externally, releasing local control');
    }
    
    setState(() {
      if (shouldUpdateRemainingSeconds) {
        _remainingSeconds = remainingSeconds;
      }
      _currentPhase = status == 'running' ? 'Running' : (status == 'paused' ? 'Paused' : 'Ready');
      _isRunning = newIsRunning;
      
      // Only start local display timer if this update indicates we should be running
      // but don't duplicate if we're already locally controlled
      if (newIsRunning && !_isLocallyControlled) {
        _startLocalDisplayTimer();
      }
      _lastServerUpdate = DateTime.now();
    });
    
    // Handle warnings
    if (_remainingSeconds <= 30 && _remainingSeconds > 0 && _isRunning) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }
  
  void _startLocalDisplayTimer() {
    _localUpdateTimer?.cancel();
    
    _localUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Only decrement locally if timer is running and we have a recent server update
      if (_isRunning && _remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
        
        // Update the server less frequently to avoid conflicts
        final timeSinceUpdate = _lastServerUpdate != null 
          ? DateTime.now().difference(_lastServerUpdate!).inSeconds 
          : 0;
        
        // Only update server every 15 seconds, and only if locally controlled
        if (_isLocallyControlled && timeSinceUpdate >= 15) {
          _updateTimerOnServer();
        }
        
        // Stop timer when it reaches 0
        if (_remainingSeconds <= 0) {
          _stopTimerWhenComplete();
        }
      }
    });
  }
  
  Future<void> _updateTimerOnServer() async {
    if (!_isRunning) return;
    
    try {
      final appwrite = AppwriteService();
      final documentId = '${widget.roomId}_${widget.roomType}';
      
      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'timers',
        documentId: documentId,
        data: {
          'remainingSeconds': _remainingSeconds,
        },
      );
      
      _lastServerUpdate = DateTime.now();
    } catch (e) {
      AppLogger().error('Failed to update timer on server: $e');
    }
  }
  
  Future<void> _stopTimerWhenComplete() async {
    try {
      final appwrite = AppwriteService();
      final documentId = '${widget.roomId}_${widget.roomType}';
      
      await appwrite.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: 'timers',
        documentId: documentId,
        data: {
          'status': 'completed',
          'isActive': false,
          'remainingSeconds': 0,
          'startTime': null,
          'pausedAt': null,
        },
      );
      
      setState(() {
        _isRunning = false;
        _currentPhase = 'Completed';
        _isLocallyControlled = false; // Release local control
      });
      
    } catch (e) {
      AppLogger().error('Failed to stop completed timer: $e');
    }
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  Color _getTimerColor() {
    if (!_isRunning) return Colors.grey;
    if (_remainingSeconds <= 0) return Colors.red;
    if (_remainingSeconds <= 30) return Colors.orange;
    if (_remainingSeconds <= 120) return Colors.yellow;
    return Colors.green;
  }
  
  
  @override
  void dispose() {
    _timerSubscription?.close();
    _localUpdateTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    // Ensure pill stays on screen
    final safeX = _position.dx.clamp(0, screenSize.width - 140);
    final safeY = _position.dy.clamp(50, screenSize.height - 100);
    
    return Positioned(
      left: safeX.toDouble(),
      top: safeY.toDouble(),
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(0, screenSize.width - 140),
              (_position.dy + details.delta.dy).clamp(50, screenSize.height - 100),
            );
          });
        },
        onPanEnd: (_) {
          setState(() {
            _isDragging = false;
          });
        },
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _remainingSeconds <= 30 && _isRunning ? _pulseAnimation.value : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getTimerColor(),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getTimerColor().withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRunning ? Icons.timer : Icons.timer_off,
                      color: _getTimerColor(),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatTime(_remainingSeconds),
                          style: TextStyle(
                            color: _getTimerColor(),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currentPhase,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    if (_isDragging) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.drag_indicator,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Separate moderator control widget
class ModeratorTimerControls extends StatefulWidget {
  final String roomId;
  final String roomType;
  final String userId;
  final VoidCallback onClose;
  
  const ModeratorTimerControls({
    super.key,
    required this.roomId,
    required this.roomType,
    required this.userId,
    required this.onClose,
  });
  
  @override
  State<ModeratorTimerControls> createState() => _ModeratorTimerControlsState();
}

class _ModeratorTimerControlsState extends State<ModeratorTimerControls> {
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();
  
  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }
  
  Future<void> _sendTimerCommand(BuildContext context, String command) async {
    // Capture ScaffoldMessenger before any async operations to avoid BuildContext async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final appwrite = AppwriteService();
      final documentId = '${widget.roomId}_${widget.roomType}';
      
      AppLogger().info('Sending timer command: $command for document ID: $documentId');
      
      final timerData = <String, dynamic>{
        'roomId': widget.roomId,
        'roomType': widget.roomType,
      };
      
      // Add command-specific data
      if (command == 'start') {
        timerData['status'] = 'running';
        timerData['isActive'] = true;
        timerData['startTime'] = DateTime.now().toIso8601String();
      } else if (command == 'stop') {
        timerData['status'] = 'stopped';
        timerData['isActive'] = false;
        timerData['startTime'] = null;
        timerData['pausedAt'] = null;
      } else if (command == 'pause') {
        timerData['status'] = 'paused';
        timerData['isActive'] = true;
        timerData['pausedAt'] = DateTime.now().toIso8601String();
      }
      
      // Get current timer state for resume functionality
      Map<String, dynamic>? currentTimer;
      if (command == 'start') {
        try {
          final doc = await appwrite.databases.getDocument(
            databaseId: 'arena_db',
            collectionId: 'timers',
            documentId: documentId,
          );
          currentTimer = doc.data;
        } catch (e) {
          // Document doesn't exist yet
        }
      }
      
      // Handle resume from pause vs fresh start
      if (command == 'start' && currentTimer != null) {
        if (currentTimer['status'] == 'paused') {
          // Resuming from pause - calculate remaining time
          final durationSeconds = currentTimer['durationSeconds'] ?? 0;
          final startTimeStr = currentTimer['startTime'];
          final pausedAtStr = currentTimer['pausedAt'];
          
          if (startTimeStr != null && pausedAtStr != null) {
            final startTime = DateTime.parse(startTimeStr);
            final pausedAt = DateTime.parse(pausedAtStr);
            final elapsed = pausedAt.difference(startTime).inSeconds;
            final remainingAtPause = (durationSeconds - elapsed).clamp(0, durationSeconds);
            
            timerData['remainingSeconds'] = remainingAtPause;
          }
        } else {
          // Fresh start - use current remaining seconds from timer
          timerData['remainingSeconds'] = currentTimer['remainingSeconds'] ?? currentTimer['durationSeconds'] ?? 0;
        }
      }
      
      try {
        // Try to update existing document first
        await appwrite.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'timers',
          documentId: documentId,
          data: timerData,
        );
        AppLogger().info('Timer command sent successfully: $command');
        
        // Note: Local control is managed by FloatingTimerPill widget
        
      } catch (updateError) {
        AppLogger().warning('Failed to update timer document, creating new one: $updateError');
        // If update fails, create new document with default values
        timerData.addAll(<String, dynamic>{
          'remainingSeconds': 300, // Default 5 minutes
          'durationSeconds': 300, // Default 5 minutes
          'createdBy': widget.userId,
          'timerType': 'general', // Default timer type
          'status': command == 'start' ? 'running' : 'stopped',
          'isActive': command == 'start',
          'startTime': command == 'start' ? DateTime.now().toIso8601String() : null,
        });
        
        await appwrite.databases.createDocument(
          databaseId: 'arena_db',
          collectionId: 'timers',
          documentId: documentId,
          data: timerData,
        );
        AppLogger().info('Timer document created with command: $command');
        
        // Note: Local control is managed by FloatingTimerPill widget
      }
      
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('✅ Timer $command'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('Failed to send timer command: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('❌ Failed to control timer: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  Future<void> _setPresetTime(BuildContext context, int seconds) async {
    // Capture ScaffoldMessenger before any async operations to avoid BuildContext async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final appwrite = AppwriteService();
      final documentId = '${widget.roomId}_${widget.roomType}';
      
      AppLogger().info('Setting timer to $seconds seconds for document ID: $documentId');
      
      final timerData = <String, dynamic>{
        'roomId': widget.roomId,
        'roomType': widget.roomType,
        'remainingSeconds': seconds,
        'durationSeconds': seconds,
        'timerType': 'general',
        'status': 'stopped',
        'isActive': false,
      };
      
      try {
        // Try to update existing document first
        await appwrite.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: 'timers',
          documentId: documentId,
          data: timerData,
        );
        AppLogger().info('Timer document updated successfully');
      } catch (updateError) {
        AppLogger().warning('Failed to update timer document, creating new one: $updateError');
        // If update fails, create new document with all required fields
        timerData['createdBy'] = widget.userId;
        timerData['timerType'] = 'general';
        timerData['status'] = 'stopped';
        timerData['isActive'] = false;
        timerData['durationSeconds'] = seconds;
        await appwrite.databases.createDocument(
          databaseId: 'arena_db',
          collectionId: 'timers',
          documentId: documentId,
          data: timerData,
        );
        AppLogger().info('Timer document created successfully');
      }
      
      // Timer pill will be updated via real-time subscription
      
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      final timeString = '$minutes:${secs.toString().padLeft(2, '0')}';
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Timer set to $timeString'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      AppLogger().error('Failed to set preset time: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('❌ Failed to set timer: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  Future<void> _setCustomTime(BuildContext context) async {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();
    
    final minutesText = _minutesController.text.trim();
    final secondsText = _secondsController.text.trim();
    
    AppLogger().info('Custom time input - Minutes: "$minutesText", Seconds: "$secondsText"');
    
    // Handle empty inputs - default to 0
    final minutes = minutesText.isEmpty ? 0 : (int.tryParse(minutesText) ?? 0);
    final seconds = secondsText.isEmpty ? 0 : (int.tryParse(secondsText) ?? 0);
    
    // Validate seconds don't exceed 59
    final validSeconds = seconds > 59 ? 59 : seconds;
    final totalSeconds = (minutes * 60) + validSeconds;
    
    AppLogger().info('Parsed values - Minutes: $minutes, Seconds: $validSeconds, Total: $totalSeconds');
    
    if (totalSeconds <= 0) {
      AppLogger().warning('Invalid time input: totalSeconds = $totalSeconds');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid time (greater than 0)'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    if (totalSeconds > 3600) { // Limit to 1 hour
      AppLogger().warning('Time input too large: $totalSeconds seconds');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum time is 60 minutes'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    AppLogger().info('Setting custom time: $totalSeconds seconds');
    await _setPresetTime(context, totalSeconds);
    
    // Clear the input fields and dismiss keyboard
    _minutesController.clear();
    _secondsController.clear();
  }
  
  Widget _buildTimeInputField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      maxLength: label == 'Minutes' ? 2 : 2, // Limit input length
      onSubmitted: (_) {
        // Auto-submit when user presses enter
        _setCustomTime(context);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        counterText: '', // Hide character counter
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: Colors.grey[800],
      ),
      textAlign: TextAlign.center,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView( // Make it scrollable to handle keyboard
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Row(
            children: [
              const Icon(Icons.timer, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              const Text(
                'Timer Controls',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                context,
                icon: Icons.play_arrow,
                label: 'Start',
                onPressed: () => _sendTimerCommand(context, 'start'),
                color: Colors.green,
              ),
              _buildControlButton(
                context,
                icon: Icons.pause,
                label: 'Pause',
                onPressed: () => _sendTimerCommand(context, 'pause'),
                color: Colors.orange,
              ),
              _buildControlButton(
                context,
                icon: Icons.stop,
                label: 'Stop',
                onPressed: () => _sendTimerCommand(context, 'stop'),
                color: Colors.red,
              ),
              _buildControlButton(
                context,
                icon: Icons.skip_next,
                label: 'Next',
                onPressed: () => _sendTimerCommand(context, 'next_phase'),
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          
          // Custom Time Input Section
          const Text(
            'Set Custom Time',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeInputField('Minutes', _minutesController),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeInputField('Seconds', _secondsController),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _setCustomTime(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 16),
                    SizedBox(width: 4),
                    Text('Set'),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Text(
            'Quick Set Timer',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildPresetButton(context, '30s', 30),
              _buildPresetButton(context, '1m', 60),
              _buildPresetButton(context, '2m', 120),
              _buildPresetButton(context, '3m', 180),
              _buildPresetButton(context, '5m', 300),
              _buildPresetButton(context, '10m', 600),
            ],
          ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildPresetButton(BuildContext context, String label, int seconds) {
    return ElevatedButton(
      onPressed: () => _setPresetTime(context, seconds),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}