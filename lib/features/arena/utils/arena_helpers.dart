import 'package:flutter/material.dart';
import 'dart:async';
import '../models/debate_phase.dart';
import '../models/participant_role.dart';
import 'arena_constants.dart';

/// Helper utilities for the Arena feature
class ArenaHelpers {
  /// Formats seconds into MM:SS format
  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  /// Gets the color for a specific role
  static Color getRoleColor(ParticipantRole role) {
    switch (role) {
      case ParticipantRole.affirmative:
        return ArenaConstants.successGreen;
      case ParticipantRole.negative:
        return ArenaConstants.scarletRed;
      case ParticipantRole.moderator:
        return ArenaConstants.accentPurple;
      case ParticipantRole.judge1:
      case ParticipantRole.judge2:
      case ParticipantRole.judge3:
        return ArenaConstants.warningAmber;
      case ParticipantRole.audience:
        return Colors.grey;
    }
  }
  
  /// Gets the gradient for a specific role
  static LinearGradient getRoleGradient(ParticipantRole role) {
    switch (role) {
      case ParticipantRole.affirmative:
        return ArenaConstants.greenGradient;
      case ParticipantRole.negative:
        return ArenaConstants.redGradient;
      case ParticipantRole.moderator:
      case ParticipantRole.judge1:
      case ParticipantRole.judge2:
      case ParticipantRole.judge3:
        return ArenaConstants.purpleGradient;
      case ParticipantRole.audience:
        return const LinearGradient(
          colors: [Colors.grey, Colors.blueGrey],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
  
  /// Gets the icon for a specific role
  static IconData getRoleIcon(ParticipantRole role) {
    switch (role) {
      case ParticipantRole.affirmative:
        return Icons.thumb_up;
      case ParticipantRole.negative:
        return Icons.thumb_down;
      case ParticipantRole.moderator:
        return Icons.gavel;
      case ParticipantRole.judge1:
      case ParticipantRole.judge2:
      case ParticipantRole.judge3:
        return Icons.balance;
      case ParticipantRole.audience:
        return Icons.people;
    }
  }
  
  /// Gets the phase color based on current speaker
  static Color getPhaseColor(DebatePhase phase) {
    if (phase.isAffirmativePhase) {
      return ArenaConstants.successGreen;
    } else if (phase.isNegativePhase) {
      return ArenaConstants.scarletRed;
    } else {
      return ArenaConstants.accentPurple;
    }
  }
  
  /// Gets the timer warning color based on remaining time
  static Color getTimerColor(int remainingSeconds) {
    if (remainingSeconds <= 10) {
      return Colors.red;
    } else if (remainingSeconds <= 30) {
      return Colors.orange;
    } else {
      return Colors.white;
    }
  }
  
  /// Validates topic length
  static String? validateTopic(String? topic) {
    if (topic == null || topic.trim().isEmpty) {
      return 'Topic is required';
    }
    if (topic.trim().length < ArenaConstants.minTopicLength) {
      return 'Topic must be at least ${ArenaConstants.minTopicLength} characters';
    }
    if (topic.trim().length > ArenaConstants.maxTopicLength) {
      return 'Topic cannot exceed ${ArenaConstants.maxTopicLength} characters';
    }
    return null;
  }
  
  /// Validates description length
  static String? validateDescription(String? description) {
    if (description == null || description.trim().isEmpty) {
      return null; // Description is optional
    }
    if (description.trim().length < ArenaConstants.minDescriptionLength) {
      return 'Description must be at least ${ArenaConstants.minDescriptionLength} characters';
    }
    if (description.trim().length > ArenaConstants.maxDescriptionLength) {
      return 'Description cannot exceed ${ArenaConstants.maxDescriptionLength} characters';
    }
    return null;
  }
  
  /// Truncates text to a specific length
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  /// Gets the next available judge role
  static String? getNextAvailableJudgeRole(Map<String, dynamic> participants) {
    for (int i = 1; i <= ArenaConstants.maxJudges; i++) {
      final judgeRole = 'judge$i';
      if (!participants.containsKey(judgeRole)) {
        return judgeRole;
      }
    }
    return null;
  }
  
  /// Checks if user has permission for action
  static bool hasPermission(ParticipantRole userRole, String action) {
    switch (action) {
      case 'start_timer':
      case 'stop_timer':
      case 'advance_phase':
      case 'assign_roles':
      case 'close_room':
        return userRole == ParticipantRole.moderator;
      case 'vote':
        return userRole.canVote;
      case 'speak':
        return userRole.canSpeak;
      default:
        return false;
    }
  }
  
  /// Creates a snackbar for success messages
  static SnackBar createSuccessSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Text(message),
        ],
      ),
      backgroundColor: ArenaConstants.successGreen,
      duration: const Duration(seconds: 3),
    );
  }
  
  /// Creates a snackbar for error messages
  static SnackBar createErrorSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: ArenaConstants.scarletRed,
      duration: const Duration(seconds: 5),
    );
  }
  
  /// Creates a snackbar for warning messages
  static SnackBar createWarningSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.warning, color: Colors.black),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.black))),
        ],
      ),
      backgroundColor: ArenaConstants.warningAmber,
      duration: const Duration(seconds: 4),
    );
  }
  
  /// Calculates grid height for audience display
  static double calculateAudienceGridHeight(int audienceCount) {
    final rowCount = (audienceCount / ArenaConstants.audienceGridColumns).ceil();
    return (rowCount * (ArenaConstants.audienceGridHeight / 2)).clamp(70.0, ArenaConstants.audienceGridHeight);
  }
  
  /// Note: App is locked to portrait orientation
  /// This method is deprecated and always returns false
  @Deprecated('App is now locked to portrait orientation. This method always returns false.')
  static bool isLandscape(BuildContext context) {
    return false; // App is locked to portrait
  }
  
  /// Gets appropriate font size based on screen size
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) {
      return baseFontSize * 0.8;
    } else if (screenWidth > 600) {
      return baseFontSize * 1.2;
    }
    return baseFontSize;
  }
  
  /// Formats duration for display
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
  
  /// Creates a confirmation dialog
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
  
  /// Debounces function calls
  static Function debounce(Function func, Duration delay) {
    Timer? timer;
    return () {
      timer?.cancel();
      timer = Timer(delay, () => func());
    };
  }
}