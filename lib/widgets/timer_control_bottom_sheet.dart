import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/timer_state.dart';
import '../services/appwrite_timer_service.dart';
import '../config/timer_presets.dart';
import '../core/logging/app_logger.dart';

/// Timer Control Bottom Sheet for moderators
/// 
/// Provides comprehensive timer controls including:
/// - Timer presets selection
/// - Custom timer creation
/// - Timer control buttons (start/pause/stop/reset)
/// - Time adjustment (+30s, +1min, etc.)
class TimerControlBottomSheet extends StatefulWidget {
  final String roomId;
  final RoomType roomType;
  final String userId;
  final TimerState? activeTimer;
  final AppwriteTimerService timerService;

  const TimerControlBottomSheet({
    super.key,
    required this.roomId,
    required this.roomType,
    required this.userId,
    required this.activeTimer,
    required this.timerService,
  });

  @override
  State<TimerControlBottomSheet> createState() => _TimerControlBottomSheetState();
}

class _TimerControlBottomSheetState extends State<TimerControlBottomSheet> {
  final TextEditingController _customMinutesController = TextEditingController();
  final TextEditingController _customSecondsController = TextEditingController();
  
  TimerConfiguration? _selectedPreset;
  int? _selectedPresetDuration;
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    
    // Get presets for current room type
    final roomPreset = TimerPresets.presets[widget.roomType];
    if (roomPreset != null && roomPreset.timers.isNotEmpty) {
      _selectedPreset = roomPreset.timers.first;
      _selectedPresetDuration = _selectedPreset!.defaultDurationSeconds;
    }
  }

  @override
  void dispose() {
    _customMinutesController.dispose();
    _customSecondsController.dispose();
    super.dispose();
  }

  /// Create a new timer with selected configuration
  Future<void> _createTimer() async {
    if (_selectedPreset == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      int durationSeconds;
      
      // Use custom duration if provided, otherwise use preset
      if (_customMinutesController.text.isNotEmpty || _customSecondsController.text.isNotEmpty) {
        final minutes = int.tryParse(_customMinutesController.text) ?? 0;
        final seconds = int.tryParse(_customSecondsController.text) ?? 0;
        durationSeconds = (minutes * 60) + seconds;
        
        if (durationSeconds <= 0) {
          throw Exception('Timer duration must be greater than 0');
        }
        
        // Allow any custom duration - no min/max restrictions
      } else if (_selectedPresetDuration != null) {
        durationSeconds = _selectedPresetDuration!;
      } else {
        durationSeconds = _selectedPreset!.defaultDurationSeconds;
      }
      
      await widget.timerService.createTimer(
        roomId: widget.roomId,
        roomType: widget.roomType,
        timerType: _selectedPreset!.type,
        durationSeconds: durationSeconds,
        createdBy: widget.userId,
        title: _selectedPreset!.label,
      );
      
      AppLogger().info('🕐 Timer created successfully: ${_selectedPreset!.label} - ${durationSeconds}s');
      
      // Close bottom sheet on success
      if (mounted) {
        Navigator.of(context).pop();
      }
      
    } catch (e) {
      AppLogger().error('🕐 Failed to create timer: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Control existing timer
  Future<void> _controlTimer(String action) async {
    if (widget.activeTimer == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      switch (action) {
        case 'start':
          await widget.timerService.startTimer(widget.activeTimer!.id, widget.userId);
          break;
        case 'pause':
          await widget.timerService.pauseTimer(widget.activeTimer!.id, widget.userId);
          break;
        case 'stop':
          await widget.timerService.stopTimer(widget.activeTimer!.id, widget.userId);
          break;
        case 'reset':
          await widget.timerService.resetTimer(widget.activeTimer!.id, widget.userId);
          break;
      }
      
      AppLogger().info('🕐 Timer $action completed');
      
    } catch (e) {
      AppLogger().error('🕐 Failed to $action timer: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Add time to existing timer
  Future<void> _addTime(int seconds) async {
    if (widget.activeTimer == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await widget.timerService.addTime(widget.activeTimer!.id, seconds, widget.userId);
      AppLogger().info('🕐 Added ${seconds}s to timer');
      
    } catch (e) {
      AppLogger().error('🕐 Failed to add time to timer: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomPreset = TimerPresets.presets[widget.roomType];
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return GestureDetector(
            onTap: () {
              // Dismiss keyboard when tapping outside
              FocusScope.of(context).unfocus();
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white54,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Timer Controls',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active Timer Controls (if timer exists)
                        if (widget.activeTimer != null) ...[
                          _buildActiveTimerSection(theme),
                          const SizedBox(height: 24),
                        ],
                        
                        // Create New Timer Section
                        _buildCreateTimerSection(theme, roomPreset),
                        
                        // Error message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildActiveTimerSection(ThemeData theme) {
    final timer = widget.activeTimer!;
    final isRunning = timer.status == TimerStatus.running;
    final isPaused = timer.status == TimerStatus.paused;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Timer',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Timer info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    isRunning ? Icons.play_circle : (isPaused ? Icons.pause_circle : Icons.stop_circle),
                    color: isRunning ? Colors.green : (isPaused ? Colors.orange : Colors.red),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timer.description ?? timer.timerType.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    timer.formattedTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: isRunning ? Icons.pause : Icons.play_arrow,
                    label: isRunning ? 'Pause' : 'Start',
                    onPressed: _isLoading ? null : () => _controlTimer(isRunning ? 'pause' : 'start'),
                    color: isRunning ? Colors.orange : Colors.green,
                  ),
                  _buildControlButton(
                    icon: Icons.stop,
                    label: 'Stop',
                    onPressed: _isLoading ? null : () => _controlTimer('stop'),
                    color: Colors.red,
                  ),
                  _buildControlButton(
                    icon: Icons.refresh,
                    label: 'Reset',
                    onPressed: _isLoading ? null : () => _controlTimer('reset'),
                    color: Colors.blue,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Time adjustment buttons
              Text(
                'Add Time',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTimeAdjustButton('+30s', 30),
                  _buildTimeAdjustButton('+1m', 60),
                  _buildTimeAdjustButton('+2m', 120),
                  _buildTimeAdjustButton('+5m', 300),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildCreateTimerSection(ThemeData theme, RoomTimerPreset? roomPreset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create New Timer',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        if (roomPreset != null) ...[
          // Timer type selection
          Text(
            'Timer Type',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButton<TimerConfiguration>(
              isExpanded: true,
              value: _selectedPreset,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              items: roomPreset.timers.map((config) {
                return DropdownMenuItem(
                  value: config,
                  child: Text(config.label),
                );
              }).toList(),
              onChanged: (config) {
                setState(() {
                  _selectedPreset = config;
                  _selectedPresetDuration = config?.defaultDurationSeconds;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Preset durations
          if (_selectedPreset != null) ...[
            Text(
              'Quick Presets',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedPreset!.presetDurations.map((seconds) {
                final isSelected = _selectedPresetDuration == seconds;
                final minutes = seconds ~/ 60;
                final remainingSeconds = seconds % 60;
                String label;
                if (remainingSeconds == 0) {
                  label = '${minutes}m';
                } else if (minutes == 0) {
                  label = '${seconds}s';
                } else {
                  label = '${minutes}m ${remainingSeconds}s';
                }
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPresetDuration = seconds;
                      _customMinutesController.clear();
                      _customSecondsController.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey[800],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.white24,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          
          // Custom duration
          Text(
            'Custom Duration',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customMinutesController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Minutes',
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedPresetDuration = null;
                    });
                  },
                  onSubmitted: (_) {
                    // Move focus to seconds field
                    FocusScope.of(context).nextFocus();
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text(':', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _customSecondsController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Seconds',
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedPresetDuration = null;
                    });
                  },
                  onSubmitted: (_) {
                    // Dismiss keyboard when done
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
            ],
          ),
          
          // Keyboard dismissal button
          if (MediaQuery.of(context).viewInsets.bottom > 0) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                },
                icon: const Icon(Icons.keyboard_hide, color: Colors.blue, size: 18),
                label: const Text(
                  'Done',
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.blue, width: 1),
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _createTimer,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_circle, color: Colors.white),
              label: Text(
                _isLoading ? 'Creating...' : 'Create Timer',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          radius: 24,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: color, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
  
  Widget _buildTimeAdjustButton(String label, int seconds) {
    return GestureDetector(
      onTap: _isLoading ? null : () => _addTime(seconds),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.green,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}