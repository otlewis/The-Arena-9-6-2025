import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/instant_message.dart';
import '../models/user_profile.dart';
import '../services/appwrite_service.dart';
import '../constants/appwrite.dart';
import '../core/logging/app_logger.dart';

class InstantMessagingService {
  static final InstantMessagingService _instance = InstantMessagingService._internal();
  factory InstantMessagingService() => _instance;
  InstantMessagingService._internal();

  final AppwriteService _appwrite = AppwriteService();
  late Databases _databases;
  late Realtime _realtime;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Stream controllers for messages and conversations
  final Map<String, StreamController<List<InstantMessage>>> _messageStreamControllers = {};
  final StreamController<List<Conversation>> _conversationsStreamController = 
      StreamController<List<Conversation>>.broadcast();
  final StreamController<int> _unreadCountStreamController = 
      StreamController<int>.broadcast();
  
  // Cache for messages and conversations
  final Map<String, List<InstantMessage>> _messagesCache = {};
  final Map<String, Conversation> _conversationsCache = {};
  String? _currentUserId;
  
  // Subscriptions
  RealtimeSubscription? _messagesSubscription;
  RealtimeSubscription? _conversationsSubscription;

  Future<void> initialize() async {
    try {
      _databases = _appwrite.databases;
      _realtime = _appwrite.realtime;
      
      final currentUser = await _appwrite.getCurrentUser();
      _currentUserId = currentUser?.$id;
      
      if (_currentUserId != null) {
        await _subscribeToInstantMessages();
        await _loadConversations();
      }
      
      AppLogger().info('📱 Instant messaging service initialized');
    } catch (e) {
      AppLogger().error('📱 Failed to initialize instant messaging: $e');
      rethrow;
    }
  }

  /// Send an instant message to another user
  Future<InstantMessage> sendMessage({
    required String receiverId,
    required String content,
    required UserProfile sender,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final conversationId = InstantMessageAppwrite.generateConversationId(
        _currentUserId!,
        receiverId,
      );

      final message = InstantMessage(
        id: '', // Will be set by Appwrite
        senderId: _currentUserId!,
        receiverId: receiverId,
        content: content,
        timestamp: DateTime.now(),
        isRead: false,
        senderUsername: sender.name,
        senderAvatar: sender.avatar,
        conversationId: conversationId,
      );

      final document = await _databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages', // You'll need to create this collection
        documentId: ID.unique(),
        data: message.toAppwrite(),
      );

      AppLogger().info('📱 Sent instant message to $receiverId. Document ID: ${document.$id}');
      
      // Update conversation
      await _updateConversation(
        conversationId: conversationId,
        lastMessage: content,
        receiverId: receiverId,
      );
      
      return InstantMessageAppwrite.fromAppwrite(document.data, document.$id);
    } catch (e) {
      AppLogger().error('📱 Failed to send instant message: $e');
      rethrow;
    }
  }

  /// Get stream of messages for a conversation
  Stream<List<InstantMessage>> getMessagesStream(String conversationId) {
    final key = 'messages_$conversationId';
    
    if (_messageStreamControllers.containsKey(key)) {
      // Reload messages for new listeners
      _loadConversationMessages(conversationId);
      return _messageStreamControllers[key]!.stream;
    }

    final controller = StreamController<List<InstantMessage>>.broadcast(
      onListen: () => _loadConversationMessages(conversationId),
    );
    
    _messageStreamControllers[key] = controller;
    return controller.stream;
  }

  /// Get stream of all conversations for current user
  Stream<List<Conversation>> getConversationsStream() {
    return _conversationsStreamController.stream;
  }

  /// Get stream of total unread message count
  Stream<int> getUnreadCountStream() {
    return _unreadCountStreamController.stream;
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    if (_currentUserId == null) return;

    try {
      // Get unread messages in this conversation
      final response = await _databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.equal('conversationId', conversationId),
          Query.equal('receiverId', _currentUserId!),
          Query.equal('isRead', false),
        ],
      );

      // Update each message to mark as read
      for (final doc in response.documents) {
        await _databases.updateDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: 'instant_messages',
          documentId: doc.$id,
          data: {'isRead': true},
        );
      }

      AppLogger().info('📱 Marked ${response.documents.length} messages as read');
      
      // Update unread count
      await _updateUnreadCount();
    } catch (e) {
      AppLogger().error('📱 Failed to mark messages as read: $e');
    }
  }

  /// Search for users to start a conversation
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // Try search first (requires search index on 'name' field)
      final response = await _databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'users',
        queries: [
          Query.search('name', query),
          Query.limit(20),
        ],
      );

      AppLogger().info('📱 Search found ${response.documents.length} users for query: $query');

      final users = response.documents
          .map((doc) => UserProfile.fromMap(doc.data))
          .where((user) => user.id != _currentUserId) // Exclude current user
          .toList();
      
      if (users.isNotEmpty) return users;
    } catch (e) {
      AppLogger().error('📱 Search failed, trying fallback: $e');
    }
    
    // Fallback: Get all users and filter locally
    try {
      final fallbackResponse = await _databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'users',
        queries: [Query.limit(50)], // Get more users for better filtering
      );
      
      AppLogger().info('📱 Fallback: Retrieved ${fallbackResponse.documents.length} users');
      
      final filteredUsers = fallbackResponse.documents
          .map((doc) => UserProfile.fromMap(doc.data))
          .where((user) => 
              user.id != _currentUserId && 
              (user.name.toLowerCase().contains(query.toLowerCase()) ||
               user.email.toLowerCase().contains(query.toLowerCase())))
          .take(20)
          .toList();
      
      AppLogger().info('📱 Fallback: Filtered to ${filteredUsers.length} users');
      return filteredUsers;
    } catch (fallbackError) {
      AppLogger().error('📱 Fallback search also failed: $fallbackError');
      return [];
    }
  }

  /// Subscribe to instant messages
  Future<void> _subscribeToInstantMessages() async {
    if (_currentUserId == null) return;

    try {
      const channel = 'databases.${AppwriteConstants.databaseId}.collections.instant_messages.documents';
      
      _messagesSubscription = _realtime.subscribe([channel]);
      _messagesSubscription!.stream.listen((event) {
        if (event.events.contains('$channel.*.create') ||
            event.events.contains('$channel.*.update')) {
          _handleMessageEvent(event);
        }
      });

      AppLogger().info('📱 Subscribed to instant messages');
    } catch (e) {
      AppLogger().error('📱 Failed to subscribe to instant messages: $e');
    }
  }

  /// Handle realtime message events
  void _handleMessageEvent(RealtimeMessage event) {
    try {
      final message = InstantMessageAppwrite.fromAppwrite(
        event.payload,
        event.payload['\$id'] ?? '',
      );

      // Only process messages for current user
      if (message.senderId != _currentUserId && message.receiverId != _currentUserId) {
        return;
      }

      // Update appropriate message stream
      final conversationId = message.conversationId;
      if (conversationId != null) {
        final key = 'messages_$conversationId';
        if (_messagesCache.containsKey(conversationId)) {
          _messagesCache[conversationId]!.add(message);
          _messagesCache[conversationId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          
          if (_messageStreamControllers.containsKey(key)) {
            _messageStreamControllers[key]!.add(_messagesCache[conversationId]!);
          }
        }
      }

      // Update conversations list
      _loadConversations();
      
      // Update unread count if message is for current user and unread
      if (message.receiverId == _currentUserId && !message.isRead) {
        AppLogger().info('📱 🔔 Received new message from ${message.senderId}');
        _updateUnreadCount();
        // Play sound notification for received message
        _playMessageReceivedSound();
      } else {
        AppLogger().info('📱 Message event: receiverId=${message.receiverId}, currentUserId=$_currentUserId, isRead=${message.isRead}');
      }
    } catch (e) {
      AppLogger().error('📱 Failed to handle message event: $e');
    }
  }

  /// Load messages for a conversation
  Future<void> _loadConversationMessages(String conversationId) async {
    try {
      AppLogger().info('📱 Loading messages for conversation: $conversationId');
      
      final response = await _databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.equal('conversationId', conversationId),
          Query.orderAsc('timestamp'),
          Query.limit(100), // Load last 100 messages
        ],
      );

      AppLogger().info('📱 Found ${response.documents.length} messages for conversation $conversationId');

      final messages = response.documents
          .map((doc) => InstantMessageAppwrite.fromAppwrite(doc.data, doc.$id))
          .toList();

      _messagesCache[conversationId] = messages;
      
      final key = 'messages_$conversationId';
      if (_messageStreamControllers.containsKey(key)) {
        _messageStreamControllers[key]!.add(messages);
      }
    } catch (e) {
      AppLogger().error('📱 Failed to load conversation messages: $e');
    }
  }

  /// Load all conversations for current user
  Future<void> _loadConversations() async {
    if (_currentUserId == null) return;

    try {
      // Get all unique conversations where user is participant
      AppLogger().info('📱 Loading conversations for user: $_currentUserId');
      
      final sentMessages = await _databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.equal('senderId', _currentUserId!),
          Query.orderDesc('timestamp'),
          Query.limit(50),
        ],
      );

      final receivedMessages = await _databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.equal('receiverId', _currentUserId!),
          Query.orderDesc('timestamp'),
          Query.limit(50),
        ],
      );
      
      AppLogger().info('📱 Found ${sentMessages.documents.length} sent messages, ${receivedMessages.documents.length} received messages');

      // Combine and process messages to create conversations
      final allMessages = [
        ...sentMessages.documents.map((doc) => 
            InstantMessageAppwrite.fromAppwrite(doc.data, doc.$id)),
        ...receivedMessages.documents.map((doc) => 
            InstantMessageAppwrite.fromAppwrite(doc.data, doc.$id)),
      ];

      // Group by conversation ID
      final conversationGroups = <String, List<InstantMessage>>{};
      for (final message in allMessages) {
        final convId = message.conversationId ?? '';
        conversationGroups[convId] = (conversationGroups[convId] ?? [])..add(message);
      }

      // Create conversation objects
      final conversations = <Conversation>[];
      for (final entry in conversationGroups.entries) {
        if (entry.value.isEmpty) continue;
        
        // Sort messages by timestamp
        entry.value.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final latestMessage = entry.value.first;
        
        // Get other user ID
        final otherUserId = latestMessage.senderId == _currentUserId
            ? latestMessage.receiverId
            : latestMessage.senderId;
        
        // Get other user profile
        final otherUser = await _appwrite.getUserProfile(otherUserId);
        if (otherUser == null) continue;
        
        // Count unread messages
        final unreadCount = entry.value
            .where((msg) => msg.receiverId == _currentUserId && !msg.isRead)
            .length;
        
        conversations.add(Conversation(
          id: entry.key,
          participantIds: [_currentUserId!, otherUserId],
          lastMessageTime: latestMessage.timestamp,
          lastMessage: latestMessage.content,
          unreadCount: unreadCount,
          participants: {
            otherUserId: UserInfo(
              id: otherUserId,
              username: otherUser.name,
              avatar: otherUser.avatar,
            ),
          },
        ));
      }

      // Sort conversations by last message time
      conversations.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      
      // Update cache and stream
      _conversationsCache.clear();
      for (final conv in conversations) {
        _conversationsCache[conv.id] = conv;
      }
      
      _conversationsStreamController.add(conversations);
    } catch (e) {
      AppLogger().error('📱 Failed to load conversations: $e');
    }
  }

  /// Update conversation metadata
  Future<void> _updateConversation({
    required String conversationId,
    required String lastMessage,
    required String receiverId,
  }) async {
    // In a real implementation, you might have a separate conversations collection
    // For now, we'll just trigger a reload of conversations
    await _loadConversations();
  }

  /// Update total unread count
  Future<void> _updateUnreadCount() async {
    if (_currentUserId == null) return;

    try {
      final response = await _databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: 'instant_messages',
        queries: [
          Query.equal('receiverId', _currentUserId!),
          Query.equal('isRead', false),
        ],
      );

      _unreadCountStreamController.add(response.total);
    } catch (e) {
      AppLogger().error('📱 Failed to update unread count: $e');
    }
  }

  /// Play sound notification for received message
  Future<void> _playMessageReceivedSound() async {
    try {
      AppLogger().info('📱 🔊 Attempting to play instant message sound...');
      await _audioPlayer.play(AssetSource('audio/instantmessage.mp3'));
      AppLogger().info('📱 🔊 Successfully played instant message notification sound');
    } catch (e) {
      AppLogger().error('📱 Failed to play message sound: $e');
    }
  }

  void dispose() {
    _messagesSubscription?.close();
    _conversationsSubscription?.close();
    _conversationsStreamController.close();
    _unreadCountStreamController.close();
    _audioPlayer.dispose();
    
    for (final controller in _messageStreamControllers.values) {
      controller.close();
    }
    _messageStreamControllers.clear();
  }
}