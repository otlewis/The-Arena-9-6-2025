import 'package:appwrite/appwrite.dart';
import 'dart:async';
import '../constants/appwrite.dart';
import 'appwrite_service.dart';
import '../core/logging/app_logger.dart';

/// Challenge message model for type safety
class ChallengeMessage {
  final String id;
  final String challengerId;
  final String challengedId;
  final String challengerName;
  final String? challengerAvatar;
  final String topic;
  final String? description;
  final String? category; // Debate category (e.g., 'politics', 'science', 'ethics')
  final String position; // 'affirmative' or 'negative'
  final String status; // 'pending', 'accepted', 'declined', 'expired'
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;
  final DateTime? dismissedAt;
  final String? arenaRoomId;
  final String messageType;
  final int priority;

  ChallengeMessage({
    required this.id,
    required this.challengerId,
    required this.challengedId,
    required this.challengerName,
    this.challengerAvatar,
    required this.topic,
    this.description,
    this.category,
    required this.position,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
    this.dismissedAt,
    this.arenaRoomId,
    required this.messageType,
    required this.priority,
  });

  factory ChallengeMessage.fromMap(Map<String, dynamic> map) {
    return ChallengeMessage(
      id: map['\$id'] ?? map['id'] ?? '',
      challengerId: map['challengerId'] ?? '',
      challengedId: map['challengedId'] ?? '',
      challengerName: map['challengerName'] ?? 'Unknown User',
      challengerAvatar: map['challengerAvatar'],
      topic: map['topic'] ?? 'No topic',
      description: map['description'],
      category: map['category'],
      position: map['position'] ?? 'affirmative',
      status: map['status'] ?? 'pending',
      createdAt: DateTime.parse(map['\$createdAt'] ?? map['createdAt'] ?? DateTime.now().toIso8601String()),
      expiresAt: DateTime.parse(map['expiresAt'] ?? DateTime.now().add(const Duration(hours: 24)).toIso8601String()),
      respondedAt: map['respondedAt'] != null ? DateTime.parse(map['respondedAt']) : null,
      dismissedAt: map['dismissedAt'] != null ? DateTime.parse(map['dismissedAt']) : null,
      arenaRoomId: map['arenaRoomId'],
      messageType: map['messageType'] ?? 'challenge',
      priority: map['priority'] ?? 3,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'challengerId': challengerId,
      'challengedId': challengedId,
      'challengerName': challengerName,
      'challengerAvatar': challengerAvatar,
      'topic': topic,
      'description': description,
      'category': category,
      'position': position,
      'status': status,
      'expiresAt': expiresAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'dismissedAt': dismissedAt?.toIso8601String(),
      'arenaRoomId': arenaRoomId,
      'messageType': messageType,
      'priority': priority,
    };
  }

  /// Convert to the format expected by the existing modal
  Map<String, dynamic> toModalFormat() {
    if (isArenaRole) {
      // Format for arena role notification modal
      return {
        'id': id,
        'role': position, // The role they're being invited to
        'topic': topic,
        'description': description,
        'category': category,
        'arenaId': arenaRoomId,
        'userId': challengedId, // The user being invited
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };
    } else {
      // Format for challenge modal  
      return {
        'id': id,
        'challengerId': challengerId,
        'challengedId': challengedId,
        'challengerName': challengerName,
        'challengerAvatar': challengerAvatar,
        'topic': topic,
        'description': description,
        'category': category,
        'position': position,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'respondedAt': respondedAt?.toIso8601String(),
        'arenaRoomId': arenaRoomId,
      };
    }
  }

  bool get isPending => status == 'pending';
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isDismissed => dismissedAt != null;
  bool get isArenaRole => messageType == 'arena_role';
  bool get isChallenge => messageType == 'challenge';
}

/// Reliable messaging service using persistent storage and streams
class ChallengeMessagingService {
  static final ChallengeMessagingService _instance = ChallengeMessagingService._internal();
  factory ChallengeMessagingService() => _instance;
  ChallengeMessagingService._internal();

  final AppwriteService _appwrite = AppwriteService();
  
  // Stream controllers for reactive UI updates
  final _incomingChallengesController = StreamController<ChallengeMessage>.broadcast();
  final _challengeUpdatesController = StreamController<ChallengeMessage>.broadcast();
  final _challengeDeclinedController = StreamController<ChallengeMessage>.broadcast(); // For challenger notifications
  final _pendingChallengesController = StreamController<List<ChallengeMessage>>.broadcast();
  final _arenaRoleInvitationsController = StreamController<ChallengeMessage>.broadcast();
  
  // Cached data
  String? _currentUserId;
  List<ChallengeMessage> _pendingChallenges = [];
  RealtimeSubscription? _realtimeSubscription;
  bool _isInitialized = false;
  
  // Stream getters - these are what the UI will listen to
  Stream<ChallengeMessage> get incomingChallenges => _incomingChallengesController.stream;
  Stream<ChallengeMessage> get challengeUpdates => _challengeUpdatesController.stream;
  Stream<ChallengeMessage> get challengeDeclined => _challengeDeclinedController.stream; // Expose stream
  Stream<List<ChallengeMessage>> get pendingChallenges => _pendingChallengesController.stream;
  Stream<ChallengeMessage> get arenaRoleInvitations => _arenaRoleInvitationsController.stream;
  
  // Getters for immediate access
  List<ChallengeMessage> get currentPendingChallenges => List.unmodifiable(_pendingChallenges);
  int get pendingChallengeCount => _pendingChallenges.where((c) => c.isPending && !c.isDismissed).length;
  bool get isInitialized => _isInitialized;
  
  /// Initialize the messaging service for a user
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) {
      AppLogger().debug('📱 ChallengeMessagingService already initialized for user: $userId');
      return;
    }
    
    _currentUserId = userId;
    AppLogger().debug('📱 Initializing ChallengeMessagingService for user: $userId');
    
    // Load existing pending challenges
    await _loadPendingChallenges();
    
    // Start realtime listening
    await _startRealtimeListening();
    
    _isInitialized = true;
    AppLogger().debug('📱 ✅ ChallengeMessagingService initialized successfully');
  }
  
  /// Load pending challenges from database
  Future<void> _loadPendingChallenges() async {
    if (_currentUserId == null) return;
    
    try {
      AppLogger().debug('📱 Loading pending challenges for user: $_currentUserId');
      
      // Query for pending challenges where user is the recipient
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'challenge_messages',
        queries: [
          Query.equal('challengedId', _currentUserId!),
          Query.equal('status', 'pending'),
          Query.orderDesc('\$createdAt'),
          Query.limit(50),
        ],
      );
      
      _pendingChallenges = response.documents
          .map((doc) => ChallengeMessage.fromMap(doc.data))
          .where((challenge) => !challenge.isExpired) // Filter out expired
          .toList();
      
      AppLogger().debug('📱 Loaded ${_pendingChallenges.length} pending challenges');
      
      // Notify listeners
      _pendingChallengesController.add(_pendingChallenges);
      
      // Clean up expired challenges
      await _cleanupExpiredChallenges();
      
    } catch (e) {
      AppLogger().error('Error loading pending challenges: $e');
    }
  }
  
  /// Start realtime listening for new challenges and updates
  Future<void> _startRealtimeListening() async {
    if (_currentUserId == null) return;
    
    try {
      AppLogger().debug('📱 Starting realtime subscription for challenge messages');
      AppLogger().debug('📱 Subscribing to: databases.${AppwriteConstants.databaseId}.collections.challenge_messages.documents');
      
      // Dispose existing subscription if any
      if (_realtimeSubscription != null) {
        AppLogger().debug('📱 Closing existing subscription');
        _realtimeSubscription!.close();
        _realtimeSubscription = null;
      }
      
      // Create realtime client directly to ensure proper subscription
      final realtime = Realtime(_appwrite.client);
      
      // Subscribe to challenge_messages collection
      _realtimeSubscription = realtime.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.challenge_messages.documents'
      ]);
      
      // Add connection status logging
      _realtimeSubscription!.stream.listen(
        (response) {
          _handleRealtimeEvent(response);
        },
        onError: (error) {
          AppLogger().error('Realtime subscription error: $error');
        },
        onDone: () {
          AppLogger().debug('📱 ⚠️ Realtime subscription ended');
        },
      );
      
      AppLogger().debug('📱 ✅ Realtime subscription active for challenge_messages');
      
    } catch (e) {
      AppLogger().error('Error starting realtime subscription: $e');
      AppLogger().error('Error details: ${e.toString()}');
    }
  }
  
  /// Handle realtime events from Appwrite
  void _handleRealtimeEvent(RealtimeMessage response) {
    try {
      final events = response.events;
      final payload = response.payload;
      
      AppLogger().debug('📱 REALTIME EVENT: events=${events.join(", ")}');
      AppLogger().debug('📱 REALTIME PAYLOAD: ${payload.isNotEmpty ? payload.keys.join(", ") : "empty"}');
      
      if (payload.isEmpty) {
        AppLogger().debug('📱 REALTIME: Skipping empty payload');
        return;
      }
      
      final challengeData = Map<String, dynamic>.from(payload);
      final challenge = ChallengeMessage.fromMap(challengeData);
      
      AppLogger().debug('📱 REALTIME: challenge.challengedId=${challenge.challengedId}, currentUserId=$_currentUserId');
      AppLogger().debug('📱 REALTIME: challenge.messageType=${challenge.messageType}, isArenaRole=${challenge.isArenaRole}');
      
      // Skip instant messages - let AgoraInstantMessagingService handle them
      if (challenge.messageType == 'instant_message') {
        AppLogger().debug('📱 REALTIME: Skipping instant message - handled by AgoraInstantMessagingService');
        return;
      }
      
      // Only process events relevant to current user
      if (challenge.challengedId != _currentUserId && challenge.challengerId != _currentUserId) {
        AppLogger().debug('📱 REALTIME: Skipping - not relevant to current user');
        return;
      }
      
      if (events.any((event) => event.contains('create'))) {
        AppLogger().debug('📱 REALTIME: Processing CREATE event');
        _handleNewChallenge(challenge);
      } else if (events.any((event) => event.contains('update'))) {
        AppLogger().debug('📱 Challenge update: ${challenge.status}');
        _handleChallengeUpdate(challenge);
      } else if (events.any((event) => event.contains('delete'))) {
        AppLogger().debug('📱 REALTIME: Processing DELETE event');
        _handleChallengeDeleted(challenge);
      }
      
    } catch (e) {
      AppLogger().error('Error handling realtime event: $e');
    }
  }
  
  /// Handle new incoming challenge or arena role invitation
  void _handleNewChallenge(ChallengeMessage challenge) {
    AppLogger().debug('📱 HANDLE NEW CHALLENGE: type=${challenge.messageType}, challengedId=${challenge.challengedId}, currentUserId=$_currentUserId');

    // First, check if the message is relevant to the current user.
    if (challenge.challengedId != _currentUserId) {
      AppLogger().debug('📱 HANDLE NEW CHALLENGE: Skipping, not for this user.');
      return;
    }

    // Add any new, relevant message to the main list for the inbox UI.
    // This includes pending challenges, arena roles, and our decline notifications.
    if ((challenge.isPending && !challenge.isExpired) || challenge.messageType == 'decline_notification') {
      if (!_pendingChallenges.any((c) => c.id == challenge.id)) {
        AppLogger().debug('📱 Adding new message to pending list: ${challenge.id}, type: ${challenge.messageType}');
        _pendingChallenges.insert(0, challenge);
        _pendingChallengesController.add(_pendingChallenges);
      }
    }

    // If it's a decline notification, also push it to the dedicated stream for ephemeral UI like sounds.
    if (challenge.messageType == 'decline_notification' && challenge.challengedId == _currentUserId) {
      _challengeDeclinedController.add(challenge);
    }

    // Second, decide if a modal should be shown. This should only happen for
    // actionable, pending invitations. Decline notifications should not trigger a modal.
    if (challenge.isPending && !challenge.isExpired) {
      if (challenge.isArenaRole) {
        AppLogger().debug('📱 🏛️ Incoming arena role invitation, emitting for modal display.');
        _arenaRoleInvitationsController.add(challenge);
      } else if (challenge.isChallenge) {
        AppLogger().debug('📱 🔔 Incoming regular challenge, emitting for modal display.');
        _incomingChallengesController.add(challenge);
      }
    } else {
      AppLogger().debug('📱 HANDLE NEW CHALLENGE: Skipping modal for non-pending or notification-type message.');
    }
  }
  
  /// Handle challenge status updates
  void _handleChallengeUpdate(ChallengeMessage challenge) {
    // If the current user is the one who sent the challenge, and it was declined,
    // notify them via a special stream.
    if (challenge.challengerId == _currentUserId && challenge.status == 'declined') {
      AppLogger().info('📱 Challenge declined by user ${challenge.challengedId}. Notifying challenger.');
      _challengeDeclinedController.add(challenge);
    }

    // Update in pending list
    final index = _pendingChallenges.indexWhere((c) => c.id == challenge.id);
    if (index != -1) {
      if (challenge.isPending && !challenge.isExpired) {
        _pendingChallenges[index] = challenge;
      } else {
        // Remove if no longer pending or expired
        _pendingChallenges.removeAt(index);
      }
      _pendingChallengesController.add(_pendingChallenges);
    }
    
    // Emit update event
    _challengeUpdatesController.add(challenge);
  }
  
  /// Handle challenge deletion
  void _handleChallengeDeleted(ChallengeMessage challenge) {
    _pendingChallenges.removeWhere((c) => c.id == challenge.id);
    _pendingChallengesController.add(_pendingChallenges);
  }
  
  /// Send a new challenge
  Future<ChallengeMessage> sendChallenge({
    required String challengedUserId,
    required String topic,
    String? description,
    required String position,
  }) async {
    if (_currentUserId == null) throw Exception('User not initialized');
    if (challengedUserId == _currentUserId) throw Exception('Cannot challenge yourself');
    
    try {
      AppLogger().debug('📱 Sending challenge to $challengedUserId: $topic');
      
      // Get current user profile for challenger info
      final currentUserProfile = await _appwrite.getCurrentUser();
      if (currentUserProfile == null) throw Exception('User not authenticated');
      
      final challengerProfile = await _appwrite.getUserProfile(_currentUserId!);
      
      // Create challenge message
      final challengeData = {
        'challengerId': _currentUserId!,
        'challengedId': challengedUserId,
        'challengerName': challengerProfile?.name ?? currentUserProfile.name,
        'challengerAvatar': challengerProfile?.avatar ?? '',
        'topic': topic.trim(),
        'description': description?.trim() ?? '',
        'position': position,
        'status': 'pending',
        'expiresAt': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'messageType': 'challenge',
        'priority': 3,
      };
      
      // Create document in Appwrite
      final response = await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'challenge_messages',
        documentId: ID.unique(),
        data: challengeData,
      );
      
      final challenge = ChallengeMessage.fromMap(response.data);
      AppLogger().debug('📱 ✅ Challenge sent successfully: ${challenge.id}');
      
      return challenge;
      
    } catch (e) {
      AppLogger().error('Error sending challenge: $e');
      rethrow;
    }
  }
  
  // Track processed challenges to prevent duplicates
  final Set<String> _processingChallenges = {};
  
  /// Respond to a challenge (accept/decline)
  Future<void> respondToChallenge(String challengeId, String response) async {
    if (_currentUserId == null) throw Exception('User not initialized');
    
    // Prevent duplicate processing
    if (_processingChallenges.contains(challengeId)) {
      AppLogger().debug('📱 ⚠️ Challenge $challengeId already being processed, skipping...');
      return;
    }
    
    _processingChallenges.add(challengeId);
    
    try {
      AppLogger().debug('📱 Responding to challenge $challengeId: $response');
      
      final updateData = {
        'status': response,
        'respondedAt': DateTime.now().toIso8601String(),
      };
      
      // If accepting, create arena room
      if (response == 'accepted') {
        final challenge = _pendingChallenges.firstWhere((c) => c.id == challengeId);
        final roomId = await _createArenaRoom(challenge);
        updateData['arenaRoomId'] = roomId;
      } else if (response == 'declined') {
        // Find the original challenge to get details
        final originalChallenge = _pendingChallenges.firstWhere((c) => c.id == challengeId, orElse: () => throw Exception('Original challenge not found'));
        await _sendDeclinedNotification(originalChallenge);
      }
      
      // Update challenge in database
      await _appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'challenge_messages',
        documentId: challengeId,
        data: updateData,
      );
      
      AppLogger().debug('📱 ✅ Challenge response recorded: $response');
      
    } catch (e) {
      AppLogger().error('Error responding to challenge: $e');
      rethrow;
    } finally {
      // Remove from processing set after delay to prevent rapid retries
      Future.delayed(const Duration(seconds: 2), () {
        _processingChallenges.remove(challengeId);
      });
    }
  }
  
  /// Sends a system message back to the challenger when a challenge is declined
  Future<void> _sendDeclinedNotification(ChallengeMessage originalChallenge) async {
    try {
      AppLogger().info('Sending declined notification for challenge: ${originalChallenge.id}');
      
      final currentUserProfile = await _appwrite.getUserProfile(_currentUserId!);
      final declinerName = currentUserProfile?.name ?? 'A user';

      final notificationMessage = {
        // Swap challenger and challenged so the notification goes to the original challenger
        'challengerId': originalChallenge.challengedId, // The one who declined
        'challengedId': originalChallenge.challengerId, // The one who sent the original challenge
        'challengerName': declinerName,
        'challengerAvatar': currentUserProfile?.avatar ?? '',
        'topic': originalChallenge.topic,
        'description': 'Declined your challenge.',
        'position': originalChallenge.position,
        'status': 'processed', // Not pending, can't be actioned
        'expiresAt': DateTime.now().add(const Duration(days: 90)).toIso8601String(), // Long expiry
        'messageType': 'decline_notification', // Special type for UI handling
        'priority': 1, // Low priority
      };

      await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'challenge_messages',
        documentId: ID.unique(),
        data: notificationMessage,
      );

      AppLogger().info('✅ Declined notification sent to ${originalChallenge.challengerId}');
    } catch (e) {
      AppLogger().error('❌ Error sending declined notification: $e');
      // Don't rethrow, failing to send this notification is not a critical error
    }
  }
  
  /// Dismiss a challenge (keep in list but don't show modal again)
  Future<void> dismissChallenge(String challengeId) async {
    try {
      AppLogger().debug('📱 Dismissing challenge: $challengeId');
      
      await _appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'challenge_messages',
        documentId: challengeId,
        data: {
          'dismissedAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().debug('📱 ✅ Challenge dismissed');
      
    } catch (e) {
      AppLogger().error('Error dismissing challenge: $e');
      rethrow;
    }
  }
  
  /// Respond to an arena role invitation (accept/decline)
  Future<void> respondToArenaRoleInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    if (_currentUserId == null) throw Exception('User not initialized');
    
    try {
      final response = accept ? 'accepted' : 'declined';
      AppLogger().debug('📱 🏛️ Responding to arena role invitation $invitationId: $response');
      
      // Update invitation status in database
      await _appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'challenge_messages',
        documentId: invitationId,
        data: {
          'status': response,
          'respondedAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().debug('📱 🏛️ ✅ Arena role invitation response recorded: $response');
      
    } catch (e) {
      AppLogger().error('Error responding to arena role invitation: $e');
      rethrow;
    }
  }
  
  /// Create arena room when challenge is accepted
  Future<String> _createArenaRoom(ChallengeMessage challenge) async {
    try {
      AppLogger().debug('📱 Creating arena room for accepted challenge: ${challenge.id}');
      AppLogger().debug('📱 Challenge details: challengerId=${challenge.challengerId}, challengedId=${challenge.challengedId}');
      
      final roomId = await _appwrite.createArenaRoom(
        challengeId: challenge.id,
        challengerId: challenge.challengerId,
        challengedId: challenge.challengedId,
        topic: challenge.topic,
        description: challenge.description,
      );
      
      AppLogger().debug('📱 ✅ Arena room created with ID: $roomId');
      
      // Assign roles based on challenger's position
      AppLogger().debug('📱 Assigning roles: challenger position = ${challenge.position}');
      if (challenge.position == 'affirmative') {
        AppLogger().info('Assigned affirmative to user ${challenge.challengerId} in room $roomId');
        await _appwrite.assignArenaRole(roomId: roomId, userId: challenge.challengerId, role: 'affirmative');
        AppLogger().info('Assigned negative to user ${challenge.challengedId} in room $roomId');
        await _appwrite.assignArenaRole(roomId: roomId, userId: challenge.challengedId, role: 'negative');
      } else {
        AppLogger().info('Assigned negative to user ${challenge.challengerId} in room $roomId');
        await _appwrite.assignArenaRole(roomId: roomId, userId: challenge.challengerId, role: 'negative');
        AppLogger().info('Assigned affirmative to user ${challenge.challengedId} in room $roomId');
        await _appwrite.assignArenaRole(roomId: roomId, userId: challenge.challengedId, role: 'affirmative');
      }
      
      AppLogger().debug('📱 Arena room setup complete - invitations will be sent by debaters after their selection process');
      
      AppLogger().debug('📱 ✅ Arena room created: $roomId');
      return roomId;
      
    } catch (e) {
      AppLogger().error('Error creating arena room: $e');
      AppLogger().error('Error details: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Clean up expired challenges
  Future<void> _cleanupExpiredChallenges() async {
    try {
      final expiredChallenges = _pendingChallenges.where((c) => c.isExpired).toList();
      
      for (final challenge in expiredChallenges) {
        await _appwrite.databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: 'challenge_messages',
          documentId: challenge.id,
          data: {'status': 'expired'},
        );
      }
      
      if (expiredChallenges.isNotEmpty) {
        AppLogger().debug('📱 Cleaned up ${expiredChallenges.length} expired challenges');
        await _loadPendingChallenges(); // Refresh list
      }
      
    } catch (e) {
      AppLogger().error('Error cleaning up expired challenges: $e');
    }
  }
  
  
  
  /// Send arena role invitation to a specific user
  Future<void> _sendArenaRoleInvitation({
    required String userId,
    required String userName,
    required String arenaRoomId,
    required String role,
    required String topic,
    String? description,
    String? category,
  }) async {
    try {
      AppLogger().debug('📨 Sending $role invitation to $userName for arena: $arenaRoomId');
      AppLogger().debug('📨 Target user ID: $userId');
      AppLogger().debug('📨 Current user ID (sender): $_currentUserId');
      
      // Create arena role invitation message
      final invitationData = {
        'challengerId': _currentUserId!, // The system/arena is "challenging" them to take a role
        'challengedId': userId,
        'challengerName': 'Arena System',
        'challengerAvatar': '',
        'topic': topic,
        'description': description ?? '',
        // 'category': category, // Temporarily commented out until database supports it
        'position': role, // Using position field to store the role
        'status': 'pending',
        'expiresAt': DateTime.now().toUtc().add(const Duration(hours: 2)).toIso8601String(), // 2 hours for arena roles
        'messageType': 'arena_role', // Different message type
        'priority': 5, // Higher priority than regular challenges
        'arenaRoomId': arenaRoomId, // Link to the arena
      };
      
      AppLogger().debug('Invitation data: challengerId=${invitationData['challengerId']}, challengedId=${invitationData['challengedId']}');
      
      // Create document in Appwrite
      await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'challenge_messages',
        documentId: ID.unique(),
        data: invitationData,
      );
      
      AppLogger().debug('📨 ✅ Arena role invitation sent to $userName');
      
    } catch (e) {
      AppLogger().error('Error sending arena role invitation to $userName: $e');
      // Don't rethrow - continue with other invitations
    }
  }

  /// Send personal arena role invitation from a specific debater
  Future<void> sendPersonalArenaRoleInvitation({
    required String userId,
    required String userName,
    required String arenaRoomId,
    required String role,
    required String topic,
    required String inviterName,
    String? description,
  }) async {
    try {
      AppLogger().debug('📨 👤 Sending PERSONAL $role invitation to $userName from $inviterName');
      AppLogger().debug('📨 Target user ID: $userId');
      AppLogger().debug('📨 Inviter ID: $_currentUserId');
      
      // Create personal arena role invitation message
      final invitationData = {
        'challengerId': _currentUserId!, // The debater is inviting them
        'challengedId': userId,
        'challengerName': inviterName,
        'challengerAvatar': '', // Could get from profile
        'topic': topic,
        'description': description ?? '',
        'position': role, // Using position field to store the role
        'status': 'pending',
        'expiresAt': DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(), // 1 hour for personal invites
        'messageType': 'arena_role', // Same type but with personal context
        'priority': 8, // Higher priority than system invites
        'arenaRoomId': arenaRoomId, // Link to the arena
      };
      
      AppLogger().debug('Personal invitation data: challengerId=${invitationData['challengerId']}, challengedId=${invitationData['challengedId']}');
      
      // Create document in Appwrite
      await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'challenge_messages',
        documentId: ID.unique(),
        data: invitationData,
      );
      
      AppLogger().info('👤 Personal arena role invitation sent to $userName from $inviterName');
      
    } catch (e) {
      AppLogger().error('Error sending personal arena role invitation to $userName: $e');
      rethrow; // Re-throw for personal invites so caller knows it failed
    }
  }

  /// Send individual arena role invitation (public method for moderator use)
  Future<void> sendArenaRoleInvitation({
    required String userId,
    required String userName,
    required String arenaRoomId,
    required String role,
    required String topic,
    String? description,
    String? category,
  }) async {
    return _sendArenaRoleInvitation(
      userId: userId,
      userName: userName,
      arenaRoomId: arenaRoomId,
      role: role,
      topic: topic,
      description: description,
      category: category,
    );
  }

  /// Mixed invitation system: Send personal invites first, then fill with random
  Future<void> sendMixedArenaInvitations({
    required String arenaRoomId,
    required String topic,
    required String challengerId,
    required String challengedId,
    required Map<String, String?> affirmativeSelections,
    required Map<String, String?> negativeSelections,
    String? description,
    String? category,
  }) async {
    try {
      AppLogger().debug('🎭 Starting mixed arena invitation system for room: $arenaRoomId');
      AppLogger().debug('🎭 Affirmative selections: $affirmativeSelections');
      AppLogger().debug('🎭 Negative selections: $negativeSelections');
      
      // Track which roles have been filled by personal invites
      final filledRoles = <String>{};
      
      // Send personal invites from affirmative debater
      for (final entry in affirmativeSelections.entries) {
        if (entry.value != null) {
          final roleId = entry.key;
          final userId = entry.value!;
          
          try {
            // Get user profile for invitation
            final userProfile = await _appwrite.getUserProfile(userId);
            if (userProfile != null) {
              final affirmativeProfile = await _appwrite.getUserProfile(challengerId);
              await sendPersonalArenaRoleInvitation(
                userId: userId,
                userName: userProfile.name,
                arenaRoomId: arenaRoomId,
                role: roleId,
                topic: topic,
                inviterName: affirmativeProfile?.name ?? 'Affirmative Debater',
                description: description,
              );
              filledRoles.add(roleId);
              AppLogger().info('👤 Personal invite sent for $roleId to ${userProfile.name}');
            } else {
              AppLogger().warning('User profile not found for $userId, skipping personal invite for $roleId');
            }
          } catch (e) {
            AppLogger().error('Failed to send personal invite for $roleId to $userId: $e');
            // Don't add to filledRoles if the invite failed
          }
          
          // Add delay to prevent rate limiting
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      
      // Send personal invites from negative debater (avoid duplicates)
      for (final entry in negativeSelections.entries) {
        if (entry.value != null && !filledRoles.contains(entry.key)) {
          final roleId = entry.key;
          final userId = entry.value!;
          
          try {
            // Get user profile for invitation
            final userProfile = await _appwrite.getUserProfile(userId);
            if (userProfile != null) {
              final negativeProfile = await _appwrite.getUserProfile(challengedId);
              await sendPersonalArenaRoleInvitation(
                userId: userId,
                userName: userProfile.name,
                arenaRoomId: arenaRoomId,
                role: roleId,
                topic: topic,
                inviterName: negativeProfile?.name ?? 'Negative Debater',
                description: description,
              );
              filledRoles.add(roleId);
              AppLogger().info('👤 Personal invite sent for $roleId to ${userProfile.name}');
            } else {
              AppLogger().warning('User profile not found for $userId, skipping personal invite for $roleId');
            }
          } catch (e) {
            AppLogger().error('Failed to send personal invite for $roleId to $userId: $e');
            // Don't add to filledRoles if the invite failed
          }
          
          // Add delay to prevent rate limiting
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      
      AppLogger().debug('🎭 Personal invites completed. Filled roles: $filledRoles');
      
      // Now fill remaining roles with random qualified users
      final unfilledRoles = ['moderator'] // Only moderator is selected by debaters
          .where((role) => !filledRoles.contains(role))
          .toList();
      
      if (unfilledRoles.isNotEmpty) {
        AppLogger().debug('🎭 Filling ${unfilledRoles.length} remaining roles with random invites: $unfilledRoles');
        
        // Get random qualified users for remaining roles
        final allUsers = await _appwrite.databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: 'users',
          queries: [
            Query.limit(50), // Get a good sample
            Query.notEqual('\$id', challengerId), // Exclude debaters
            Query.notEqual('\$id', challengedId),
          ],
        );
        
        // Shuffle and select users for unfilled roles
        final availableUsers = allUsers.documents.toList()..shuffle();
        
        for (int i = 0; i < unfilledRoles.length && i < availableUsers.length; i++) {
          final role = unfilledRoles[i];
          final user = availableUsers[i];
          
          try {
            await _sendArenaRoleInvitation(
              userId: user.$id,
              userName: user.data['name'] ?? 'User',
              arenaRoomId: arenaRoomId,
              role: role,
              topic: topic,
              description: description,
              category: category,
            );
            
            AppLogger().info('Random invite sent for $role to ${user.data['name']}');
          } catch (e) {
            AppLogger().error('Failed to send random invite for $role to ${user.data['name'] ?? user.$id}: $e');
            // Continue with next user rather than failing the whole process
          }
          
          // Add delay to prevent rate limiting
          await Future.delayed(const Duration(milliseconds: 200));
        }
        
        if (unfilledRoles.length > availableUsers.length) {
          AppLogger().warning('Warning: Not enough available users (${availableUsers.length}) for all unfilled roles (${unfilledRoles.length})');
        }
      }
      
      AppLogger().debug('🎭 ✅ Mixed invitation system completed for arena: $arenaRoomId');
      
    } catch (e) {
      AppLogger().error('Error in mixed arena invitation system: $e');
      rethrow;
    }
  }
  
  /// Manual refresh of pending challenges
  Future<void> refresh() async {
    AppLogger().debug('📱 Manual refresh requested');
    await _loadPendingChallenges();
  }
  
  /// Dispose the service
  void dispose() {
    AppLogger().debug('📱 Disposing ChallengeMessagingService');
    
    _realtimeSubscription?.close();
    _incomingChallengesController.close();
    _challengeUpdatesController.close();
    _challengeDeclinedController.close();
    _pendingChallengesController.close();
    _arenaRoleInvitationsController.close();
    
    _currentUserId = null;
    _pendingChallenges.clear();
    _processingChallenges.clear();
    _isInitialized = false;
  }
} 