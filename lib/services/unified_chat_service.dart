import 'package:appwrite/appwrite.dart';
import 'dart:async';
import '../constants/appwrite.dart';
import '../models/discussion_chat_message.dart';
import '../models/instant_message.dart';
import '../models/user_profile.dart';
import 'appwrite_service.dart';
import 'challenge_messaging_service.dart';
import '../core/logging/app_logger.dart';

/// Unified chat service that handles both room chat and private DMs
/// Integrates with existing IM system while adding Mattermost-inspired features
class UnifiedChatService {
  static final UnifiedChatService _instance = UnifiedChatService._internal();
  factory UnifiedChatService() => _instance;
  UnifiedChatService._internal();

  final AppwriteService _appwrite = AppwriteService();
  final ChallengeMessagingService _challengeMessaging = ChallengeMessagingService();
  
  // Stream controllers for reactive UI
  final _roomMessagesController = StreamController<List<DiscussionChatMessage>>.broadcast();
  final _newRoomMessageController = StreamController<DiscussionChatMessage>.broadcast();
  final _dmMessagesController = StreamController<List<InstantMessage>>.broadcast();
  final _newDmMessageController = StreamController<InstantMessage>.broadcast();
  final _participantsController = StreamController<List<ChatParticipant>>.broadcast();
  final _typingUsersController = StreamController<List<String>>.broadcast();
  
  // Cache and state
  String? _currentUserId;
  String? _currentRoomId;
  String? _currentConversationId;
  List<DiscussionChatMessage> _roomMessages = [];
  List<InstantMessage> _dmMessages = [];
  List<ChatParticipant> _participants = [];
  RealtimeSubscription? _roomChatSubscription;
  RealtimeSubscription? _dmSubscription;
  final Map<String, UserProfile> _userProfileCache = {};
  bool _isInitialized = false;
  
  // Stream getters
  Stream<List<DiscussionChatMessage>> get roomMessages => _roomMessagesController.stream;
  Stream<DiscussionChatMessage> get newRoomMessage => _newRoomMessageController.stream;
  Stream<List<InstantMessage>> get dmMessages => _dmMessagesController.stream;
  Stream<InstantMessage> get newDmMessage => _newDmMessageController.stream;
  Stream<List<ChatParticipant>> get participants => _participantsController.stream;
  Stream<List<String>> get typingUsers => _typingUsersController.stream;
  
  // Getters for immediate access
  List<DiscussionChatMessage> get currentRoomMessages => List.unmodifiable(_roomMessages);
  List<InstantMessage> get currentDmMessages => List.unmodifiable(_dmMessages);
  List<ChatParticipant> get currentParticipants => List.unmodifiable(_participants);
  bool get isInitialized => _isInitialized;
  String? get currentRoomId => _currentRoomId;
  String? get currentConversationId => _currentConversationId;

  /// Initialize the unified chat service
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) {
      AppLogger().debug('🗨️ UnifiedChatService already initialized for user: $userId');
      return;
    }
    
    _currentUserId = userId;
    AppLogger().debug('🗨️ Initializing UnifiedChatService for user: $userId');
    
    // Initialize existing challenge messaging service
    await _challengeMessaging.initialize(userId);
    
    _isInitialized = true;
    AppLogger().debug('🗨️ ✅ UnifiedChatService initialized successfully');
  }

  /// Start room chat session (public discussion)
  Future<void> startRoomChat(String roomId) async {
    if (!_isInitialized || _currentUserId == null) {
      throw Exception('Chat service not initialized');
    }
    
    AppLogger().debug('🗨️ Starting room chat session for room: $roomId');
    
    // Clean up previous session
    await _cleanupSubscriptions();
    
    _currentRoomId = roomId;
    _currentConversationId = null; // Clear DM session
    
    // Load room messages and participants
    await _loadRoomMessages(roomId);
    await _loadRoomParticipants(roomId);
    
    // Start real-time subscriptions
    await _startRoomChatSubscription(roomId);
    
    AppLogger().debug('🗨️ ✅ Room chat session started');
  }

  /// Start direct message session (private chat)
  Future<void> startDirectMessage(String otherUserId) async {
    if (!_isInitialized || _currentUserId == null) {
      throw Exception('Chat service not initialized');
    }
    
    AppLogger().debug('🗨️ Starting DM session with user: $otherUserId');
    
    // Clean up previous session
    await _cleanupSubscriptions();
    
    _currentRoomId = null; // Clear room session
    _currentConversationId = InstantMessageAppwrite.generateConversationId(_currentUserId!, otherUserId);
    
    // Load DM messages
    await _loadDmMessages(otherUserId);
    
    // Start real-time subscriptions
    await _startDmSubscription();
    
    AppLogger().debug('🗨️ ✅ DM session started');
  }

  /// Send room message (public to all participants)
  Future<DiscussionChatMessage> sendRoomMessage({
    required String content,
    DiscussionMessageType type = DiscussionMessageType.text,
    String? replyToId,
    List<String>? mentions,
    List<String>? attachments,
  }) async {
    if (_currentRoomId == null || _currentUserId == null) {
      throw Exception('No active room chat session');
    }

    try {
      AppLogger().debug('🗨️ Sending room message to: $_currentRoomId');
      
      // Get current user profile
      final userProfile = await _getUserProfile(_currentUserId!);
      
      // Process reply information
      String? replyToContent;
      String? replyToSender;
      if (replyToId != null) {
        final replyMessage = _roomMessages.firstWhere(
          (msg) => msg.id == replyToId,
          orElse: () => throw Exception('Reply message not found'),
        );
        replyToContent = replyMessage.content.length > 100 
            ? '${replyMessage.content.substring(0, 100)}...'
            : replyMessage.content;
        replyToSender = replyMessage.senderName;
      }
      
      // Create message data - skip type field until we fix the enum issue
      final messageDoc = <String, dynamic>{
        'roomId': _currentRoomId!,
        'senderId': _currentUserId!,
        'senderName': userProfile?.name ?? 'Unknown User',
        'content': content.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      AppLogger().debug('🗨️ Sending message data: $messageDoc');
      
      // Add optional fields only if they exist and have values
      if (userProfile?.avatar != null) {
        messageDoc['senderAvatar'] = userProfile!.avatar!;
      }
      if (replyToId != null) {
        messageDoc['replyToId'] = replyToId;
        messageDoc['replyToContent'] = replyToContent;
        messageDoc['replyToSender'] = replyToSender;
      }
      
      // Save to Appwrite
      final response = await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'discussion_chat_messages',
        documentId: ID.unique(),
        data: messageDoc,
      );
      
      final savedMessage = DiscussionChatMessageAppwrite.fromAppwrite(response.data, response.$id);
      AppLogger().debug('🗨️ ✅ Room message sent: ${savedMessage.id}');
      
      return savedMessage;
      
    } catch (e) {
      AppLogger().error('Error sending room message: $e');
      rethrow;
    }
  }

  /// Send direct message (private to specific user)
  Future<InstantMessage> sendDirectMessage({
    required String receiverId,
    required String content,
  }) async {
    if (_currentUserId == null) {
      throw Exception('No active user session');
    }

    try {
      AppLogger().debug('🗨️ Sending DM to: $receiverId');
      
      // Get current user profile
      final userProfile = await _getUserProfile(_currentUserId!);
      
      // Create message data
      final messageData = InstantMessage(
        id: '', // Will be set by Appwrite
        senderId: _currentUserId!,
        receiverId: receiverId,
        content: content.trim(),
        timestamp: DateTime.now(),
        isRead: false,
        senderUsername: userProfile?.name,
        senderAvatar: userProfile?.avatar,
        conversationId: InstantMessageAppwrite.generateConversationId(_currentUserId!, receiverId),
      );
      
      // Save to Appwrite (using existing instant_messages collection)
      final response = await _appwrite.databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        documentId: ID.unique(),
        data: messageData.toAppwrite(),
      );
      
      final savedMessage = InstantMessageAppwrite.fromAppwrite(response.data, response.$id);
      AppLogger().debug('🗨️ ✅ DM sent: ${savedMessage.id}');
      
      return savedMessage;
      
    } catch (e) {
      AppLogger().error('Error sending DM: $e');
      rethrow;
    }
  }

  /// Add reaction to room message
  Future<void> addReaction(String messageId, String emoji) async {
    if (_currentRoomId == null || _currentUserId == null) {
      throw Exception('No active room chat session');
    }

    try {
      AppLogger().debug('🗨️ Adding reaction $emoji to message: $messageId');
      
      // Find the message
      final messageIndex = _roomMessages.indexWhere((msg) => msg.id == messageId);
      if (messageIndex == -1) {
        throw Exception('Message not found');
      }
      
      final message = _roomMessages[messageIndex];
      final reactions = Map<String, int>.from(message.reactions ?? {});
      
      // Toggle reaction (add or remove)
      if (reactions.containsKey(emoji)) {
        reactions[emoji] = reactions[emoji]! + 1;
      } else {
        reactions[emoji] = 1;
      }
      
      // Update in database
      await _appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'discussion_chat_messages',
        documentId: messageId,
        data: {'reactions': reactions},
      );
      
      AppLogger().debug('🗨️ ✅ Reaction added');
      
    } catch (e) {
      AppLogger().error('Error adding reaction: $e');
      rethrow;
    }
  }

  /// Edit room message
  Future<void> editMessage(String messageId, String newContent) async {
    if (_currentRoomId == null || _currentUserId == null) {
      throw Exception('No active room chat session');
    }

    try {
      AppLogger().debug('🗨️ Editing message: $messageId');
      
      // Verify user owns the message
      final message = _roomMessages.firstWhere(
        (msg) => msg.id == messageId,
        orElse: () => throw Exception('Message not found'),
      );
      
      if (message.senderId != _currentUserId) {
        throw Exception('Can only edit your own messages');
      }
      
      // Update in database
      await _appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'discussion_chat_messages',
        documentId: messageId,
        data: {
          'content': newContent.trim(),
          'isEdited': true,
          'editedAt': DateTime.now().toIso8601String(),
        },
      );
      
      AppLogger().debug('🗨️ ✅ Message edited');
      
    } catch (e) {
      AppLogger().error('Error editing message: $e');
      rethrow;
    }
  }

  /// Delete room message (soft delete)
  Future<void> deleteMessage(String messageId) async {
    if (_currentRoomId == null || _currentUserId == null) {
      throw Exception('No active room chat session');
    }

    try {
      AppLogger().debug('🗨️ Deleting message: $messageId');
      
      // Verify user owns the message or is moderator
      final message = _roomMessages.firstWhere(
        (msg) => msg.id == messageId,
        orElse: () => throw Exception('Message not found'),
      );
      
      final currentParticipant = _participants.firstWhere(
        (p) => p.userId == _currentUserId,
        orElse: () => throw Exception('User not found in participants'),
      );
      
      if (message.senderId != _currentUserId && currentParticipant.role != 'moderator') {
        throw Exception('Can only delete your own messages or be a moderator');
      }
      
      // Soft delete in database
      await _appwrite.databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'discussion_chat_messages',
        documentId: messageId,
        data: {
          'isDeleted': true,
          'deletedAt': DateTime.now().toIso8601String(),
          'content': '[Message deleted]',
        },
      );
      
      AppLogger().debug('🗨️ ✅ Message deleted');
      
    } catch (e) {
      AppLogger().error('Error deleting message: $e');
      rethrow;
    }
  }

  /// Load room messages from database
  Future<void> _loadRoomMessages(String roomId) async {
    try {
      AppLogger().debug('🗨️ Loading room messages for: $roomId');
      
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'discussion_chat_messages',
        queries: [
          Query.equal('roomId', roomId),
          Query.orderDesc('\$createdAt'),
          Query.limit(100), // Load last 100 messages
        ],
      );
      
      _roomMessages = response.documents
          .map((doc) => DiscussionChatMessageAppwrite.fromAppwrite(doc.data, doc.$id))
          .toList()
          .reversed // Show oldest first
          .toList();
      
      AppLogger().debug('🗨️ Loaded ${_roomMessages.length} room messages');
      _roomMessagesController.add(_roomMessages);
      
    } catch (e) {
      AppLogger().error('Error loading room messages: $e');
      _roomMessages = [];
      _roomMessagesController.add(_roomMessages);
    }
  }

  /// Load DM messages from database
  Future<void> _loadDmMessages(String otherUserId) async {
    try {
      AppLogger().debug('🗨️ Loading DM messages with: $otherUserId');
      
      final conversationId = InstantMessageAppwrite.generateConversationId(_currentUserId!, otherUserId);
      
      final response = await _appwrite.databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.equal('conversationId', conversationId),
          Query.orderDesc('\$createdAt'),
          Query.limit(100), // Load last 100 messages
        ],
      );
      
      _dmMessages = response.documents
          .map((doc) => InstantMessageAppwrite.fromAppwrite(doc.data, doc.$id))
          .toList()
          .reversed // Show oldest first
          .toList();
      
      AppLogger().debug('🗨️ Loaded ${_dmMessages.length} DM messages');
      _dmMessagesController.add(_dmMessages);
      
    } catch (e) {
      AppLogger().error('Error loading DM messages: $e');
      _dmMessages = [];
      _dmMessagesController.add(_dmMessages);
    }
  }

  /// Load room participants
  Future<void> _loadRoomParticipants(String roomId) async {
    try {
      AppLogger().debug('🗨️ Loading room participants for: $roomId');
      
      // Get room data with participants (reusing existing Open Discussion logic)
      final roomData = await _appwrite.getRoom(roomId);
      if (roomData == null) {
        throw Exception('Room not found');
      }
      
      final participants = roomData['participants'] as List<dynamic>? ?? [];
      _participants.clear();
      
      for (final participantData in participants) {
        final userId = participantData['userId'];
        final role = participantData['role'];
        
        // Get user profile
        final userProfile = await _getUserProfile(userId);
        
        _participants.add(ChatParticipant(
          userId: userId,
          username: userProfile?.name ?? 'Unknown User',
          role: role,
          avatar: userProfile?.avatar,
          isOnline: true, // Could be enhanced with presence detection
          joinedAt: DateTime.now(), // Could be tracked
        ));
      }
      
      AppLogger().debug('🗨️ Loaded ${_participants.length} participants');
      _participantsController.add(_participants);
      
    } catch (e) {
      AppLogger().error('Error loading room participants: $e');
      _participants = [];
      _participantsController.add(_participants);
    }
  }

  /// Start real-time subscription for room chat
  Future<void> _startRoomChatSubscription(String roomId) async {
    try {
      AppLogger().debug('🗨️ Starting room chat subscription for: $roomId');
      
      final realtime = Realtime(_appwrite.client);
      
      _roomChatSubscription = realtime.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.discussion_chat_messages.documents'
      ]);
      
      _roomChatSubscription!.stream.listen(
        (response) => _handleRoomChatRealtimeEvent(response),
        onError: (error) => AppLogger().error('Room chat subscription error: $error'),
      );
      
      AppLogger().debug('🗨️ ✅ Room chat subscription active');
      
    } catch (e) {
      AppLogger().error('Error starting room chat subscription: $e');
    }
  }

  /// Start real-time subscription for DMs
  Future<void> _startDmSubscription() async {
    try {
      AppLogger().debug('🗨️ Starting DM subscription');
      
      final realtime = Realtime(_appwrite.client);
      
      _dmSubscription = realtime.subscribe([
        'databases.${AppwriteConstants.databaseId}.collections.instant_messages.documents'
      ]);
      
      _dmSubscription!.stream.listen(
        (response) => _handleDmRealtimeEvent(response),
        onError: (error) => AppLogger().error('DM subscription error: $error'),
      );
      
      AppLogger().debug('🗨️ ✅ DM subscription active');
      
    } catch (e) {
      AppLogger().error('Error starting DM subscription: $e');
    }
  }

  /// Handle real-time events for room chat
  void _handleRoomChatRealtimeEvent(RealtimeMessage response) {
    try {
      final events = response.events;
      final payload = response.payload;
      
      if (payload.isEmpty) return;
      
      final messageData = Map<String, dynamic>.from(payload);
      final message = DiscussionChatMessageAppwrite.fromAppwrite(messageData, messageData['\$id'] ?? '');
      
      // Only process messages for current room
      if (message.roomId != _currentRoomId) return;
      
      if (events.any((event) => event.contains('create'))) {
        _handleNewRoomMessage(message);
      } else if (events.any((event) => event.contains('update'))) {
        _handleRoomMessageUpdate(message);
      } else if (events.any((event) => event.contains('delete'))) {
        _handleRoomMessageDelete(message);
      }
      
    } catch (e) {
      AppLogger().error('Error handling room chat realtime event: $e');
    }
  }

  /// Handle real-time events for DMs
  void _handleDmRealtimeEvent(RealtimeMessage response) {
    try {
      final events = response.events;
      final payload = response.payload;
      
      if (payload.isEmpty) return;
      
      final messageData = Map<String, dynamic>.from(payload);
      final message = InstantMessageAppwrite.fromAppwrite(messageData, messageData['\$id'] ?? '');
      
      // Only process messages for current conversation
      if (message.conversationId != _currentConversationId) return;
      
      if (events.any((event) => event.contains('create'))) {
        _handleNewDmMessage(message);
      }
      
    } catch (e) {
      AppLogger().error('Error handling DM realtime event: $e');
    }
  }

  /// Handle new room message
  void _handleNewRoomMessage(DiscussionChatMessage message) {
    // Avoid duplicates
    if (_roomMessages.any((m) => m.id == message.id)) return;
    
    _roomMessages.add(message);
    _roomMessagesController.add(_roomMessages);
    _newRoomMessageController.add(message);
    
    AppLogger().debug('🗨️ New room message received: ${message.id}');
  }

  /// Handle room message update
  void _handleRoomMessageUpdate(DiscussionChatMessage message) {
    final index = _roomMessages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      _roomMessages[index] = message;
      _roomMessagesController.add(_roomMessages);
    }
    
    AppLogger().debug('🗨️ Room message updated: ${message.id}');
  }

  /// Handle room message delete
  void _handleRoomMessageDelete(DiscussionChatMessage message) {
    _roomMessages.removeWhere((m) => m.id == message.id);
    _roomMessagesController.add(_roomMessages);
    
    AppLogger().debug('🗨️ Room message deleted: ${message.id}');
  }

  /// Handle new DM message
  void _handleNewDmMessage(InstantMessage message) {
    // Avoid duplicates
    if (_dmMessages.any((m) => m.id == message.id)) return;
    
    _dmMessages.add(message);
    _dmMessagesController.add(_dmMessages);
    _newDmMessageController.add(message);
    
    AppLogger().debug('🗨️ New DM received: ${message.id}');
  }

  /// Get user profile with caching
  Future<UserProfile?> _getUserProfile(String userId) async {
    if (_userProfileCache.containsKey(userId)) {
      return _userProfileCache[userId];
    }
    
    try {
      final profile = await _appwrite.getUserProfile(userId);
      if (profile != null) {
        _userProfileCache[userId] = profile;
      }
      return profile;
    } catch (e) {
      AppLogger().error('Error loading user profile for $userId: $e');
      return null;
    }
  }

  /// Clean up subscriptions
  Future<void> _cleanupSubscriptions() async {
    _roomChatSubscription?.close();
    _dmSubscription?.close();
    _roomChatSubscription = null;
    _dmSubscription = null;
  }

  /// Stop current chat session
  Future<void> stopSession() async {
    AppLogger().debug('🗨️ Stopping chat session');
    
    await _cleanupSubscriptions();
    
    _currentRoomId = null;
    _currentConversationId = null;
    _roomMessages.clear();
    _dmMessages.clear();
    _participants.clear();
    
    // Notify listeners of empty state
    _roomMessagesController.add(_roomMessages);
    _dmMessagesController.add(_dmMessages);
    _participantsController.add(_participants);
  }

  /// Dispose the service
  void dispose() {
    AppLogger().debug('🗨️ Disposing UnifiedChatService');
    
    _cleanupSubscriptions();
    
    _roomMessagesController.close();
    _newRoomMessageController.close();
    _dmMessagesController.close();
    _newDmMessageController.close();
    _participantsController.close();
    _typingUsersController.close();
    
    _roomMessages.clear();
    _dmMessages.clear();
    _participants.clear();
    _userProfileCache.clear();
    
    _currentUserId = null;
    _currentRoomId = null;
    _currentConversationId = null;
    _isInitialized = false;
  }
}