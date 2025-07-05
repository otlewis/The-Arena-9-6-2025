import 'package:appwrite/appwrite.dart';
import '../services/appwrite_service.dart';
import '../models/message.dart';
import 'dart:async';
import '../core/logging/app_logger.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final AppwriteService _appwrite = AppwriteService();
  StreamSubscription? _messageSubscription;
  final StreamController<List<Message>> _messagesController = StreamController<List<Message>>.broadcast();
  
  Stream<List<Message>> get messagesStream => _messagesController.stream;
  
  /// Send a text message
  Future<bool> sendMessage({
    required String roomId,
    required String content,
    String? replyToMessageId,
    List<String> mentions = const [],
  }) async {
    try {
      final user = await _appwrite.getCurrentUser();
      if (user == null) return false;

      final userProfile = await _appwrite.getUserProfile(user.$id);
      
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        roomId: roomId,
        senderId: user.$id,
        senderName: userProfile?.displayName ?? user.name ?? 'User',
        senderAvatar: userProfile?.avatar,
        type: MessageType.text,
        content: content,
        timestamp: DateTime.now(),
        replyToMessageId: replyToMessageId,
        mentions: mentions,
      );

      // Save to Appwrite
      await _appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'messages',
        documentId: ID.unique(),
        data: message.toMap(),
      );

      AppLogger().debug('💬 Message sent: $content');
      return true;
    } catch (e) {
      AppLogger().error('Error sending message: $e');
      return false;
    }
  }

  /// Send a gift notification message
  Future<bool> sendGiftNotification({
    required String roomId,
    required String giftId,
    required String giftName,
    required String senderId,
    required String senderName,
    required String recipientId,
    required String recipientName,
    required int cost,
    String? message,
  }) async {
    try {
      final giftMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        type: MessageType.system,
        content: '🎁 $senderName sent a $giftName gift to $recipientName${message != null ? ' • "$message"' : ''}',
        timestamp: DateTime.now(),
        metadata: {
          'messageType': 'gift',
          'giftId': giftId,
          'giftName': giftName,
          'recipientId': recipientId,
          'recipientName': recipientName,
          'cost': cost,
          'giftMessage': message,
        },
      );

      // Save to Appwrite
      await _appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'messages',
        documentId: ID.unique(),
        data: giftMessage.toMap(),
      );

      AppLogger().debug('🎁 Gift notification sent: $giftName from $senderName to $recipientName');
      return true;
    } catch (e) {
      AppLogger().error('Error sending gift notification: $e');
      return false;
    }
  }

  /// Send a system message
  Future<bool> sendSystemMessage({
    required String roomId,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final systemMessage = Message.systemMessage(
        roomId: roomId,
        content: content,
        metadata: metadata,
      );

      // Save to Appwrite
      await _appwrite.databases.createDocument(
        databaseId: 'arena_db',
        collectionId: 'messages',
        documentId: ID.unique(),
        data: systemMessage.toMap(),
      );

      AppLogger().info('System message sent: $content');
      return true;
    } catch (e) {
      AppLogger().error('Error sending system message: $e');
      return false;
    }
  }

  /// Get messages for a room
  Future<List<Message>> getRoomMessages(String roomId, {int limit = 50}) async {
    try {
      final response = await _appwrite.databases.listDocuments(
        databaseId: 'arena_db',
        collectionId: 'messages',
        queries: [
          Query.equal('roomId', roomId),
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );

      final messages = response.documents.map((doc) {
        final data = doc.data;
        data['id'] = doc.$id;
        return Message.fromMap(data);
      }).toList();

      // Sort by timestamp (newest first for display)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return messages;
    } catch (e) {
      AppLogger().error('Error getting room messages: $e');
      return [];
    }
  }

  /// Subscribe to real-time messages for a room
  void subscribeToRoomMessages(String roomId) {
    try {
      _messageSubscription?.cancel();

      _messageSubscription = _appwrite.realtime.subscribe([
        'databases.arena_db.collections.messages.documents'
      ]).stream.listen((response) {
        AppLogger().debug('💬 Real-time message update: ${response.events}');
        
        if (response.events.any((event) => event.contains('create'))) {
          final messageData = response.payload;
          
          // Check if this message belongs to current room
          if (messageData['roomId'] == roomId) {
            messageData['id'] = messageData['\$id'];
            final newMessage = Message.fromMap(messageData);
            
            // Get current messages and add new one
            getRoomMessages(roomId).then((messages) {
              _messagesController.add(messages);
            });
          }
        }
      });

      AppLogger().debug('💬 Subscribed to messages for room: $roomId');
      
      // Load initial messages
      getRoomMessages(roomId).then((messages) {
        _messagesController.add(messages);
      });
    } catch (e) {
      AppLogger().error('Error subscribing to room messages: $e');
    }
  }

  /// Unsubscribe from messages
  void unsubscribe() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    AppLogger().debug('💬 Unsubscribed from messages');
  }

  /// Clear messages stream
  void clearMessages() {
    _messagesController.add([]);
  }

  /// Dispose service
  void dispose() {
    unsubscribe();
    _messagesController.close();
  }
} 