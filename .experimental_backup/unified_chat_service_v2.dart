import 'dart:async';
import 'package:appwrite/appwrite.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';
import 'consolidated_audio_service.dart';

/// Unified chat service handling all messaging functionality
/// Consolidates: unified_chat_service, challenge_messaging_service,
/// instant_message_service, room_chat_service
class UnifiedChatServiceV2 {
  static final UnifiedChatServiceV2 _instance = UnifiedChatServiceV2._internal();
  factory UnifiedChatServiceV2() => _instance;
  UnifiedChatServiceV2._internal();

  final AppLogger _logger = AppLogger();
  final AppwriteService _appwriteService = AppwriteService();
  final ConsolidatedAudioService _audioService = ConsolidatedAudioService();

  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, StreamController<List<MessageModel>>> _messageControllers = {};
  final Map<String, List<MessageModel>> _messageCache = {};
  final Set<String> _processedMessageIds = {};

  bool _initialized = false;
  String? _currentUserId;

  /// Initialize the chat service
  Future<void> initialize(String userId) async {
    if (_initialized) return;

    try {
      _logger.info('💬 Initializing unified chat service');
      _currentUserId = userId;
      await _audioService.initialize();
      _initialized = true;
      _logger.info('✅ Chat service initialized');
    } catch (e) {
      _logger.error('Failed to initialize chat service: $e');
      rethrow;
    }
  }

  /// Send an instant message
  Future<MessageModel> sendInstantMessage({
    required String receiverId,
    required String content,
    String? conversationId,
  }) async {
    if (!_initialized) throw Exception('Chat service not initialized');

    try {
      final convId = conversationId ?? _generateConversationId(_currentUserId!, receiverId);

      final message = MessageModel(
        id: _generateMessageId(),
        senderId: _currentUserId!,
        receiverId: receiverId,
        content: content,
        conversationId: convId,
        messageType: MessageType.instant,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Save to Appwrite
      await _appwriteService.createDocument(
        databaseId: 'arena_db',
        collectionId: 'instant_messages',
        documentId: message.id,
        data: message.toJson(),
      );

      // Update local cache
      _addMessageToCache(convId, message);

      _logger.info('Sent instant message: ${message.id}');
      return message;
    } catch (e) {
      _logger.error('Failed to send instant message: $e');
      rethrow;
    }
  }

  /// Send a room chat message
  Future<MessageModel> sendRoomMessage({
    required String roomId,
    required String content,
    String? replyToId,
  }) async {
    if (!_initialized) throw Exception('Chat service not initialized');

    try {
      final message = MessageModel(
        id: _generateMessageId(),
        senderId: _currentUserId!,
        roomId: roomId,
        content: content,
        messageType: MessageType.room,
        timestamp: DateTime.now(),
        replyToId: replyToId,
      );

      // Save to Appwrite
      await _appwriteService.createDocument(
        databaseId: 'arena_db',
        collectionId: 'room_messages',
        documentId: message.id,
        data: message.toJson(),
      );

      // Update local cache
      _addMessageToCache(roomId, message);

      _logger.info('Sent room message: ${message.id}');
      return message;
    } catch (e) {
      _logger.error('Failed to send room message: $e');
      rethrow;
    }
  }

  /// Send a challenge message
  Future<MessageModel> sendChallengeMessage({
    required String challengeId,
    required String receiverId,
    required String content,
    required ChallengeMessageType challengeType,
  }) async {
    if (!_initialized) throw Exception('Chat service not initialized');

    try {
      final message = MessageModel(
        id: _generateMessageId(),
        senderId: _currentUserId!,
        receiverId: receiverId,
        content: content,
        challengeId: challengeId,
        messageType: MessageType.challenge,
        challengeMessageType: challengeType,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Save to Appwrite
      await _appwriteService.createDocument(
        databaseId: 'arena_db',
        collectionId: 'challenge_messages',
        documentId: message.id,
        data: message.toJson(),
      );

      // Update local cache
      _addMessageToCache(challengeId, message);

      _logger.info('Sent challenge message: ${message.id}');
      return message;
    } catch (e) {
      _logger.error('Failed to send challenge message: $e');
      rethrow;
    }
  }

  /// Get message stream for a conversation
  Stream<List<MessageModel>> getConversationStream(String conversationId) {
    if (!_messageControllers.containsKey(conversationId)) {
      _messageControllers[conversationId] = StreamController<List<MessageModel>>.broadcast();
      _subscribeToConversation(conversationId);
    }

    // Return cached messages immediately
    if (_messageCache.containsKey(conversationId)) {
      _messageControllers[conversationId]!.add(_messageCache[conversationId]!);
    }

    return _messageControllers[conversationId]!.stream;
  }

  /// Get room messages stream
  Stream<List<MessageModel>> getRoomMessagesStream(String roomId) {
    return getConversationStream('room_$roomId');
  }

  /// Get challenge messages stream
  Stream<List<MessageModel>> getChallengeMessagesStream(String challengeId) {
    return getConversationStream('challenge_$challengeId');
  }

  /// Subscribe to conversation updates
  Future<void> _subscribeToConversation(String conversationId) async {
    try {
      String collectionId;
      String filter;

      if (conversationId.startsWith('room_')) {
        collectionId = 'room_messages';
        filter = 'roomId="${conversationId.substring(5)}"';
      } else if (conversationId.startsWith('challenge_')) {
        collectionId = 'challenge_messages';
        filter = 'challengeId="${conversationId.substring(10)}"';
      } else {
        collectionId = 'instant_messages';
        filter = 'conversationId="$conversationId"';
      }

      // Subscribe to real-time updates
      final subscription = _appwriteService.subscribeToCollection(
        databaseId: 'arena_db',
        collectionId: collectionId,
        filter: filter,
        callback: (data) => _handleMessageUpdate(conversationId, data),
      );

      _subscriptions[conversationId] = subscription;

      // Load initial messages
      await _loadConversationHistory(conversationId);

      _logger.debug('Subscribed to conversation: $conversationId');
    } catch (e) {
      _logger.error('Failed to subscribe to conversation $conversationId: $e');
    }
  }

  /// Load conversation history
  Future<void> _loadConversationHistory(String conversationId) async {
    try {
      String collectionId;
      Map<String, dynamic> query;

      if (conversationId.startsWith('room_')) {
        collectionId = 'room_messages';
        query = {'roomId': conversationId.substring(5)};
      } else if (conversationId.startsWith('challenge_')) {
        collectionId = 'challenge_messages';
        query = {'challengeId': conversationId.substring(10)};
      } else {
        collectionId = 'instant_messages';
        query = {'conversationId': conversationId};
      }

      final messages = await _appwriteService.getDocuments(
        databaseId: 'arena_db',
        collectionId: collectionId,
        query: query,
        orderBy: 'timestamp',
        limit: 50,
      );

      final messageList = messages.map((doc) => MessageModel.fromJson(doc)).toList();
      _messageCache[conversationId] = messageList;

      // Notify stream
      _messageControllers[conversationId]?.add(messageList);

      _logger.debug('Loaded ${messageList.length} messages for $conversationId');
    } catch (e) {
      _logger.error('Failed to load conversation history: $e');
    }
  }

  /// Handle real-time message updates
  void _handleMessageUpdate(String conversationId, Map<String, dynamic> data) {
    try {
      final message = MessageModel.fromJson(data);

      // Prevent duplicate processing
      if (_processedMessageIds.contains(message.id)) return;
      _processedMessageIds.add(message.id);

      // Add to cache
      _addMessageToCache(conversationId, message);

      // Play sound for new messages
      if (message.senderId != _currentUserId) {
        _audioService.playMessageReceived();
      }

      _logger.debug('Processed message update: ${message.id}');
    } catch (e) {
      _logger.error('Failed to handle message update: $e');
    }
  }

  /// Add message to cache and notify stream
  void _addMessageToCache(String conversationId, MessageModel message) {
    if (!_messageCache.containsKey(conversationId)) {
      _messageCache[conversationId] = [];
    }

    final messages = _messageCache[conversationId]!;

    // Check for duplicates
    if (messages.any((m) => m.id == message.id)) return;

    // Insert in chronological order
    final insertIndex = messages.indexWhere((m) => m.timestamp.isAfter(message.timestamp));
    if (insertIndex == -1) {
      messages.add(message);
    } else {
      messages.insert(insertIndex, message);
    }

    // Notify stream
    _messageControllers[conversationId]?.add(List.from(messages));
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, List<String> messageIds) async {
    try {
      for (final messageId in messageIds) {
        await _appwriteService.updateDocument(
          databaseId: 'arena_db',
          collectionId: _getCollectionForConversation(conversationId),
          documentId: messageId,
          data: {'isRead': true},
        );
      }

      // Update cache
      final messages = _messageCache[conversationId];
      if (messages != null) {
        for (final message in messages) {
          if (messageIds.contains(message.id)) {
            final index = messages.indexOf(message);
            messages[index] = message.copyWith(isRead: true);
          }
        }
        _messageControllers[conversationId]?.add(List.from(messages));
      }

      _logger.debug('Marked ${messageIds.length} messages as read');
    } catch (e) {
      _logger.error('Failed to mark messages as read: $e');
    }
  }

  /// Get unread message count for a conversation
  int getUnreadCount(String conversationId) {
    final messages = _messageCache[conversationId];
    if (messages == null) return 0;

    return messages.where((m) => !m.isRead && m.senderId != _currentUserId).length;
  }

  /// Get total unread message count
  int getTotalUnreadCount() {
    int total = 0;
    for (final conversationId in _messageCache.keys) {
      total += getUnreadCount(conversationId);
    }
    return total;
  }

  /// Generate conversation ID for instant messages
  String _generateConversationId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return 'conv_${sortedIds.join('_')}';
  }

  /// Generate unique message ID
  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${_currentUserId}';
  }

  /// Get collection name for conversation
  String _getCollectionForConversation(String conversationId) {
    if (conversationId.startsWith('room_')) return 'room_messages';
    if (conversationId.startsWith('challenge_')) return 'challenge_messages';
    return 'instant_messages';
  }

  /// Clean up conversation resources
  Future<void> unsubscribeFromConversation(String conversationId) async {
    await _subscriptions[conversationId]?.cancel();
    _subscriptions.remove(conversationId);

    await _messageControllers[conversationId]?.close();
    _messageControllers.remove(conversationId);

    _messageCache.remove(conversationId);

    _logger.debug('Unsubscribed from conversation: $conversationId');
  }

  /// Dispose the service
  Future<void> dispose() async {
    try {
      // Cancel all subscriptions
      for (final subscription in _subscriptions.values) {
        await subscription.cancel();
      }
      _subscriptions.clear();

      // Close all controllers
      for (final controller in _messageControllers.values) {
        await controller.close();
      }
      _messageControllers.clear();

      // Clear caches
      _messageCache.clear();
      _processedMessageIds.clear();

      _initialized = false;
      _currentUserId = null;

      _logger.info('Chat service disposed');
    } catch (e) {
      _logger.error('Error disposing chat service: $e');
    }
  }

  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'initialized': _initialized,
      'activeSubscriptions': _subscriptions.length,
      'activeControllers': _messageControllers.length,
      'cachedConversations': _messageCache.length,
      'processedMessages': _processedMessageIds.length,
      'totalUnreadCount': getTotalUnreadCount(),
    };
  }
}

/// Message types
enum MessageType {
  instant,
  room,
  challenge,
}

/// Challenge message types
enum ChallengeMessageType {
  invitation,
  acceptance,
  rejection,
  notification,
}