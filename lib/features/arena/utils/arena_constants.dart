import 'package:flutter/material.dart';

/// Constants used throughout the Arena feature
class ArenaConstants {
  // Colors
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color deepPurple = Color(0xFF6B46C1);
  static const Color scarletRed = Color(0xFFFF2400);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningAmber = Color(0xFFFFC107);
  
  // Gradients
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [deepPurple, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient redGradient = LinearGradient(
    colors: [scarletRed, Color(0xFFFF5252)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Dimensions
  static const double defaultBorderRadius = 12.0;
  static const double largeBorderRadius = 20.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Avatar sizes
  static const double smallAvatarRadius = 20.0;
  static const double mediumAvatarRadius = 30.0;
  static const double largeAvatarRadius = 40.0;
  static const double extraLargeAvatarRadius = 50.0;
  
  // Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 400);
  static const Duration longAnimationDuration = Duration(milliseconds: 800);
  
  // Timer constants
  static const int timerWarningThreshold = 30; // seconds
  static const int defaultTimerDuration = 300; // 5 minutes
  static const int extendTimeAmount = 60; // 1 minute
  static const int quickExtendTime = 30; // 30 seconds
  static const int longExtendTime = 300; // 5 minutes
  
  // Audience display
  static const int audienceGridColumns = 4;
  static const double audienceGridHeight = 140.0;
  static const double audienceGridSpacing = 6.0;
  static const double audienceGridAspectRatio = 0.85;
  
  // Participant display
  static const double participantCardHeight = 200.0;
  static const double judgeCardHeight = 120.0;
  static const double moderatorCardHeight = 150.0;
  
  // Text styles
  static const TextStyle titleTextStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
  
  static const TextStyle subtitleTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  static const TextStyle bodyTextStyle = TextStyle(
    fontSize: 14,
    color: Colors.white70,
  );
  
  static const TextStyle captionTextStyle = TextStyle(
    fontSize: 12,
    color: Colors.white54,
  );
  
  static const TextStyle timerTextStyle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
    color: Colors.white,
  );
  
  // Box shadows
  static const List<BoxShadow> defaultShadow = [
    BoxShadow(
      color: Colors.black26,
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black38,
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
  
  // Database constants
  static const String databaseId = 'arena_db';
  static const String debateRoomsCollection = 'debate_rooms';
  static const String roomParticipantsCollection = 'room_participants';
  static const String userProfilesCollection = 'user_profiles';
  static const String debateVotesCollection = 'debate_votes';
  static const String messagesCollection = 'messages';
  
  // Room status constants
  static const String roomStatusActive = 'active';
  static const String roomStatusClosed = 'closed';
  static const String roomStatusCompleted = 'completed';
  
  // Error messages
  static const String errorLoadingRoom = 'Failed to load room data';
  static const String errorLoadingParticipants = 'Failed to load participants';
  static const String errorJoiningRoom = 'Failed to join room';
  static const String errorLeavingRoom = 'Failed to leave room';
  static const String errorSubmittingVote = 'Failed to submit vote';
  static const String errorAssigningRole = 'Failed to assign role';
  static const String errorStartingTimer = 'Failed to start timer';
  static const String errorClosingRoom = 'Failed to close room';
  
  // Success messages
  static const String successJoinedRoom = 'Successfully joined the debate room';
  static const String successLeftRoom = 'Successfully left the debate room';
  static const String successVoteSubmitted = 'Vote submitted successfully';
  static const String successRoleAssigned = 'Role assigned successfully';
  static const String successRoomClosed = 'Room closed successfully';
  
  // Validation constants
  static const int minTopicLength = 10;
  static const int maxTopicLength = 200;
  static const int minDescriptionLength = 20;
  static const int maxDescriptionLength = 500;
  static const int maxParticipants = 100;
  static const int maxJudges = 3;
  
  // iOS optimization constants
  static const Duration iosCacheValidDuration = Duration(seconds: 30);
  static const int iosMaxCachedProfiles = 50;
  static const int iosMaxCachedRooms = 10;
  
  // Realtime constants
  static const Duration realtimeReconnectDelay = Duration(seconds: 5);
  static const Duration roomStatusCheckInterval = Duration(seconds: 10);
  static const Duration heartbeatInterval = Duration(seconds: 30);
  
  // Navigation constants
  static const String homeRoute = '/home';
  static const String arenaRoute = '/arena';
  static const String resultsRoute = '/arena/results';
  static const String moderatorRoute = '/arena/moderator';
  
  // File size limits
  static const int maxFileLines = 500;
  static const int maxFileSizeKB = 50;
  
  // Performance constants
  static const int maxRealtimeEvents = 100;
  static const Duration debounceDelay = Duration(milliseconds: 300);
  static const int maxRetryAttempts = 3;
}