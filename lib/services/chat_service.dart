import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:appwrite/appwrite.dart';
import '../models/chat_message.dart';
import '../models/user_profile.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Real-time chat service for Arena rooms
/// 
/// Provides messaging functionality across Arena, Debates & Discussions, 
/// and Open Discussion rooms with real-time updates and user presence.
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final AppwriteService _appwriteService = AppwriteService();
  final Map<String, RealtimeSubscription> _activeSubscriptions = {};
  final Map<String, StreamController<List<ChatMessage>>> _messageStreamControllers = {};
  final Map<String, StreamController<List<ChatUserPresence>>> _presenceStreamControllers = {};
  
  static const String _messagesCollectionId = 'chat_messages';
  static const String _presenceCollectionId = 'chat_presence';
  static const int _messageHistoryLimit = 100;
  static const int _maxMessageLength = 500;
  static const Duration _rateLimitDuration = Duration(seconds: 2);
  
  bool _isInitialized = false;
  DateTime? _lastMessageSent;

  /// Initialize the chat service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      AppLogger().info('💬 ChatService: Initializing...');
      _isInitialized = true;
      AppLogger().info('💬 ChatService: Initialized successfully');
    } catch (e) {
      AppLogger().error('💬 ChatService: Initialization failed: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Send a message to a chat room
  Future<String> sendMessage({
    required String content,
    required String chatRoomId,
    required ChatRoomType roomType,
    required UserProfile user,
    String? userRole,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    await _ensureInitialized();
    
    // Rate limiting
    if (_lastMessageSent != null && 
        DateTime.now().difference(_lastMessageSent!) < _rateLimitDuration) {
      throw Exception('Please wait before sending another message');
    }
    
    // Content validation
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw Exception('Message cannot be empty');
    }
    
    if (trimmedContent.length > _maxMessageLength) {
      throw Exception('Message too long (max $_maxMessageLength characters)');
    }
    
    try {
      AppLogger().debug('💬 Sending message to room: $chatRoomId');
      
      final message = ChatMessage(
        id: '', // Will be set by Appwrite
        content: trimmedContent,
        username: user.name,
        userId: user.id,
        chatRoomId: chatRoomId,
        roomType: roomType.value,
        timestamp: DateTime.now(),
        userAvatar: user.avatar,
        userRole: userRole,
        messageType: messageType,
        metadata: metadata,
      );

      final response = await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: _messagesCollectionId,
        documentId: ID.unique(),
        data: message.toAppwrite(),
      );

      _lastMessageSent = DateTime.now();
      
      final messageId = response.data['\$id'] as String;
      AppLogger().info('💬 Message sent successfully: $messageId');
      
      // Update user presence
      await _updateUserPresence(
        userId: user.id,
        username: user.name,
        chatRoomId: chatRoomId,
        userAvatar: user.avatar,
        userRole: userRole,
      );
      
      return messageId;
    } catch (e) {
      AppLogger().error('💬 Error sending message: $e');
      rethrow;
    }
  }

  /// Send a system message (moderator notifications, etc.)
  Future<String> sendSystemMessage({
    required String content,
    required String chatRoomId,
    required ChatRoomType roomType,
    required String systemUserId,
    String systemUsername = 'System',
    Map<String, dynamic>? metadata,
  }) async {
    await _ensureInitialized();
    
    try {
      final message = ChatMessage(
        id: '',
        content: content,
        username: systemUsername,
        userId: systemUserId,
        chatRoomId: chatRoomId,
        roomType: roomType.value,
        timestamp: DateTime.now(),
        isSystemMessage: true,
        messageType: 'system_notification',
        userRole: 'system',
        metadata: metadata,
      );

      final response = await _appwriteService.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: _messagesCollectionId,
        documentId: ID.unique(),
        data: message.toAppwrite(),
      );

      return response.data['\$id'] as String;
    } catch (e) {
      AppLogger().error('💬 Error sending system message: $e');
      rethrow;
    }
  }

  /// Get a stream of messages for a chat room
  Stream<List<ChatMessage>> getMessagesStream(String chatRoomId) {
    final key = 'messages_$chatRoomId';
    
    if (_messageStreamControllers.containsKey(key)) {
      // For existing streams, reload messages to ensure new listeners get current state
      AppLogger().debug('💬 Reloading existing messages for room: $chatRoomId');
      _loadRoomMessages(chatRoomId, _messageStreamControllers[key]!);
      return _messageStreamControllers[key]!.stream;
    }

    final controller = StreamController<List<ChatMessage>>.broadcast();
    _messageStreamControllers[key] = controller;

    _subscribeToMessages(chatRoomId, controller);
    
    return controller.stream;
  }

  /// Get a stream of user presence for a chat room
  Stream<List<ChatUserPresence>> getPresenceStream(String chatRoomId) {
    final key = 'presence_$chatRoomId';
    
    if (_presenceStreamControllers.containsKey(key)) {
      // For existing streams, reload presence to ensure new listeners get current state
      _loadRoomPresence(chatRoomId, _presenceStreamControllers[key]!);
      return _presenceStreamControllers[key]!.stream;
    }

    final controller = StreamController<List<ChatUserPresence>>.broadcast();
    _presenceStreamControllers[key] = controller;

    _subscribeToPresence(chatRoomId, controller);
    
    return controller.stream;
  }

  /// Subscribe to real-time message updates
  void _subscribeToMessages(String chatRoomId, StreamController<List<ChatMessage>> controller) {
    const channel = 'databases.arena_db.collections.chat_messages.documents';
    
    try {
      final subscription = _appwriteService.realtime.subscribe([channel]);
      
      subscription.stream.listen((response) {
        try {
          // Load all messages for the room when any message changes
          _loadRoomMessages(chatRoomId, controller);
        } catch (e) {
          AppLogger().error('💬 Error processing message update: $e');
          controller.addError(e);
        }
      }, onError: (error) {
        AppLogger().error('💬 Message subscription error: $error');
        controller.addError(error);
      });

      _activeSubscriptions['messages_$chatRoomId'] = subscription;
      
      // Load initial messages
      _loadRoomMessages(chatRoomId, controller);
      
    } catch (e) {
      AppLogger().error('💬 Failed to subscribe to messages for room $chatRoomId: $e');
      controller.addError(e);
    }
  }

  /// Subscribe to real-time presence updates
  void _subscribeToPresence(String chatRoomId, StreamController<List<ChatUserPresence>> controller) {
    const channel = 'databases.arena_db.collections.chat_presence.documents';
    
    try {
      final subscription = _appwriteService.realtime.subscribe([channel]);
      
      subscription.stream.listen((response) {
        try {
          _loadRoomPresence(chatRoomId, controller);
        } catch (e) {
          AppLogger().error('💬 Error processing presence update: $e');
          controller.addError(e);
        }
      }, onError: (error) {
        AppLogger().error('💬 Presence subscription error: $error');
        controller.addError(error);
      });

      _activeSubscriptions['presence_$chatRoomId'] = subscription;
      
      // Load initial presence
      _loadRoomPresence(chatRoomId, controller);
      
    } catch (e) {
      AppLogger().error('💬 Failed to subscribe to presence for room $chatRoomId: $e');
      controller.addError(e);
    }
  }

  /// Load messages for a room
  Future<void> _loadRoomMessages(String chatRoomId, StreamController<List<ChatMessage>> controller) async {
    try {
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: _messagesCollectionId,
        queries: [
          Query.equal('chatRoomId', chatRoomId),
          Query.orderDesc('\$createdAt'),
          Query.limit(_messageHistoryLimit),
        ],
      );
      
      final messages = response.documents
          .map((doc) => ChatMessage.fromAppwrite(doc.data))
          .toList()
          .reversed // Reverse to show oldest first
          .toList();
      
      AppLogger().debug('💬 Loaded ${messages.length} messages for room: $chatRoomId');
      controller.add(messages);
    } catch (e) {
      AppLogger().error('💬 Failed to load room messages: $e');
      controller.addError(e);
    }
  }

  /// Load presence for a room
  Future<void> _loadRoomPresence(String chatRoomId, StreamController<List<ChatUserPresence>> controller) async {
    try {
      final response = await _appwriteService.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: _presenceCollectionId,
        queries: [
          Query.equal('chatRoomId', chatRoomId),
          Query.equal('isOnline', true),
          Query.orderDesc('lastSeen'),
          Query.limit(50),
        ],
      );
      
      final presence = response.documents
          .map((doc) => ChatUserPresence.fromAppwrite(doc.data))
          .toList();
      
      controller.add(presence);
    } catch (e) {
      AppLogger().error('💬 Failed to load room presence: $e');
      controller.addError(e);
    }
  }

  /// Update user presence in a chat room
  Future<void> _updateUserPresence({
    required String userId,
    required String username,
    required String chatRoomId,
    String? userAvatar,
    String? userRole,
  }) async {
    try {
      final presence = ChatUserPresence(
        userId: userId,
        username: username,
        chatRoomId: chatRoomId,
        lastSeen: DateTime.now(),
        userAvatar: userAvatar,
        userRole: userRole,
        isOnline: true,
      );

      // Try to update existing presence, create if doesn't exist
      try {
        await _appwriteService.databases.updateDocument(
          databaseId: 'arena_db',
          collectionId: _presenceCollectionId,
          documentId: _generatePresenceDocumentId(userId, chatRoomId),
          data: presence.toAppwrite(),
        );
      } catch (e) {
        // If update fails, create new document
        await _appwriteService.databases.createDocument(
          databaseId: 'arena_db',
          collectionId: _presenceCollectionId,
          documentId: _generatePresenceDocumentId(userId, chatRoomId),
          data: presence.toAppwrite(),
        );
      }
    } catch (e) {
      AppLogger().error('💬 Failed to update user presence: $e');
      // Don't rethrow - presence updates shouldn't break messaging
    }
  }

  /// Join a chat room (update presence)
  Future<void> joinChatRoom({
    required String chatRoomId,
    required UserProfile user,
    String? userRole,
  }) async {
    await _ensureInitialized();
    
    try {
      await _updateUserPresence(
        userId: user.id,
        username: user.name,
        chatRoomId: chatRoomId,
        userAvatar: user.avatar,
        userRole: userRole,
      );
      
      AppLogger().info('💬 User ${user.name} joined chat room: $chatRoomId');
    } catch (e) {
      AppLogger().error('💬 Failed to join chat room: $e');
      rethrow;
    }
  }

  /// Leave a chat room (update presence)
  Future<void> leaveChatRoom({
    required String chatRoomId,
    required String userId,
  }) async {
    try {
      await _appwriteService.databases.updateDocument(
        databaseId: 'arena_db',
        collectionId: _presenceCollectionId,
        documentId: _generatePresenceDocumentId(userId, chatRoomId),
        data: {'isOnline': false, 'lastSeen': DateTime.now().toIso8601String()},
      );
      
      AppLogger().info('💬 User left chat room: $chatRoomId');
    } catch (e) {
      AppLogger().error('💬 Failed to leave chat room: $e');
      // Don't rethrow - this shouldn't break the app
    }
  }

  /// Generate a valid Appwrite document ID for presence records
  String _generatePresenceDocumentId(String userId, String chatRoomId) {
    // Create a hash of userId + chatRoomId to ensure uniqueness
    final combined = '$userId:$chatRoomId';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    
    // Take first 32 characters of hash and add 'p' prefix for "presence"
    // This ensures we stay under 36 char limit and don't start with underscore
    return 'p${digest.toString().substring(0, 31)}';
  }

  /// Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Dispose all subscriptions and streams
  void dispose() {
    AppLogger().info('💬 ChatService: Disposing...');
    
    for (final subscription in _activeSubscriptions.values) {
      subscription.close();
    }
    _activeSubscriptions.clear();

    for (final controller in _messageStreamControllers.values) {
      controller.close();
    }
    _messageStreamControllers.clear();

    for (final controller in _presenceStreamControllers.values) {
      controller.close();
    }
    _presenceStreamControllers.clear();
  }
} 