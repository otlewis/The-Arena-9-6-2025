import 'dart:async';
import 'package:flutter/material.dart';
import '../../../main.dart' show ArenaApp;
import '../../../core/logging/app_logger.dart';

/// Room Closing Modal - DO NOT MODIFY UI LAYOUT
/// This modal shows countdown when room is being closed by moderator
class RoomClosingModal extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback onCountdownComplete;
  final VoidCallback? onForceNavigation;

  const RoomClosingModal({
    super.key,
    required this.initialSeconds,
    required this.onCountdownComplete,
    this.onForceNavigation,
  });

  @override
  State<RoomClosingModal> createState() => _RoomClosingModalState();
}

class _RoomClosingModalState extends State<RoomClosingModal> {
  late int _secondsRemaining;
  late Timer _timer;
  bool _hasNavigated = false; // Track if we've already navigated

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.initialSeconds;
    _startCountdown();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _forceNavigation() {
    if (!_hasNavigated && mounted) {
      _hasNavigated = true;
      AppLogger().info('Forcing navigation back to arena lobby from closing modal');
      
      // Call the parent's navigation callback if provided
      if (widget.onForceNavigation != null) {
        widget.onForceNavigation!();
      } else {
        // Fallback navigation
        try {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ArenaApp()),
            (route) => false,
          );
          AppLogger().info('Successfully navigated from modal to Main App');
        } catch (e) {
          AppLogger().error('Modal navigation failed: $e');
        }
      }
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsRemaining--;
        });
        
        if (_secondsRemaining <= 0) {
          timer.cancel();
          _forceNavigation(); // Use force navigation instead of callback
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red[400]!,
              Colors.red[600]!,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              const Text(
                'ROOM CLOSING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Message
              const Text(
                'The moderator has closed this arena room.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              // Countdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Returning to lobby in:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_secondsRemaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Text(
                      'seconds',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Leave Now Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _timer.cancel();
                    _forceNavigation(); // Use force navigation
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Leave Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}