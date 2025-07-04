import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../../../services/appwrite_service.dart';
import '../utils/arena_constants.dart';
import '../../../core/logging/app_logger.dart';

/// Service for managing real-time arena updates
class ArenaRealtimeService {
  final AppwriteService _appwriteService;
  RealtimeSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _roomStatusChecker;
  
  // Callbacks
  VoidCallback? _onParticipantsChanged;
  VoidCallback? _onRoomDataChanged;
  Function(String)? _onRoomClosed;
  VoidCallback? _onConnectionLost;
  VoidCallback? _onConnectionRestored;
  
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  
  ArenaRealtimeService({required AppwriteService appwriteService})
      : _appwriteService = appwriteService;
  
  /// Subscribe to room updates
  void subscribeToRoom({
    required String roomId,
    VoidCallback? onParticipantsChanged,
    VoidCallback? onRoomDataChanged,
    Function(String)? onRoomClosed,
    VoidCallback? onConnectionLost,
    VoidCallback? onConnectionRestored,
  }) {
    _onParticipantsChanged = onParticipantsChanged;
    _onRoomDataChanged = onRoomDataChanged;
    _onRoomClosed = onRoomClosed;
    _onConnectionLost = onConnectionLost;
    _onConnectionRestored = onConnectionRestored;
    
    _establishSubscription(roomId);
    _startHeartbeat();
    _startRoomStatusChecker(roomId);
  }
  
  /// Establish real-time subscription
  void _establishSubscription(String roomId) {
    try {
      _subscription = _appwriteService.realtime.subscribe([
        'databases.${ArenaConstants.databaseId}.collections.${ArenaConstants.roomParticipantsCollection}.documents',
        'databases.${ArenaConstants.databaseId}.collections.${ArenaConstants.debateRoomsCollection}.documents.$roomId',
      ]);
      
      _subscription?.stream.listen(
        _handleRealtimeMessage,
        onError: _handleConnectionError,
        onDone: _handleConnectionDone,
      );
      
      _isConnected = true;
      _reconnectAttempts = 0;
      AppLogger().info('🔄 Real-time subscription established for room: $roomId');
    } catch (e) {
      AppLogger().error('❌ Failed to establish real-time subscription: $e');
      _scheduleReconnect(roomId);
    }
  }
  
  /// Handle real-time messages
  void _handleRealtimeMessage(RealtimeMessage message) {
    try {
      final event = message.events.isNotEmpty ? message.events.first : '';
      AppLogger().debug('📨 Real-time event: $event');
      
      if (event.contains(ArenaConstants.roomParticipantsCollection)) {
        _onParticipantsChanged?.call();
      } else if (event.contains(ArenaConstants.debateRoomsCollection)) {
        _onRoomDataChanged?.call();
        
        // Check if room was closed
        final payload = message.payload;
        if (payload != null && payload['status'] == ArenaConstants.roomStatusClosed) {
          _onRoomClosed?.call(ArenaConstants.roomStatusClosed);
        }
      }
    } catch (e) {
      AppLogger().warning('⚠️ Error handling real-time message: $e');
    }
  }
  
  /// Handle connection errors
  void _handleConnectionError(dynamic error) {
    AppLogger().warning('🔌 Real-time connection error: $error');
    _isConnected = false;
    _onConnectionLost?.call();
    
    // Don't immediately reconnect to avoid spam
    Future.delayed(ArenaConstants.realtimeReconnectDelay, () {
      if (!_isConnected && _reconnectAttempts < ArenaConstants.maxRetryAttempts) {
        // Will be handled by heartbeat
      }
    });
  }
  
  /// Handle connection done
  void _handleConnectionDone() {
    AppLogger().info('🔌 Real-time connection closed');
    _isConnected = false;
    _onConnectionLost?.call();
  }
  
  /// Schedule reconnection
  void _scheduleReconnect(String roomId) {
    if (_reconnectAttempts >= ArenaConstants.maxRetryAttempts) {
      AppLogger().error('❌ Max reconnection attempts reached');
      return;
    }
    
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2); // Exponential backoff
    
    AppLogger().info('🔄 Scheduling reconnection attempt $_reconnectAttempts in ${delay.inSeconds}s');
    
    Timer(delay, () {
      if (!_isConnected) {
        _establishSubscription(roomId);
      }
    });
  }
  
  /// Start heartbeat to monitor connection
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(ArenaConstants.heartbeatInterval, (timer) {
      if (!_isConnected) {
        AppLogger().warning('💓 Heartbeat detected disconnection');
        _onConnectionLost?.call();
      } else {
        AppLogger().debug('💓 Heartbeat: Connection OK');
      }
    });
  }
  
  /// Start room status checker
  void _startRoomStatusChecker(String roomId) {
    _roomStatusChecker = Timer.periodic(ArenaConstants.roomStatusCheckInterval, (timer) async {
      try {
        final roomData = await _appwriteService.databases.getDocument(
          databaseId: ArenaConstants.databaseId,
          collectionId: ArenaConstants.debateRoomsCollection,
          documentId: roomId,
        );
        
        final status = roomData.data['status'];
        if (status == ArenaConstants.roomStatusClosed || status == ArenaConstants.roomStatusCompleted) {
          timer.cancel();
          _onRoomClosed?.call(status);
          AppLogger().info('🏁 Room status checker detected room closure: $status');
        }
      } catch (e) {
        AppLogger().warning('⚠️ Room status check failed: $e');
      }
    });
  }
  
  /// Force refresh connection
  void refreshConnection(String roomId) {
    AppLogger().info('🔄 Force refreshing real-time connection');
    _subscription?.close();
    _isConnected = false;
    _reconnectAttempts = 0;
    _establishSubscription(roomId);
  }
  
  /// Check connection status
  bool get isConnected => _isConnected;
  
  /// Get connection info
  Map<String, dynamic> getConnectionInfo() {
    return {
      'isConnected': _isConnected,
      'reconnectAttempts': _reconnectAttempts,
      'hasSubscription': _subscription != null,
      'hasHeartbeat': _heartbeatTimer?.isActive ?? false,
      'hasRoomChecker': _roomStatusChecker?.isActive ?? false,
    };
  }
  
  /// Simulate connection test
  Future<bool> testConnection() async {
    try {
      // Try a simple database operation to test connectivity
      await _appwriteService.databases.listDocuments(
        databaseId: ArenaConstants.databaseId,
        collectionId: ArenaConstants.debateRoomsCollection,
        queries: [],
      );
      return true;
    } catch (e) {
      AppLogger().warning('🔌 Connection test failed: $e');
      return false;
    }
  }
  
  /// Dispose resources
  void dispose() {
    AppLogger().info('🧹 Disposing real-time service');
    
    _subscription?.close();
    _subscription = null;
    
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    _roomStatusChecker?.cancel();
    _roomStatusChecker = null;
    
    _isConnected = false;
    _reconnectAttempts = 0;
    
    // Clear callbacks
    _onParticipantsChanged = null;
    _onRoomDataChanged = null;
    _onRoomClosed = null;
    _onConnectionLost = null;
    _onConnectionRestored = null;
    
    AppLogger().debug('✅ Real-time service disposed');
  }
}