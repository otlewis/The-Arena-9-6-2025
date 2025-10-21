import 'dart:async';
import 'package:flutter/material.dart';

/// A widget that displays a live countdown for a user's timeout
class TimeoutCountdownWidget extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback? onExpired;

  const TimeoutCountdownWidget({
    super.key,
    required this.expiresAt,
    this.onExpired,
  });

  @override
  State<TimeoutCountdownWidget> createState() => _TimeoutCountdownWidgetState();
}

class _TimeoutCountdownWidgetState extends State<TimeoutCountdownWidget> {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final diff = widget.expiresAt.difference(now);

    if (diff.isNegative) {
      _remaining = Duration.zero;
      if (widget.onExpired != null) {
        widget.onExpired!();
      }
    } else {
      _remaining = diff;
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _updateRemaining();
      });

      if (_remaining == Duration.zero) {
        timer.cancel();
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.green.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 6),
            Text(
              'Timeout Expired',
              style: TextStyle(
                color: Colors.green,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Determine color based on remaining time
    Color color;
    if (_remaining.inMinutes < 1) {
      color = Colors.red; // Less than 1 minute
    } else if (_remaining.inMinutes < 5) {
      color = Colors.orange; // Less than 5 minutes
    } else {
      color = Colors.blue; // 5+ minutes
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            _formatDuration(_remaining),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
