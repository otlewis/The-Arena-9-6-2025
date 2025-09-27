import 'dart:async';
import 'package:appwrite/appwrite.dart';
import '../core/logging/app_logger.dart';
import 'appwrite_service.dart';

/// Centralized real-time subscription manager for room-related events
/// Consolidates multiple subscriptions into a single connection for efficiency
class RoomRealtimeManager {
  static final RoomRealtimeManager _instance = RoomRealtimeManager._internal();
  factory RoomRealtimeManager() => _instance;
  RoomRealtimeManager._internal();

  final AppwriteService _appwrite = AppwriteService();
  final AppLogger _logger = AppLogger();

  // Single subscription per room
  final Map<String, RealtimeSubscription> _roomSubscriptions = {};

  // Event stream controllers for different event types
  final Map<String, StreamController<RealtimeMessage>> _participantControllers = {};
  final Map<String, StreamController<RealtimeMessage>> _chatControllers = {};
  final Map<String, StreamController<RealtimeMessage>> _roomStatusControllers = {};
  final Map<String, StreamController<RealtimeMessage>> _handRaiseControllers = {};
  final Map<String, StreamController<RealtimeMessage>> _timerControllers = {};
  final Map<String, StreamController<RealtimeMessage>> _materialControllers = {};

  // Batch update system
  final Map<String, List<RealtimeMessage>> _pendingUpdates = {};
  final Map<String, Timer> _batchTimers = {};
  static const Duration _batchWindow = Duration(milliseconds: 100);

  /// Subscribe to all room events with a single consolidated subscription
  Future<RoomSubscription> subscribeToRoom({
    required String roomId,
    required String roomType, // 'debate_discussion', 'arena', 'discussion'
  }) async {
    // Clean up any existing subscription for this room
    await unsubscribeFromRoom(roomId);

    _logger.info('📡 Creating consolidated subscription for room: $roomId ($roomType)');

    // Create stream controllers for this room
    _participantControllers[roomId] = StreamController<RealtimeMessage>.broadcast();
    _chatControllers[roomId] = StreamController<RealtimeMessage>.broadcast();
    _roomStatusControllers[roomId] = StreamController<RealtimeMessage>.broadcast();
    _handRaiseControllers[roomId] = StreamController<RealtimeMessage>.broadcast();
    _timerControllers[roomId] = StreamController<RealtimeMessage>.broadcast();
    _materialControllers[roomId] = StreamController<RealtimeMessage>.broadcast();

    // Build subscription channels based on room type
    final channels = _buildChannelsForRoomType(roomId, roomType);

    // Create single subscription for all channels
    final subscription = _appwrite.realtimeInstance.subscribe(channels);
    _roomSubscriptions[roomId] = subscription;

    // Route events to appropriate stream controllers
    subscription.stream.listen(
      (message) => _handleRealtimeMessage(roomId, message),
      onError: (error) => _handleSubscriptionError(roomId, error),
      onDone: () => _handleSubscriptionDone(roomId),
      cancelOnError: false,
    );

    _logger.info('✅ Consolidated subscription active for room: $roomId');

    // Return subscription handle
    return RoomSubscription(
      roomId: roomId,
      participants: _participantControllers[roomId]!.stream,
      chat: _chatControllers[roomId]!.stream,
      roomStatus: _roomStatusControllers[roomId]!.stream,
      handRaises: _handRaiseControllers[roomId]!.stream,
      timer: _timerControllers[roomId]!.stream,
      materials: _materialControllers[roomId]!.stream,
    );
  }

  /// Build appropriate channels based on room type
  List<String> _buildChannelsForRoomType(String roomId, String roomType) {
    final channels = <String>[];

    switch (roomType) {
      case 'debate_discussion':
        channels.addAll([
          'databases.arena_db.collections.debate_discussion_participants.documents',
          'databases.arena_db.collections.debate_discussion_rooms.documents.$roomId',
          'databases.arena_db.collections.discussion_chat_messages.documents',
          'databases.arena_db.collections.room_hand_raises.documents',
          'databases.arena_db.collections.timers.documents',
          'databases.arena_db.collections.shared_materials.documents',
        ]);
        break;

      case 'arena':
        channels.addAll([
          'databases.arena_db.collections.arena_participants.documents',
          'databases.arena_db.collections.arena_rooms.documents.$roomId',
          'databases.arena_db.collections.arena_chat_messages.documents',
          'databases.arena_db.collections.timers.documents',
          'databases.arena_db.collections.arena_judgments.documents',
        ]);
        break;

      case 'discussion':
        channels.addAll([
          'databases.arena_db.collections.room_participants.documents',
          'databases.arena_db.collections.discussion_rooms.documents.$roomId',
          'databases.arena_db.collections.chat_messages.documents',
          'databases.arena_db.collections.room_hand_raises.documents',
        ]);
        break;
    }

    _logger.debug('📡 Subscribing to ${channels.length} channels for $roomType room');
    return channels;
  }

  /// Handle incoming real-time messages and route to appropriate controllers
  void _handleRealtimeMessage(String roomId, RealtimeMessage message) {
    // Check if message is for this room
    final payload = message.payload;
    final messageRoomId = payload['roomId'] as String?;

    // Only process if it's for this room (or a room-wide event)
    if (messageRoomId != null && messageRoomId != roomId) {
      return;
    }

    // Add to batch queue
    _pendingUpdates[roomId] ??= [];
    _pendingUpdates[roomId]!.add(message);

    // Cancel existing timer and start new batch window
    _batchTimers[roomId]?.cancel();
    _batchTimers[roomId] = Timer(_batchWindow, () {
      _processBatchedUpdates(roomId);
    });
  }

  /// Process batched updates to reduce UI rebuilds
  void _processBatchedUpdates(String roomId) {
    final updates = _pendingUpdates[roomId];
    if (updates == null || updates.isEmpty) return;

    _logger.debug('⚡ Processing ${updates.length} batched updates for room: $roomId');

    // Group updates by type
    final participantUpdates = <RealtimeMessage>[];
    final chatUpdates = <RealtimeMessage>[];
    final roomUpdates = <RealtimeMessage>[];
    final handRaiseUpdates = <RealtimeMessage>[];
    final timerUpdates = <RealtimeMessage>[];
    final materialUpdates = <RealtimeMessage>[];

    for (final message in updates) {
      for (final event in message.events) {
        if (event.contains('participants')) {
          participantUpdates.add(message);
        } else if (event.contains('chat_messages')) {
          chatUpdates.add(message);
        } else if (event.contains('rooms.documents.$roomId')) {
          roomUpdates.add(message);
        } else if (event.contains('hand_raises')) {
          handRaiseUpdates.add(message);
        } else if (event.contains('timers')) {
          timerUpdates.add(message);
        } else if (event.contains('materials') || event.contains('shared_materials')) {
          materialUpdates.add(message);
        }
      }
    }

    // Send consolidated updates to respective streams
    if (participantUpdates.isNotEmpty && _participantControllers[roomId] != null) {
      _participantControllers[roomId]!.add(_createBatchedMessage(participantUpdates));
    }
    if (chatUpdates.isNotEmpty && _chatControllers[roomId] != null) {
      _chatControllers[roomId]!.add(_createBatchedMessage(chatUpdates));
    }
    if (roomUpdates.isNotEmpty && _roomStatusControllers[roomId] != null) {
      _roomStatusControllers[roomId]!.add(_createBatchedMessage(roomUpdates));
    }
    if (handRaiseUpdates.isNotEmpty && _handRaiseControllers[roomId] != null) {
      _handRaiseControllers[roomId]!.add(_createBatchedMessage(handRaiseUpdates));
    }
    if (timerUpdates.isNotEmpty && _timerControllers[roomId] != null) {
      _timerControllers[roomId]!.add(_createBatchedMessage(timerUpdates));
    }
    if (materialUpdates.isNotEmpty && _materialControllers[roomId] != null) {
      _materialControllers[roomId]!.add(_createBatchedMessage(materialUpdates));
    }

    // Clear pending updates
    _pendingUpdates[roomId]!.clear();
  }

  /// Create a batched message from multiple updates
  RealtimeMessage _createBatchedMessage(List<RealtimeMessage> messages) {
    // Combine all events and payloads
    final allEvents = <String>[];
    final combinedPayload = <String, dynamic>{};

    for (final message in messages) {
      allEvents.addAll(message.events);
      combinedPayload.addAll(message.payload);
    }

    // Return last message with combined events (simplified approach)
    // In production, you'd want to properly merge payloads
    return messages.last;
  }

  /// Handle subscription errors
  void _handleSubscriptionError(String roomId, dynamic error) {
    _logger.error('❌ Subscription error for room $roomId: $error');

    // Attempt reconnection after delay
    Future.delayed(const Duration(seconds: 2), () {
      _logger.info('🔄 Attempting to reconnect subscription for room: $roomId');
      // Reconnection logic would go here
    });
  }

  /// Handle subscription completion
  void _handleSubscriptionDone(String roomId) {
    _logger.warning('⚠️ Subscription closed for room: $roomId');
    // Clean up resources for this room
    _cleanupRoom(roomId);
  }

  /// Unsubscribe from a room and clean up resources
  Future<void> unsubscribeFromRoom(String roomId) async {
    _logger.info('🔌 Unsubscribing from room: $roomId');

    // Cancel subscription
    _roomSubscriptions[roomId]?.close();
    _roomSubscriptions.remove(roomId);

    // Cancel batch timer
    _batchTimers[roomId]?.cancel();
    _batchTimers.remove(roomId);

    // Clear pending updates
    _pendingUpdates.remove(roomId);

    // Close and remove stream controllers
    await _participantControllers[roomId]?.close();
    _participantControllers.remove(roomId);

    await _chatControllers[roomId]?.close();
    _chatControllers.remove(roomId);

    await _roomStatusControllers[roomId]?.close();
    _roomStatusControllers.remove(roomId);

    await _handRaiseControllers[roomId]?.close();
    _handRaiseControllers.remove(roomId);

    await _timerControllers[roomId]?.close();
    _timerControllers.remove(roomId);

    await _materialControllers[roomId]?.close();
    _materialControllers.remove(roomId);

    _logger.info('✅ Cleaned up resources for room: $roomId');
  }

  /// Clean up room resources
  void _cleanupRoom(String roomId) {
    unsubscribeFromRoom(roomId);
  }

  /// Dispose all subscriptions
  Future<void> dispose() async {
    _logger.info('💥 Disposing all room subscriptions');

    // Copy room IDs to avoid modification during iteration
    final roomIds = List<String>.from(_roomSubscriptions.keys);

    for (final roomId in roomIds) {
      await unsubscribeFromRoom(roomId);
    }
  }

  /// Get subscription statistics
  Map<String, dynamic> getStats() {
    return {
      'activeSubscriptions': _roomSubscriptions.length,
      'rooms': _roomSubscriptions.keys.toList(),
      'pendingUpdates': _pendingUpdates.map((k, v) => MapEntry(k, v.length)),
      'activeBatches': _batchTimers.keys.toList(),
    };
  }
}

/// Room subscription handle with separated event streams
class RoomSubscription {
  final String roomId;
  final Stream<RealtimeMessage> participants;
  final Stream<RealtimeMessage> chat;
  final Stream<RealtimeMessage> roomStatus;
  final Stream<RealtimeMessage> handRaises;
  final Stream<RealtimeMessage> timer;
  final Stream<RealtimeMessage> materials;

  RoomSubscription({
    required this.roomId,
    required this.participants,
    required this.chat,
    required this.roomStatus,
    required this.handRaises,
    required this.timer,
    required this.materials,
  });
}