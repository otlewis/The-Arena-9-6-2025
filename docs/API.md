# API Documentation

## Overview

The Arena application integrates with several external services and provides internal APIs for managing debate functionality.

## External Integrations

### Appwrite Backend

#### Authentication Service
```dart
class AppwriteService {
  /// Register a new user account
  Future<User> registerUser({
    required String email,
    required String password,
    required String name,
  });

  /// Authenticate user with email/password
  Future<User> loginUser({
    required String email,
    required String password,
  });

  /// Get current authenticated user
  Future<User?> getCurrentUser();

  /// Sign out current user
  Future<void> logoutUser();
}
```

#### Database Operations
```dart
class AppwriteService {
  /// Create a new arena room
  Future<Document> createArenaRoom({
    required String topic,
    required String description,
    required String challengerId,
    required String challengedId,
  });

  /// Get arena room by ID
  Future<Document?> getArenaRoom(String roomId);

  /// Update arena room status
  Future<Document> updateArenaRoom(String roomId, Map<String, dynamic> data);

  /// Assign user to arena role
  Future<void> assignArenaRole({
    required String roomId,
    required String userId,
    required String role,
  });

  /// Get user's debate clubs
  Future<List<Document>> getUserClubs(String userId);
}
```

#### Real-time Subscriptions
```dart
class AppwriteService {
  /// Subscribe to arena room updates
  RealtimeSubscription subscribeToArenaRoom(
    String roomId,
    Function(RealtimeMessage) callback,
  );

  /// Subscribe to challenge messages
  RealtimeSubscription subscribeToChallenges(
    String userId,
    Function(RealtimeMessage) callback,
  );

  /// Subscribe to club updates
  RealtimeSubscription subscribeToClub(
    String clubId,
    Function(RealtimeMessage) callback,
  );
}
```

### Agora Voice SDK

#### Voice Service Interface
```dart
abstract class AgoraService {
  /// Initialize the Agora engine
  Future<void> initialize();

  /// Join voice channel
  Future<void> joinChannel();

  /// Leave voice channel
  Future<void> leaveChannel();

  /// Switch to speaker role (can broadcast audio)
  Future<void> switchToSpeaker();

  /// Switch to audience role (listen only)
  Future<void> switchToAudience();

  /// Mute/unmute local audio
  Future<void> muteLocalAudio(bool muted);

  /// Enable/disable speakerphone
  Future<void> setEnableSpeakerphone(bool enabled);
}
```

#### Event Callbacks
```dart
class AgoraService {
  /// Called when user joins channel
  Function(int uid)? onUserJoined;

  /// Called when user leaves channel
  Function(int uid)? onUserLeft;

  /// Called when user mutes/unmutes audio
  Function(int uid, bool muted)? onUserMuteAudio;

  /// Called when channel join status changes
  Function(bool joined)? onJoinChannel;
}
```

## Internal APIs

### Arena Provider

#### State Management
```dart
@riverpod
class ArenaNotifier extends _$ArenaNotifier {
  /// Initialize arena with room data
  Future<void> initialize();

  /// Request permission to speak
  Future<void> requestToSpeak();

  /// Stop speaking and return to audience
  Future<void> stopSpeaking();

  /// Start the debate
  Future<void> startDebate();

  /// Send chat message
  Future<void> sendMessage(String message);

  /// Leave the arena
  Future<void> leaveArena();

  /// Update debate phase
  Future<void> updatePhase(DebatePhase phase);

  /// Submit judge score
  Future<void> submitScore(Map<String, dynamic> score);
}
```

#### Arena State Model
```dart
@freezed
class ArenaState with _$ArenaState {
  const factory ArenaState({
    required String roomId,
    required String topic,
    required String description,
    required ArenaStatus status,
    required DebatePhase currentPhase,
    required List<ArenaParticipant> participants,
    required List<Message> messages,
    required Timer? phaseTimer,
    required Map<String, dynamic> scores,
    String? error,
  }) = _ArenaState;

  factory ArenaState.initial() => ArenaState(
    roomId: '',
    topic: '',
    description: '',
    status: ArenaStatus.waiting,
    currentPhase: DebatePhase.waiting,
    participants: [],
    messages: [],
    phaseTimer: null,
    scores: {},
  );
}
```

### Challenge Messaging Service

#### Challenge Management
```dart
class ChallengeMessagingService {
  /// Send a debate challenge
  Future<void> sendChallenge({
    required String challengedUserId,
    required String topic,
    required String description,
    required String position,
  });

  /// Respond to received challenge
  Future<void> respondToChallenge(
    String challengeId,
    String response, // 'accepted' | 'declined'
  );

  /// Dismiss challenge for later
  Future<void> dismissChallenge(String challengeId);

  /// Invite user to arena role
  Future<void> inviteToArenaRole({
    required String userId,
    required String arenaId,
    required String role,
  });

  /// Respond to arena role invitation
  Future<void> respondToArenaRoleInvitation({
    required String invitationId,
    required bool accept,
  });
}
```

#### Message Subscriptions
```dart
class ChallengeMessagingService {
  /// Subscribe to incoming challenges
  Stream<Map<String, dynamic>> get challengeStream;

  /// Subscribe to arena role invitations
  Stream<Map<String, dynamic>> get arenaRoleInvitationStream;

  /// Get all user messages
  Future<List<Map<String, dynamic>>> getUserMessages(String userId);

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId);
}
```

### Sound Service

#### Audio Management
```dart
class SoundService {
  /// Initialize sound system
  Future<void> initialize();

  /// Enable/disable sound effects
  void setSoundEnabled(bool enabled);

  /// Play challenge received sound
  Future<void> playChallengeSound();

  /// Play 30-second warning sound
  Future<void> play30SecWarningSound();

  /// Play arena timer zero sound
  Future<void> playArenaZeroSound();

  /// Play applause sound for celebration
  Future<void> playApplauseSound();

  /// Play custom sound file
  Future<void> playCustomSound(String fileName);

  /// Stop any playing sound
  Future<void> stopSound();
}
```

## Data Models

### Core Models

#### User Model
```dart
class User {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final DateTime createdAt;
  final Map<String, dynamic> preferences;
}
```

#### Arena Model
```dart
class Arena {
  final String id;
  final String topic;
  final String description;
  final ArenaStatus status;
  final DebatePhase currentPhase;
  final String challengerId;
  final String challengedId;
  final DateTime createdAt;
  final Map<String, dynamic> settings;
}
```

#### Message Model
```dart
class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
}
```

### Enums

#### Arena Status
```dart
enum ArenaStatus {
  waiting,     // Waiting for participants
  speaking,    // Debate in progress
  voting,      // Judge voting phase
  completed,   // Debate finished
}
```

#### Debate Phase
```dart
enum DebatePhase {
  waiting,         // Waiting to start
  opening,         // Opening statements
  rebuttal,        // Rebuttals
  crossExamination, // Cross-examination
  closing,         // Closing arguments
  voting,          // Judge voting
  results,         // Results display
}
```

#### Arena Role
```dart
enum ArenaRole {
  affirmativeDebater,  // Pro argument debater
  negativeDebater,     // Con argument debater
  judge,               // Scoring judge
  moderator,           // Debate moderator
  audience,            // Spectator
}
```

## Error Handling

### Custom Exceptions
```dart
class AppError implements Exception {
  final String message;
  final String code;
  final dynamic originalError;
  
  const AppError(this.message, this.code, [this.originalError]);
}

class ValidationError extends AppError {
  final String field;
  
  const ValidationError(this.field, String message) 
    : super(message, 'VALIDATION_ERROR');
}

class NetworkError extends AppError {
  const NetworkError(String message) 
    : super(message, 'NETWORK_ERROR');
}
```

### Error Response Format
```dart
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? errorCode;
  
  const ApiResponse.success(this.data) 
    : success = true, error = null, errorCode = null;
    
  const ApiResponse.error(this.error, this.errorCode) 
    : success = false, data = null;
}
```

## Rate Limiting

### API Rate Limits
- **Challenge Creation**: 10 per hour per user
- **Message Sending**: 60 per minute per user
- **Arena Creation**: 5 per hour per user
- **Voice Channel Join**: 20 per hour per user

### Implementation
```dart
class RateLimiter {
  final Map<String, List<DateTime>> _requests = {};
  
  bool isAllowed(String key, int maxRequests, Duration timeWindow) {
    final now = DateTime.now();
    final requests = _requests[key] ?? [];
    
    // Remove old requests outside time window
    requests.removeWhere((time) => now.difference(time) > timeWindow);
    
    if (requests.length >= maxRequests) {
      return false;
    }
    
    requests.add(now);
    _requests[key] = requests;
    return true;
  }
}
```

This API documentation provides comprehensive coverage of all major interfaces and integration points in the Arena application.